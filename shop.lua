-- shop.lua
-- Manages the game's shop logic: generating offers, handling purchases, restocking.

local GameData = require("data")
local Employee = require("employee") -- For creating new employee instances using Employee:new()
local Names = require("names")
local Shop = {}

function Shop:getModifiedUpgradeCost(upgradeData, hiredEmployees)
    local cost = upgradeData.cost
    if hiredEmployees then
        for _, emp in ipairs(hiredEmployees) do
            if emp.special and emp.special.type == 'boost_other_remotes' and emp.special.upgrade_cost_increase then
                local costMultiplier = emp.special.upgrade_cost_increase
                if emp.special.scales_with_level then
                    costMultiplier = 1 + ((costMultiplier - 1) * (emp.level or 1))
                end
                cost = math.floor(cost * costMultiplier)
            end
        end
    end
    return cost
end

function Shop:populateOffers(gameState, currentShopOffers, purchasedPermanentUpgrades, forceRestock)
    local numEmployeeSlots = 2 -- CHANGED: Reduced from 3 to 2
    local numDecorationSlots = 1 -- NEW: Added decoration slot

    if forceRestock then
        print("Shop:populateOffers - Force Restock Initiated.")
        
        -- Handle employee offers
        local newEmployeeOffers = {}
        if currentShopOffers.employees then
            for i = 1, numEmployeeSlots do
                local existingOffer = currentShopOffers.employees[i]
                if existingOffer and (existingOffer.sold or existingOffer.isLocked) then 
                    table.insert(newEmployeeOffers, existingOffer) 
                else 
                    table.insert(newEmployeeOffers, self:_generateRandomEmployeeOffer(gameState))
                end
            end
        end
        currentShopOffers.employees = newEmployeeOffers

        -- Handle decoration offers
        local newDecorationOffers = {}
        if currentShopOffers.decorations then
            for i = 1, numDecorationSlots do
                local existingOffer = currentShopOffers.decorations[i]
                if existingOffer and (existingOffer.sold or existingOffer.isLocked) then
                    table.insert(newDecorationOffers, existingOffer)
                else
                    table.insert(newDecorationOffers, self:_generateRandomDecorationOffer(gameState))
                end
            end
        else
            for i = 1, numDecorationSlots do
                table.insert(newDecorationOffers, self:_generateRandomDecorationOffer(gameState))
            end
        end
        currentShopOffers.decorations = newDecorationOffers

        -- Handle upgrade offers
        if not (currentShopOffers.upgrade and (currentShopOffers.upgrade.sold or currentShopOffers.upgrade.isLocked)) then
            currentShopOffers.upgrade = self:_generateRandomUpgradeOffer(purchasedPermanentUpgrades)
        end
        
    else
        if currentShopOffers.restockCountThisWeek == 0 then
            print("Shop:populateOffers - Generating new shop offers for the week.")
            
            -- Handle preserved employees
            local preservedEmployees = {}
            if currentShopOffers.employees then
                for _, offer in ipairs(currentShopOffers.employees) do
                    if offer and offer.isLocked then
                        table.insert(preservedEmployees, offer)
                    end
                end
            end
            
            currentShopOffers.employees = preservedEmployees
            while #currentShopOffers.employees < numEmployeeSlots do
                table.insert(currentShopOffers.employees, self:_generateRandomEmployeeOffer(gameState))
            end

            -- Handle preserved decorations
            local preservedDecorations = {}
            if currentShopOffers.decorations then
                for _, offer in ipairs(currentShopOffers.decorations) do
                    if offer and offer.isLocked then
                        table.insert(preservedDecorations, offer)
                    end
                end
            end
            
            currentShopOffers.decorations = preservedDecorations
            while #currentShopOffers.decorations < numDecorationSlots do
                table.insert(currentShopOffers.decorations, self:_generateRandomDecorationOffer(gameState))
            end

            -- Handle upgrade offers
            if not (currentShopOffers.upgrade and currentShopOffers.upgrade.isLocked) then
                currentShopOffers.upgrade = self:_generateRandomUpgradeOffer(purchasedPermanentUpgrades)
            end
        end
    end

    local eventArgs = { offers = currentShopOffers.employees, guaranteeRareOrLegendary = false }
    require("effects_dispatcher").dispatchEvent("onPopulateShop", gameState, eventArgs, { modal = modal })
    
    if eventArgs.guaranteeRareOrLegendary then
        local hasRareOrLegendary = false
        for _, offer in ipairs(eventArgs.offers) do
            if offer.rarity == 'Rare' or offer.rarity == 'Legendary' then
                hasRareOrLegendary = true
                break
            end
        end
        
        if not hasRareOrLegendary and #eventArgs.offers > 0 then
            eventArgs.offers[1] = self:_generateRandomEmployeeOfMinRarity(gameState, 'Rare')
        end
    end
    
    currentShopOffers.employees = eventArgs.offers
