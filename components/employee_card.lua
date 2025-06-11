-- components/employee_card.lua
-- A self-contained component for displaying and interacting with an employee card.

local Drawing = require("drawing")
local Shop = require("shop")
local Placement = require("placement")
local Employee = require("employee") -- Needed for stat calculation

local EmployeeCard = {}
EmployeeCard.__index = EmployeeCard

--- Creates a new EmployeeCard component.
function EmployeeCard:new(params)
    local instance = setmetatable({}, EmployeeCard)
    instance.data = params.data
    instance.rect = params.rect
    instance.context = params.context
    
    -- References to state needed for interactions
    instance.gameState = params.gameState
    instance.battleState = params.battleState -- Add this line
    instance.draggedItemState = params.draggedItemState
    instance.uiElementRects = params.uiElementRects
    
    return instance
end

--- private helper to generate and queue the tooltip for this specific card.
--- private helper to generate and queue the tooltip for this specific card.
function EmployeeCard:_createTooltip()
    local mouseX, mouseY = love.mouse.getPosition()
    -- Get effective data for the tooltip (handles Mimic, etc.)
    -- FIX: Added 'Drawing.' prefix to correctly call the helper function.
    local cardData = Drawing._getEffectiveCardData(self.data, self.gameState)
    local stats = Employee:calculateStatsWithPosition(cardData, self.gameState.hiredEmployees, self.gameState.deskAssignments, self.gameState.purchasedPermanentUpgrades, self.gameState.desks, self.gameState)
    local log = stats.calculationLog

    local description = cardData.description or "No description."
    if cardData.variant == 'remote' and cardData.remoteDescription then
        description = cardData.remoteDescription
    end
    if cardData.isSmithCopy then
        description = description .. "\n\n(This employee has been assimilated by Agent Smith)"
    end
    
    local tooltipLines = {}
    local function addTooltipLine(text, color)
        local colorStr = color and string.format("[%.1f,%.1f,%.1f]", color[1], color[2], color[3]) or ""
        table.insert(tooltipLines, colorStr .. text)
    end
    
    local textWidthForWrap = 280
    local _, wrappedDescText = Drawing.UI.font:getWrap(description, textWidthForWrap - 16)
    for _, line in ipairs(wrappedDescText) do addTooltipLine(line, {1, 1, 1}) end
    addTooltipLine("", nil); addTooltipLine("", nil)
    
    addTooltipLine("PRODUCTIVITY:", {0.1, 0.65, 0.35})
    for _, line in ipairs(log.productivity) do addTooltipLine(line, {1, 1, 1}) end
    if #log.productivity > 1 then 
        addTooltipLine("──────", {0.7, 0.7, 0.7})
        addTooltipLine(tostring(stats.currentProductivity), {0.1, 0.65, 0.35})
    end
    
    addTooltipLine("", nil); addTooltipLine("", nil)
    
    addTooltipLine("FOCUS:", {0.25, 0.55, 0.9})
    for _, line in ipairs(log.focus) do addTooltipLine(line, {1, 1, 1}) end
    if #log.focus > 1 then
        addTooltipLine("──────", {0.7, 0.7, 0.7})
        addTooltipLine(string.format("%.2fx", stats.currentFocus), {0.25, 0.55, 0.9})
    end

    local tooltipText = ""
    for _, line in ipairs(tooltipLines) do
        if line:match("^%[") then local colorEnd = line:find("%]"); if colorEnd then tooltipText = tooltipText .. line:sub(colorEnd + 1) .. "\n" else tooltipText = tooltipText .. line .. "\n" end
        else tooltipText = tooltipText .. line .. "\n" end
    end
    
    local lineHeight = Drawing.UI.font:getHeight()
    local tooltipHeight = (#tooltipLines * lineHeight) + 16
    local tooltipWidth = textWidthForWrap + 16
    local tipX = mouseX + 15; local tipY = mouseY
    if tipX + tooltipWidth > love.graphics.getWidth() then tipX = mouseX - tooltipWidth - 15 end
    if tipY + tooltipHeight > love.graphics.getHeight() then tipY = love.graphics.getHeight() - tooltipHeight end
    
    table.insert(Drawing.tooltipsToDraw, { text = tooltipText, x = tipX, y = tipY, w = tooltipWidth, h = tooltipHeight, coloredLines = tooltipLines })
end

--- Draws the card and handles its own tooltip generation.
function EmployeeCard:draw()
    if not self.data then return end

        -- For remote workers, don't draw if no position is set yet
    if self.context == "remote_worker" then
        if not (self.uiElementRects.remote and self.uiElementRects.remote[self.data.instanceId]) then
            return -- Don't draw until position is calculated
        end
    end

    -- Handle placeholder for dragged items
    if self.draggedItemState.item and self.draggedItemState.item.originalShopInstanceId == self.data.instanceId then
        love.graphics.setColor(0.5,0.5,0.5,0.5)
        Drawing.drawPanel(self.rect.x, self.rect.y, self.rect.w, self.rect.h, {0.8,0.8,0.8,0.5})
        return
    end

    local rect = self.rect
    if self.context == 'remote_worker' then

        if self.uiElementRects.remote and self.uiElementRects.remote[self.data.instanceId] then
            rect = self.uiElementRects.remote[self.data.instanceId]
        else
            return
        end
    end
    
    if not rect or not rect.x then return end

    local mouseX, mouseY = love.mouse.getPosition()
    love.graphics.push()
    love.graphics.translate(rect.x, rect.y)

    local cardData = Drawing._getEffectiveCardData(self.data, self.gameState)
    local isSelected = (not self.draggedItemState.item and self.gameState.selectedEmployeeForPlacementInstanceId == cardData.instanceId)
    local isCombineTarget = false
    if not isSelected then
        -- Use the new Employee:getFromState method
        local sourceEmp = (self.draggedItemState.item and self.draggedItemState.item.data) or Employee:getFromState(self.gameState, self.gameState.selectedEmployeeForPlacementInstanceId)
        if sourceEmp and sourceEmp.instanceId ~= cardData.instanceId then
            isCombineTarget = Placement:isPotentialCombineTarget(self.gameState, cardData, sourceEmp)
        end
    end
    
    Drawing._drawCardBackgroundAndShaders(cardData, rect.x, rect.y, rect.w, rect.h, self.context, Drawing.foilShader, Drawing.holoShader)
    Drawing._drawCardIndicatorsAndRings(cardData, rect.x, rect.y, rect.w, rect.h, isSelected, isCombineTarget)
    Drawing._drawCardTextContent(cardData, rect.x, rect.y, rect.w, rect.h, self.context, self.gameState, self.uiElementRects)
    Drawing._drawCardContextualOverlays(cardData, rect.x, rect.y, rect.w, rect.h, self.context)
    -- Use self.battleState instead of _G.battleState
    Drawing._drawCardBattleAnimation(cardData, rect.x, rect.y, rect.w, rect.h, self.battleState)
    
    love.graphics.pop()
    
    if Drawing.isMouseOver(mouseX, mouseY, rect.x, rect.y, rect.w, rect.h) then
        if not self.draggedItemState.item and self.gameState.gamePhase ~= "battle_active" then
            self:_createTooltip()
        end
    end
end

function Employee:getFromState(gameState, instanceId)
    if not gameState or not gameState.hiredEmployees or not instanceId then return nil end
    for _, emp in ipairs(gameState.hiredEmployees) do
        if emp.instanceId == instanceId then return emp end
    end
    return nil
end

function EmployeeCard:handleMousePress(x, y, button)
    if button ~= 1 or not self.data or self.data.sold or self.gameState.gamePhase == 'battle_active' then 
        return false 
    end

    local rect = self.rect
    if self.context == 'remote_worker' and self.uiElementRects.remote[self.data.instanceId] then
        rect = self.uiElementRects.remote[self.data.instanceId]
    end

    if rect and Drawing.isMouseOver(x, y, rect.x, rect.y, rect.w, rect.h) then
        -- Handle special game modes first.
        if self.gameState.temporaryEffectFlags.reOrgSwapModeActive and (self.context == 'desk_placed' or self.context == 'remote_worker') then
            local firstSelectionId = self.gameState.temporaryEffectFlags.reOrgFirstSelectionInstanceId
            if not firstSelectionId then
                self.gameState.temporaryEffectFlags.reOrgFirstSelectionInstanceId = self.data.instanceId
                local empType = (self.data.variant == 'remote' and "remote worker" or "office worker")
                Drawing.showModal("First Selection", self.data.name .. " selected. Now select a " .. empType .. ".")
            else
                local success, msg = Placement:performReOrgSwap(self.gameState, firstSelectionId, self.data.instanceId)
                Drawing.showModal(success and "Re-Org Complete" or "Re-Org Failed", msg)
                if success then 
                    self.gameState.temporaryEffectFlags.reOrgUsedThisSprint = true
                    _G.buildUIComponents()
                end
                self.gameState.temporaryEffectFlags.reOrgSwapModeActive = false
                self.gameState.temporaryEffectFlags.reOrgFirstSelectionInstanceId = nil
            end
            return true
        
        elseif self.gameState.temporaryEffectFlags.photocopierCopyModeActive and self.context == 'desk_placed' then
            local emp = self.data
            if emp.rarity ~= 'Legendary' then
                self.gameState.temporaryEffectFlags.photocopierTargetForNextItem = emp.instanceId
                self.gameState.temporaryEffectFlags.photocopierUsedThisSprint = true
                Drawing.showModal("Target Acquired", emp.name .. " will be duplicated at the start of the next work item.")
            else
                Drawing.showModal("Copy Failed", "Cannot copy a Legendary employee.")
            end
            self.gameState.temporaryEffectFlags.photocopierCopyModeActive = false
            return true
        end

        -- If not in a special mode, proceed with normal context actions.
        if self.context == 'shop_offer' then
            -- This is the key fix: calculate the cost and add it to the dragged item.
            local finalHiringCost = Shop:getFinalHiringCost(self.gameState, self.data, self.gameState.purchasedPermanentUpgrades)
            self.draggedItemState.item = { 
                type = "shop_employee", 
                data = self.data, 
                cost = finalHiringCost, -- Add the cost here
                originalShopInstanceId = self.data.instanceId 
            }
            return true

        elseif self.context == 'desk_placed' then
            self.draggedItemState.item = { type = "placed_employee", data = self.data, originalDeskId = self.data.deskId }
            self.data.deskId = nil
            self.gameState.deskAssignments[self.draggedItemState.item.originalDeskId] = nil
            return true

        elseif self.context == 'remote_worker' then
            self.draggedItemState.item = { type = "placed_employee", data = self.data, originalVariant = 'remote' }
            return true
        end
    end
    return false
end

function EmployeeCard:handleMouseDrop(x, y, droppedItem)
    -- This component represents a potential drop target (another employee).
    -- First, check if the drop happened on this specific card.
    local rect = self.rect
    if self.context == 'remote_worker' and self.uiElementRects.remote[self.data.instanceId] then
        rect = self.uiElementRects.remote[self.data.instanceId]
    end
    if not rect or not Drawing.isMouseOver(x, y, rect.x, rect.y, rect.w, rect.h) then
        return false -- Drop was not on me
    end

    local targetEmployee = self.data
    local droppedEmployeeData = droppedItem.data
    
    -- Can't drop an employee on themselves
    if targetEmployee.instanceId == droppedEmployeeData.instanceId then return false end

    if droppedItem.type == "shop_employee" then
        if self.gameState.budget < droppedItem.cost then
            Drawing.showModal("Can't Afford", "Not enough budget. Need $" .. droppedItem.cost)
            return true -- Handled (by showing a modal)
        elseif droppedEmployeeData.special and (droppedEmployeeData.special.type == 'haunt_target_on_hire' or droppedEmployeeData.special.type == 'slime_merge') then
            self.gameState.budget = self.gameState.budget - droppedItem.cost
            if droppedEmployeeData.special.type == 'haunt_target_on_hire' then
                targetEmployee.baseProductivity = targetEmployee.baseProductivity + (droppedEmployeeData.special.prod_boost or 10)
                targetEmployee.baseFocus = targetEmployee.baseFocus + (droppedEmployeeData.special.focus_add or 0.5)
                targetEmployee.haunt_stacks = (targetEmployee.haunt_stacks or 0) + 1
            elseif droppedEmployeeData.special.type == 'slime_merge' then
                targetEmployee.baseProductivity = targetEmployee.baseProductivity * 2; targetEmployee.baseFocus = targetEmployee.baseFocus * 2; targetEmployee.rarity = "Legendary"
                targetEmployee.slime_stacks = (targetEmployee.slime_stacks or 0) + 1
            end
            Shop:markOfferSold(self.gameState.currentShopOffers, droppedItem.originalShopInstanceId, nil)
            return true -- Handled
        elseif Placement:isPotentialCombineTarget(self.gameState, targetEmployee, droppedEmployeeData) then
            self.gameState.budget = self.gameState.budget - droppedItem.cost
            local tempNewEmployee = Employee:new(droppedEmployeeData.id, droppedEmployeeData.variant, droppedEmployeeData.fullName)
            table.insert(self.gameState.hiredEmployees, tempNewEmployee)
            local success, msg = Placement:combineAndLevelUpEmployees(self.gameState, targetEmployee.instanceId, tempNewEmployee.instanceId)
            if success then Shop:markOfferSold(self.gameState.currentShopOffers, droppedItem.originalShopInstanceId, nil)
            else self.gameState.budget = self.gameState.budget + droppedItem.cost; Drawing.showModal("Combine Failed", msg) end
            return true -- Handled
        else
            Drawing.showModal("Cannot Combine", "These employees cannot be combined.")
            return false -- Not handled, so the employee should snap back
        end
    elseif droppedItem.type == "placed_employee" then
        if targetEmployee.variant == 'remote' then
            return Placement:handleEmployeeDropOnRemoteEmployee(self.gameState, droppedEmployeeData, targetEmployee.instanceId)
        else
            return Placement:handleEmployeeDropOnDesk(self.gameState, droppedEmployeeData, targetEmployee.deskId, droppedItem.originalDeskId)
        end
    end

    return false -- Drop was on me, but I couldn't do anything with it
end

return EmployeeCard