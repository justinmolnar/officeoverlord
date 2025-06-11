-- battle.lua
-- Manages the logic for the weekly work cycle (the "battle").

local GameData = require("data")
local Employee = require("employee") -- For calculating stats
local Placement = require("placement")

local Battle = {}

-- This helper function is now local to this module
local function getEmployeeFromGameState(gs, instanceId)
    if not gs or not gs.hiredEmployees or not instanceId then return nil end
    for _, emp in ipairs(gs.hiredEmployees) do
        if emp.instanceId == instanceId then return emp end
    end
    return nil
end

function Battle:startChallenge(gameState, showMessage)
    require("effects_dispatcher").dispatchEvent("onWorkItemStart", gameState)

    gameState.temporaryEffectFlags.isTopRowDisabled = nil
    gameState.temporaryEffectFlags.isRemoteWorkDisabled = nil
    gameState.temporaryEffectFlags.isShopDisabled = nil
    gameState.temporaryEffectFlags.itGuyUsedThisItem = nil 
    gameState.temporaryEffectFlags.globalFocusMultiplier = nil 
    gameState.temporaryEffectFlags.globalSalaryMultiplier = nil

    for _, emp in ipairs(gameState.hiredEmployees) do
        emp.workCyclesThisItem = 0
        emp.contributionThisItem = 0
    end

    if gameState.temporaryEffectFlags.shopDisabledNextWorkItem then
        gameState.temporaryEffectFlags.isShopDisabled = true
        gameState.temporaryEffectFlags.shopDisabledNextWorkItem = nil 
    end

    if gameState.temporaryEffectFlags.gladosModifierForNextItem then
        local mod = gameState.temporaryEffectFlags.gladosModifierForNextItem
        if mod.listeners and mod.listeners.onApply then
            mod.listeners.onApply(mod, gameState)
        else
            print("Warning: GLaDOS modifier has no onApply listener.")
        end
        gameState.temporaryEffectFlags.gladosModifierForNextItem = nil 
    end

    local currentSprintData = GameData.ALL_SPRINTS[gameState.currentSprintIndex]
    if not currentSprintData then
        print("Error or All Sprints Cleared: CurrentSprintIndex is " .. tostring(gameState.currentSprintIndex))
        return "game_won"
    end
    local currentWorkItemData = currentSprintData.workItems[gameState.currentWorkItemIndex]
    if not currentWorkItemData then
        print("Error: Could not find Work Item " .. gameState.currentWorkItemIndex .. " in Sprint " .. gameState.currentSprintIndex)
        return "game_over" 
    end

    gameState.currentWeekWorkload = currentWorkItemData.workload

    if currentWorkItemData.modifier then
        local mod = currentWorkItemData.modifier
        if mod.listeners and mod.listeners.onApply then
            mod.listeners.onApply(mod, gameState)
            print("APPLIED SPRINT MODIFIER: " .. mod.type)
        else
            print("Warning: Sprint modifier has no onApply listener.")
        end
    end
    
    gameState.initialWorkloadForBar = gameState.currentWeekWorkload

    return "battle_active"
end


-- Calculates the contribution for a single employee.
function Battle:calculateEmployeeContribution(employeeInstance, gameState)
   local EffectsDispatcher = require("effects_dispatcher")
   
   local eventArgs = {
       wasInstaWin = false,
       shouldSkipWorkload = false,
       overrideContribution = nil,
       employee = employeeInstance,
       productivityMultiplier = 1,
       contributionMultiplier = 1,
       focusMultiplier = 1,
   }
   EffectsDispatcher.dispatchEvent("onBeforeContribution", gameState, eventArgs)

   if eventArgs.wasInstaWin then
       gameState.currentWeekWorkload = 0
       return { productivity = 9999, focus = 9999, totalContribution = 99999 }
   end
   
   if eventArgs.overrideContribution then
       return eventArgs.overrideContribution
   end

   if eventArgs.shouldSkipWorkload then
       return { productivity = eventArgs.productivity, focus = eventArgs.focus, totalContribution = 0 }
   end

   employeeInstance.workCyclesThisItem = (employeeInstance.workCyclesThisItem or 0) + 1

   local stats = Employee:calculateStatsWithPosition(employeeInstance, gameState.hiredEmployees, gameState.deskAssignments, gameState.purchasedPermanentUpgrades, gameState.desks, gameState)
   local individualProductivity = stats.currentProductivity
   local individualFocus = stats.currentFocus
   
   -- Store original values for display
   local displayProductivity = individualProductivity
   local displayFocus = individualFocus
   
   individualProductivity = individualProductivity * eventArgs.productivityMultiplier
   individualFocus = individualFocus * eventArgs.focusMultiplier

   if gameState.temporaryEffectFlags.officeDogActiveThisTurn and gameState.temporaryEffectFlags.officeDogTarget == employeeInstance.instanceId then
       individualFocus = individualFocus * 2
       print(employeeInstance.name .. " gets Office Dog focus boost! New Focus: " .. individualFocus)
       gameState.temporaryEffectFlags.officeDogActiveThisTurn = false 
       gameState.temporaryEffectFlags.officeDogTarget = nil
   end
   
   local employeeContribution = math.floor(individualProductivity * individualFocus)
   
   employeeContribution = math.floor(employeeContribution * eventArgs.contributionMultiplier)

   employeeInstance.contributionThisItem = (employeeInstance.contributionThisItem or 0) + employeeContribution
   
   -- Store multiplier info for battle display
   local multiplierText = ""
   if eventArgs.productivityMultiplier > 1 or eventArgs.focusMultiplier > 1 or eventArgs.contributionMultiplier > 1 then
       local multipliers = {}
       if eventArgs.productivityMultiplier > 1 then
           table.insert(multipliers, string.format("P×%.1f", eventArgs.productivityMultiplier))
       end
       if eventArgs.focusMultiplier > 1 then
           table.insert(multipliers, string.format("F×%.1f", eventArgs.focusMultiplier))
       end
       if eventArgs.contributionMultiplier > 1 then
           table.insert(multipliers, string.format("C×%.1f", eventArgs.contributionMultiplier))
       end
       multiplierText = " (" .. table.concat(multipliers, ", ") .. ")"
   end
   
   local afterContributionEventArgs = {
       contribution = employeeContribution
   }
   EffectsDispatcher.dispatchEvent("onAfterContribution", gameState, afterContributionEventArgs)

   return {
       productivity = displayProductivity,
       focus = displayFocus,
       totalContribution = employeeContribution,
       multiplierText = multiplierText
   }
