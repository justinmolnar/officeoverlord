-- components/upgrade_card.lua
-- A self-contained component for the upgrade offer in the shop.

local Drawing = require("drawing")
local Shop = require("shop")

local UpgradeCard = {}
UpgradeCard.__index = UpgradeCard

function UpgradeCard:new(params)
    local instance = setmetatable({}, UpgradeCard)
    instance.data = params.data
    instance.rect = params.rect

    -- References to global state
    instance.gameState = params.gameState
    instance.uiElementRects = params.uiElementRects
    instance.modal = params.modal

    return instance
end


function UpgradeCard:draw()
    if not self.data then return end

    Drawing._drawUpgradeCardFrame(self.data, self.rect.x, self.rect.y, self.rect.w, self.rect.h)
    Drawing._drawUpgradeCardContent(self.data, self.rect.w, self.rect.h, self.gameState, Shop)
    
    if self.data.sold then
        Drawing._drawUpgradeCardSoldOverlay(self.rect.w, self.rect.h)
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
            -- FIX: Call the new master UI builder function
            _G.buildUIComponents()
        end
        return true
    end
    return false
end

return UpgradeCard