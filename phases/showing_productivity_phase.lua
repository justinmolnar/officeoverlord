-- phases/showing_productivity_phase.lua
-- First animation step: show the employee's productivity value.

local BasePhase = require("phases.base_phase")
local ShowingProductivityPhase = setmetatable({}, BasePhase)
ShowingProductivityPhase.__index = ShowingProductivityPhase

function ShowingProductivityPhase:new(manager)
    local instance = setmetatable(BasePhase:new(manager), self)
    instance.nextPhaseName = 'showing_focus'
    return instance
end

function ShowingProductivityPhase:enter(gameState, battleState)
    battleState.timer = 0.6
end

return ShowingProductivityPhase