-- phases/showing_total_phase.lua
-- Third animation step: show the final calculated contribution.

local BasePhase = require("phases.base_phase")
local ShowingTotalPhase = setmetatable({}, BasePhase)
ShowingTotalPhase.__index = ShowingTotalPhase

function ShowingTotalPhase:new(manager)
    return setmetatable(BasePhase:new(manager), self)
end

function ShowingTotalPhase:enter(gameState, battleState)
    battleState.isShaking = true
end

function ShowingTotalPhase:update(dt, gameState, battleState)
    battleState.timer = battleState.timer - dt
    if battleState.timer <= 0 then
        -- Add the contribution to the running total for the round
        battleState.roundTotalContribution = battleState.roundTotalContribution + battleState.lastContribution.totalContribution
        battleState.lastRoundContributions[battleState.currentWorkerId] = battleState.lastContribution
        
        battleState.timer = 0.3 -- Set timer for the next phase
        self.manager:changePhase('turn_over', gameState, battleState)
    end
end

function ShowingTotalPhase:exit(gameState, battleState)
    battleState.isShaking = false
end

return ShowingTotalPhase