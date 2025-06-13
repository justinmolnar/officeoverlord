-- phases/chipping_workload_phase.lua
-- Animates the workload bar decreasing based on the round's total contribution.

local BasePhase = require("phases.base_phase")
local ChippingWorkloadPhase = setmetatable({}, BasePhase)
ChippingWorkloadPhase.__index = ChippingWorkloadPhase

function ChippingWorkloadPhase:new(manager)
    return setmetatable(BasePhase:new(manager), self)
end

function ChippingWorkloadPhase:update(dt, gameState, battleState)
    if battleState.chipAmountRemaining > 0 and gameState.currentWeekWorkload > 0 then
        battleState.chipTimer = battleState.chipTimer + dt
        local chipsToProcess = math.floor(battleState.chipTimer * battleState.chipSpeed)
        if chipsToProcess > 0 then
            local amountToChipThisFrame = math.min(battleState.chipAmountRemaining, chipsToProcess, gameState.currentWeekWorkload)
            gameState.currentWeekWorkload = gameState.currentWeekWorkload - amountToChipThisFrame
            battleState.chipAmountRemaining = battleState.chipAmountRemaining - amountToChipThisFrame
            battleState.chipTimer = battleState.chipTimer - (chipsToProcess / battleState.chipSpeed)
        end
    else
        battleState.isShaking = false
        battleState.currentWorkerId = nil
        battleState.lastContribution = nil

        if gameState.currentWeekWorkload <= 0 then
            -- This function (defined in main.lua) handles the win and transitions game state.
            _G.handleWinCondition() 
            -- We don't need to transition the battle phase manager, as the main game state will change.
            return 
        end
        self.manager:changePhase('ending_round', gameState, battleState)
    end
end

return ChippingWorkloadPhase
