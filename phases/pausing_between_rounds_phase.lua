-- phases/pausing_between_rounds_phase.lua
-- A simple timed delay before the next work cycle begins.

local BasePhase = require("phases.base_phase")
local PausingBetweenRoundsPhase = setmetatable({}, BasePhase)
PausingBetweenRoundsPhase.__index = PausingBetweenRoundsPhase

function PausingBetweenRoundsPhase:new(manager)
    local instance = setmetatable(BasePhase:new(manager), self)
    instance.nextPhaseName = 'fast_recalculate_and_setup'
    return instance
end

function PausingBetweenRoundsPhase:enter(gameState, battleState)
    -- This timer logic was previously in chipping_salaries_phase.lua
    local speedMultiplier = math.min(2 ^ gameState.currentWeekCycles, 16)
    battleState.timer = 1.0 / speedMultiplier
end

function PausingBetweenRoundsPhase:onTimerComplete(gameState, battleState)
    gameState.currentWeekCycles = gameState.currentWeekCycles + 1
end

return PausingBetweenRoundsPhase