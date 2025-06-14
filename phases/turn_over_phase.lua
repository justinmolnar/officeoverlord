-- phases/turn_over_phase.lua
-- A brief pause to clean up after an employee's turn before starting the next.

local BasePhase = require("phases.base_phase")
local TurnOverPhase = setmetatable({}, BasePhase)
TurnOverPhase.__index = TurnOverPhase

function TurnOverPhase:new(manager)
    local instance = setmetatable(BasePhase:new(manager), self)
    instance.nextPhaseName = 'idle'
    return instance
end

function TurnOverPhase:enter(gameState, battleState)
    -- This timer value was previously set in the 'showing_total' phase.
    -- It is now self-contained here.
    battleState.timer = 0.3
end

function TurnOverPhase:onTimerComplete(gameState, battleState)
    -- Clean up state from the completed turn
    battleState.currentWorkerId = nil
    battleState.lastContribution = nil
    battleState.nextEmployeeIndex = battleState.nextEmployeeIndex + 1
end

return TurnOverPhase