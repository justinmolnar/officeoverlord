-- components/desk_slot.lua
-- A self-contained component for an individual desk slot on the office floor.

local Drawing = require("drawing")
local Placement = require("placement")
local GameData = require("data")
local Employee = require("employee")
local Shop = require("shop")
local SoundManager = require("sound_manager")


local DeskSlot = {}
DeskSlot.__index = DeskSlot

function DeskSlot:new(params)
    local instance = setmetatable({}, DeskSlot)
    instance.rect = params.rect
    instance.data = params.data -- The specific desk data from gameState.desks
    instance.gameState = params.gameState
    instance.modal = params.modal
    return instance
end

-- Helper function to generate positional overlays for this desk
function DeskSlot:_generatePositionalOverlays(sourceEmployee, sourceDeskId)
    if not sourceEmployee or not sourceEmployee.positionalEffects or not sourceDeskId then
        return {}
    end

    local overlays = {}
    for direction, effect in pairs(sourceEmployee.positionalEffects) do
        local directionsToParse = (direction == "all_adjacent" or direction == "sides") and {"up", "down", "left", "right"} or {direction}
        if direction == "sides" then directionsToParse = {"left", "right"} end

        for _, dir in ipairs(directionsToParse) do
            local targetDeskId = Employee:getNeighboringDeskId(sourceDeskId, dir, GameData.GRID_WIDTH, GameData.TOTAL_DESK_SLOTS, self.gameState.desks)
            if targetDeskId then
                local bonusValue, bonusText, bonusColor
                if effect.productivity_add then
                    bonusValue = effect.productivity_add * (effect.scales_with_level and (sourceEmployee.level or 1) or 1)
                    bonusText = string.format("%+d P", bonusValue)
                    bonusColor = {0.1, 0.65, 0.35, 0.75} -- Green
                elseif effect.focus_add then
                    bonusValue = effect.focus_add * (effect.scales_with_level and (sourceEmployee.level or 1) or 1)
                    bonusText = string.format("%+.1f F", bonusValue)
                    bonusColor = {0.25, 0.55, 0.9, 0.75} -- Blue
                elseif effect.focus_mult then
                    bonusText = string.format("x%.1f F", effect.focus_mult)
                    bonusColor = {0.8, 0.3, 0.8, 0.75} -- Purple for multipliers
                end
                
                if bonusText then
                    table.insert(overlays, { 
                        targetDeskId = targetDeskId, 
                        text = bonusText, 
                        color = bonusColor 
                    })
                end
            end
        end
    end
    return overlays
end

function DeskSlot:draw(context)
    local deskData = self.data
    local x, y, width, height = self.rect.x, self.rect.y, self.rect.w, self.rect.h
    
    local row = math.floor((tonumber(string.match(deskData.id, "%d+")) or 0) / GameData.GRID_WIDTH)
    local isDeskDisabled = (self.gameState.temporaryEffectFlags.isTopRowDisabled and row == 0)

    local bgColor, borderColor
    if isDeskDisabled then
        bgColor, borderColor = {0.4, 0.4, 0.4, 1}, {0.2, 0.2, 0.2, 1}
    elseif deskData.status == "owned" then
        bgColor, borderColor = Drawing.UI.colors.desk_owned_bg, Drawing.UI.colors.desk_owned_border
    elseif deskData.status == "purchasable" then
        bgColor, borderColor = Drawing.UI.colors.desk_purchasable_bg, Drawing.UI.colors.desk_purchasable_border
    else -- "locked"
        bgColor, borderColor = Drawing.UI.colors.desk_locked_bg, Drawing.UI.colors.desk_locked_border
    end

    Drawing.drawPanel(x, y, width, height, bgColor, borderColor, 3)

    love.graphics.setFont(Drawing.UI.fontSmall)
    if isDeskDisabled then
        love.graphics.setColor(1,0.2,0.2,1)
        love.graphics.printf("DISABLED", x, y + height/2 - Drawing.UI.fontSmall:getHeight()/2, width, "center")
    elseif not self.gameState.deskAssignments[deskData.id] then
        love.graphics.setColor(Drawing.UI.colors.desk_text)
        if deskData.status == "owned" then
            -- Draw ghost placeholder if an item was dragged from this desk
            if context.draggedItemState and context.draggedItemState.item and context.draggedItemState.item.originalDeskId == self.data.id then
                Drawing.drawPanel(x, y, width, height, {0.5, 0.5, 0.5, 0.2}, {0.7, 0.7, 0.7, 0.5}, 3)
            else
                love.graphics.printf("Empty", x, y + height/2 - Drawing.UI.fontSmall:getHeight()/2, width, "center")
            end
        elseif deskData.status == "purchasable" then
            love.graphics.printf("Buy\n$" .. deskData.cost, x, y + height/2 - Drawing.UI.fontSmall:getHeight(), width, "center")
        elseif deskData.status == "locked" then
            love.graphics.printf("Locked", x, y + height/2 - Drawing.UI.fontSmall:getHeight()/2, width, "center")
        end
    end

    -- Drop Zone Highlighting Logic
    if context.draggedItemState and context.draggedItemState.item then
        local droppedItem = context.draggedItemState.item
        local isValidTarget = false
        
        -- Only check for validity if the dragged item is NOT a remote employee
        if droppedItem.data.variant ~= 'remote' then
            if (droppedItem.type == "shop_employee" or droppedItem.type == "placed_employee") then
                if self.data.status == "owned" and not self.gameState.deskAssignments[self.data.id] then
                    isValidTarget = true
                end
            elseif droppedItem.type == "shop_decoration" then
                if self.data.status == "owned" and not self.gameState.deskDecorations[self.data.id] then
                    isValidTarget = true
                end
            end
        end

        if isValidTarget then
            love.graphics.setLineWidth(3)
            love.graphics.setColor(Drawing.UI.colors.combine_target_ring) -- Use the existing green color
            love.graphics.rectangle("line", x, y, width, height, 4)
            love.graphics.setLineWidth(1)
        end
    end

    if context and context.overlaysToDraw then
        local mouseX, mouseY = love.mouse.getPosition()
        local isHovered = Drawing.isMouseOver(mouseX, mouseY, x, y, width, height)
        
        if isHovered then
            local sourceEmployeeForOverlay = nil
            local draggedItem = context.draggedItemState and context.draggedItemState.item
            
            if draggedItem and (draggedItem.type == "placed_employee" or draggedItem.type == "shop_employee") then
                sourceEmployeeForOverlay = draggedItem.data
            else
                local empId = self.gameState.deskAssignments[deskData.id]
                if empId then
                    sourceEmployeeForOverlay = Employee:getFromState(self.gameState, empId)
                    if draggedItem and draggedItem.data and draggedItem.data.instanceId == empId then
                        sourceEmployeeForOverlay = nil
                    end
                end
            end

            if sourceEmployeeForOverlay then
                local overlays = self:_generatePositionalOverlays(sourceEmployeeForOverlay, deskData.id)
                for _, overlay in ipairs(overlays) do
                    table.insert(context.overlaysToDraw, overlay)
                end
            end
        end
    end
