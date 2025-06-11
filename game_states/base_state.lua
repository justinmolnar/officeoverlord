-- game_states/base_state.lua
local BaseState = {}
BaseState.__index = BaseState

function BaseState:new()
    local instance = setmetatable({}, self)
    return instance
end

function BaseState:enter(gameState, battleState, context)
    -- Override in subclasses
    -- context contains references to UI state, panels, etc.
end

function BaseState:exit(gameState, battleState, context)
    -- Override in subclasses
end

function BaseState:update(dt, gameState, battleState, context)
    -- Override in subclasses
end

function BaseState:draw(gameState, battleState, context)
    -- Override in subclasses
    -- context contains panelRects, uiElementRects, draggedItemState, etc.
end

function BaseState:handleInput(x, y, button, gameState, battleState, context)
    -- Default input handling - loop through components
    if context.uiComponents then
        for _, component in ipairs(context.uiComponents) do
            if component.handleMousePress and component:handleMousePress(x, y, button) then
                return true
            end
        end
    end
    return false
end

return BaseState