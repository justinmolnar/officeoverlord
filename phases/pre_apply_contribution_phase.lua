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
    local endOfRoundEventArgs = { pyramidSchemeActive = false }
    EffectsDispatcher.dispatchEvent("onEndOfRound", gameState, { modal = self.manager.services.modal }, endOfRoundEventArgs)

    if endOfRoundEventArgs.pyramidSchemeActive then
        local contributions = {}
        for instId, contribData in pairs(battleState.lastRoundContributions) do
            contributions[instId] = contribData.totalContribution
        end
        
        local transfers = Battle:calculatePyramidSchemeTransfers(gameState, contributions)
        for instId, amount in pairs(transfers) do
            if battleState.lastRoundContributions[instId] then
                battleState.lastRoundContributions[instId].totalContribution = battleState.lastRoundContributions[instId].totalContribution + amount
            end
        end
    end
    
    -- Recalculate the final total for the round after any modifications.
    battleState.roundTotalContribution = 0
    for _, contribData in pairs(battleState.lastRoundContributions) do
        battleState.roundTotalContribution = battleState.roundTotalContribution + contribData.totalContribution
    end

    self.manager:changePhase('apply_round_contribution', gameState, battleState)
end

return PreApplyContributionPhase