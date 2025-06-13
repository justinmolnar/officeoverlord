-- phases/base_phase.lua
-- The base "class" for all battle phase states.

local BasePhase = {}
BasePhase.__index = BasePhase

function BasePhase:new(manager)
    local instance = setmetatable({}, self)
    instance.manager = manager -- Reference back to the manager for changing state
    return instance
end

-- Called when entering the phase.
function BasePhase:enter(gameState, battleState)
    -- Override in subclasses
end

-- Called every frame while the phase is active.
function BasePhase:update(dt, gameState, battleState)
    -- Override in subclasses
end

-- Called when exiting the phase.
function BasePhase:exit(gameState, battleState)
    -- Override in subclasses
end

return BasePhase