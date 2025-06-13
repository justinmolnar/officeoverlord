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
    instance.battleState = params.battleState
    instance.draggedItemState = params.draggedItemState
    instance.uiElementRects = params.uiElementRects
    instance.modal = params.modal
    
    -- Animation state
    instance.animationState = {
        isPickedUp = false,
        pickupProgress = 0,
        targetPickupProgress = 0,
        dropTargetX = 0,
        dropTargetY = 0,
        isDropping = false,
        dropProgress = 0,
        initialX = nil,
        initialY = nil,
        currentTime = nil,
        dropStartX = nil,
        dropStartY = nil,
        dropStartTime = nil
    }
    
    return instance
end

function EmployeeCard:update(dt)
    local anim = self.animationState
    
    -- Update current time for animations
    if anim.currentTime then
        anim.currentTime = anim.currentTime + dt
    end
    
    -- Handle pickup animation
    local pickupSpeed = 8.0
    if anim.targetPickupProgress > anim.pickupProgress then
        anim.pickupProgress = math.min(anim.targetPickupProgress, anim.pickupProgress + pickupSpeed * dt)
    elseif anim.targetPickupProgress < anim.pickupProgress then
        anim.pickupProgress = math.max(anim.targetPickupProgress, anim.pickupProgress - pickupSpeed * dt)
    end
    
    -- Handle drop snap animation
    if anim.isDropping then
        local dropSpeed = 6.0  -- Slower for smoother animation
        anim.dropProgress = math.min(1.0, anim.dropProgress + dropSpeed * dt)
        
        if anim.dropProgress >= 1.0 then
            anim.isDropping = false
            anim.dropProgress = 0
            anim.currentTime = nil
            anim.initialX = nil
            anim.initialY = nil
            anim.dropStartX = nil
            anim.dropStartY = nil
            anim.dropTargetX = nil
            anim.dropTargetY = nil
        end
    end
end

function EmployeeCard:startPickupAnimation()
    self.animationState.isPickedUp = true
    self.animationState.targetPickupProgress = 1.0
end

function EmployeeCard:startDropAnimation(targetX, targetY)
    -- Store the current mouse position as the start point for drop animation
    self.animationState.dropStartX = love.mouse.getX()
    self.animationState.dropStartY = love.mouse.getY()
    self.animationState.dropTargetX = targetX
    self.animationState.dropTargetY = targetY
    self.animationState.isDropping = true
    self.animationState.dropProgress = 0
    self.animationState.isPickedUp = false
    self.animationState.targetPickupProgress = 0
    self.animationState.dropStartTime = love.timer.getTime()
end

function EmployeeCard:cancelPickupAnimation()
    self.animationState.isPickedUp = false
    self.animationState.targetPickupProgress = 0
    self.animationState.currentTime = nil
    self.animationState.initialX = nil
    self.animationState.initialY = nil
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

-- Helper function to generate positional overlays when dragging
function EmployeeCard:_generateDragOverlays(context)
    if not context.draggedItemState or not context.draggedItemState.item then return end
    if context.draggedItemState.item.data.instanceId ~= self.data.instanceId then return end
    
    local draggedEmployee = context.draggedItemState.item.data
    if not draggedEmployee.positionalEffects then return end
    
    -- Generate overlays for all owned desks
    for _, desk in ipairs(self.gameState.desks) do
        if desk.status == "owned" then
            local overlays = self:_generatePositionalOverlaysForDesk(draggedEmployee, desk.id)
            if context.overlaysToDraw then
                for _, overlay in ipairs(overlays) do
                    table.insert(context.overlaysToDraw, overlay)
                end
            end
        end
    end
end

-- Helper to generate overlays for a specific desk
function EmployeeCard:_generatePositionalOverlaysForDesk(sourceEmployee, sourceDeskId)
    if not sourceEmployee or not sourceEmployee.positionalEffects or not sourceDeskId then
        return {}
    end

    local overlays = {}
    local GameData = require("data")
    local Employee = require("employee")
    
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

