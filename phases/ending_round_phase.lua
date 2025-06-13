-- phases/ending_round_phase.lua
-- Marks progress and calculates salaries before payment.

local BasePhase = require("phases.base_phase")
local Battle = require("battle")

local EndingRoundPhase = setmetatable({}, BasePhase)
EndingRoundPhase.__index = EndingRoundPhase

function EndingRoundPhase:new(manager)
    return setmetatable(BasePhase:new(manager), self)
end

function EndingRoundPhase:enter(gameState, battleState)
    if gameState.initialWorkloadForBar > 0 then
        local progress = math.max(0, gameState.currentWeekWorkload / gameState.initialWorkloadForBar)
        table.insert(battleState.progressMarkers, progress)
    end
    
    battleState.salariesToPayThisRound = Battle:calculateTotalSalariesForRound(gameState)
    self.manager:changePhase('paying_salaries', gameState, battleState)
end

return EndingRoundPhase