end

--- Handles mouse clicks, specifically for purchasing the desk.
function DeskSlot:handleMousePress(x, y, button)
    if button == 1 and self.data.status == "purchasable" and Drawing.isMouseOver(x, y, self.rect.x, self.rect.y, self.rect.w, self.rect.h) then
        -- Attempt to buy the desk
        local success, msg = Placement:attemptBuyDesk(self.gameState, self.data.id)
        if not success then
            self.modal:show("Purchase Failed", msg)
        else
            Placement:updateDeskAvailability(self.gameState.desks)
            -- Rebuild the entire UI to reflect the new state of the desk
            _G.buildUIComponents()
        end
        return true -- Input was handled
    end
    return false
end

function DeskSlot:handleMouseDrop(x, y, droppedItem)
    if not Drawing.isMouseOver(x, y, self.rect.x, self.rect.y, self.rect.w, self.rect.h) then
        return false
    end

    if droppedItem.type == "shop_decoration" then
        if self.gameState.deskDecorations[self.data.id] then
            self.modal:show("Placement Blocked", "This desk already has a decoration. Replace it from an inventory screen (not yet implemented).")
            SoundManager:playEffect('error')
            return false
        end

        if self.gameState.budget < droppedItem.cost then
            self.modal:show("Can't Afford", "Not enough budget. Need $" .. droppedItem.cost)
            SoundManager:playEffect('error')
            return false
        end

        local success = Placement:handleDecorationDropOnDesk(self.gameState, droppedItem.data, self.data.id, self.modal)
        if success then
            self.gameState.budget = self.gameState.budget - droppedItem.cost
            Shop:markOfferSold(self.gameState.currentShopOffers, nil, nil, droppedItem.data.instanceId)
            SoundManager:playEffect('place')
            _G.buildUIComponents()
        end
        return success
    end

    if self.data.status ~= "owned" or self.gameState.deskAssignments[self.data.id] then
        return false
    end
    
    local droppedEmployeeData = droppedItem.data
    
    if droppedItem.type == "shop_employee" then
        if self.gameState.budget < droppedItem.cost then
            self.modal:show("Can't Afford", "Not enough budget to hire. Need $" .. droppedItem.cost)
            SoundManager:playEffect('error')
            return false
        elseif droppedEmployeeData.special and (droppedEmployeeData.special.type == 'haunt_target_on_hire' or droppedEmployeeData.special.type == 'slime_merge') then
            self.modal:show("Invalid Placement", "This special unit must be placed on an existing employee, not an empty desk.")
            SoundManager:playEffect('error')
            return false
        elseif droppedEmployeeData.variant == 'remote' then
            self.modal:show("Invalid Placement", droppedEmployeeData.fullName .. " is a remote worker and cannot be placed on a desk.")
            SoundManager:playEffect('error')
            return false
        end

        local deskIndex = tonumber(string.match(self.data.id, "desk%-(%d+)"))
        if droppedEmployeeData.special and droppedEmployeeData.special.placement_restriction == 'not_top_row' and deskIndex and math.floor(deskIndex / GameData.GRID_WIDTH) == 0 then
            self.modal:show("Placement Error", droppedEmployeeData.fullName .. " cannot be placed in the top row.")
            SoundManager:playEffect('error')
            return false
        end
        
        self.gameState.budget = self.gameState.budget - droppedItem.cost
        local newEmp = Employee:new(droppedEmployeeData.id, droppedEmployeeData.variant, droppedEmployeeData.fullName)
        table.insert(self.gameState.hiredEmployees, newEmp)
        Placement:handleEmployeeDropOnDesk(self.gameState, newEmp, self.data.id, nil, self.modal)
        Shop:markOfferSold(self.gameState.currentShopOffers, droppedItem.originalShopInstanceId, nil)
        SoundManager:playEffect('hire')
        return true

    elseif droppedItem.type == "placed_employee" then
        local success = Placement:handleEmployeeDropOnDesk(self.gameState, droppedEmployeeData, self.data.id, droppedItem.originalDeskId, self.modal)
        if success then SoundManager:playEffect('place') end
        return success
    end

    return false
end

return DeskSlot