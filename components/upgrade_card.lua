-- components/upgrade_card.lua
-- A self-contained component for the upgrade offer in the shop.

local Drawing = require("drawing")
local Shop = require("shop")

local UpgradeCard = {}
UpgradeCard.__index = UpgradeCard

---
-- LOCAL HELPER FUNCTIONS (Moved from drawing.lua)
---

local function _drawUpgradeCardFrame(upgradeData, x, y, width, height)
    love.graphics.push()
    love.graphics.translate(x, y)
    
    local bgColor = upgradeData.sold and {0.6,0.6,0.6,1} or Drawing.UI.colors.card_bg
    Drawing.drawPanel(0, 0, width, height, bgColor, Drawing.UI.colors.card_border, 3)
    
    love.graphics.setColor(upgradeData.sold and {0.4,0.4,0.4,1} or Drawing.UI.colors.text)
end

local function _drawUpgradeCardContent(upgradeData, width, height, gameState, Shop)
    local padding = 4
    
    love.graphics.setFont(Drawing.UI.titleFont)
    local icon = upgradeData.icon or "❓"
    local iconWidth = Drawing.UI.titleFont:getWidth(icon)
    love.graphics.printf(icon, 0, padding, width - padding, "right")

    local textWrapWidth = width - iconWidth - (padding * 2)
    local currentY = padding

    love.graphics.setFont(Drawing.UI.font)
    currentY = currentY + Drawing.drawTextWrapped(upgradeData.name, padding, currentY, textWrapWidth, Drawing.UI.font, "left", 2) + 5

    love.graphics.setFont(Drawing.UI.fontSmall)
    
    local finalCost = Shop:getModifiedUpgradeCost(upgradeData, gameState.hiredEmployees)
    love.graphics.printf("Cost: $" .. finalCost, padding, currentY, textWrapWidth, "left")
    
    currentY = currentY + Drawing.UI.fontSmall:getHeight() + 2
    Drawing.drawTextWrapped(upgradeData.description or "", padding, currentY, textWrapWidth, Drawing.UI.fontSmall, "left", 3)
end

local function _drawUpgradeCardSoldOverlay(width, height)
    love.graphics.setColor(Drawing.UI.colors.card_sold_overlay_bg)
    love.graphics.rectangle("fill",0,0,width,height,3,3)
    
    love.graphics.setFont(Drawing.UI.fontLarge)
    love.graphics.setColor(Drawing.UI.colors.card_sold_overlay_text)
    love.graphics.printf("SOLD", 0, height/2 - Drawing.UI.fontLarge:getHeight()/2, width, "center")
end


---
-- COMPONENT METHODS
---

function UpgradeCard:new(params)
    local instance = setmetatable({}, UpgradeCard)
    instance.data = params.data
    instance.rect = params.rect
    instance.gameState = params.gameState
    instance.uiElementRects = params.uiElementRects
    instance.modal = params.modal
    return instance
end

function UpgradeCard:draw()
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
    local finalCost = Shop:getModifiedUpgradeCost(cardData, self.gameState.hiredEmployees)
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

function UpgradeCard:handleMousePress(x, y, button)
    if button ~= 1 or not self.data or self.data.sold then return false end

    if Drawing.isMouseOver(x, y, self.rect.x, self.rect.y, self.rect.w, self.rect.h) then
        local success, msg = Shop:buyUpgrade(self.gameState, self.data.id)
        if not success then 
            self.modal:show("Can't Upgrade", msg)
        else 
            Shop:markOfferSold(self.gameState.currentShopOffers, nil, self.data)
            _G.buildUIComponents()
        end
        return true
    end
    return false
end

return UpgradeCard