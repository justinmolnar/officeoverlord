-- employee.lua
-- Handles logic related to individual employees, including stat calculations,
-- and provides the constructor for creating employee instances.

local GameData = require("data") -- For BASE_EMPLOYEE_CARDS and game constants like GRID_WIDTH

local Employee = {}
Employee.__index = Employee

-- Constructor for a new employee instance.
-- @param baseId (string): The ID of the employee from GameData.BASE_EMPLOYEE_CARDS.
-- @param variant (string, optional): "remote", "foil", or "holo".
-- @return (table): A new employee instance table, or nil if baseId is not found.
function Employee:new(baseId, variant, fullName)
    local baseCard = nil
    -- Find the base card definition in GameData
    for _, cardDataInLoop in ipairs(GameData.BASE_EMPLOYEE_CARDS) do
        if cardDataInLoop.id == baseId then
            baseCard = cardDataInLoop
            break
        end
    end

    if not baseCard then
        print("Error: Base employee card not found for ID: " .. tostring(baseId))
        return nil
    end

    -- Create a new table for the instance, performing a deep copy of the base card data
    local instance = {}
    for key, value in pairs(baseCard) do
        if type(value) == "table" then
            instance[key] = {} -- Create a new table for nested tables (e.g., positionalEffects)
            for nestedKey, nestedValue in pairs(value) do
                if type(nestedValue) == "table" then -- Handle doubly nested tables if any (e.g. positionalEffects.direction.effect)
                    instance[key][nestedKey] = {}
                    for nnk, nnv in pairs(nestedValue) do
                         instance[key][nestedKey][nnk] = nnv
                    end
                else
                    instance[key][nestedKey] = nestedValue
                end
            end
        else
            instance[key] = value
        end
    end

    -- Assign unique instance properties
    instance.instanceId = string.format("%s-%d-%.4f", baseCard.id, love.math.random(100000, 999999), love.timer.getTime())
    instance.level = 1 -- All new employees start at level 1
    instance.workCyclesThisItem = 0 -- For abilities that track cycles
    instance.contributionThisSprint = 0 -- NEW: Track performance over a whole sprint
    instance.fullName = fullName or "Unnamed" -- Use provided name or a fallback
    
    -- MODIFIED: Use the new 'variant' system, accepting remote, foil, holo, or standard
    instance.variant = variant or "standard"

    -- Adjust hiringBonus and weeklySalary if this instance is remote
    if instance.variant == 'remote' then
        instance.hiringBonus = math.floor(baseCard.hiringBonus * GameData.REMOTE_HIRING_BONUS_MODIFIER)
        instance.weeklySalary = math.floor(baseCard.weeklySalary * GameData.REMOTE_SALARY_MODIFIER)
    -- Foil and Holo variants do not have inherent stat changes, their effects are global or cosmetic.
    else
        -- Keep original salary/bonus for standard, foil, and holo
        instance.hiringBonus = baseCard.hiringBonus
        instance.weeklySalary = baseCard.weeklySalary
    end
    
    setmetatable(instance, self) -- Set the metatable to enable Employee methods on this instance
    return instance
end

local function isUpgradePurchased_local(purchasedUpgradesList, upgradeId)
    if not purchasedUpgradesList then return false end
    for _, id in ipairs(purchasedUpgradesList) do
        if id == upgradeId then return true end
    end
    return false
end

