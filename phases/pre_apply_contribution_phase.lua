-- phases/pre_apply_contribution_phase.lua
-- Handles end-of-round effects before applying the final contribution total.

local BasePhase = require("phases.base_phase")
local Battle = require("battle")
local EffectsDispatcher = require("effects_dispatcher")

local PreApplyContributionPhase = setmetatable({}, BasePhase)
PreApplyContributionPhase.__index = PreApplyContributionPhase

function PreApplyContributionPhase:new(manager)
    return setmetatable(BasePhase:new(manager), self)
end

function PreApplyContributionPhase:enter(gameState, battleState)
    local endOfRoundEventArgs = { 
        lastRoundContributions = battleState.lastRoundContributions 
    }
    EffectsDispatcher.dispatchEvent("onEndOfRound", gameState, { modal = self.manager.services.modal }, endOfRoundEventArgs)

    -- The listener for pyramid scheme will modify the contributions table directly.
    -- After the event, we just need to recalculate the total.
    
    battleState.roundTotalContribution = 0
    for _, contribData in pairs(battleState.lastRoundContributions) do
        battleState.roundTotalContribution = battleState.roundTotalContribution + contribData.totalContribution
    end

    self.manager:changePhase('apply_round_contribution', gameState, battleState)
end

return PreApplyContributionPhase