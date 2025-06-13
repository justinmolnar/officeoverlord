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
    require("effects_dispatcher").dispatchEvent("onApplyUpgrades", gameState, applyUpgradesEventArgs, { modal = modal })

    local upgradeArgs = {
        employee = employeeInstance,
        productivity = currentProductivity,
        focus = currentFocus,
        log = calculationLog
    }
    require("effects_dispatcher").dispatchEvent("onApplyUpgradeModifiers", gameState, upgradeArgs, { modal = modal })
    
    currentProductivity = upgradeArgs.productivity
    currentFocus = upgradeArgs.focus

    local focusEventArgs = {
        employee = employeeInstance,
        focusMultiplier = 1.0
    }
    require("effects_dispatcher").dispatchEvent("onApplyGlobalFocusModifiers", gameState, focusEventArgs, { modal = modal })
    currentFocus = currentFocus * focusEventArgs.focusMultiplier
    
    currentProductivity = math.floor(currentProductivity)

    local secretBuffEventArgs = {
        employee = employeeInstance,
        productivityBonus = 0
    }
    require("effects_dispatcher").dispatchEvent("onApplySecretBuffs", gameState, secretBuffEventArgs, { modal = modal })
    currentProductivity = currentProductivity + secretBuffEventArgs.productivityBonus

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
    local Placement = require("placement")
    local totalProdBonus = 0
    local totalProdMultiplier = 1.0
    local totalFocusMultiplier = 1.0
    local log = { productivity = {}, focus = {} }

    if effectiveInstance.variant == 'remote' or not effectiveInstance.deskId or (effectiveInstance.special and effectiveInstance.special.ignores_positional_bonuses) then
        return { prod = 0, prodMult = 1.0, focusMult = 1.0, log = log }
    end
    
    local isInverterActive = isUpgradePurchased_local(purchasedPermanentUpgrades, 'positional_inverter')
    
    local ownDecoration = require("placement"):getDecorationOnDesk(gameState, effectiveInstance.deskId)
    local hasFocusProtection = ownDecoration and ownDecoration.effect.type == 'desk_focus_protection'
    local focusProtectionMultiplier = hasFocusProtection and (1 - ownDecoration.effect.negative_reduction) or 1.0

    local eventArgs

    local function apply_effect(effectDetails, sourceEmployee)
        local multValue = effectDetails.scales_with_level and (sourceEmployee.level or 1) or 1
        
        if effectDetails.productivity_add then
            local val = effectDetails.productivity_add * multValue
            if isInverterActive then val = -val end
            totalProdBonus = totalProdBonus + val
            table.insert(log.productivity, string.format("%s%d from %s", val >= 0 and "+" or "", val, sourceEmployee.name))
        end
        if effectDetails.productivity_mult then
            local val = effectDetails.productivity_mult
            if effectDetails.scales_with_level then
                val = 1 + ((val - 1) * multValue)
            end
            if isInverterActive and val ~= 1 then val = 1 / val end
            totalProdMultiplier = totalProdMultiplier * val
            table.insert(log.productivity, string.format("*%.1fx from %s", val, sourceEmployee.name))
        end
        if effectDetails.focus_add then
            if eventArgs.neutralizeFocus then table.insert(log.focus, "Positional focus ignored (HR)"); return end
            local val = effectDetails.focus_add * multValue
            if isInverterActive then val = -val end
            if val < 0 and hasFocusProtection then val = val * focusProtectionMultiplier end
            totalFocusMultiplier = totalFocusMultiplier * (1 + val)
            table.insert(log.focus, string.format("%s%.0f%% from %s", val >= 0 and "+" or "", val * 100, sourceEmployee.name))
        end
        if effectDetails.focus_mult then
            if eventArgs.neutralizeFocus then table.insert(log.focus, "Positional focus ignored (HR)"); return end
            local val = 1 + ((effectDetails.focus_mult - 1) * multValue)
            if isInverterActive and val ~= 0 then val = 1 / val end
            if val < 1 and hasFocusProtection then val = 1 - ((1 - val) * focusProtectionMultiplier) end
            totalFocusMultiplier = totalFocusMultiplier * val
            table.insert(log.focus, string.format("*%.1f from %s", val, sourceEmployee.name))
        end
    end

    eventArgs = {
        employee = effectiveInstance,
        override = false,
        neutralizeFocus = false,
        results = nil,
        applyEffect = apply_effect,
        log = log
    }
    require("effects_dispatcher").dispatchEvent("onCalculatePositionalBonuses", gameState, eventArgs, { modal = modal })

    if eventArgs.override then
        return { prod = totalProdBonus, prodMult = totalProdMultiplier, focusMult = totalFocusMultiplier, log = log }
    end

    for _, sourceEmployee in ipairs(allHiredEmployees) do
        if sourceEmployee.instanceId ~= effectiveInstance.instanceId and sourceEmployee.deskId and sourceEmployee.positionalEffects then
            if not (sourceEmployee.isSmithCopy and effectiveInstance.isSmithCopy) then
                for directionKey, effectDetails in pairs(sourceEmployee.positionalEffects) do
                    local directionsToParse = (directionKey == "all_adjacent") and {"up", "down", "left", "right"} or {directionKey}
                    for _, actualDirection in ipairs(directionsToParse) do
                        if Placement:getNeighboringDeskId(sourceEmployee.deskId, actualDirection, GameData.GRID_WIDTH, GameData.TOTAL_DESK_SLOTS, desksData) == effectiveInstance.deskId then
                            if not (effectDetails.condition_not_id and effectiveInstance.id == effectDetails.condition_not_id) then
                                apply_effect(effectDetails, sourceEmployee)
                            end
                        end
                    end
                end
            end
        end
    end

    for _, sourceDesk in ipairs(desksData) do
        local decoration = require("placement"):getDecorationOnDesk(gameState, sourceDesk.id)
        if decoration and decoration.effect and (decoration.effect.type == 'desk_area_focus' or decoration.effect.type == 'desk_area_productivity') then
            local directions = {"up", "down", "left", "right"}
            for _, dir in ipairs(directions) do
                local neighborDeskId = Placement:getNeighboringDeskId(sourceDesk.id, dir, GameData.GRID_WIDTH, GameData.TOTAL_DESK_SLOTS, desksData)
                if neighborDeskId and neighborDeskId == effectiveInstance.deskId then
                    local effectDetails = {}
                    if decoration.effect.adjacent_productivity_add then
                        effectDetails.productivity_add = decoration.effect.adjacent_productivity_add
                    end
                    if decoration.effect.adjacent_focus_add then
                        effectDetails.focus_add = decoration.effect.adjacent_focus_add
                    end
                    apply_effect(effectDetails, { name = decoration.name })
                    break
                end
            end
        end
    end

    return { prod = totalProdBonus, prodMult = totalProdMultiplier, focusMult = totalFocusMultiplier, log = log }