function Employee:calculateBaseStatsWithModifiers(employeeInstance, allHiredEmployees, purchasedPermanentUpgrades, gameState)
    local calculationLog = {
        productivity = {string.format("Base: %d", employeeInstance.baseProductivity)},
        focus = {string.format("Base: %.2fx", employeeInstance.baseFocus)}
    }
    
    local currentProductivity = employeeInstance.baseProductivity 
    local currentFocus = employeeInstance.baseFocus 

    local applyUpgradesEventArgs = { employee = employeeInstance, blockedUpgrades = {} }
    require("effects_dispatcher").dispatchEvent("onApplyUpgrades", gameState, applyUpgradesEventArgs)

    if purchasedPermanentUpgrades then
        for _, upgradeId in ipairs(purchasedPermanentUpgrades) do
            if not (gameState.temporaryEffectFlags.disabledUpgrades and gameState.temporaryEffectFlags.disabledUpgrades[upgradeId]) then
                for _, upgradeData in ipairs(GameData.ALL_UPGRADES) do
                    if upgradeData.id == upgradeId and upgradeData.effect then
                        if applyUpgradesEventArgs.blockedUpgrades[upgradeId] then
                            table.insert(calculationLog.productivity, string.format("Tech upgrade '%s' ignored", upgradeData.name))
                            goto continue_upgrade_loop
                        end

                        if upgradeData.effect.type == 'productivityMultiplierAll' then
                            currentProductivity = currentProductivity * (1 + upgradeData.effect.value)
                            table.insert(calculationLog.productivity, string.format("*%.0f%% from %s", upgradeData.effect.value * 100, upgradeData.name))
                        elseif upgradeData.effect.type == 'focusMultiplierAllFlat' or upgradeData.effect.type == 'focus_boost_all_flat_permanent' then
                            currentFocus = currentFocus * (1 + upgradeData.effect.value) 
                            table.insert(calculationLog.focus, string.format("*%.0f%% from %s", upgradeData.effect.value * 100, upgradeData.name))
                        elseif upgradeData.effect.type == 'productivity_boost_all_flat_permanent' then
                            currentProductivity = currentProductivity + upgradeData.effect.value
                            table.insert(calculationLog.productivity, string.format("+%d from %s", upgradeData.effect.value, upgradeData.name))
                        elseif upgradeData.effect.type == 'temporary_focus_boost_all' then
                            currentFocus = currentFocus * (1 + upgradeData.effect.value)
                            table.insert(calculationLog.focus, string.format("*%.0f%% from %s", upgradeData.effect.value * 100, upgradeData.name))
                        end
                    end
                    ::continue_upgrade_loop::
                end
            else
                table.insert(calculationLog.productivity, string.format("Upgrade '%s' disabled by conspiracy!", upgradeId))
            end
        end
    end

    if gameState.temporaryEffectFlags.globalFocusMultiplier then
        currentFocus = currentFocus * gameState.temporaryEffectFlags.globalFocusMultiplier
        table.insert(calculationLog.focus, string.format("*%.0f%% from GLaDOS Test", (gameState.temporaryEffectFlags.globalFocusMultiplier) * 100))
    end
    
    currentProductivity = math.floor(currentProductivity)

    if employeeInstance.special and employeeInstance.special.initial_focus_multiplier then
        currentFocus = currentFocus * employeeInstance.special.initial_focus_multiplier
        table.insert(calculationLog.focus, string.format("*%.2fx from own ability", employeeInstance.special.initial_focus_multiplier))
    end

    local finalStats = {
        currentProductivity = math.max(0, currentProductivity),
        currentFocus = math.max(0.1, currentFocus) 
    }
    
    return finalStats, calculationLog
end

