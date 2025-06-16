-- shop.lua
-- Manages the game's shop logic: generating offers, handling purchases, restocking.

local GameData = require("data")
local Employee = require("employee") -- For creating new employee instances using Employee:new()
local Names = require("names")
local Shop = {}

local function tableContains(tbl, value)
    for _, v in ipairs(tbl) do
        if v == value then return true end
    end
    return false
end

local function _shallowCopy(sourceTable)
    if not sourceTable then return {} end
    local newTable = {}
    for k, v in pairs(sourceTable) do
        if type(v) == "table" then
            newTable[k] = {}
            for nk, nv in pairs(v) do newTable[k][nk] = nv end
        else
            newTable[k] = v
        end
    end
    return newTable
end

local function _populateOfferList(self, offerList, numSlots, forceRestock, generator, ...)
    local generatorArgs = {...}
    local newOffers = {}
    if forceRestock then
        for i = 1, numSlots do
            local existingOffer = offerList and offerList[i]
            if existingOffer and (existingOffer.sold or existingOffer.isLocked) then
                table.insert(newOffers, existingOffer)
            else
                table.insert(newOffers, generator(self, unpack(generatorArgs)))
            end
        end
    else -- New week logic
        local preservedOffers = {}
        if offerList then
            for _, offer in ipairs(offerList) do
                if offer and offer.isLocked then
                    table.insert(preservedOffers, offer)
                end
            end
        end
        newOffers = preservedOffers
        while #newOffers < numSlots do
            table.insert(newOffers, generator(self, unpack(generatorArgs)))
        end
    end
    return newOffers
end

function Shop:forceAddItemOffer(itemType, itemId, currentShopOffers, variant)
    local masterList
    if itemType == 'employee' then
        masterList = GameData.BASE_EMPLOYEE_CARDS
    elseif itemType == 'upgrade' then
        masterList = GameData.ALL_UPGRADES
    elseif itemType == 'decoration' then
        masterList = GameData.ALL_DESK_DECORATIONS
    else
        return
    end

    local itemData = nil
    for _, item in ipairs(masterList) do
        if item.id == itemId then
            itemData = item
            break
        end
    end

    if not itemData then
        print("DEBUG ERROR: Could not find " .. itemType .. " with id: " .. tostring(itemId))
        return
    end

    if itemType == 'employee' then
        local newOffer = self:_generateEmployeeOfferFromCard(itemData, variant)
        if not currentShopOffers.employees then currentShopOffers.employees = {} end
        -- FIX: Use direct assignment to replace the item in the first slot
        currentShopOffers.employees[1] = newOffer
        print("DEBUG: Forced " .. newOffer.name .. " (" .. (variant or "standard") .. ") into shop slot 1.")
    elseif itemType == 'upgrade' then
        local upgradeOffer = _shallowCopy(itemData)
        upgradeOffer.sold = false
        upgradeOffer.instanceId = "shop-upgrade-" .. upgradeOffer.id .. "-" ..love.timer.getTime()
        if not currentShopOffers.upgrades then currentShopOffers.upgrades = {} end
        currentShopOffers.upgrades[1] = upgradeOffer
        print("DEBUG: Forced upgrade '" .. upgradeOffer.name .. "' into shop.")
    elseif itemType == 'decoration' then
        local decorationOffer = self:_generateDecorationOfferFromData(itemData)
        if not currentShopOffers.decorations then currentShopOffers.decorations = {} end
        -- FIX: Use direct assignment to replace the item in the first slot
        currentShopOffers.decorations[1] = decorationOffer
        print("DEBUG: Forced decoration '" .. decorationOffer.name .. "' into shop slot 1.")
    end
end

local function _findAndMarkSold(offerList, targetInstanceId, itemType)
    if not offerList or not targetInstanceId then return false end

    for i, offer in ipairs(offerList) do
        if offer and offer.instanceId == targetInstanceId then
            print("Shop:markOfferSold: Found " .. itemType .. " offer: " .. offer.name .. " (ID: " .. offer.instanceId .. ").")
            offer.sold = true
            return true
        end
    end
    return false
end



