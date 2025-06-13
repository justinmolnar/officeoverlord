-- components/dropdown.lua
-- A self-contained Dropdown component for the debug menu.

local Drawing = require("drawing")

local Dropdown = {}
Dropdown.__index = Dropdown

function Dropdown:new(params)
    local instance = setmetatable({}, Dropdown)
    instance.rect = params.rect
    -- A reference to the state table that holds .options, .selected, .isOpen, etc.
    instance.state = params.state
    return instance
end

function Dropdown:draw()
    Drawing.drawDropdown(self.rect, self.state)
    -- The open list must be drawn last, so we handle it in the main draw loop
end

function Dropdown:drawOpenList()
    if self.state.isOpen then
        Drawing.drawOpenDropdownList(self.rect, self.state)
    end
end

function Dropdown:handleMousePress(x, y, button)
    if button ~= 1 then return false end

    -- If the dropdown is open, it should handle any click.
    if self.state.isOpen then
        local optionHeight = 20
        local listVisibleHeight = math.min(#self.state.options * optionHeight, 200)
        local listRect = { x = self.rect.x, y = self.rect.y + self.rect.h, w = self.rect.w, h = listVisibleHeight }

        -- Check if the user clicked on an option within the list.
        if Drawing.isMouseOver(x, y, listRect.x, listRect.y, listRect.w, listRect.h) then
            local clickedIndex = math.floor((y + self.state.scrollOffset - listRect.y) / optionHeight) + 1
            if clickedIndex >= 1 and clickedIndex <= #self.state.options then
                self.state.selected = clickedIndex
            end
        end

        -- In either case (a click on an item or a click outside), close the dropdown.
        self.state.isOpen = false
        -- Return true to consume the mouse click and prevent it from affecting other components.
        return true
    end

    -- If the dropdown is not open, only check for a click on the main box to open it.
    if Drawing.isMouseOver(x, y, self.rect.x, self.rect.y, self.rect.w, self.rect.h) then
        self.state.isOpen = true
        return true
    end

    -- If the click was not on this component at all, return false.
    return false
end

function Dropdown:handleMouseWheel(y)
    if self.state.isOpen then
        local optionHeight = 20
        local scrollSpeed = optionHeight * 3
        self.state.scrollOffset = self.state.scrollOffset - (y * scrollSpeed)
        
        local listVisibleHeight = math.min(#self.state.options * optionHeight, 200)
        local maxScroll = math.max(0, (#self.state.options * optionHeight) - listVisibleHeight)
        self.state.scrollOffset = math.max(0, math.min(self.state.scrollOffset, maxScroll))
        return true -- Consume scroll wheel input
    end
    return false
end

return Dropdown