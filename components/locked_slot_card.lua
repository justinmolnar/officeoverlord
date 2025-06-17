-- components/locked_slot_card.lua
-- A component for a locked shop slot, styled like a locked desk.

local Drawing = require("drawing")
local SoundManager = require("sound_manager")

local LockedSlotCard = {}
LockedSlotCard.__index = LockedSlotCard

function LockedSlotCard:new(params)
    local instance = setmetatable({}, LockedSlotCard)
    instance.rect = params.rect
    instance.text = params.text or "Unlock Slot"
    instance.cost = params.cost or 0
    instance.isEnabled = params.isEnabled or function() return true end
    instance.onClick = params.onClick or function() end
    return instance
end

function LockedSlotCard:draw()
    local x, y, w, h = self.rect.x, self.rect.y, self.rect.w, self.rect.h
    local mouseX, mouseY = love.mouse.getPosition()
    local isHovered = Drawing.isMouseOver(mouseX, mouseY, x, y, w, h)
    local enabled = self.isEnabled()

    -- Use the same colors as a locked desk slot
    local bgColor = Drawing.UI.colors.desk_locked_bg
    local borderColor = Drawing.UI.colors.desk_locked_border
    local textColor = Drawing.UI.colors.desk_text
    
    -- Add a subtle hover effect if the slot is affordable
    if enabled and isHovered then
        bgColor = {bgColor[1] * 1.05, bgColor[2] * 1.05, bgColor[3] * 1.05, 1}
    elseif not enabled then
        textColor = {0.6, 0.6, 0.6, 1} -- Disabled text color
    end

    Drawing.drawPanel(x, y, w, h, bgColor, borderColor, 3)

    -- Draw the unlock text and cost
    love.graphics.setColor(textColor)
    love.graphics.setFont(Drawing.UI.font)
    love.graphics.printf(self.text .. "\n$" .. self.cost, x, y + h/2 - Drawing.UI.font:getHeight(), w, "center")
end

function LockedSlotCard:handleMousePress(x, y, button)
    if button == 1 and self.isEnabled() and Drawing.isMouseOver(x, y, self.rect.x, self.rect.y, self.rect.w, self.rect.h) then
        SoundManager:playEffect('click')
        self.onClick()
        return true
    end
    return false
end

return LockedSlotCard