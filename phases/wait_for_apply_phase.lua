-- phases/wait_for_apply_phase.lua
-- A simple delay used when no animations are needed after a recalculation.

local BasePhase = require("phases.base_phase")
local WaitForApplyPhase = setmetatable({}, BasePhase)
WaitForApplyPhase.__index = WaitForApplyPhase

function WaitForApplyPhase:new(manager)
    local instance = setmetatable(BasePhase:new(manager), self)
    instance.nextPhaseName = 'pre_apply_contribution'
    return instance
end

function WaitForApplyPhase:enter(gameState, battleState)
    battleState.timer = 0.4
end

return WaitForApplyPhase