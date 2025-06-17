-- components/tooltip.lua
-- A self-contained component for creating and drawing tooltips.

local Drawing = require("drawing")

local Tooltip = {}
Tooltip.__index = Tooltip

---
-- Creates a new tooltip object.
-- @param params A table of parameters:
-- {
--    x = mouseX,
--    y = mouseY,
--    width = 200, -- Optional: max width
--    content = { -- A table of lines to display
--        { text = "Line 1", color = {1,1,1} },
--        { text = "Line 2", color = {0.8, 0.8, 0.8} }
--    }
-- }
function Tooltip:new(params)
    local instance = setmetatable({}, Tooltip)
    
    instance.content = params.content or {}
    instance.maxWidth = params.width or 250

    -- Calculate dimensions based on content
    instance:_calculateDimensions()

    -- Calculate position based on mouse position and dimensions
    instance:_calculatePosition(params.x, params.y)

    return instance
end

--- Internal function to calculate the width and height of the tooltip.
function Tooltip:_calculateDimensions()
    local font = Drawing.UI.font or love.graphics.getFont()
    local lineHeight = font:getHeight()
    local totalHeight = 16 -- Initial top/bottom padding
    local actualWidth = 0

    for _, lineInfo in ipairs(self.content) do
        local text = lineInfo.text or ""
        if text == "" then
            totalHeight = totalHeight + lineHeight * 0.5
        else
            local _, wrappedLines = font:getWrap(text, self.maxWidth - 16)
            for _, line in ipairs(wrappedLines) do
                 actualWidth = math.max(actualWidth, font:getWidth(line))
            end
            totalHeight = totalHeight + #wrappedLines * lineHeight
        end
    end
    
    self.width = actualWidth + 16 -- Add left/right padding
    self.height = totalHeight
end

--- Internal function to position the tooltip so it stays on screen.
function Tooltip:_calculatePosition(mouseX, mouseY)
    self.x = mouseX + 15
    self.y = mouseY

    if self.x + self.width > love.graphics.getWidth() then
        self.x = mouseX - self.width - 15
    end
    if self.y + self.height > love.graphics.getHeight() then
        self.y = love.graphics.getHeight() - self.height
    end
    if self.y < 0 then
        self.y = 0
    end
end

--- Draws the tooltip panel and its content.
function Tooltip:draw()
    Drawing.drawPanel(self.x, self.y, self.width, self.height, {0.1, 0.1, 0.1, 0.95}, {0.3, 0.3, 0.3, 1})
    
    local font = Drawing.UI.font or love.graphics.getFont()
    love.graphics.setFont(font)
    
    local currentY = self.y + 8
    local lineHeight = font:getHeight()

    for _, lineInfo in ipairs(self.content) do
        local text = lineInfo.text or ""
        if text == "" then
            currentY = currentY + lineHeight * 0.5
        else
            love.graphics.setColor(lineInfo.color or {1, 1, 1, 1})
            local _, wrappedLines = font:getWrap(text, self.width - 16)
            for _, lineText in ipairs(wrappedLines) do
                love.graphics.print(lineText, self.x + 8, currentY)
                currentY = currentY + lineHeight
            end
        end
    end
end

return Tooltip