function Employee:calculatePositionalBonuses(effectiveInstance, allHiredEmployees, deskAssignments, purchasedPermanentUpgrades, desksData, gameState)
    local totalProdBonus = 0
    local totalFocusMultiplier = 1.0
    local log = { productivity = {}, focus = {} }

    if effectiveInstance.variant == 'remote' or not effectiveInstance.deskId or (effectiveInstance.special and effectiveInstance.special.ignores_positional_bonuses) then
        return { prod = 0, focusMult = 1.0, log = log }
    end
    
    local isInverterActive = isUpgradePurchased_local(purchasedPermanentUpgrades, 'positional_inverter')
    
    local eventArgs -- Declare the table before the function that uses it.

    local function apply_effect(effectDetails, sourceEmployee)
        local multValue = effectDetails.scales_with_level and (sourceEmployee.level or 1) or 1
        
        if effectDetails.productivity_add then
            local val = effectDetails.productivity_add * multValue
            if isInverterActive then val = -val end
            totalProdBonus = totalProdBonus + val
            table.insert(log.productivity, string.format("%s%d from %s", val >= 0 and "+" or "", val, sourceEmployee.name))
        end
        if effectDetails.focus_add then
            if eventArgs.neutralizeFocus then table.insert(log.focus, "Positional focus ignored (HR)"); return end
            local val = effectDetails.focus_add * multValue
            if isInverterActive then val = -val end
            totalFocusMultiplier = totalFocusMultiplier * (1 + val)
            table.insert(log.focus, string.format("%s%.0f%% from %s", val > 0 and "+" or "", val * 100, sourceEmployee.name))
        end
        if effectDetails.focus_mult then
            if eventArgs.neutralizeFocus then table.insert(log.focus, "Positional focus ignored (HR)"); return end
            local val = 1 + ((effectDetails.focus_mult - 1) * multValue)
            if isInverterActive and val ~= 0 then val = 1 / val end
            totalFocusMultiplier = totalFocusMultiplier * val
            table.insert(log.focus, string.format("*%.1f from %s", val, sourceEmployee.name))
        end
    end

    eventArgs = { -- Populate the table after the function is defined.
        employee = effectiveInstance,
        override = false,
        neutralizeFocus = false,
        results = nil,
        applyEffect = apply_effect,
        log = log
    }
    require("effects_dispatcher").dispatchEvent("onCalculatePositionalBonuses", gameState, eventArgs)

    if eventArgs.override then
        return { prod = totalProdBonus, focusMult = totalFocusMultiplier, log = log }
    end

    for _, sourceEmployee in ipairs(allHiredEmployees) do
        if sourceEmployee.instanceId ~= effectiveInstance.instanceId and sourceEmployee.deskId and sourceEmployee.positionalEffects then
            if not (sourceEmployee.isSmithCopy and effectiveInstance.isSmithCopy) then
                for directionKey, effectDetails in pairs(sourceEmployee.positionalEffects) do
                    local directionsToParse = (directionKey == "all_adjacent") and {"up", "down", "left", "right"} or {directionKey}
                    for _, actualDirection in ipairs(directionsToParse) do
                        if self:getNeighboringDeskId(sourceEmployee.deskId, actualDirection, GameData.GRID_WIDTH, GameData.TOTAL_DESK_SLOTS, desksData) == effectiveInstance.deskId then
                            if not (effectDetails.condition_not_id and effectiveInstance.id == effectDetails.condition_not_id) then
                                apply_effect(effectDetails, sourceEmployee)
                            end
                        end
                    end
                end
            end
        end
    end

    return { prod = totalProdBonus, focusMult = totalFocusMultiplier, log = log }
end

