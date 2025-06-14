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

function Employee:calculateStatsWithPosition(employeeInstance, allHiredEmployees, deskAssignments, purchasedPermanentUpgrades, desksData, gameState)
    -- Phase 1: Determine the effective employee (handles The Mimic)
    local effectiveEmployeeArgs = { employee = employeeInstance }
    require("effects_dispatcher").dispatchEvent("onGetEffectiveEmployee", gameState, { modal = modal }, effectiveEmployeeArgs)
    local effectiveInstance = effectiveEmployeeArgs.employee

    -- Phase 2: Initialize the stats object that all listeners will modify
    local stats = {
        productivity = effectiveInstance.baseProductivity,
        focus = effectiveInstance.baseFocus,
        log = {
            productivity = {string.format("Base: %d", effectiveInstance.baseProductivity)},
            focus = {string.format("Base: %.2fx", effectiveInstance.baseFocus)}
        }
    }

    -- Phase 3: Dispatch the main calculation event.
    local eventArgs = {
        employee = effectiveInstance,
        stats = stats,
        gameState = gameState,
        -- NEW: Add a table to track raw bonuses for amplification effects.
        bonusesApplied = {
            positional = { prod = 0, focus = 0 }
        }
    }
    
    require("effects_dispatcher").dispatchEvent("onCalculateStats", gameState, { modal = modal }, eventArgs)
    
    -- Phase 4: Return the final, modified stats
    return { 
        currentProductivity = math.max(0, math.floor(eventArgs.stats.productivity)), 
        currentFocus = math.max(0.1, eventArgs.stats.focus), 
        calculationLog = eventArgs.stats.log 
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