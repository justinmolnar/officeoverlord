-- phases/idle_phase.lua
-- The "waiting" phase between employee turns or at the start of a round.

local BasePhase = require("phases.base_phase")
local IdlePhase = setmetatable({}, BasePhase)
IdlePhase.__index = IdlePhase

function IdlePhase:new(manager)
    return setmetatable(BasePhase:new(manager), self)
end

function IdlePhase:update(dt, gameState, battleState)
    if battleState.nextEmployeeIndex > #battleState.activeEmployees then
        -- All employees have acted, move to apply the results.
        self.manager:changePhase('pre_apply_contribution', gameState, battleState)
    else
        -- Get the next employee ready for their turn.
        local currentEmployee = battleState.activeEmployees[battleState.nextEmployeeIndex]
        if currentEmployee then
            -- Dispatch the turn start event for any listeners (like Narrator)
            require("effects_dispatcher").dispatchEvent("onTurnStart", gameState, { modal = self.manager.services.modal }, { currentEmployee = currentEmployee })
        end
        self.manager:changePhase('turn_speed_check', gameState, battleState)
    end
end

return IdlePhase