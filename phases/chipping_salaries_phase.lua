-- phases/chipping_salaries_phase.lua
-- Animates the budget decreasing as salaries are paid.

local BasePhase = require("phases.base_phase")
local Battle = require("battle")

local ChippingSalariesPhase = setmetatable({}, BasePhase)
ChippingSalariesPhase.__index = ChippingSalariesPhase

function ChippingSalariesPhase:new(manager)
    return setmetatable(BasePhase:new(manager), self)
end

-- This local helper function avoids duplicating the result handling logic.
function handleRoundResult(roundResult, gameState)
    if roundResult == "lost_budget" then 
        _G.setGamePhase("game_over")
        return 
    end
    if roundResult == "lost_bailout" then 
        local currentSprintData = require("data").ALL_SPRINTS[gameState.currentSprintIndex]
        if currentSprintData then 
            local currentWorkItemData = currentSprintData.workItems[gameState.currentWorkItemIndex]
            if currentWorkItemData then 
                gameState.currentWeekWorkload = currentWorkItemData.workload
                gameState.initialWorkloadForBar = currentWorkItemData.workload
            end
        end
        gameState.currentWeekCycles = 0
        gameState.totalSalariesPaidThisWeek = 0
        gameState.currentShopOffers = {employees={}, upgrade=nil, restockCountThisWeek=0}
        _G.setGamePhase("hiring_and_upgrades")
        return 
    end
end

function ChippingSalariesPhase:update(dt, gameState, battleState)
    if battleState.salaryChipAmountRemaining > 0 then
        battleState.chipTimer = battleState.chipTimer + dt
        local chipsToProcess = math.floor(battleState.chipTimer * battleState.chipSpeed)
        if chipsToProcess > 0 then
            local amountToChipThisFrame = math.min(battleState.salaryChipAmountRemaining, chipsToProcess)
            gameState.budget = gameState.budget - amountToChipThisFrame
            gameState.totalSalariesPaidThisWeek = gameState.totalSalariesPaidThisWeek + amountToChipThisFrame
            battleState.salaryChipAmountRemaining = battleState.salaryChipAmountRemaining - amountToChipThisFrame
            battleState.chipTimer = battleState.chipTimer - (chipsToProcess / battleState.chipSpeed)
        end
   else
        local roundResult = Battle:endWorkCycleRound(gameState, battleState.salariesToPayThisRound, function(...) self.manager.services.modal:show(...) end)
        handleRoundResult(roundResult, gameState)

        local speedMultiplier = math.min(2 ^ gameState.currentWeekCycles, 16)
        battleState.timer = 1.0 / speedMultiplier
        self.manager:changePhase('pausing_between_rounds', gameState, battleState)
   end
end

return ChippingSalariesPhase