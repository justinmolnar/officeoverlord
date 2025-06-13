-- phases/turn_over_phase.lua
-- A brief pause to clean up after an employee's turn before starting the next.

local BasePhase = require("phases.base_phase")
local TurnOverPhase = setmetatable({}, BasePhase)
TurnOverPhase.__index = TurnOverPhase

function TurnOverPhase:new(manager)
    return setmetatable(BasePhase:new(manager), self)
end

function TurnOverPhase:update(dt, gameState, battleState)
    battleState.timer = battleState.timer - dt
    if battleState.timer <= 0 then
        -- Clean up state from the completed turn
        battleState.currentWorkerId = nil
        battleState.lastContribution = nil
        battleState.nextEmployeeIndex = battleState.nextEmployeeIndex + 1
        
        -- Go back to the idle phase to decide what's next
        self.manager:changePhase('idle', gameState, battleState)
    end
end

return TurnOverPhase