end

-- NEW: Generate random decoration offer
function Shop:_generateRandomDecorationOffer(gameState)
    if #GameData.ALL_DESK_DECORATIONS == 0 then
        print("Warning (Shop:_generateRandomDecorationOffer): No desk decorations defined.")
        return nil
    end

    local weights = { Common = 10, Uncommon = 5, Rare = 2, Legendary = 1 }
    local weightedPool = {}
    
    for _, decorationData in ipairs(GameData.ALL_DESK_DECORATIONS) do
        local rarity = decorationData.rarity or 'Common'
        local weight = weights[rarity] or 1
        for _ = 1, weight do
            table.insert(weightedPool, decorationData)
        end
    end

    if #weightedPool == 0 then
        print("Warning (Shop:_generateRandomDecorationOffer): Weighted pool is empty.")
        return nil
    end
    
    local randomIndex = love.math.random(#weightedPool)
    local chosenDecorationData = weightedPool[randomIndex]
    
    local decorationOffer = self:_generateDecorationOfferFromData(chosenDecorationData)
    decorationOffer.displayCost = self:getFinalDecorationCost(gameState, decorationOffer)

    return decorationOffer
end

-- NEW: Generate decoration offer from base data
function Shop:_generateDecorationOfferFromData(chosenDecorationData)
    local decorationOffer = {}

    -- Copy all properties from base decoration data
    for k, v in pairs(chosenDecorationData) do 
        if type(v) == "table" then
            decorationOffer[k] = {}
            for nk, nv in pairs(v) do decorationOffer[k][nk] = nv end
        else
            decorationOffer[k] = v 
        end
    end 
    
    -- Add shop-specific properties
    decorationOffer.instanceId = string.format("shop-decoration-%s-%d-%.4f", decorationOffer.id, love.math.random(100000,999999), love.timer.getTime())
    decorationOffer.sold = false 
    
    print("Generated shop decoration offer: " .. decorationOffer.name .. ", Rarity: " .. decorationOffer.rarity .. ", Cost: $" .. decorationOffer.cost)
    return decorationOffer
end

-- NEW: Calculate final decoration cost (with potential modifiers)
function Shop:getFinalDecorationCost(gameState, decorationOffer)
    if not decorationOffer then return 0 end

    local eventArgs = { 
        finalCost = decorationOffer.cost, 
        decorationRarity = decorationOffer.rarity 
    }
    require("effects_dispatcher").dispatchEvent("onCalculateDecorationCost", gameState, eventArgs, { modal = modal })
    
    return eventArgs.finalCost
end

function Shop:getFinalHiringCost(gameState, employeeOffer, purchasedUpgrades)
    if not employeeOffer then return 0 end

    local eventArgs = { 
        finalCost = employeeOffer.hiringBonus, 
        employeeRarity = employeeOffer.rarity 
    }
    require("effects_dispatcher").dispatchEvent("onCalculateHiringCost", gameState, eventArgs, { modal = modal })
    
    return eventArgs.finalCost
end

function Shop:_generateRandomEmployeeOffer(gameState)
    if #GameData.BASE_EMPLOYEE_CARDS == 0 then
        print("Warning (Shop:_generateRandomEmployeeOffer): No base employee cards defined.")
        return nil
    end

    local weights = { Common = 10, Uncommon = 5, Rare = 2, Legendary = 1 }
    local weightedPool = {}
    for _, cardData in ipairs(GameData.BASE_EMPLOYEE_CARDS) do
        if not cardData.isNotPurchasable then
            local rarity = cardData.rarity or 'Common'
            local weight = weights[rarity] or 1
            for _ = 1, weight do
                table.insert(weightedPool, cardData)
            end
        end
    end

    if #weightedPool == 0 then
        print("Warning (Shop:_generateRandomEmployeeOffer): Weighted pool is empty. No valid employees to offer.")
        return nil
    end
    
    local randomIndex = love.math.random(#weightedPool)
    local chosenBaseCardData = weightedPool[randomIndex]
    
    local variant = "standard"
    if chosenBaseCardData.forceVariant then
        variant = chosenBaseCardData.forceVariant
    else
        local rand = love.math.random() 
        local hasSubsidizedHousing = self:isUpgradePurchased(gameState.purchasedPermanentUpgrades, 'subsidized_housing')

        if rand < 0.075 then
            variant = "holo"
        elseif rand < 0.15 then
            variant = "foil"
        elseif rand < 0.30 and not hasSubsidizedHousing then
            variant = "remote"
        end
    end
    
    local shopOffer = self:_generateEmployeeOfferFromCard(chosenBaseCardData, variant)
    shopOffer.displayCost = self:getFinalHiringCost(gameState, shopOffer, gameState.purchasedPermanentUpgrades)

    return shopOffer
end

function Shop:_generateRandomEmployeeOfRarity(gameState, rarity)
    local availableCards = {}
    for _, cardData in ipairs(GameData.BASE_EMPLOYEE_CARDS) do
        if cardData.rarity == rarity then
            table.insert(availableCards, cardData)
        end
    end

    if #availableCards > 0 then
        local chosenCard = availableCards[love.math.random(#availableCards)]
        -- For now, new employees from this effect are always standard variant
        return self:_generateEmployeeOfferFromCard(chosenCard, "standard")
    end

    -- Fallback if no employees of that rarity exist
    print("Warning: Could not find any employees of rarity '" .. rarity .. "' to generate.")
    return self:_generateRandomEmployeeOffer(gameState)
end

function Shop:_generateRandomEmployeeOfMinRarity(gameState, minRarity)
    local rarities = { Common = 1, Uncommon = 2, Rare = 3, Legendary = 4 }
    local minRarityLevel = rarities[minRarity] or 3 -- Default to Rare if invalid
    
    local validCards = {}
    for _, cardData in ipairs(GameData.BASE_EMPLOYEE_CARDS) do
        local cardRarityLevel = rarities[cardData.rarity] or 1
        if cardRarityLevel >= minRarityLevel then
            table.insert(validCards, cardData)
        end
    end

    if #validCards > 0 then
        local chosenCard = validCards[love.math.random(#validCards)]
        -- For now, new employees from this effect are always standard variant
        local variant = chosenCard.forceVariant or "standard"
        return self:_generateEmployeeOfferFromCard(chosenCard, variant)
    end
    
    -- Fallback in case there are no rare/legendary cards
    return self:_generateRandomEmployeeOffer(gameState)
end

function Shop:_generateRandomUpgradeOffer(purchasedPermanentUpgrades)
    local weights = { Common = 12, Uncommon = 6, Rare = 3, Legendary = 1 }
    local weightedPool = {}

    local hasLegendaryOverhaul = self:isUpgradePurchased(purchasedPermanentUpgrades, 'borg_hivemind') or 
                                 self:isUpgradePurchased(purchasedPermanentUpgrades, 'corporate_personhood')
    local overhaulIds = { borg_hivemind = true, corporate_personhood = true, multiverse_merger = true }


    for _, upgData in ipairs(GameData.ALL_UPGRADES) do
        local isAlreadyPermanentAndUnique = false
        if purchasedPermanentUpgrades then
            for _, purchasedId in ipairs(purchasedPermanentUpgrades) do
                if upgData.id == purchasedId then
                    local nonUniqueTypes = { ['budget_add_flat'] = true, ['one_time_team_focus_boost_multiplier'] = true, ['one_time_workload_reduction_percent'] = true, ['temporary_focus_boost_all'] = true, ['code_debt'] = true }
                    
                    -- If the upgrade has no effect OR its effect type is not in the non-unique list, treat it as unique.
                    if not (upgData.effect and nonUniqueTypes[upgData.effect.type]) then
                        isAlreadyPermanentAndUnique = true 
                    end
                    break
                end
            end
        end

        local isBlockedOverhaul = hasLegendaryOverhaul and overhaulIds[upgData.id]
        if not isAlreadyPermanentAndUnique and not isBlockedOverhaul then
            local rarity = upgData.rarity or 'Common'
            local weight = weights[rarity] or 1
            for _ = 1, weight do
                table.insert(weightedPool, upgData)
            end
        end
    end

    if #weightedPool > 0 then
        local randomIndex = love.math.random(#weightedPool)
        local chosenUpgradeData = weightedPool[randomIndex]
        
        local upgradeOffer = {}
        for k,v in pairs(chosenUpgradeData) do upgradeOffer[k] = v end
        upgradeOffer.sold = false
        upgradeOffer.instanceId = "shop-upgrade-" .. upgradeOffer.id .. "-" ..love.timer.getTime()
        
        return upgradeOffer
    end

    return nil
end

function Shop:markOfferSold(currentShopOffers, employeeShopInstanceIdToMark, upgradeDataToMark, decorationInstanceIdToMark)
    if employeeShopInstanceIdToMark and currentShopOffers.employees then
        local found = false
        for i, offer in ipairs(currentShopOffers.employees) do
            if offer and offer.instanceId == employeeShopInstanceIdToMark then
                print("Shop:markOfferSold: Found employee offer: " .. offer.name .. " (ID: " .. offer.instanceId .. "). Current sold: " .. tostring(offer.sold))
                offer.sold = true 
                print("Shop:markOfferSold: Marked as sold. New status: " .. tostring(currentShopOffers.employees[i].sold))
                found = true
                return
            end
        end
        if not found then
            print("ERROR (Shop:markOfferSold): Employee shop offer NOT FOUND. InstanceID sought: " .. employeeShopInstanceIdToMark)
            print("Current shop offers for employees:")
            for i, off in ipairs(currentShopOffers.employees) do
                if off then print("  - Slot " .. i .. ": " .. off.name .. ", ID: " .. off.instanceId .. ", Sold: " .. tostring(off.sold))
                else print("  - Slot " .. i .. ": nil") end
            end
        end
    elseif upgradeDataToMark and currentShopOffers.upgrade then
        if currentShopOffers.upgrade.instanceId == upgradeDataToMark.instanceId or currentShopOffers.upgrade.id == upgradeDataToMark.id then
             print("Shop:markOfferSold: Found upgrade offer: " .. currentShopOffers.upgrade.name .. ". Current sold: " .. tostring(currentShopOffers.upgrade.sold))
            currentShopOffers.upgrade.sold = true
            print("Shop:markOfferSold: Marked as sold. New status: " .. tostring(currentShopOffers.upgrade.sold))
        else
            print("ERROR (Shop:markOfferSold): Upgrade shop offer ID did not match. Sought based on passed data, current shop upgrade ID: " .. (currentShopOffers.upgrade.instanceId or currentShopOffers.upgrade.id))
        end
    elseif decorationInstanceIdToMark and currentShopOffers.decorations then
        -- NEW: Handle decoration sold marking
        local found = false
        for i, offer in ipairs(currentShopOffers.decorations) do
            if offer and offer.instanceId == decorationInstanceIdToMark then
                print("Shop:markOfferSold: Found decoration offer: " .. offer.name .. " (ID: " .. offer.instanceId .. ")")
                offer.sold = true
                found = true
                return
            end
        end
        if not found then
            print("ERROR (Shop:markOfferSold): Decoration shop offer NOT FOUND. InstanceID sought: " .. decorationInstanceIdToMark)
        end
    else
        print("ERROR (Shop:markOfferSold): Called with invalid parameters or empty shop offers structure.")
    end
end

-- NEW: Buy decoration function
function Shop:buyDecoration(gameState, decorationIdToBuy)
    local decorationData = nil
    
    if gameState.currentShopOffers.decorations then
        for _, decorationOffer in ipairs(gameState.currentShopOffers.decorations) do
            if decorationOffer and decorationOffer.id == decorationIdToBuy then
                decorationData = decorationOffer
                break
            end
        end
    end

    if not decorationData or decorationData.sold then
        return false, "Selected decoration not available or already purchased this turn."
    end
    
    local finalCost = self:getFinalDecorationCost(gameState, decorationData)
    if gameState.budget < finalCost then
        return false, "Not enough budget. Need $" .. finalCost .. "."
    end
    
    gameState.budget = gameState.budget - finalCost
    
    -- Add to owned decorations (for now, we'll add to inventory for later placement)
    local decorationInstance = {}
    for k, v in pairs(decorationData) do decorationInstance[k] = v end
    decorationInstance.instanceId = string.format("owned-decoration-%s-%d-%.4f", decorationData.id, love.math.random(100000,999999), love.timer.getTime())
    table.insert(gameState.ownedDecorations, decorationInstance)
    
    self:markOfferSold(gameState.currentShopOffers, nil, nil, decorationData.instanceId)
    
    _G.buildUIComponents()
    
    return true, decorationData.name .. " purchased! (Added to inventory for placement)"
end

function Shop:attemptRestock(gameState)
    local restockCost = GameData.BASE_RESTOCK_COST * (2 ^ gameState.currentShopOffers.restockCountThisWeek)
    
    local eventArgs = { finalCost = restockCost }
    require("effects_dispatcher").dispatchEvent("onCalculateRestockCost", gameState, eventArgs, { modal = modal })
    restockCost = eventArgs.finalCost

    if gameState.budget < restockCost then
        return false, "Not enough budget to restock. Need $" .. restockCost
    end
    local hasUnsoldItem = false
    if gameState.currentShopOffers.employees then
        for _, empOffer in ipairs(gameState.currentShopOffers.employees) do
            if empOffer and not empOffer.sold and not empOffer.isLocked then hasUnsoldItem = true; break end
        end
    end
    if not hasUnsoldItem and gameState.currentShopOffers.upgrade and not gameState.currentShopOffers.upgrade.sold and not gameState.currentShopOffers.upgrade.isLocked then
        hasUnsoldItem = true
    end
    -- NEW: Check decorations for unsold items
    if not hasUnsoldItem and gameState.currentShopOffers.decorations then
        for _, decorationOffer in ipairs(gameState.currentShopOffers.decorations) do
            if decorationOffer and not decorationOffer.sold and not decorationOffer.isLocked then hasUnsoldItem = true; break end
        end
    end
    if not hasUnsoldItem then
        return false, "All available shop offers are locked or have been purchased. Nothing to restock."
    end
    gameState.budget = gameState.budget - restockCost
    gameState.currentShopOffers.restockCountThisWeek = gameState.currentShopOffers.restockCountThisWeek + 1
    self:populateOffers(gameState, gameState.currentShopOffers, gameState.purchasedPermanentUpgrades, true)
    
    _G.buildUIComponents()

    return true, "Shop restocked! Unsold items have been replaced."
end

function Shop:buyUpgrade(gameState, upgradeIdToBuy) 
    local upgradeData = nil
    
    if gameState.currentShopOffers.upgrade and gameState.currentShopOffers.upgrade.id == upgradeIdToBuy then
        upgradeData = gameState.currentShopOffers.upgrade
    end

    if not upgradeData or upgradeData.sold then
        return false, "Selected upgrade not available or already purchased this turn."
    end
    
    local finalCost = self:getModifiedUpgradeCost(upgradeData, gameState.hiredEmployees)
    if gameState.budget < finalCost then
        return false, "Not enough budget. Need $" .. finalCost .. "."
    end
    
    local isPermanentAndUnique = true
    if upgradeData.effect then
        local nonUniqueTypes = {
            ['budget_add_flat'] = true,
            ['one_time_team_focus_boost_multiplier'] = true,
            ['one_time_workload_reduction_percent'] = true,
            ['temporary_focus_boost_all'] = true,
            ['code_debt'] = true,
            ['multiverse_merger'] = true
        }
        if nonUniqueTypes[upgradeData.effect.type] then
            isPermanentAndUnique = false
        end
    end

    if isPermanentAndUnique and self:isUpgradePurchased(gameState.purchasedPermanentUpgrades, upgradeData.id) then
         return false, "This type of permanent upgrade has already been acquired."
    end

    gameState.budget = gameState.budget - finalCost
    table.insert(gameState.purchasedPermanentUpgrades, upgradeData.id)
    
    if upgradeData.listeners and upgradeData.listeners.onPurchase then
        require("effects_dispatcher").dispatchEvent("onPurchase", gameState, { modal = modal }, { upgrade = upgradeData })
    end
    
    _G.buildUIComponents()
    
    return true, upgradeData.name .. " purchased!"
end

function Shop:isUpgradePurchased(purchasedUpgradesList, upgradeId)
    if not purchasedUpgradesList then return false end
    for _, id in ipairs(purchasedUpgradesList) do
        if id == upgradeId then return true end
    end
    return false
end

function Shop:forceAddEmployeeOffer(currentShopOffers, employeeId, variant)
    local baseCard = nil
    for _, cardData in ipairs(GameData.BASE_EMPLOYEE_CARDS) do
        if cardData.id == employeeId then
            baseCard = cardData
            break
        end
    end
    
    if not baseCard then
        print("DEBUG ERROR: Could not find employee with id: " .. tostring(employeeId))
        return
    end

    local newOffer = self:_generateEmployeeOfferFromCard(baseCard, variant)
    
    if not currentShopOffers.employees then currentShopOffers.employees = {} end

    currentShopOffers.employees[1] = newOffer
    print("DEBUG: Forced " .. newOffer.name .. " (" .. variant .. ") into shop slot 1.")
end

function Shop:forceAddUpgradeOffer(currentShopOffers, upgradeId)
    local upgradeData = nil
    for _, upg in ipairs(GameData.ALL_UPGRADES) do
        if upg.id == upgradeId then
            upgradeData = upg
            break
        end
    end

    if not upgradeData then
        print("DEBUG ERROR: Could not find upgrade with id: " .. tostring(upgradeId))
        return
    end

    local upgradeOffer = {}
    for k,v in pairs(upgradeData) do upgradeOffer[k] = v end
    upgradeOffer.sold = false
    upgradeOffer.instanceId = "shop-upgrade-" .. upgradeOffer.id .. "-" ..love.timer.getTime()
    
    currentShopOffers.upgrade = upgradeOffer
    print("DEBUG: Forced upgrade '" .. upgradeOffer.name .. "' into shop.")
end

-- NEW: Force add decoration offer for debugging
function Shop:forceAddDecorationOffer(currentShopOffers, decorationId)
    local decorationData = nil
    for _, decoration in ipairs(GameData.ALL_DESK_DECORATIONS) do
        if decoration.id == decorationId then
            decorationData = decoration
            break
        end
    end

    if not decorationData then
        print("DEBUG ERROR: Could not find decoration with id: " .. tostring(decorationId))
        return
    end

    local decorationOffer = self:_generateDecorationOfferFromData(decorationData)
    
    if not currentShopOffers.decorations then currentShopOffers.decorations = {} end

    currentShopOffers.decorations[1] = decorationOffer
    print("DEBUG: Forced decoration '" .. decorationOffer.name .. "' into shop slot 1.")
end

function Shop:_generateEmployeeOfferFromCard(chosenBaseCardData, variant)
    local shopOffer = {}

    for k,v in pairs(chosenBaseCardData) do 
        if type(v) == "table" then
            shopOffer[k] = {}
            for nk, nv in pairs(v) do shopOffer[k][nk] = nv end
        else
            shopOffer[k] = v 
        end
    end 
    
    shopOffer.variant = variant or "standard"

    local firstName = Names.firstNames[love.math.random(#Names.firstNames)]
    local lastName = Names.lastNames[love.math.random(#Names.lastNames)]
    shopOffer.fullName = firstName .. " " .. lastName

    shopOffer.instanceId = string.format("shop-%s-%d-%.4f", shopOffer.id, love.math.random(100000,999999), love.timer.getTime())
    shopOffer.level = 1 
    shopOffer.sold = false 

    if shopOffer.variant == 'remote' then
        shopOffer.hiringBonus = math.floor(chosenBaseCardData.hiringBonus * GameData.REMOTE_HIRING_BONUS_MODIFIER)
        shopOffer.weeklySalary = math.floor(chosenBaseCardData.weeklySalary * GameData.REMOTE_SALARY_MODIFIER)
    end
    
    print("Generated shop employee offer: " .. shopOffer.fullName .. " (" .. shopOffer.name .. "), Rarity: " .. shopOffer.rarity .. ", Variant: " .. shopOffer.variant)
    return shopOffer
end

return Shop