local function _generateWeightedRandomItem(sourceList, weights, filterFunc)
    local weightedPool = {}
    if not sourceList then return nil end

    for _, itemData in ipairs(sourceList) do
        -- Apply the filter function if it exists and evaluates to true
        if not filterFunc or filterFunc(itemData) then
            local rarity = itemData.rarity or 'Common'
            local weight = weights[rarity] or 1
            for _ = 1, weight do
                table.insert(weightedPool, itemData)
            end
        end
    end

    if #weightedPool == 0 then
        return nil
    end
    
    local randomIndex = love.math.random(#weightedPool)
    return weightedPool[randomIndex]
end

function Shop:getModifiedUpgradeCost(upgradeData, hiredEmployees)
    local eventArgs = {
        cost = upgradeData.cost,
        upgradeData = upgradeData
    }
    require("effects_dispatcher").dispatchEvent("onCalculateUpgradeCost", {hiredEmployees = hiredEmployees}, eventArgs)
    return math.floor(eventArgs.cost)
end

function Shop:_populateEmployeeOffers(gameState, currentShopOffers, numEmployeeSlots, forceRestock)
    currentShopOffers.employees = _populateOfferList(self, currentShopOffers.employees, numEmployeeSlots, forceRestock, self._generateRandomEmployeeOffer, gameState)
end

function Shop:_populateDecorationOffers(gameState, currentShopOffers, numDecorationSlots, forceRestock)
    currentShopOffers.decorations = _populateOfferList(self, currentShopOffers.decorations, numDecorationSlots, forceRestock, self._generateRandomDecorationOffer, gameState)
end

function Shop:_populateUpgradesOffer(gameState, currentShopOffers, forceRestock)
    local numUpgradeSlots = 1 -- Define the number of slots here for clarity
    currentShopOffers.upgrades = _populateOfferList(self, currentShopOffers.upgrades, numUpgradeSlots, forceRestock, self._generateRandomUpgradeOffer, gameState.purchasedPermanentUpgrades)
end

function Shop:populateOffers(gameState, currentShopOffers, purchasedPermanentUpgrades, forceRestock)
    local numEmployeeSlots = 2
    local numDecorationSlots = 1

    -- If this is the first population of the week, there's no need to force a restock.
    -- The helpers will generate fresh items for any non-locked slots.
    local isFirstPopulation = currentShopOffers.restockCountThisWeek == 0
    if isFirstPopulation then
        forceRestock = false
    end

    print("Shop:populateOffers - Populating offers. Force Restock: " .. tostring(forceRestock))

    self:_populateEmployeeOffers(gameState, currentShopOffers, numEmployeeSlots, forceRestock)
    self:_populateDecorationOffers(gameState, currentShopOffers, numDecorationSlots, forceRestock)
    self:_populateUpgradesOffer(gameState, currentShopOffers, forceRestock)
    
    -- After populating, dispatch event for listeners like Headhunter to potentially modify the offers.
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
            -- Replace the first offer with a guaranteed rare+
            eventArgs.offers[1] = self:_generateRandomEmployeeOfMinRarity(gameState, 'Rare')
        end
    end
    
    currentShopOffers.employees = eventArgs.offers
end

function Shop:getFinalRestockCost(gameState)
    local restockCost = GameData.BASE_RESTOCK_COST * (2 ^ (gameState.currentShopOffers.restockCountThisWeek or 0))
    
    local eventArgs = { finalCost = restockCost }
    require("effects_dispatcher").dispatchEvent("onCalculateRestockCost", gameState, {}, { modal = modal })
    
    return eventArgs.finalCost
end

function Shop:_generateRandomDecorationOffer(gameState)
    if #GameData.ALL_DESK_DECORATIONS == 0 then
        print("Warning (Shop:_generateRandomDecorationOffer): No desk decorations defined.")
        return nil
    end

    local weights = { Common = 10, Uncommon = 5, Rare = 2, Legendary = 1 }
    
    local chosenDecorationData = _generateWeightedRandomItem(GameData.ALL_DESK_DECORATIONS, weights)

    if not chosenDecorationData then
        print("Warning (Shop:_generateRandomDecorationOffer): No valid desk decorations to offer.")
        return nil
    end
    
    local decorationOffer = self:_generateDecorationOfferFromData(chosenDecorationData)
    decorationOffer.displayCost = self:getFinalDecorationCost(gameState, decorationOffer)

    return decorationOffer
end

-- NEW: Generate decoration offer from base data
function Shop:_generateDecorationOfferFromData(chosenDecorationData)
    local decorationOffer = _shallowCopy(chosenDecorationData)
    
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
    
    -- Filter out employees who are not purchasable
    local filterFunc = function(cardData)
        return not cardData.isNotPurchasable
    end
    
    local chosenBaseCardData = _generateWeightedRandomItem(GameData.BASE_EMPLOYEE_CARDS, weights, filterFunc)

    if not chosenBaseCardData then
        print("Warning (Shop:_generateRandomEmployeeOffer): Weighted pool is empty. No valid employees to offer.")
        return nil
    end
    
    local possibleVariants = {"standard", "embossed", "laminated", "remote"}
    local eventArgs = { possibleVariants = possibleVariants, baseCard = chosenBaseCardData }
    require("effects_dispatcher").dispatchEvent("onGenerateEmployeeVariant", gameState, {}, eventArgs)
    
    local variant = "standard"
    if chosenBaseCardData.forceVariant then
        variant = chosenBaseCardData.forceVariant
    else
        local rand = love.math.random() 
        if rand < 0.075 and tableContains(eventArgs.possibleVariants, "embossed") then
            variant = "embossed"
        elseif rand < 0.15 and tableContains(eventArgs.possibleVariants, "laminated") then
            variant = "laminated"
        elseif rand < 0.30 and tableContains(eventArgs.possibleVariants, "remote") then
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

    local hasLegendaryOverhaul = self:isUpgradePurchased(purchasedPermanentUpgrades, 'borg_hivemind') or 
                                 self:isUpgradePurchased(purchasedPermanentUpgrades, 'corporate_personhood')
    local overhaulIds = { borg_hivemind = true, corporate_personhood = true, multiverse_merger = true }

    -- Complex filtering logic is now neatly contained in this filter function
    local filterFunc = function(upgData)
        local isAlreadyPermanentAndUnique = false
        if purchasedPermanentUpgrades then
            for _, purchasedId in ipairs(purchasedPermanentUpgrades) do
                if upgData.id == purchasedId then
                    local nonUniqueTypes = { ['budget_add_flat'] = true, ['one_time_team_focus_boost_multiplier'] = true, ['one_time_workload_reduction_percent'] = true, ['temporary_focus_boost_all'] = true, ['code_debt'] = true }
                    
                    if not (upgData.effect and nonUniqueTypes[upgData.effect.type]) then
                        isAlreadyPermanentAndUnique = true 
                    end
                    break
                end
            end
        end

        local isBlockedOverhaul = hasLegendaryOverhaul and overhaulIds[upgData.id]
        return not isAlreadyPermanentAndUnique and not isBlockedOverhaul
    end

    local chosenUpgradeData = _generateWeightedRandomItem(GameData.ALL_UPGRADES, weights, filterFunc)

    if chosenUpgradeData then
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
        if not _findAndMarkSold(currentShopOffers.employees, employeeShopInstanceIdToMark, "employee") then
            print("ERROR (Shop:markOfferSold): Employee shop offer NOT FOUND. InstanceID sought: " .. employeeShopInstanceIdToMark)
            print("Current shop offers for employees:")
            for i, off in ipairs(currentShopOffers.employees) do
                if off then print("  - Slot " .. i .. ": " .. off.name .. ", ID: " .. off.instanceId .. ", Sold: " .. tostring(off.sold))
                else print("  - Slot " .. i .. ": nil") end
            end
        end
        return -- Explicitly return after handling
    elseif upgradeDataToMark and currentShopOffers.upgrades then
        if not _findAndMarkSold(currentShopOffers.upgrades, upgradeDataToMark.instanceId, "upgrade") then
             -- Fallback for old calls that might pass the whole object without a proper instanceId
            for i, offer in ipairs(currentShopOffers.upgrades) do
                if offer and offer.id == upgradeDataToMark.id then
                    offer.sold = true
                    print("Shop:markOfferSold: Marked upgrade as sold via ID fallback.")
                    return
                end
            end
            print("ERROR (Shop:markOfferSold): Upgrade shop offer ID did not match.")
        end
    elseif decorationInstanceIdToMark and currentShopOffers.decorations then
        if not _findAndMarkSold(currentShopOffers.decorations, decorationInstanceIdToMark, "decoration") then
            print("ERROR (Shop:markOfferSold): Decoration shop offer NOT FOUND. InstanceID sought: " .. decorationInstanceIdToMark)
        end
        return -- Explicitly return after handling
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
    if not hasUnsoldItem and gameState.currentShopOffers.upgrades then
        for _, upgOffer in ipairs(gameState.currentShopOffers.upgrades) do
            if upgOffer and not upgOffer.sold and not upgOffer.isLocked then hasUnsoldItem = true; break end
        end
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
    
    if gameState.currentShopOffers.upgrades then
        for _, offer in ipairs(gameState.currentShopOffers.upgrades) do
            if offer and offer.id == upgradeIdToBuy then
                upgradeData = offer
                break
            end
        end
    end

    if not upgradeData or upgradeData.sold then
        return false, "Selected upgrade not available or already purchased this turn."
    end
    
    local finalCost = self:getModifiedUpgradeCost(upgradeData, gameState.hiredEmployees)
    if gameState.budget < finalCost then
        return false, "Not enough budget. Need $" .. finalCost .. "."
    end
    
    -- This logic is now data-driven, checking a property on the upgrade itself.
    local isPermanentAndUnique = upgradeData.isUnique ~= false -- Defaults to true if nil

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

function Shop:_generateEmployeeOfferFromCard(chosenBaseCardData, variant)
    local shopOffer = _shallowCopy(chosenBaseCardData)
    
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
    else
        shopOffer.hiringBonus = chosenBaseCardData.hiringBonus
        shopOffer.weeklySalary = chosenBaseCardData.weeklySalary
    end
    
    print("Generated shop employee offer: " .. shopOffer.fullName .. " (" .. shopOffer.name .. "), Rarity: " .. shopOffer.rarity .. ", Variant: " .. shopOffer.variant)
    return shopOffer
end

return Shop