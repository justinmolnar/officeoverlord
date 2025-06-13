-- phases/paying_salaries_phase.lua
-- Sets up the values for the salary chip-away animation.

local BasePhase = require("phases.base_phase")
local Battle = require("battle")

local PayingSalariesPhase = setmetatable({}, BasePhase)
PayingSalariesPhase.__index = PayingSalariesPhase

function PayingSalariesPhase:new(manager)
    return setmetatable(BasePhase:new(manager), self)
end

function PayingSalariesPhase:enter(gameState, battleState)
    battleState.salaryChipAmountRemaining = battleState.salariesToPayThisRound
    if battleState.salaryChipAmountRemaining > 0 then
        local speedMultiplier = math.min(2 ^ gameState.currentWeekCycles, 16)
        battleState.chipSpeed = math.max(150, battleState.salaryChipAmountRemaining * 3.0) * speedMultiplier
        battleState.chipTimer = 0
        self.manager:changePhase('chipping_salaries', gameState, battleState)
    else
        -- No salaries to pay, check for end-of-round results and move on.
        local roundResult = Battle:endWorkCycleRound(gameState, 0, function(...) self.manager.services.modal:show(...) end)
        handleRoundResult(roundResult, gameState)
        
        local speedMultiplier = math.min(2 ^ gameState.currentWeekCycles, 16)
        battleState.timer = 1.0 / speedMultiplier
        self.manager:changePhase('pausing_between_rounds', gameState, battleState)
    end
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

return PayingSalariesPhase