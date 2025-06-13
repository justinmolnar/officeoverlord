-- phases/pausing_between_rounds_phase.lua
-- A simple timed delay before the next work cycle begins.

local BasePhase = require("phases.base_phase")
local PausingBetweenRoundsPhase = setmetatable({}, BasePhase)
PausingBetweenRoundsPhase.__index = PausingBetweenRoundsPhase

function PausingBetweenRoundsPhase:new(manager)
    return setmetatable(BasePhase:new(manager), self)
end

function PausingBetweenRoundsPhase:update(dt, gameState, battleState)
    battleState.timer = battleState.timer - dt
    if battleState.timer <= 0 then
        gameState.currentWeekCycles = gameState.currentWeekCycles + 1
        -- In the future, this might go to a "recalculate" phase, but for now, it goes back to idle.
        self.manager:changePhase('fast_recalculate_and_setup', gameState, battleState)
    end
end

return PausingBetweenRoundsPhase