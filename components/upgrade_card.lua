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

    -- This component now orchestrates its own drawing using its local helpers
    _drawUpgradeCardFrame(self.data, self.rect.x, self.rect.y, self.rect.w, self.rect.h)
    
    _drawUpgradeCardContent(self.data, self.rect.w, self.rect.h, self.gameState, Shop)
    
    if self.data.sold then
        _drawUpgradeCardSoldOverlay(self.rect.w, self.rect.h)
    end
    
    love.graphics.pop()
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