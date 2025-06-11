-- components/purchased_upgrade_icon.lua
-- A self-contained component for an icon in the purchased upgrades panel.

local Drawing = require("drawing")

local PurchasedUpgradeIcon = {}
PurchasedUpgradeIcon.__index = PurchasedUpgradeIcon

function PurchasedUpgradeIcon:new(params)
    local instance = setmetatable({}, PurchasedUpgradeIcon)
    instance.rect = params.rect
    instance.upgData = params.upgData
    instance.gameState = params.gameState
    return instance
end

--- Internal helper to determine if the upgrade can be clicked right now.
function PurchasedUpgradeIcon:_isClickable()
    if not self.upgData or not self.upgData.id then return false end
    
    local gs = self.gameState
    local flags = gs.temporaryEffectFlags
    
    local conditions = {
        motivational_speaker = gs.gamePhase == 'hiring_and_upgrades' and not flags.motivationalSpeakerUsedThisSprint and gs.budget >= 1000,
        the_reorg = gs.gamePhase == 'hiring_and_upgrades' and not flags.reOrgUsedThisSprint,
        sentient_photocopier = gs.gamePhase == 'hiring_and_upgrades' and not flags.photocopierUsedThisSprint,
        multiverse_merger = flags.multiverseMergerAvailable
    }
    
    return conditions[self.upgData.id] or false
end

--- Internal helper to generate this icon's tooltip.
function PurchasedUpgradeIcon:_createTooltip()
    local mouseX, mouseY = love.mouse.getPosition()
    local isClickable = self:_isClickable()

    local tooltipText = self.upgData.name .. ": " .. self.upgData.description
    if isClickable then
        tooltipText = tooltipText .. "\n\n(Click to Activate)"
    end
    
    local textWidthForWrap = 200
    local wrappedHeight = Drawing.drawTextWrapped(tooltipText, 0, 0, textWidthForWrap, Drawing.UI.font, "left", nil, false) 
    local tooltipWidth = textWidthForWrap + 10
    local tooltipHeight = wrappedHeight + 6
    local tipX = mouseX + 5
    local tipY = mouseY - tooltipHeight - 2
    
    if tipX + tooltipWidth > love.graphics.getWidth() then tipX = mouseX - tooltipWidth - 5 end
    
    table.insert(Drawing.tooltipsToDraw, { text = tooltipText, x = tipX, y = tipY, w = tooltipWidth, h = tooltipHeight })
end

--- Draws the icon and its hover effects.
function PurchasedUpgradeIcon:draw()
    -- This print confirms the component is being drawn each frame.
    -- print("Drawing upgrade icon:", self.upgData.name)

    local isClickable = self:_isClickable()
    local mouseX, mouseY = love.mouse.getPosition()
    local isHovered = Drawing.isMouseOver(mouseX, mouseY, self.rect.x, self.rect.y, self.rect.w, self.rect.h)

    if isClickable and isHovered then
        love.graphics.setColor(0.2, 0.8, 0.2, 0.4)
        love.graphics.rectangle("fill", self.rect.x - 2, self.rect.y - 2, self.rect.w + 4, self.rect.h + 4, 3)
    end

    love.graphics.setFont(Drawing.UI.titleFont or Drawing.UI.fontLarge) 
    love.graphics.setColor(Drawing.UI.colors.text_light)
    love.graphics.print(self.upgData.icon or "?", self.rect.x, self.rect.y)

    if isHovered then
        -- This print will appear if the game detects you are hovering over the icon.
        self:_createTooltip()
    end
end

--- Handles clicks to activate the upgrade's ability.
function PurchasedUpgradeIcon:handleMousePress(x, y, button)
    if button == 1 and self:_isClickable() and Drawing.isMouseOver(x, y, self.rect.x, self.rect.y, self.rect.w, self.rect.h) then
        if self.upgData.listeners and self.upgData.listeners.onActivate then
            -- The listener is responsible for checking its own conditions.
            if self.upgData.listeners.onActivate(self.upgData, self.gameState) then
                return true -- The click was handled by the listener.
            end
        end
    end
    return false
end

return PurchasedUpgradeIcon