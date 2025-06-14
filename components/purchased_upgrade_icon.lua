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
    instance.battleState = params.battleState
    instance.modal = params.modal
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

--- Internal helper to determine if the upgrade's effect is currently active.
function PurchasedUpgradeIcon:_isEffectActive()
    if not self.upgData or not self.upgData.id then return false end
    
    local gs = self.gameState
    local bs = self.battleState
    local flags = gs.temporaryEffectFlags
    
    -- Check for various active upgrade effects
    local activeConditions = {
        -- Automation is active if someone is currently automated
        automation_v1 = flags.automatedEmployeeId ~= nil,
        
        -- First mover is active if we're in battle and showing the first employee
        first_mover = gs.gamePhase == "battle_active" and bs and bs.nextEmployeeIndex == 1 and (bs.phase == 'showing_productivity' or bs.phase == 'showing_focus' or bs.phase == 'showing_total'),
        
        -- Motivational speaker boost is active
        motivational_speaker = flags.motivationalBoostNextItem or flags.globalFocusMultiplier == 2.0,
        
        -- Team building boost is active
        team_building_event = flags.teamBuildingActiveThisWeek,
        
        -- Assembly line is active during battle
        assembly_line = gs.gamePhase == "battle_active",
        
        -- Move fast break things is always active if purchased
        move_fast_break_things = true,
        
        -- Specialist niche is active if someone is the specialist
        specialist_niche = flags.specialistId ~= nil,
        
        -- Focus funnel is active if there's a target
        focus_funnel = flags.focusFunnelTargetId ~= nil,
        
        -- Office dog upgrade is active during a dog motivation turn
        office_dog = flags.officeDogActiveThisTurn,
        
        -- GLaDOS is always active providing productivity boost
        borg_hivemind = flags.hiveMindStats ~= nil,
        
        -- Brain interface is active if hive mind stats exist
        brain_interface = flags.hiveMindStats ~= nil
    }
    
    return activeConditions[self.upgData.id] or false
end

--- Internal helper to create and queue the tooltip for a hovered upgrade icon.
function PurchasedUpgradeIcon:_createTooltip()
    local mouseX, mouseY = love.mouse.getPosition()
    local isClickable = self:_isClickable()
    local isActive = self:_isEffectActive()

    local tooltipText = self.upgData.name .. ": " .. self.upgData.description
    if isActive then
        tooltipText = tooltipText .. "\n\n[EFFECT ACTIVE]"
    end
    if isClickable then
        tooltipText = tooltipText .. "\n\n(Click to Activate)"
    end
    
    local textWidthForWrap = 200
    local wrappedHeight = Drawing.drawTextWrapped(tooltipText, 0, 0, textWidthForWrap, Drawing.UI.font, "left", nil, false) 
    local tooltipWidth = textWidthForWrap + 10
    local tooltipHeight = wrappedHeight + 6
    local tipX = mouseX + 5
    local tipY = mouseY - tooltipHeight - 2
    
    -- Reposition tooltip if it would go off-screen
    if tipX + tooltipWidth > love.graphics.getWidth() then tipX = mouseX - tooltipWidth - 5 end
    
    table.insert(Drawing.tooltipsToDraw, { text = tooltipText, x = tipX, y = tipY, w = tooltipWidth, h = tooltipHeight })
end

--- Draws the icon and its hover/active effects.
function PurchasedUpgradeIcon:draw()
    local isClickable = self:_isClickable()
    local isActive = self:_isEffectActive()
    local mouseX, mouseY = love.mouse.getPosition()
    local isHovered = Drawing.isMouseOver(mouseX, mouseY, self.rect.x, self.rect.y, self.rect.w, self.rect.h)

    -- Draw active effect border (pulsing gold)
    if isActive then
        local pulseIntensity = 0.3 + 0.2 * math.sin(love.timer.getTime() * 4)
        love.graphics.setColor(0, 0.1, 0, pulseIntensity)
        love.graphics.setLineWidth(3)
        love.graphics.rectangle("line", self.rect.x - 3, self.rect.y - 3, self.rect.w + 6, self.rect.h + 6, 5)
        love.graphics.setLineWidth(1)
    end

    -- Draw clickable highlight
    if isClickable and isHovered then
        love.graphics.setColor(0.2, 0.8, 0.2, 0.4)
        love.graphics.rectangle("fill", self.rect.x - 2, self.rect.y - 2, self.rect.w + 4, self.rect.h + 4, 3)
    end

    love.graphics.setFont(Drawing.UI.titleFont or Drawing.UI.fontLarge) 
    love.graphics.setColor(0, 0.1, 0, 1)
    love.graphics.print(self.upgData.icon or "?", self.rect.x, self.rect.y)

    if isHovered then
        self:_createTooltip()
    end
end

--- Handles clicks to activate the upgrade's ability.
function PurchasedUpgradeIcon:handleMousePress(x, y, button)
    if button == 1 and self:_isClickable() and Drawing.isMouseOver(x, y, self.rect.x, self.rect.y, self.rect.w, self.rect.h) then
        if self.upgData.listeners and self.upgData.listeners.onActivate then
            local eventArgs = {}
            require("effects_dispatcher").dispatchEvent("onActivate", self.gameState, { modal = self.modal }, eventArgs)
            if eventArgs.showModal then
                self.modal:show(eventArgs.showModal.title, eventArgs.showModal.message)
            end
            return true
        end
    end
    return false
end

return PurchasedUpgradeIcon