--- Draws the card and handles its own tooltip generation.
function EmployeeCard:draw(context)
    if not self.data then return end

    -- For remote workers, don't draw if no position is set yet
    if self.context == "remote_worker" then
        if not (self.uiElementRects.remote and self.uiElementRects.remote[self.data.instanceId]) then
            return
        end
    end

    -- Handle placeholder for dragged items - don't show pickup animation when item is being dragged
    if self.draggedItemState.item and self.draggedItemState.item.data and self.draggedItemState.item.data.instanceId == self.data.instanceId then
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
    
    -- Calculate animation offsets - but only if this item is NOT being dragged
    local anim = self.animationState
    local offsetY = 0
    local shadowAlpha = 0.3
    local shadowOffset = 2
    
    -- Don't show pickup animation if this item is currently being dragged
    local isBeingDragged = self.draggedItemState.item and self.draggedItemState.item.data and self.draggedItemState.item.data.instanceId == self.data.instanceId
    
    if not isBeingDragged then
        -- Apply pickup animation
        if anim.pickupProgress > 0 then
            local easeProgress = 1 - (1 - anim.pickupProgress)^3 -- Ease out cubic
            offsetY = -8 * easeProgress
            shadowAlpha = 0.3 + (0.4 * easeProgress)
            shadowOffset = 2 + (6 * easeProgress)
        end
        
        -- Apply drop animation
        if anim.isDropping then
            local easeProgress = 1 - (1 - anim.dropProgress)^2 -- Ease out quad
            local startX = anim.dropTargetX
            local startY = anim.dropTargetY
            -- Smooth interpolation back to rest position
            rect = {
                x = startX + (rect.x - startX) * easeProgress,
                y = startY + (rect.y - startY) * easeProgress,
                w = rect.w,
                h = rect.h
            }
        end
    end

    love.graphics.push()
    
    -- Draw drop shadow only if not being dragged
    if not isBeingDragged then
        love.graphics.setColor(0, 0, 0, shadowAlpha)
        love.graphics.rectangle("fill", rect.x + shadowOffset, rect.y + shadowOffset + offsetY, rect.w, rect.h, 3)
    end
    
    love.graphics.translate(rect.x, rect.y + offsetY)

    local cardData = Drawing._getEffectiveCardData(self.data, self.gameState)
    
    Drawing.drawPanel(0, 0, rect.w, rect.h, {1,1,1,1}, {0.7,0.7,0.7,1}, 3)

    local padding = 8
    local stats = Employee:calculateStatsWithPosition(cardData, self.gameState.hiredEmployees, self.gameState.deskAssignments, self.gameState.purchasedPermanentUpgrades, self.gameState.desks, self.gameState)

    -- == TOP LEFT ==
    love.graphics.setFont(Drawing.UI.font)
    love.graphics.setColor(Drawing.UI.colors.text)
    love.graphics.print(cardData.fullName or "Employee Name", padding, padding)
    
    local secondRowY = padding + Drawing.UI.font:getHeight() + 2
    love.graphics.setFont(Drawing.UI.fontMedium)
    love.graphics.setColor(0.4, 0.4, 0.4, 1)
    love.graphics.print("Lvl " .. (cardData.level or 1), padding, secondRowY)
    love.graphics.print(cardData.name, padding + 35, secondRowY)

    -- == PORTRAIT AREA ==
    local portraitY = secondRowY + 22
    local portraitSize = 60
    love.graphics.setColor(0.85, 0.85, 0.85, 1)
    love.graphics.rectangle("fill", padding, portraitY, portraitSize, portraitSize)
    local portraitImg = nil
    local success, result = pcall(love.graphics.newImage, cardData.icon)
    if success then portraitImg = result end
    if portraitImg then
        love.graphics.setColor(1, 1, 1, 1)
        local scale = math.min(portraitSize / portraitImg:getWidth(), portraitSize / portraitImg:getHeight())
        local imgX = padding + (portraitSize - portraitImg:getWidth() * scale) / 2
        local imgY = portraitY + (portraitSize - portraitImg:getHeight() * scale) / 2
        love.graphics.draw(portraitImg, imgX, imgY, 0, scale, scale)
    end

    -- == CENTER RIGHT - HIRING COST ==
    if self.context == "shop_offer" then        
        love.graphics.setFont(Drawing.UI.font)
        love.graphics.setColor(0.85, 0.2, 0.2, 1)
        local labelText = "HIRING COST"
        local labelWidth = Drawing.UI.font:getWidth(labelText)
        local centerRightX = rect.w - padding - labelWidth
        local centerY = rect.h / 2 - Drawing.UI.font:getHeight() - 5
        love.graphics.print(labelText, centerRightX, centerY)
        
        love.graphics.setFont(Drawing.UI.titleFont)
        local costText = "$" .. (cardData.displayCost or cardData.hiringBonus)
        local costTextWidth = Drawing.UI.titleFont:getWidth(costText)
        local costX = rect.w - padding - costTextWidth
        love.graphics.print(costText, costX, centerY + Drawing.UI.font:getHeight() + 5)
    end

    -- == BOTTOM ROW ==
    local bottomY = rect.h - padding - Drawing.UI.font:getHeight()
    
    -- Variant (Bottom Left)
    love.graphics.setFont(Drawing.UI.fontMedium)
    if cardData.variant == 'remote' then love.graphics.setColor(0.6,0.3,0.8,1); love.graphics.print("REMOTE", padding, bottomY)
    elseif cardData.variant == 'foil' then love.graphics.setColor(0.8, 0.7, 0.1, 1); love.graphics.print("FOIL", padding, bottomY)
    elseif cardData.variant == 'holo' then love.graphics.setColor(0.2, 0.7, 0.9, 1); love.graphics.print("HOLO", padding, bottomY)
    end

    -- P/F Stats and Salary in bottom right
    love.graphics.setFont(Drawing.UI.fontMedium)
    love.graphics.setColor(0.85, 0.2, 0.2, 1)
    local salaryText = "Salary $" .. cardData.weeklySalary
    local salaryWidth = Drawing.UI.fontMedium:getWidth(salaryText)
    love.graphics.print(salaryText, rect.w - padding - salaryWidth, bottomY - 12)
    
    love.graphics.setFont(Drawing.UI.font)
    local focusText = "F. " .. string.format("%.1f", stats.currentFocus)
    local prodText = "P. " .. tostring(stats.currentProductivity)
    local statsText = prodText .. "  " .. focusText
    local statsWidth = Drawing.UI.font:getWidth(statsText)
    love.graphics.setColor(0.1, 0.65, 0.35, 1)
    love.graphics.print(prodText, rect.w - padding - statsWidth, bottomY)
    love.graphics.setColor(0.25, 0.55, 0.9, 1)
    love.graphics.print(focusText, rect.w - padding - Drawing.UI.font:getWidth(focusText), bottomY)

    -- Overlays and Animations
    local isSelected = (not self.draggedItemState.item and self.gameState.selectedEmployeeForPlacementInstanceId == cardData.instanceId)
    local isCombineTarget = false
    local draggedItem = self.draggedItemState.item
    if draggedItem and (draggedItem.type == "shop_employee" or draggedItem.type == "placed_employee") then
        local sourceEmp = draggedItem.data
        if sourceEmp and sourceEmp.instanceId ~= cardData.instanceId then
            isCombineTarget = Placement:isPotentialCombineTarget(self.gameState, cardData, sourceEmp)
        end
    end
    Drawing._drawCardIndicatorsAndRings(cardData, 0, 0, rect.w, rect.h, isSelected, isCombineTarget)
    Drawing._drawCardContextualOverlays(cardData, 0, 0, rect.w, rect.h, self.context)
    Drawing._drawCardBattleAnimation(cardData, 0, 0, rect.w, rect.h, self.battleState)

    love.graphics.pop()
    
    if Drawing.isMouseOver(mouseX, mouseY, rect.x, rect.y + offsetY, rect.w, rect.h) then
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
                self.modal:show("First Selection", self.data.name .. " selected. Now select a " .. empType .. ".")
            else
                local success, msg = Placement:performReOrgSwap(self.gameState, firstSelectionId, self.data.instanceId)
                self.modal:show(success and "Re-Org Complete" or "Re-Org Failed", msg)
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
                self.modal:show("Target Acquired", emp.name .. " will be duplicated at the start of the next work item.")
            else
                self.modal:show("Copy Failed", "Cannot copy a Legendary employee.")
            end
            self.gameState.temporaryEffectFlags.photocopierCopyModeActive = false
            return true
        end

        -- Store initial position for smooth pickup animation
        self.animationState.initialX = rect.x + rect.w/2
        self.animationState.initialY = rect.y + rect.h/2
        self.animationState.currentTime = 0
        
        -- Start pickup animation when dragging begins
        self:startPickupAnimation()

        -- If not in a special mode, proceed with normal context actions.
        if self.context == 'shop_offer' then
            local finalHiringCost = Shop:getFinalHiringCost(self.gameState, self.data, self.gameState.purchasedPermanentUpgrades)
            self.draggedItemState.item = { 
                type = "shop_employee", 
                data = self.data, 
                cost = finalHiringCost,
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
            self.modal:show("Can't Afford", "Not enough budget. Need $" .. droppedItem.cost)
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
            else self.gameState.budget = self.gameState.budget + droppedItem.cost; self.modal:show("Combine Failed", msg) end
            return true -- Handled
        else
            self.modal:show(
                "Cannot Combine",
                "These employees cannot be combined."
            )
            return false -- Not handled, so the employee should snap back
        end
    elseif droppedItem.type == "placed_employee" then
        if targetEmployee.variant == 'remote' then
            return Placement:handleEmployeeDropOnRemoteEmployee(self.gameState, droppedEmployeeData, targetEmployee.instanceId, self.modal)
        else
            return Placement:handleEmployeeDropOnDesk(self.gameState, droppedEmployeeData, targetEmployee.deskId, droppedItem.originalDeskId, self.modal)
        end
    end

    return false -- Drop was on me, but I couldn't do anything with it
end

return EmployeeCard