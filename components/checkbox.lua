-- components/checkbox.lua
-- A self-contained Checkbox component for the debug menu.

local Drawing = require("drawing")

local Checkbox = {}
Checkbox.__index = Checkbox

function Checkbox:new(params)
    local instance = setmetatable({}, Checkbox)
    instance.rect = params.rect
    instance.label = params.label
    -- A reference to the state table that holds the .checked property
    instance.state = params.state
    -- A callback for when the value changes
    instance.onToggle = params.onToggle or function() end
    return instance
end

function Checkbox:draw()
    Drawing.drawCheckbox(self.rect, self.label, self.state.checked)
end

function Checkbox:handleMousePress(x, y, button)
    if button == 1 and Drawing.isMouseOver(x, y, self.rect.x, self.rect.y, self.rect.w, self.rect.h) then
        self.state.checked = not self.state.checked
        self.onToggle(self.state.checked)
        return true
    end
    return false
end

return Checkbox