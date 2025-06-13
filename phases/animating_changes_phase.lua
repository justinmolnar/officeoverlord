-- phases/animating_changes_phase.lua
-- Animates the contribution values on cards that changed between rounds.

local BasePhase = require("phases.base_phase")
local AnimatingChangesPhase = setmetatable({}, BasePhase)
AnimatingChangesPhase.__index = AnimatingChangesPhase

function AnimatingChangesPhase:new(manager)
    return setmetatable(BasePhase:new(manager), self)
end

function AnimatingChangesPhase:update(dt, gameState, battleState)
    battleState.timer = battleState.timer - dt
    if battleState.timer <= 0 then
        if battleState.currentWorkerId then
            battleState.nextChangedEmployeeIndex = battleState.nextChangedEmployeeIndex + 1
        end
        if battleState.nextChangedEmployeeIndex > #battleState.changedEmployeesForAnimation then
            battleState.currentWorkerId = nil
            battleState.lastContribution = nil
            self.manager:changePhase('pre_apply_contribution', gameState, battleState)
        else
            local changeInfo = battleState.changedEmployeesForAnimation[battleState.nextChangedEmployeeIndex]
            battleState.currentWorkerId = changeInfo.emp.instanceId
            battleState.lastContribution = changeInfo.new
            battleState.isShaking = true
            battleState.timer = 0.5
        end
    end
end

function AnimatingChangesPhase:exit(gameState, battleState)
    battleState.isShaking = false
end

return AnimatingChangesPhase