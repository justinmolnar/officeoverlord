-- phases/showing_total_phase.lua
-- Third animation step: show the final calculated contribution.

local BasePhase = require("phases.base_phase")
local ShowingTotalPhase = setmetatable({}, BasePhase)
ShowingTotalPhase.__index = ShowingTotalPhase

function ShowingTotalPhase:new(manager)
    local instance = setmetatable(BasePhase:new(manager), self)
    instance.nextPhaseName = 'turn_over'
    return instance
end

function ShowingTotalPhase:enter(gameState, battleState)
    battleState.isShaking = true
    battleState.timer = 0.3
end

function ShowingTotalPhase:onTimerComplete(gameState, battleState)
    -- Add the contribution to the running total for the round
    battleState.roundTotalContribution = battleState.roundTotalContribution + battleState.lastContribution.totalContribution
    battleState.lastRoundContributions[battleState.currentWorkerId] = battleState.lastContribution
end

function ShowingTotalPhase:exit(gameState, battleState)
    battleState.isShaking = false
end

return ShowingTotalPhase