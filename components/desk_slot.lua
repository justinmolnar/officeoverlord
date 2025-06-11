-- components/desk_slot.lua
-- A self-contained component for an individual desk slot on the office floor.

local Drawing = require("drawing")
local Placement = require("placement")
local GameData = require("data")
local Employee = require("employee")
local Shop = require("shop")

local DeskSlot = {}
DeskSlot.__index = DeskSlot

function DeskSlot:new(params)
    local instance = setmetatable({}, DeskSlot)
    instance.rect = params.rect
    instance.data = params.data -- The specific desk data from gameState.desks
    instance.gameState = params.gameState
    return instance
end

--- Draws the desk slot based on its status (locked, purchasable, owned).
function DeskSlot:draw()
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
    -- Only draw text if the desk is NOT occupied
    elseif not self.gameState.deskAssignments[deskData.id] then
        love.graphics.setColor(Drawing.UI.colors.desk_text)
        if deskData.status == "owned" then
            love.graphics.printf("Empty", x, y + height/2 - Drawing.UI.fontSmall:getHeight()/2, width, "center")
        elseif deskData.status == "purchasable" then
            love.graphics.printf("Buy\n$" .. deskData.cost, x, y + height/2 - Drawing.UI.fontSmall:getHeight(), width, "center")
        elseif deskData.status == "locked" then
            love.graphics.printf("Locked", x, y + height/2 - Drawing.UI.fontSmall:getHeight()/2, width, "center")
        end
    end
end

--- Handles mouse clicks, specifically for purchasing the desk.
function DeskSlot:handleMousePress(x, y, button)
    if button == 1 and self.data.status == "purchasable" and Drawing.isMouseOver(x, y, self.rect.x, self.rect.y, self.rect.w, self.rect.h) then
        -- Attempt to buy the desk
        local success, msg = Placement:attemptBuyDesk(self.gameState, self.data.id)
        if not success then
            Drawing.showModal("Purchase Failed", msg)
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
    -- This component is only a valid drop target if it's an empty, owned desk.
    if self.data.status ~= "owned" or self.gameState.deskAssignments[self.data.id] then
        return false
    end
    
    if not Drawing.isMouseOver(x, y, self.rect.x, self.rect.y, self.rect.w, self.rect.h) then
        return false -- Drop was not on me
    end

    local droppedEmployeeData = droppedItem.data
    
    if droppedItem.type == "shop_employee" then
        if self.gameState.budget < droppedItem.cost then
            Drawing.showModal("Can't Afford", "Not enough budget to hire. Need $" .. droppedItem.cost)
            return false -- CHANGED: Return false for failed drops
        elseif droppedEmployeeData.special and (droppedEmployeeData.special.type == 'haunt_target_on_hire' or droppedEmployeeData.special.type == 'slime_merge') then
            Drawing.showModal("Invalid Placement", "This special unit must be placed on an existing employee, not an empty desk.")
            return false -- CHANGED: Return false for failed drops
        elseif droppedEmployeeData.variant == 'remote' then
            Drawing.showModal("Invalid Placement", droppedEmployeeData.fullName .. " is a remote worker and cannot be placed on a desk.")
            return false -- CHANGED: Return false for failed drops
        end

        local deskIndex = tonumber(string.match(self.data.id, "desk%-(%d+)"))
        if droppedEmployeeData.special and droppedEmployeeData.special.placement_restriction == 'not_top_row' and deskIndex and math.floor(deskIndex / GameData.GRID_WIDTH) == 0 then
            Drawing.showModal("Placement Error", droppedEmployeeData.fullName .. " cannot be placed in the top row.")
            return false -- CHANGED: Return false for failed drops
        end
        
        -- All checks passed, hire and place the employee
        self.gameState.budget = self.gameState.budget - droppedItem.cost
        local newEmp = Employee:new(droppedEmployeeData.id, droppedEmployeeData.variant, droppedEmployeeData.fullName)
        table.insert(self.gameState.hiredEmployees, newEmp)
        Placement:handleEmployeeDropOnDesk(self.gameState, newEmp, self.data.id, nil)
        Shop:markOfferSold(self.gameState.currentShopOffers, droppedItem.originalShopInstanceId, nil)
        return true

    elseif droppedItem.type == "placed_employee" then
        return Placement:handleEmployeeDropOnDesk(self.gameState, droppedEmployeeData, self.data.id, droppedItem.originalDeskId)
    end

    return false
end

return DeskSlot