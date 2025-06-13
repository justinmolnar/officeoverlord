-- phases/fast_recalculate_and_setup_phase.lua
-- Recalculates contributions and checks for changes to animate between rounds.

local BasePhase = require("phases.base_phase")
local Battle = require("battle")

local FastRecalculateAndSetupPhase = setmetatable({}, BasePhase)
FastRecalculateAndSetupPhase.__index = FastRecalculateAndSetupPhase

function FastRecalculateAndSetupPhase:new(manager)
    return setmetatable(BasePhase:new(manager), self)
end

function FastRecalculateAndSetupPhase:enter(gameState, battleState)
    battleState.roundTotalContribution = 0
    battleState.changedEmployeesForAnimation = {}
    local currentRoundContributions = {}
    for i, emp in ipairs(battleState.activeEmployees) do
        if i == 1 then
            emp.isFirstMover = true
        end
        local newContrib = Battle:calculateEmployeeContribution(emp, gameState)
        currentRoundContributions[emp.instanceId] = newContrib
        local oldContrib = battleState.lastRoundContributions[emp.instanceId]
        if not oldContrib or newContrib.totalContribution ~= oldContrib.totalContribution then
            table.insert(battleState.changedEmployeesForAnimation, {emp = emp, new = newContrib, old = oldContrib})
        end
    end
    battleState.lastRoundContributions = currentRoundContributions
    
    for _, contrib in pairs(currentRoundContributions) do
        battleState.roundTotalContribution = battleState.roundTotalContribution + contrib.totalContribution
    end
    
    battleState.nextChangedEmployeeIndex = 1
    
    if #battleState.changedEmployeesForAnimation == 0 then
        battleState.timer = 0.4 
        self.manager:changePhase('wait_for_apply', gameState, battleState)
    else
        battleState.timer = 0
        self.manager:changePhase('animating_changes', gameState, battleState)
    end
end

return FastRecalculateAndSetupPhase