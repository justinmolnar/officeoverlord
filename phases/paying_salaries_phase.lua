-- phases/paying_salaries_phase.lua
-- Sets up the values for the salary chip-away animation.

local BasePhase = require("phases.base_phase")
local Battle = require("battle")

local PayingSalariesPhase = setmetatable({}, BasePhase)
PayingSalariesPhase.__index = PayingSalariesPhase

function PayingSalariesPhase:new(manager)
    return setmetatable(BasePhase:new(manager), self)
end

function PayingSalariesPhase:enter(gameState, battleState)
    battleState.salaryChipAmountRemaining = battleState.salariesToPayThisRound
    if battleState.salaryChipAmountRemaining > 0 then
        local speedMultiplier = math.min(2 ^ gameState.currentWeekCycles, 16)
        battleState.chipSpeed = math.max(150, battleState.salaryChipAmountRemaining * 3.0) * speedMultiplier
        battleState.chipTimer = 0
        self.manager:changePhase('chipping_salaries', gameState, battleState)
    else
        -- No salaries to pay, check for end-of-round results and move on.
        local roundResult = Battle:endWorkCycleRound(gameState, 0, function(...) self.manager.services.modal:show(...) end)
        
        -- Call the new centralized function
        local callbacks = {
            setGamePhase = _G.setGamePhase,
            changeBattlePhase = function(...) self.manager:changePhase(...) end
        }
        Battle:processEndOfRoundResult(roundResult, gameState, battleState, callbacks)
    end
end

return PayingSalariesPhase