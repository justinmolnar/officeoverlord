-- phases/showing_focus_phase.lua
-- Second animation step: show the focus multiplier with a shake.

local BasePhase = require("phases.base_phase")
local ShowingFocusPhase = setmetatable({}, BasePhase)
ShowingFocusPhase.__index = ShowingFocusPhase

function ShowingFocusPhase:new(manager)
    local instance = setmetatable(BasePhase:new(manager), self)
    instance.nextPhaseName = 'showing_total'
    return instance
end

function ShowingFocusPhase:enter(gameState, battleState)
    battleState.isShaking = true
    battleState.timer = 0.8
end

function ShowingFocusPhase:exit(gameState, battleState)
    battleState.isShaking = false
end

return ShowingFocusPhase