end

function Employee:calculateStatsWithPosition(employeeInstance, allHiredEmployees, deskAssignments, purchasedPermanentUpgrades, desksData, gameState)
    local eventArgs = { employee = employeeInstance }
    require("effects_dispatcher").dispatchEvent("onCalculateStats", gameState, eventArgs, { modal = modal })
    local effectiveInstance = eventArgs.employee
    
    local stats, baseCalculationLog = self:calculateBaseStatsWithModifiers(effectiveInstance, allHiredEmployees, purchasedPermanentUpgrades, gameState)
    local currentProductivity = stats.currentProductivity
    local currentFocus = stats.currentFocus
    local calculationLog = { productivity = {}, focus = {} }; for k,v in pairs(baseCalculationLog.productivity) do table.insert(calculationLog.productivity,v) end; for k,v in pairs(baseCalculationLog.focus) do table.insert(calculationLog.focus,v) end

    if effectiveInstance.deskId then
        local decoration = require("placement"):getDecorationOnDesk(gameState, effectiveInstance.deskId)
        if decoration and decoration.effect then
            local effect = decoration.effect
            local type = effect.type
            if type == 'desk_productivity_add' then
                currentProductivity = currentProductivity + (effect.value or 0)
                table.insert(calculationLog.productivity, string.format("+%d from %s", effect.value, decoration.name))
            elseif type == 'desk_focus_add' then
                currentFocus = currentFocus + (effect.value or 0)
                table.insert(calculationLog.focus, string.format("+%.2fx from %s", effect.value, decoration.name))
            elseif type == 'desk_mixed_bonus' then
                if effect.productivity_add then
                    currentProductivity = currentProductivity + effect.productivity_add
                    table.insert(calculationLog.productivity, string.format("+%d from %s", effect.productivity_add, decoration.name))
                end
                if effect.focus_add then
                    currentFocus = currentFocus + effect.focus_add
                    table.insert(calculationLog.focus, string.format("+%.2fx from %s", effect.focus_add, decoration.name))
                end
            elseif (type == 'desk_area_focus' or type == 'desk_area_productivity') then
                if effect.desk_productivity_add then
                    currentProductivity = currentProductivity + effect.desk_productivity_add
                    table.insert(calculationLog.productivity, string.format("+%d from %s", effect.desk_productivity_add, decoration.name))
                end
                if effect.desk_focus_add then
                    currentFocus = currentFocus + effect.desk_focus_add
                    table.insert(calculationLog.focus, string.format("+%.2fx from %s", effect.desk_focus_add, decoration.name))
                end
            elseif type == 'desk_focus_protection' then
                 if effect.focus_add then
                    currentFocus = currentFocus + effect.focus_add
                    table.insert(calculationLog.focus, string.format("+%.2fx from %s", effect.focus_add, decoration.name))
                 end
            end
        end
    end

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
        currentProductivity = currentProductivity * positionalBonuses.prodMult
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
    require("effects_dispatcher").dispatchEvent("onFinalizeStats", gameState, finalStatsEventArgs, { modal = modal })

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

function Employee:getFromState(gameState, instanceId)
    if not gameState or not gameState.hiredEmployees or not instanceId then return nil end
    for _, emp in ipairs(gameState.hiredEmployees) do
        if emp.instanceId == instanceId then return emp end
    end
    return nil
end

return Employee