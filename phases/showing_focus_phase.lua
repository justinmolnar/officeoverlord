-- phases/showing_focus_phase.lua
-- Second animation step: show the focus multiplier with a shake.

local BasePhase = require("phases.base_phase")
local ShowingFocusPhase = setmetatable({}, BasePhase)
ShowingFocusPhase.__index = ShowingFocusPhase

function ShowingFocusPhase:new(manager)
    return setmetatable(BasePhase:new(manager), self)
end

function ShowingFocusPhase:enter(gameState, battleState)
    battleState.isShaking = true
end

function ShowingFocusPhase:update(dt, gameState, battleState)
    battleState.timer = battleState.timer - dt
    if battleState.timer <= 0 then
        battleState.isShaking = false -- Stop shaking before the next phase starts its own shake
        battleState.timer = 0.8 -- Set timer for the next phase
        self.manager:changePhase('showing_total', gameState, battleState)
    end
end

function ShowingFocusPhase:exit(gameState, battleState)
    battleState.isShaking = false
end

return ShowingFocusPhase