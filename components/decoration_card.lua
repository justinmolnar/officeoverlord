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

    local cardData = self.data
    local x, y, w, h = self.rect.x, self.rect.y, self.rect.w, self.rect.h
    local mouseX, mouseY = love.mouse.getPosition()
    local isHovered = Drawing.isMouseOver(mouseX, mouseY, x, y, w, h)

    -- Draw small card frame
    local bgColor = cardData.sold and {0.6,0.6,0.6,1} or (isHovered and {0.9, 0.9, 0.9, 1} or Drawing.UI.colors.card_bg)
    love.graphics.push()
    love.graphics.translate(x, y)
    Drawing.drawPanel(0, 0, w, h, bgColor, Drawing.UI.colors.card_border, 5)

    -- Draw Icon
    love.graphics.setFont(Drawing.UI.titleFont)
    love.graphics.setColor(Drawing.UI.colors.text)
    love.graphics.printf(cardData.icon or "?", 0, 5, w, "center")

    -- Draw Price
    local finalCost = cardData.displayCost or cardData.cost
    love.graphics.setFont(Drawing.UI.font)
    love.graphics.setColor(0.1, 0.65, 0.35, 1) -- Green for cost
    love.graphics.printf("$" .. finalCost, 0, h - Drawing.UI.font:getHeight() - 5, w, "center")

    -- Draw Sold Overlay
    if cardData.sold then
        love.graphics.setColor(Drawing.UI.colors.card_sold_overlay_bg)
        love.graphics.rectangle("fill",0,0,w,h,5,5)
        love.graphics.setFont(Drawing.UI.fontLarge)
        love.graphics.setColor(Drawing.UI.colors.card_sold_overlay_text)
        love.graphics.printf("SOLD", 0, h/2 - Drawing.UI.fontLarge:getHeight()/2, w, "center")
    end

    love.graphics.pop()

    -- Create Tooltip
    if isHovered and not cardData.sold then
        local Tooltip = require("components/tooltip")
        
        local tooltipContent = {
            { text = self.data.name, color = {1, 1, 1} },
            { text = "" },
            { text = self.data.description, color = {0.8, 0.8, 0.8} },
            { text = "" },
            { text = "Cost: $" .. finalCost, color = {0.1, 0.65, 0.35} },
        }

        table.insert(Drawing.tooltipsToDraw, Tooltip:new({
            x = mouseX,
            y = mouseY,
            width = 200,
            content = tooltipContent
        }))
    end
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