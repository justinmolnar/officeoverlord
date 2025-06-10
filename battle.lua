-- battle.lua
-- Manages the logic for the weekly work cycle (the "battle").

local GameData = require("data")
local Employee = require("employee") -- For calculating stats
local Placement = require("placement")

local Battle = {}

-- Called when "Start Work Item" is pressed.
-- Initializes workload, resets counters for the new item.
function Battle:startChallenge(gameState)
    require("effects_dispatcher").dispatchEvent("onWorkItemStart", gameState)

    gameState.temporaryEffectFlags.isTopRowDisabled = nil
    gameState.temporaryEffectFlags.isRemoteWorkDisabled = nil
    gameState.temporaryEffectFlags.isShopDisabled = nil
    gameState.temporaryEffectFlags.itGuyUsedThisItem = nil 
    gameState.temporaryEffectFlags.globalFocusMultiplier = nil 
    gameState.temporaryEffectFlags.globalSalaryMultiplier = nil
    
    if gameState.temporaryEffectFlags.motivationalBoostNextItem then
        gameState.temporaryEffectFlags.globalFocusMultiplier = 2.0 
        gameState.temporaryEffectFlags.motivationalBoostNextItem = nil 
    end

    if gameState.temporaryEffectFlags.photocopierTargetForNextItem then
        local target = getEmployeeFromGameState(gameState, gameState.temporaryEffectFlags.photocopierTargetForNextItem)
        local emptyDeskId = nil
        for _, desk in ipairs(gameState.desks) do
            if desk.status == 'owned' and not gameState.deskAssignments[desk.id] then
                emptyDeskId = desk.id
                break
            end
        end

        if target and emptyDeskId then
            local clone = Employee:new(target.id, target.variant, "Clone of " .. target.fullName)
            clone.isTemporaryClone = true
            clone.weeklySalary = 0
            clone.level = target.level
            clone.baseProductivity = target.baseProductivity
            clone.baseFocus = target.baseFocus
            table.insert(gameState.hiredEmployees, clone)
            Placement:handleEmployeeDropOnDesk(gameState, clone, emptyDeskId, nil)
            _G.showMessage("Photocopied!", "A temporary clone of " .. target.name .. " has appeared for this work item!")
        else
            _G.showMessage("Photocopy Failed", "Could not create a clone. Ensure there is an empty desk available.")
        end
        gameState.temporaryEffectFlags.photocopierTargetForNextItem = nil 
    end

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

    if gameState.currentWorkItemIndex == 1 and not gameState.temporaryEffectFlags.museUsedThisSprint then
        local muse = nil
        for _, emp in ipairs(gameState.hiredEmployees) do
            if emp.special and emp.special.type == 'inspire_teammate' then
                muse = emp
                break
            end
        end
        if muse then
            local potentialTargets = {}
            for _, emp in ipairs(gameState.hiredEmployees) do if emp.id ~= muse.id then table.insert(potentialTargets, emp) end end
            if #potentialTargets > 0 then
                local target = potentialTargets[love.math.random(#potentialTargets)]
                target.isInspired = true
                gameState.temporaryEffectFlags.museUsedThisSprint = true
                print(muse.name .. " has inspired " .. target.name .. "!")
            end
        end
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
    
    if gameState.purchasedPermanentUpgrades then
        for _, upgradeId in ipairs(gameState.purchasedPermanentUpgrades) do
            if upgradeId == "consultant_visit" and gameState.temporaryEffectFlags.consultantVisitUsedThisWeek ~= true then
                local consultantUpgrade = nil
                for _, upg in ipairs(GameData.ALL_UPGRADES) do if upg.id == "consultant_visit" then consultantUpgrade = upg; break; end end
                if consultantUpgrade and consultantUpgrade.effect and consultantUpgrade.effect.type == "one_time_workload_reduction_percent" then
                    local reduction = math.floor(gameState.currentWeekWorkload * consultantUpgrade.effect.value)
                    gameState.currentWeekWorkload = gameState.currentWeekWorkload - reduction
                    print("Consultant Visit! Workload reduced by " .. reduction)
                    gameState.temporaryEffectFlags.consultantVisitUsedThisWeek = true
                end
            end
            if upgradeId == "team_building_event" and gameState.temporaryEffectFlags.teamBuildingFocusBoostNextWeek then
                gameState.temporaryEffectFlags.teamBuildingActiveThisWeek = true
                gameState.temporaryEffectFlags.teamBuildingFocusBoostNextWeek = nil 
                 print("Team Spirit High! Focus boosted this week.")
            end
        end
    end

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
        -- This return is different because productivity/focus are already calculated inside the listener
        return { productivity = eventArgs.productivity, focus = eventArgs.focus, totalContribution = 0 }
    end

    employeeInstance.workCyclesThisItem = (employeeInstance.workCyclesThisItem or 0) + 1

    local stats = Employee:calculateStatsWithPosition(employeeInstance, gameState.hiredEmployees, gameState.deskAssignments, gameState.purchasedPermanentUpgrades, gameState.desks, gameState)
    local individualProductivity = stats.currentProductivity
    local individualFocus = stats.currentFocus
    
    individualProductivity = individualProductivity * eventArgs.productivityMultiplier

    if employeeInstance.isFirstMover then
        individualProductivity = individualProductivity * 2
        individualFocus = individualFocus * 2
        table.insert(stats.calculationLog.productivity, "*2 from First Mover")
        table.insert(stats.calculationLog.focus, "*2 from First Mover")
    end
    if employeeInstance.isAutomated then
        table.insert(stats.calculationLog.productivity, "Contribution will be doubled by Automation v1")
    end

    if employeeInstance.snackBoostActive then
        local focusMultiplier = 1.5
        if employeeInstance.special and employeeInstance.special.scales_with_level then focusMultiplier = 1 + ((focusMultiplier - 1) * (employeeInstance.level or 1)) end
        individualFocus = individualFocus * focusMultiplier
        employeeInstance.snackBoostActive = nil
        table.insert(stats.calculationLog.focus, string.format("*%.1fx from Snack!", focusMultiplier))
    end

    if employeeInstance.narratorBoostActive then
        local focusBonus = 0.1
        local narrator = nil
        for _, emp in ipairs(gameState.hiredEmployees) do if emp.special and emp.special.type == 'narrator_boost' then narrator = emp; break; end end
        if narrator and narrator.special.scales_with_level then focusBonus = focusBonus * (narrator.level or 1) end
        individualFocus = individualFocus * (1 + focusBonus)
        employeeInstance.narratorBoostActive = nil
        table.insert(stats.calculationLog.focus, string.format("+%.0f%% from Narrator", focusBonus * 100))
    end

    if gameState.temporaryEffectFlags.officeDogActiveThisTurn and gameState.temporaryEffectFlags.officeDogTarget == employeeInstance.instanceId then
        individualFocus = individualFocus * 2
        print(employeeInstance.name .. " gets Office Dog focus boost! New Focus: " .. individualFocus)
        gameState.temporaryEffectFlags.officeDogActiveThisTurn = false 
        gameState.temporaryEffectFlags.officeDogTarget = nil
    end
    
    local employeeContribution = math.floor(individualProductivity * individualFocus)
    
    employeeContribution = math.floor(employeeContribution * eventArgs.contributionMultiplier)

    if employeeInstance.agileFirstTurnBoost then
        local boost = employeeInstance.agileFirstTurnBoost
        local agileCoach
        for _, e in ipairs(gameState.hiredEmployees) do if e.special and e.special.type == 'randomize_work_order' then agileCoach = e; break; end end
        if agileCoach and agileCoach.special.scales_with_level then boost = 1 + ((boost - 1) * (agileCoach.level or 1)) end
        employeeContribution = math.floor(employeeContribution * boost)
        table.insert(stats.calculationLog.productivity, string.format("*%.1fx from Agile Rush", boost))
        employeeInstance.agileFirstTurnBoost = nil
    end
    
    if employeeInstance.isRebooted then
        local rebootMultiplier = 3
        employeeContribution = employeeContribution * rebootMultiplier
        employeeInstance.isRebooted = nil 
    end

    if employeeInstance.isInspired then
        local museMultiplier = 3
        local muse
        for _, e in ipairs(gameState.hiredEmployees) do if e.special and e.special.type == 'inspire_teammate' then muse = e; break; end end
        if muse and muse.special.scales_with_level then museMultiplier = 1 + ((museMultiplier - 1) * (muse.level or 1)) end
        employeeContribution = employeeContribution * museMultiplier
        employeeInstance.isInspired = nil
        print(employeeInstance.name .. " feels inspired! Contribution multiplied by " .. museMultiplier)
    end

    if employeeInstance.isAutomated then
        employeeContribution = employeeContribution * 2
    end

    employeeInstance.contributionThisItem = (employeeInstance.contributionThisItem or 0) + employeeContribution
    
    local afterContributionEventArgs = {
        contribution = employeeContribution
    }
    EffectsDispatcher.dispatchEvent("onAfterContribution", gameState, afterContributionEventArgs)

    return {
        productivity = individualProductivity,
        focus = individualFocus,
        totalContribution = employeeContribution
    }
end

function Battle:calculateTotalSalariesForRound(gameState)
    local eventArgs = {
        cumulativePercentReduction = 1.0,
        totalFlatReduction = 0,
        salaryCap = nil,
        skipPayday = false
    }
    require("effects_dispatcher").dispatchEvent("onCalculateSalaries", gameState, eventArgs)

    if eventArgs.skipPayday then
        print("Payday skipped due to listener effect (e.g., Four-Day Work Week)!")
        return 0
    end

    local unionRepIsPresent = false; local accountantIsPresent = false; local csmIsPresent = false
    local csmSalaryMultiplier = 1.0
    for _, emp in ipairs(gameState.hiredEmployees) do
        if emp.special then
            if emp.special.prevents_salary_reduction then unionRepIsPresent = true end
            if emp.special.rounds_salaries then accountantIsPresent = true end
            if emp.special.type == 'secret_effects' then
                csmIsPresent = true; csmSalaryMultiplier = emp.special.salary_increase
            end
        end
    end

    local totalSalariesThisRound = 0
    
    if not unionRepIsPresent then
        for _, emp in ipairs(gameState.hiredEmployees) do
            if emp.special and emp.special.type == 'salary_reduction_percent_team' then
                local reduction = emp.special.value
                if emp.special.scales_with_level then reduction = 1 - ((1 - reduction) ^ (emp.level or 1)) end
                eventArgs.cumulativePercentReduction = eventArgs.cumulativePercentReduction * (1 - reduction)
            end
        end
        if gameState.purchasedPermanentUpgrades then
            for _, upgradeId in ipairs(gameState.purchasedPermanentUpgrades) do
                if not (gameState.temporaryEffectFlags.disabledUpgrades and gameState.temporaryEffectFlags.disabledUpgrades[upgradeId]) then
                    for _, upg in ipairs(GameData.ALL_UPGRADES) do
                        if upg.id == upgradeId and upg.effect and upg.effect.type == 'reduce_all_salaries_percent' then
                            eventArgs.cumulativePercentReduction = eventArgs.cumulativePercentReduction * (1 - upg.effect.value)
                        end
                        if upg.id == upgradeId and upg.effect and upg.effect.type == 'reduce_all_salaries_flat' then
                            eventArgs.totalFlatReduction = eventArgs.totalFlatReduction + upg.effect.value
                        end
                    end
                end
            end
        end
    end

    for _, emp in ipairs(gameState.hiredEmployees) do
        if not (emp.special and emp.special.type == 'vampire_budget_drain') then
            local finalSalary = emp.weeklySalary
            finalSalary = finalSalary - eventArgs.totalFlatReduction
            finalSalary = finalSalary * eventArgs.cumulativePercentReduction

            if eventArgs.salaryCap then
                finalSalary = math.min(finalSalary, eventArgs.salaryCap)
            end
            
            totalSalariesThisRound = totalSalariesThisRound + math.max(0, math.floor(finalSalary))
        end
    end
    
    if csmIsPresent then totalSalariesThisRound = math.floor(totalSalariesThisRound * csmSalaryMultiplier); print("Salaries secretly increased by CSM...") end
    if gameState.temporaryEffectFlags.globalSalaryMultiplier then totalSalariesThisRound = math.floor(totalSalariesThisRound * gameState.temporaryEffectFlags.globalSalaryMultiplier); print("Salaries increased by GLaDOS test...") end
    if accountantIsPresent then totalSalariesThisRound = math.floor(totalSalariesThisRound / 100 + 0.5) * 100; print("Accountant rounded total salaries to: $" .. totalSalariesThisRound) end
    
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
function Battle:endWorkCycleRound(gameState, totalSalariesThisRound)
    require("effects_dispatcher").dispatchEvent("onEndOfRound", gameState, { totalSalaries = totalSalariesThisRound })

    print("End of Work Cycle #" .. gameState.currentWeekCycles)
    print("Salaries paid this round: $" .. totalSalariesThisRound .. ". Budget remaining: $" .. gameState.budget)
    
    if gameState.budget < 0 then
        local eventArgs = { gameOverPrevented = false, message = "" }
        require("effects_dispatcher").dispatchEvent("onBudgetDepleted", gameState, eventArgs)

        if eventArgs.gameOverPrevented then
            _G.showMessage("Saved!", eventArgs.message)
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
                _G.showMessage("Legal Loophole!", "Your legal team found a loophole. The bailout is free! The current work item will restart.")
            else 
                gameState.bailOutsRemaining = gameState.bailOutsRemaining - 1
                _G.showMessage("Emergency Bailout!", "Budget crisis averted! Bailouts remaining: " .. gameState.bailOutsRemaining .. "\n\nThe current work item will restart with fresh funding.")
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