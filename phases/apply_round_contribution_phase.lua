-- phases/apply_round_contribution_phase.lua
-- Sets up the values needed for the workload chip-away animation.

local BasePhase = require("phases.base_phase")
local ApplyRoundContributionPhase = setmetatable({}, BasePhase)
ApplyRoundContributionPhase.__index = ApplyRoundContributionPhase

function ApplyRoundContributionPhase:new(manager)
    return setmetatable(BasePhase:new(manager), self)
end

function ApplyRoundContributionPhase:enter(gameState, battleState)
    battleState.chipAmountRemaining = battleState.roundTotalContribution
    if battleState.chipAmountRemaining > 0 then
        local speedMultiplier = math.min(2 ^ gameState.currentWeekCycles, 16)
        battleState.chipSpeed = math.max(150, battleState.chipAmountRemaining * 2.5) * speedMultiplier
        battleState.chipTimer = 0
        self.manager:changePhase('chipping_workload', gameState, battleState)
    else
        -- If there's no contribution, skip chipping and go straight to ending the round.
        self.manager:changePhase('ending_round', gameState, battleState)
    end
    battleState.roundTotalContribution = 0
end

return ApplyRoundContributionPhase
