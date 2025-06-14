-- phases/base_phase.lua
-- The base "class" for all battle phase states.

local BasePhase = {}
BasePhase.__index = BasePhase

function BasePhase:new(manager)
    local instance = setmetatable({}, self)
    instance.manager = manager -- Reference back to the manager for changing state
    instance.nextPhaseName = 'idle' -- Default next phase
    return instance
end

-- Called when entering the phase.
function BasePhase:enter(gameState, battleState)
    -- Override in subclasses to set battleState.timer
end

-- Generic update function to handle timers.
function BasePhase:update(dt, gameState, battleState)
    if battleState.timer > 0 then
        battleState.timer = battleState.timer - dt
        if battleState.timer <= 0 then
            self:onTimerComplete(gameState, battleState)
            self.manager:changePhase(self.nextPhaseName, gameState, battleState)
        end
    else
        -- If timer is already zero or less, transition immediately.
        self:onTimerComplete(gameState, battleState)
        self.manager:changePhase(self.nextPhaseName, gameState, battleState)
    end
end

-- Hook for child classes to run logic when the timer completes.
function BasePhase:onTimerComplete(gameState, battleState)
    -- Override in subclasses if needed
end

-- Called when exiting the phase.
function BasePhase:exit(gameState, battleState)
    -- Override in subclasses
end

return BasePhase