end

function Battle:resetBattleState(battleState, gameState)
    -- Reset all battle state properties
    battleState.activeEmployees = {}
    battleState.nextEmployeeIndex = 1
    battleState.currentWorkerId = nil
    battleState.lastContribution = nil
    battleState.phase = 'idle'
    battleState.timer = 0
    battleState.isShaking = false
    battleState.chipAmountRemaining = 0
    battleState.chipSpeed = 100
    battleState.chipTimer = 0
    battleState.roundTotalContribution = 0
    battleState.lastRoundContributions = {}
    battleState.changedEmployeesForAnimation = {}
    battleState.nextChangedEmployeeIndex = 1
    battleState.progressMarkers = {}
    battleState.salariesToPayThisRound = 0
    battleState.salaryChipAmountRemaining = 0
    
    -- Clear all employee battle-specific flags
    for _, emp in ipairs(gameState.hiredEmployees) do
        emp.isRebooted = nil
        emp.snackBoostActive = nil
        emp.snackBoostMultiplier = nil
        emp.snackBoostLevel = nil
        emp.narratorBoostActive = nil
        emp.agileFirstTurnBoost = nil
        emp.isInspired = nil
        emp.isFirstMover = nil
        emp.isAutomated = nil
        emp.assemblyLinePosition = nil
        emp.workCyclesThisItem = 0
        emp.contributionThisItem = 0
    end
    
    print("Battle state fully reset")
end

function Battle:calculateTotalSalariesForRound(gameState)
    local eventArgs = {
        cumulativePercentReduction = 1.0,
        totalFlatReduction = 0,
        salaryCap = nil,
        skipPayday = false,
        excludeEmployee = {}
    }
    require("effects_dispatcher").dispatchEvent("onCalculateSalaries", gameState, eventArgs)

    if eventArgs.skipPayday then
        print("Payday skipped due to listener effect (e.g., Four-Day Work Week)!")
        return 0
    end

    local totalSalariesThisRound = 0
    
    for _, emp in ipairs(gameState.hiredEmployees) do
        if not eventArgs.excludeEmployee[emp.instanceId] then
            local finalSalary = emp.weeklySalary
            finalSalary = finalSalary - eventArgs.totalFlatReduction
            finalSalary = finalSalary * eventArgs.cumulativePercentReduction

            if eventArgs.salaryCap then
                finalSalary = math.min(finalSalary, eventArgs.salaryCap)
            end
            
            totalSalariesThisRound = totalSalariesThisRound + math.max(0, math.floor(finalSalary))
        end
    end
    
    if gameState.temporaryEffectFlags.globalSalaryMultiplier then 
        totalSalariesThisRound = math.floor(totalSalariesThisRound * gameState.temporaryEffectFlags.globalSalaryMultiplier)
        print("Salaries increased by GLaDOS test...")
    end
    
    return totalSalariesThisRound
end