function Employee:calculateStatsWithPosition(employeeInstance, allHiredEmployees, deskAssignments, purchasedPermanentUpgrades, desksData, gameState)
    local isBrainInterfaceActive = isUpgradePurchased_local(purchasedPermanentUpgrades, 'brain_interface')
    if isBrainInterfaceActive and gameState.temporaryEffectFlags.hiveMindStats then
        local hiveMindStats = gameState.temporaryEffectFlags.hiveMindStats
        return { 
            currentProductivity = hiveMindStats.productivity, 
            currentFocus = hiveMindStats.focus, 
            calculationLog = {
                productivity = {"Hive Mind Prod: " .. hiveMindStats.productivity},
                focus = {"Hive Mind Focus: " .. string.format("%.2f", hiveMindStats.focus)}
            }
        }
    end

    local eventArgs = { employee = employeeInstance }
    require("effects_dispatcher").dispatchEvent("onCalculateStats", gameState, eventArgs)
    local effectiveInstance = eventArgs.employee
    
    local stats, baseCalculationLog = self:calculateBaseStatsWithModifiers(effectiveInstance, allHiredEmployees, purchasedPermanentUpgrades, gameState)
    local currentProductivity = stats.currentProductivity
    local currentFocus = stats.currentFocus
    local calculationLog = { productivity = {}, focus = {} }; for k,v in pairs(baseCalculationLog.productivity) do table.insert(calculationLog.productivity,v) end; for k,v in pairs(baseCalculationLog.focus) do table.insert(calculationLog.focus,v) end

    local isSpecialistNicheActive = isUpgradePurchased_local(purchasedPermanentUpgrades, 'specialist_niche')
    local specialistId = gameState.temporaryEffectFlags.specialistId
    local isSpecialist = isSpecialistNicheActive and specialistId == effectiveInstance.instanceId
    local isFocusFunnelActive = isUpgradePurchased_local(purchasedPermanentUpgrades, 'focus_funnel')

    local globalBonusProductivity = 0
    local globalBonusFocusMult = 1.0

    if allHiredEmployees then
        for _, emp in ipairs(allHiredEmployees) do
            if emp.variant == 'foil' then globalBonusProductivity = globalBonusProductivity + 5; table.insert(calculationLog.productivity, "+5 from a Foil employee") end
            if emp.variant == 'holo' then globalBonusFocusMult = globalBonusFocusMult * 1.5; table.insert(calculationLog.focus, "*1.5x from a Holo employee") end
        end
    end
    currentProductivity = currentProductivity + globalBonusProductivity
    currentFocus = currentFocus * globalBonusFocusMult

    if not isFocusFunnelActive then
        local positionalBonuses = self:calculatePositionalBonuses(effectiveInstance, allHiredEmployees, deskAssignments, purchasedPermanentUpgrades, desksData, gameState)
        currentProductivity = currentProductivity + positionalBonuses.prod
        currentFocus = currentFocus * positionalBonuses.focusMult
        for _, log in ipairs(positionalBonuses.log.productivity) do table.insert(calculationLog.productivity, log) end
        for _, log in ipairs(positionalBonuses.log.focus) do table.insert(calculationLog.focus, log) end
    else
        if effectiveInstance.instanceId == gameState.temporaryEffectFlags.focusFunnelTargetId then
            currentFocus = currentFocus * (gameState.temporaryEffectFlags.focusFunnelTotalBonus or 1.0)
            table.insert(calculationLog.focus, string.format("*%.2fx from Focus Funnel", (gameState.temporaryEffectFlags.focusFunnelTotalBonus or 1.0)))
        end
    end

    if isSpecialistNicheActive then
        local multiplier = isSpecialist and 2 or 0.5
        currentProductivity = math.floor(currentProductivity * multiplier)
        currentFocus = currentFocus * multiplier
        local logText = string.format("%s from Specialist's Niche", isSpecialist and "*2" or "/2")
        table.insert(calculationLog.productivity, logText)
        table.insert(calculationLog.focus, logText)

        if isSpecialist then
            for _, otherEmp in ipairs(allHiredEmployees) do
                if otherEmp.instanceId ~= effectiveInstance.instanceId and otherEmp.deskId and effectiveInstance.positionalEffects then
                    for _, effect in pairs(effectiveInstance.positionalEffects) do
                        if effect.productivity_add then otherEmp.baseProductivity = otherEmp.baseProductivity + effect.productivity_add end
                        if effect.focus_add then otherEmp.baseFocus = otherEmp.baseFocus + effect.focus_add end
                    end
                end
            end
        end
    end
    
    local finalStatsEventArgs = {
        employee = effectiveInstance,
        stats = {
            productivity = currentProductivity,
            focus = currentFocus,
            log = calculationLog
        }
    }
    require("effects_dispatcher").dispatchEvent("onFinalizeStats", gameState, finalStatsEventArgs)

    return { 
        currentProductivity = math.max(0, math.floor(finalStatsEventArgs.stats.productivity)), 
        currentFocus = math.max(0.1, finalStatsEventArgs.stats.focus), 
        calculationLog = finalStatsEventArgs.stats.log 
    }
end

-- Helper to find a desk by ID from a desks array (like gameState.desks)
function Employee:getDeskById(deskId, desksData)
    if not desksData then return nil end
    for _, desk in ipairs(desksData) do if desk.id == deskId then return desk end end
    return nil
end

-- Helper function to get ID of a neighboring desk
function Employee:getNeighboringDeskId(deskId, direction, gridWidth, totalDeskSlots, desksData)
    if not deskId then return nil end -- Prevent crash if deskId is nil
    local match = string.match(deskId, "desk%-(%d+)") if not match then return nil end
    local currentIndex = tonumber(match) ; local neighborIndex = -1
    local row = math.floor(currentIndex / gridWidth); local col = currentIndex % gridWidth
    if direction == "up" then if row > 0 then neighborIndex = currentIndex - gridWidth end
    elseif direction == "down" then if row < (math.ceil(totalDeskSlots / gridWidth) - 1) then neighborIndex = currentIndex + gridWidth end
    elseif direction == "left" then if col > 0 then neighborIndex = currentIndex - 1 end
    elseif direction == "right" then if col < gridWidth - 1 then neighborIndex = currentIndex + 1 end
    end
    if neighborIndex >= 0 and neighborIndex < totalDeskSlots then
        -- Check if the neighbor desk actually exists in our defined desks
        for _, desk in ipairs(desksData) do if desk.id == "desk-" .. neighborIndex then return desk.id end end
    end
    return nil
end

return Employee