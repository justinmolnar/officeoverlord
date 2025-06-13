-- phases/showing_productivity_phase.lua
-- First animation step: show the employee's productivity value.

local BasePhase = require("phases.base_phase")
local ShowingProductivityPhase = setmetatable({}, BasePhase)
ShowingProductivityPhase.__index = ShowingProductivityPhase

function ShowingProductivityPhase:new(manager)
    return setmetatable(BasePhase:new(manager), self)
end

function ShowingProductivityPhase:update(dt, gameState, battleState)
    battleState.timer = battleState.timer - dt
    if battleState.timer <= 0 then
        battleState.timer = 0.6 -- Set timer for the next phase
        self.manager:changePhase('showing_focus', gameState, battleState)
    end
end

return ShowingProductivityPhase