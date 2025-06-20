-- components/button.lua
-- A self-contained, reusable Button component with Balatro-style 3D effects.

local Drawing = require("drawing")
local SoundManager = require("sound_manager")


local Button = {}
Button.__index = Button

--- Creates a new Button component.
-- @param params A table of parameters: { rect, text, style, onClick, isEnabled }
-- isEnabled should be a function that returns true or false based on game state.
function Button:new(params)
    local instance = setmetatable({}, Button)
    instance.rect = params.rect or {x=0, y=0, w=100, h=30}
    instance.text = params.text or ""
    instance.style = params.style or "primary"
    instance.font = params.font
    instance.onClick = params.onClick or function() end
    -- The isEnabled property is now a function to dynamically check button state
    instance.isEnabled = params.isEnabled or function() return true end
    
    -- Balatro-style button state
    instance.isPressed = false
    instance.pressTimer = 0
    
    return instance
end

function Button:draw()
    local mouseX, mouseY = love.mouse.getPosition()
    local enabled = self.isEnabled()
    local isHovered = Drawing.isMouseOver(mouseX, mouseY, self.rect.x, self.rect.y, self.rect.w, self.rect.h)
    
    -- The timer logic has been moved to Button:update(dt)
    
    -- Use the updated Drawing.drawButton function with press state
    Drawing.drawButton(self.text, self.rect.x, self.rect.y, self.rect.w, self.rect.h, self.style, enabled, isHovered, self.font, self.isPressed)
end

function Button:update(dt)
    if self.isPressed then
        self.pressTimer = self.pressTimer - dt
        if self.pressTimer <= 0 then
            self.isPressed = false
            -- Perform the click action AFTER the animation finishes.
            if self.onClick then
                self.onClick()
            end
        end
    end
end

--- Handles a mouse press event, firing the onClick callback if conditions are met.
-- @return boolean True if the input was handled, false otherwise.
function Button:handleMousePress(x, y, button)
    if button == 1 and self.isEnabled() and Drawing.isMouseOver(x, y, self.rect.x, self.rect.y, self.rect.w, self.rect.h) then
        -- Only start the animation here. Do not call onClick.
        self.isPressed = true
        self.pressTimer = 0.1 -- 100ms press animation
        
        SoundManager:playEffect('click')
        -- self.onClick() -- REMOVED FROM HERE
        return true -- Input was successfully handled
    end
    return false
end

return Button