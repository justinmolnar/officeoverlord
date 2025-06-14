-- phases/chipping_salaries_phase.lua
-- Animates the budget decreasing as salaries are paid.

local BasePhase = require("phases.base_phase")
local Battle = require("battle")

local ChippingSalariesPhase = setmetatable({}, BasePhase)
ChippingSalariesPhase.__index = ChippingSalariesPhase

function ChippingSalariesPhase:new(manager)
    return setmetatable(BasePhase:new(manager), self)
end

function ChippingSalariesPhase:update(dt, gameState, battleState)
    if battleState.salaryChipAmountRemaining > 0 then
        battleState.chipTimer = battleState.chipTimer + dt
        local chipsToProcess = math.floor(battleState.chipTimer * battleState.chipSpeed)
        if chipsToProcess > 0 then
            local amountToChipThisFrame = math.min(battleState.salaryChipAmountRemaining, chipsToProcess)
            gameState.budget = gameState.budget - amountToChipThisFrame
            gameState.totalSalariesPaidThisWeek = gameState.totalSalariesPaidThisWeek + amountToChipThisFrame
            battleState.salaryChipAmountRemaining = battleState.salaryChipAmountRemaining - amountToChipThisFrame
            battleState.chipTimer = battleState.chipTimer - (chipsToProcess / battleState.chipSpeed)
        end
   else
        local roundResult = Battle:endWorkCycleRound(gameState, battleState.salariesToPayThisRound, function(...) self.manager.services.modal:show(...) end)
        
        -- Call the new centralized function
        local callbacks = {
            setGamePhase = _G.setGamePhase,
            changeBattlePhase = function(...) self.manager:changePhase(...) end
        }
        Battle:processEndOfRoundResult(roundResult, gameState, battleState, callbacks)
   end
end

return ChippingSalariesPhase