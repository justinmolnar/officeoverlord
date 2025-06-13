-- phases/starting_turn_phase.lua
-- Calculates an employee's contribution and begins the animation sequence.

local BasePhase = require("phases.base_phase")
local Battle = require("battle")

local StartingTurnPhase = setmetatable({}, BasePhase)
StartingTurnPhase.__index = StartingTurnPhase

function StartingTurnPhase:new(manager)
    return setmetatable(BasePhase:new(manager), self)
end

function StartingTurnPhase:enter(gameState, battleState)
    local currentEmployee = battleState.activeEmployees[battleState.nextEmployeeIndex]
    
    if gameState.temporaryEffectFlags.automatedEmployeeId == currentEmployee.instanceId then
        currentEmployee.isAutomated = true
    end

    if battleState.nextEmployeeIndex == 1 then
        currentEmployee.isFirstMover = true
    end

    battleState.currentWorkerId = currentEmployee.instanceId
    battleState.lastContribution = Battle:calculateEmployeeContribution(currentEmployee, gameState)
    battleState.timer = 0.5 -- Set timer for the next phase
    
    -- Immediately transition to the first animation phase
    self.manager:changePhase('showing_productivity', gameState, battleState)
end

return StartingTurnPhase