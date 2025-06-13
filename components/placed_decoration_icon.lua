-- components/placed_decoration_icon.lua
-- A self-contained component for drawing a decoration icon on the office floor.

local Drawing = require("drawing")

local PlacedDecorationIcon = {}
PlacedDecorationIcon.__index = PlacedDecorationIcon

function PlacedDecorationIcon:new(params)
    local instance = setmetatable({}, PlacedDecorationIcon)
    instance.data = params.data -- The full decoration data object
    instance.rect = params.rect -- The screen coordinates {x, y, w, h}
    return instance
end

function PlacedDecorationIcon:_createTooltip()
    local mouseX, mouseY = love.mouse.getPosition()
    local tooltipText = self.data.name .. "\n\n" .. self.data.description
    
    local textWidthForWrap = 200
    local wrappedHeight = Drawing.drawTextWrapped(tooltipText, 0, 0, textWidthForWrap, Drawing.UI.font, "left", nil, false) 
    local tooltipWidth = textWidthForWrap + 10
    local tooltipHeight = wrappedHeight + 6
    local tipX = mouseX + 15
    local tipY = mouseY
    
    if tipX + tooltipWidth > love.graphics.getWidth() then tipX = mouseX - tooltipWidth - 15 end
    if tipY + tooltipHeight > love.graphics.getHeight() then tipY = love.graphics.getHeight() - tooltipHeight end
    
    table.insert(Drawing.tooltipsToDraw, { text = tooltipText, x = tipX, y = tipY, w = tooltipWidth, h = tooltipHeight })
end

function PlacedDecorationIcon:draw()
    if not self.data then return end

    -- Set the color to black and draw the icon
    love.graphics.setColor(0, 0, 0, 1)
    love.graphics.setFont(Drawing.UI.titleFont)
    love.graphics.print(self.data.icon or "?", self.rect.x, self.rect.y)

    local mouseX, mouseY = love.mouse.getPosition()
    if Drawing.isMouseOver(mouseX, mouseY, self.rect.x, self.rect.y, self.rect.w, self.rect.h) then
        self:_createTooltip()
    end
end

return PlacedDecorationIcon