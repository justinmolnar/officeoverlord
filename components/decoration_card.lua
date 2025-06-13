-- components/decoration_card.lua
-- A self-contained component for a decoration offer in the shop.

local Drawing = require("drawing")
local Shop = require("shop")

local DecorationCard = {}
DecorationCard.__index = DecorationCard

function DecorationCard:new(params)
    local instance = setmetatable({}, DecorationCard)
    instance.data = params.data
    instance.rect = params.rect
    instance.gameState = params.gameState
    instance.draggedItemState = params.draggedItemState
    return instance
end

function DecorationCard:draw()
    if not self.data then return end

    love.graphics.push()
    love.graphics.translate(self.rect.x, self.rect.y)

    -- Basic drawing - you can replace this with your own _drawDecorationCard helpers
    local bgColor = self.data.sold and {0.6,0.6,0.6,1} or Drawing.UI.colors.card_bg
    Drawing.drawPanel(0, 0, self.rect.w, self.rect.h, bgColor, Drawing.UI.colors.card_border, 3)
    love.graphics.setColor(self.data.sold and {0.4,0.4,0.4,1} or Drawing.UI.colors.text)

    love.graphics.setFont(Drawing.UI.titleFont)
    love.graphics.printf(self.data.icon or "?", 0, 4, self.rect.w - 4, "right")

    love.graphics.setFont(Drawing.UI.font)
    Drawing.drawTextWrapped(self.data.name, 4, 4, self.rect.w - (Drawing.UI.titleFont:getWidth(self.data.icon or "?") + 8), Drawing.UI.font, "left", 2)
    
    love.graphics.setFont(Drawing.UI.fontSmall)
    love.graphics.printf("Cost: $" .. (self.data.displayCost or self.data.cost), 4, 30, self.rect.w - 8, "left")
    Drawing.drawTextWrapped(self.data.description or "", 4, 42, self.rect.w - 8, Drawing.UI.fontSmall, "left", 3)
    
    if self.data.sold then
        love.graphics.setColor(Drawing.UI.colors.card_sold_overlay_bg)
        love.graphics.rectangle("fill",0,0,self.rect.w,self.rect.h,3,3)
        love.graphics.setFont(Drawing.UI.fontLarge)
        love.graphics.setColor(Drawing.UI.colors.card_sold_overlay_text)
        love.graphics.printf("SOLD", 0, self.rect.h/2 - Drawing.UI.fontLarge:getHeight()/2, self.rect.w, "center")
    end

    love.graphics.pop()
end

function DecorationCard:handleMousePress(x, y, button)
    if button ~= 1 or not self.data or self.data.sold then return false end

    if Drawing.isMouseOver(x, y, self.rect.x, self.rect.y, self.rect.w, self.rect.h) then
        self.draggedItemState.item = {
            type = "shop_decoration",
            data = self.data,
            cost = self.data.displayCost or self.data.cost
        }
        return true
    end
    return false
end

return DecorationCard