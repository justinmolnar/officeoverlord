-- phases/wait_for_apply_phase.lua
-- A simple delay used when no animations are needed after a recalculation.

local BasePhase = require("phases.base_phase")
local WaitForApplyPhase = setmetatable({}, BasePhase)
WaitForApplyPhase.__index = WaitForApplyPhase

function WaitForApplyPhase:new(manager)
    return setmetatable(BasePhase:new(manager), self)
end

function WaitForApplyPhase:update(dt, gameState, battleState)
    battleState.timer = battleState.timer - dt
    if battleState.timer <= 0 then
        self.manager:changePhase('pre_apply_contribution', gameState, battleState)
    end
end

return WaitForApplyPhase