function Battle:calculatePyramidSchemeTransfers(gameState, roundContributions)
    local transfers = {}
    local middleRowBonusPool = 0
    local apexBonusPool = 0

    local bottomRowDeskIndices = {6, 7, 8}
    local middleRowDeskIndices = {3, 4, 5}
    local apexDeskId = "desk-1"
    
    local middleRowEmployees = {}
    local apexEmployeeId = nil

    for _, emp in ipairs(gameState.hiredEmployees) do
        if emp.deskId then
            local deskIndex = tonumber(string.match(emp.deskId, "desk%-(%d+)"))
            if deskIndex then
                for _, midIndex in ipairs(middleRowDeskIndices) do
                    if deskIndex == midIndex then table.insert(middleRowEmployees, emp.instanceId) end
                end
                if emp.deskId == apexDeskId then
                    apexEmployeeId = emp.instanceId
                end
            end
        end
    end

    for instanceId, contribution in pairs(roundContributions) do
        local emp = getEmployeeFromGameState(gameState, instanceId)
        if emp and emp.deskId then
            local deskIndex = tonumber(string.match(emp.deskId, "desk%-(%d+)"))
            if deskIndex then
                local isBottomRow = false
                for _, botIndex in ipairs(bottomRowDeskIndices) do if deskIndex == botIndex then isBottomRow = true; break; end end
                
                local isMiddleRow = false
                for _, midIndex in ipairs(middleRowDeskIndices) do if deskIndex == midIndex then isMiddleRow = true; break; end end

                if isBottomRow then
                    local transferAmount = math.floor(contribution * 0.1)
                    transfers[instanceId] = (transfers[instanceId] or 0) - transferAmount
                    middleRowBonusPool = middleRowBonusPool + transferAmount
                elseif isMiddleRow then
                    local transferAmount = math.floor(contribution * 0.1)
                    transfers[instanceId] = (transfers[instanceId] or 0) - transferAmount
                    apexBonusPool = apexBonusPool + transferAmount
                end
            end
        end
    end

    if #middleRowEmployees > 0 and middleRowBonusPool > 0 then
        local bonusPerMiddle = math.floor(middleRowBonusPool / #middleRowEmployees)
        for _, empId in ipairs(middleRowEmployees) do
            transfers[empId] = (transfers[empId] or 0) + bonusPerMiddle
        end
    end

    if apexEmployeeId and apexBonusPool > 0 then
        transfers[apexEmployeeId] = (transfers[apexEmployeeId] or 0) + apexBonusPool
    end

    return transfers
end

-- Processes logic at the end of a full work round.
function Battle:endWorkCycleRound(gameState, totalSalariesThisRound, showMessage)
    require("effects_dispatcher").dispatchEvent("onEndOfRound", gameState, { totalSalaries = totalSalariesThisRound })

    print("End of Work Cycle #" .. gameState.currentWeekCycles)
    print("Salaries paid this round: $" .. totalSalariesThisRound .. ". Budget remaining: $" .. gameState.budget)
    
    if gameState.budget < 0 then
        local eventArgs = { gameOverPrevented = false, message = "" }
        require("effects_dispatcher").dispatchEvent("onBudgetDepleted", gameState, eventArgs)

        if eventArgs.gameOverPrevented then
            showMessage("Saved!", eventArgs.message)
            gameState.budget = GameData.BAILOUT_BUDGET_AMOUNT
            return "lost_bailout"
        end

        if gameState.bailOutsRemaining > 0 then
            local bailoutIsFree = false
            if self:isUpgradePurchased(gameState.purchasedPermanentUpgrades, "legal_retainer", gameState) then
                local upgData; for _, u in ipairs(GameData.ALL_UPGRADES) do if u.id == "legal_retainer" then upgData = u; break; end end
                if upgData and love.math.random() < upgData.effect.chance then bailoutIsFree = true end
            end
            
            if bailoutIsFree then 
                showMessage("Legal Loophole!", "Your legal team found a loophole. The bailout is free! The current work item will restart.")
            else 
                gameState.bailOutsRemaining = gameState.bailOutsRemaining - 1
                showMessage("Emergency Bailout!", "Budget crisis averted! Bailouts remaining: " .. gameState.bailOutsRemaining .. "\n\nThe current work item will restart with fresh funding.")
            end
            
            gameState.budget = GameData.BAILOUT_BUDGET_AMOUNT
            print("Budget depleted! Bailout used. Bailouts remaining: " .. gameState.bailOutsRemaining)
            return "lost_bailout"
        else
            print("Budget depleted! No bailouts left. Game Over.")
            return "lost_budget"
        end
    end

    return "continue_next_round"
end


-- Helper function to check if an upgrade is purchased
function Battle:isUpgradePurchased(purchasedUpgrades, upgradeId, gameState)
    if not purchasedUpgrades then return false end
    if gameState.temporaryEffectFlags.disabledUpgrades and gameState.temporaryEffectFlags.disabledUpgrades[upgradeId] then
        return false -- Upgrade is disabled by conspiracy
    end
    for _, id in ipairs(purchasedUpgrades) do
        if id == upgradeId then return true end
    end
    return false
end

return Battle