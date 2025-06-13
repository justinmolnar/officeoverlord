-- components/employee_card.lua
-- A self-contained component for displaying and interacting with an employee card.

local Drawing = require("drawing")
local Shop = require("shop")
local Placement = require("placement")
local Employee = require("employee")

local EmployeeCard = {}
EmployeeCard.__index = EmployeeCard

---
-- LOCAL HELPER FUNCTIONS (Moved from drawing.lua)
---

local function _getEffectiveCardData(employeeData, gameState)
    local cardData = employeeData
    
    local contextArgs = { employee = employeeData, effectiveData = cardData }
    -- Assuming a global or passed-in effects dispatcher
    require("effects_dispatcher").dispatchEvent("onGetEffectiveCardData", gameState, contextArgs, { modal = modal })
    cardData = contextArgs.effectiveData
    
    return cardData
end

local function _drawCardBackgroundAndShaders(cardData, width, height, context, foilShader, holoShader)
    local rarity = cardData.rarity or 'Common'
    local bgColor

    if rarity == 'Common' then bgColor = Drawing.UI.colors.rarity_common_bg
    elseif rarity == 'Uncommon' then bgColor = Drawing.UI.colors.rarity_uncommon_bg
    elseif rarity == 'Rare' then bgColor = Drawing.UI.colors.rarity_rare_bg
    elseif rarity == 'Legendary' then bgColor = Drawing.UI.colors.rarity_legendary_bg
    else bgColor = Drawing.UI.colors.rarity_common_bg
    end

    if context == "worker_done" or context == "worker_training" then bgColor = {0.7, 0.7, 0.7, 1} end
    if cardData.isRebooted then bgColor = {0.7, 0.9, 1, 1} end 
    if cardData.snackBoostActive then bgColor = {1, 0.9, 0.7, 1} end 
    if cardData.id == 'mimic1' and not cardData.copiedState then bgColor = {0.8, 0.7, 1.0, 1} end
    if cardData.isSlimeHybrid then bgColor = {0.7, 1.0, 0.7, 1} end
    
    local borderColor = cardData.isNepotismBaby and {1, 0.84, 0, 1} or Drawing.UI.colors.card_border

    if cardData.variant == 'foil' and foilShader then
        love.graphics.setShader(foilShader)
        foilShader:send("time", love.timer.getTime())
    elseif cardData.variant == 'holo' and holoShader then
        love.graphics.setShader(holoShader)
        holoShader:send("time", love.timer.getTime())
    end
    
    Drawing.drawPanel(0, 0, width, height, bgColor, borderColor, 5)
    love.graphics.setShader()
end

local function _drawCardIndicatorsAndRings(cardData, width, height, isSelected, isCombineTarget)
    if cardData.positionalEffects and cardData.variant ~= 'remote' then
        local bonusIndicatorWidth = 4
        for direction, effect in pairs(cardData.positionalEffects) do
            local directionsToDraw = (direction == "all_adjacent") and {"up", "down", "left", "right"} or {direction}
            for _, dir in ipairs(directionsToDraw) do
                local effectColor = {0,0,0,1}
                if effect.productivity_add or effect.productivity_mult then effectColor = {0.1, 0.65, 0.35, 1} 
                elseif effect.focus_add or effect.focus_mult then effectColor = {0.25, 0.55, 0.9, 1} end
                love.graphics.setColor(effectColor)

                if dir == "up" then love.graphics.rectangle("fill", 0, 0, width, bonusIndicatorWidth, 5, 5, 0, 0)
                elseif dir == "down" then love.graphics.rectangle("fill", 0, height - bonusIndicatorWidth, width, bonusIndicatorWidth, 0, 0, 5, 5)
                elseif dir == "left" then love.graphics.rectangle("fill", 0, 0, bonusIndicatorWidth, height, 5, 0, 0, 5)
                elseif dir == "right" then love.graphics.rectangle("fill", width - bonusIndicatorWidth, 0, bonusIndicatorWidth, height, 0, 5, 5, 0)
                end
            end
        end
    end
    
    if isSelected then 
        love.graphics.setLineWidth(3); love.graphics.setColor(Drawing.UI.colors.selection_ring)
        love.graphics.rectangle("line", -1, -1, width+2, height+2, 6, 6)
    elseif isCombineTarget then 
        love.graphics.setLineWidth(3); love.graphics.setColor(Drawing.UI.colors.combine_target_ring)
        love.graphics.rectangle("line", -1, -1, width+2, height+2, 6, 6)
    end
    love.graphics.setLineWidth(1)
end

local function _drawCardTextContent(cardData, width, height, context, gameState)
    local padding = 8
    love.graphics.setColor(Drawing.UI.colors.text)
    
    love.graphics.setFont(Drawing.UI.font)
    love.graphics.print(cardData.fullName or "Employee Name", padding, padding)
    
    local secondRowY = padding + Drawing.UI.font:getHeight() + 2
    love.graphics.setFont(Drawing.UI.fontMedium)
    love.graphics.setColor(0.4, 0.4, 0.4, 1)
    love.graphics.print("Lvl " .. (cardData.level or 1), padding, secondRowY)
    love.graphics.print(cardData.name, padding + 35, secondRowY)

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

    if context == "shop_offer" then        
        love.graphics.setFont(Drawing.UI.font)
        love.graphics.setColor(0.85, 0.2, 0.2, 1)
        local labelText = "HIRING COST"
        local labelWidth = Drawing.UI.font:getWidth(labelText)
        local centerRightX = width - padding - labelWidth
        local centerY = height / 2 - Drawing.UI.font:getHeight() - 5
        love.graphics.print(labelText, centerRightX, centerY)
        
        love.graphics.setFont(Drawing.UI.titleFont)
        local costText = "$" .. (cardData.displayCost or cardData.hiringBonus)
        local costTextWidth = Drawing.UI.titleFont:getWidth(costText)
        local costX = width - padding - costTextWidth
        love.graphics.print(costText, costX, centerY + Drawing.UI.font:getHeight() + 5)
    end

    local bottomY = height - padding - Drawing.UI.font:getHeight()
    
    love.graphics.setFont(Drawing.UI.fontMedium)
    if cardData.variant == 'remote' then love.graphics.setColor(0.6,0.3,0.8,1); love.graphics.print("REMOTE", padding, bottomY)
    elseif cardData.variant == 'foil' then love.graphics.setColor(0.8, 0.7, 0.1, 1); love.graphics.print("FOIL", padding, bottomY)
    elseif cardData.variant == 'holo' then love.graphics.setColor(0.2, 0.7, 0.9, 1); love.graphics.print("HOLO", padding, bottomY)
    end

    local stats = Employee:calculateStatsWithPosition(cardData, gameState.hiredEmployees, gameState.deskAssignments, gameState.purchasedPermanentUpgrades, gameState.desks, gameState)
    love.graphics.setFont(Drawing.UI.fontMedium)
    love.graphics.setColor(0.85, 0.2, 0.2, 1)
    local salaryText = "Salary $" .. cardData.weeklySalary
    local salaryWidth = Drawing.UI.fontMedium:getWidth(salaryText)
    love.graphics.print(salaryText, width - padding - salaryWidth, bottomY - 12)
    
    love.graphics.setFont(Drawing.UI.font)
    local focusText = "F. " .. string.format("%.1f", stats.currentFocus)
    local prodText = "P. " .. tostring(stats.currentProductivity)
    local statsText = prodText .. "  " .. focusText
    local statsWidth = Drawing.UI.font:getWidth(statsText)
    love.graphics.setColor(0.1, 0.65, 0.35, 1)
    love.graphics.print(prodText, width - padding - statsWidth, bottomY)
    love.graphics.setColor(0.25, 0.55, 0.9, 1)
    love.graphics.print(focusText, width - padding - Drawing.UI.font:getWidth(focusText), bottomY)
end

local function _drawCardContextualOverlays(cardData, width, height, context)
    if cardData.isNepotismBaby then
        love.graphics.setFont(Drawing.UI.fontSmall)
        love.graphics.setColor(1, 0.84, 0, 1)
        love.graphics.printf("NEPOTISM HIRE", 0, height - Drawing.UI.fontSmall:getHeight()*2.5, width, "center")
    end
    
    if context == "shop_offer" and cardData.sold then
        love.graphics.setColor(Drawing.UI.colors.card_sold_overlay_bg); love.graphics.rectangle("fill", 0, 0, width, height, 5, 5)
        love.graphics.setFont(Drawing.UI.fontLarge); love.graphics.setColor(Drawing.UI.colors.card_sold_overlay_text); love.graphics.printf("SOLD", 0, height/2 - Drawing.UI.fontLarge:getHeight()/2, width, "center")
    end
    
    if context == "worker_training" then
        love.graphics.setColor(0,0,0,0.6); love.graphics.rectangle("fill", 0, 0, width, height, 5,5)
        love.graphics.setFont(Drawing.UI.fontLarge); love.graphics.setColor(1,1,1,1);
        love.graphics.printf("TRAINING", 0, height/2 - Drawing.UI.fontLarge:getHeight()/2, width, "center")
    end
end

local function _drawCardBattleAnimation(cardData, width, height, battleState)
    if battleState.currentWorkerId == cardData.instanceId and battleState.lastContribution then
        local shakeX, shakeY = 0, 0
        if battleState.isShaking then
            shakeX = (love.math.random() - 0.5) * 4
            shakeY = (love.math.random() - 0.5) * 4
        end
        
        love.graphics.push()
        love.graphics.translate(shakeX, shakeY)
        
        love.graphics.setColor(0,0,0,0.7)
        love.graphics.rectangle("fill", 0, 0, width, height, 5,5)
        local font = Drawing.UI.titleFont or Drawing.UI.fontLarge
        love.graphics.setFont(font)
        love.graphics.setColor(1,1,1,1)
        
        local contrib = battleState.lastContribution
        local textToShow = ""
        local multiplierText = contrib.multiplierText or ""
        
        if battleState.phase == 'showing_productivity' then textToShow = tostring(contrib.productivity) .. multiplierText
        elseif battleState.phase == 'showing_focus' then textToShow = "x " .. string.format("%.2f", contrib.focus) .. multiplierText
        elseif battleState.phase == 'showing_total' then textToShow = "= " .. tostring(contrib.totalContribution)
        elseif battleState.phase == 'animating_changes' then 
             local changedInfo = battleState.changedEmployeesForAnimation[battleState.nextChangedEmployeeIndex]
             if changedInfo then 
                 local newMultiplierText = changedInfo.new.multiplierText or ""
                 textToShow = tostring(changedInfo.new.totalContribution) .. newMultiplierText
             end
        end
        
        love.graphics.printf(textToShow, 0, height/2 - font:getHeight()/2, width, "center")
        
        love.graphics.pop()
    end
end


---
-- COMPONENT METHODS
---

function EmployeeCard:new(params)
    local instance = setmetatable({}, EmployeeCard)
    instance.data = params.data
    instance.rect = params.rect
    instance.context = params.context
    instance.gameState = params.gameState
    instance.battleState = params.battleState
    instance.draggedItemState = params.draggedItemState
    instance.uiElementRects = params.uiElementRects
    instance.modal = params.modal
    instance.animationState = { isPickedUp = false, pickupProgress = 0, targetPickupProgress = 0, dropTargetX = 0, dropTargetY = 0, isDropping = false, dropProgress = 0, initialX = nil, initialY = nil, currentTime = nil, dropStartX = nil, dropStartY = nil, dropStartTime = nil }
    return instance
end

function EmployeeCard:update(dt)
    local anim = self.animationState
    if anim.currentTime then anim.currentTime = anim.currentTime + dt end
    
    local pickupSpeed = 8.0
    if anim.targetPickupProgress > anim.pickupProgress then anim.pickupProgress = math.min(anim.targetPickupProgress, anim.pickupProgress + pickupSpeed * dt)
    elseif anim.targetPickupProgress < anim.pickupProgress then anim.pickupProgress = math.max(anim.targetPickupProgress, anim.pickupProgress - pickupSpeed * dt)
    end
    
    if anim.isDropping then
        local dropSpeed = 6.0
        anim.dropProgress = math.min(1.0, anim.dropProgress + dropSpeed * dt)
        if anim.dropProgress >= 1.0 then
            anim.isDropping = false; anim.dropProgress = 0; anim.currentTime = nil; anim.initialX = nil; anim.initialY = nil; anim.dropStartX = nil; anim.dropStartY = nil; anim.dropTargetX = nil; anim.dropTargetY = nil
            if anim.onComplete then local callback = anim.onComplete; anim.onComplete = nil; callback() end
        end
    end
end

function EmployeeCard:startPickupAnimation()
    self.animationState.isPickedUp = true
    self.animationState.targetPickupProgress = 1.0
end

function EmployeeCard:startDropAnimation(targetX, targetY, onComplete)
    self.animationState.dropStartX = love.mouse.getX(); self.animationState.dropStartY = love.mouse.getY()
    self.animationState.dropTargetX = targetX; self.animationState.dropTargetY = targetY
    self.animationState.isDropping = true; self.animationState.dropProgress = 0
    self.animationState.isPickedUp = false; self.animationState.targetPickupProgress = 0
    self.animationState.dropStartTime = love.timer.getTime(); self.animationState.onComplete = onComplete
end

function EmployeeCard:cancelPickupAnimation()
    self.animationState.isPickedUp = false
    self.animationState.targetPickupProgress = 0
    self.animationState.currentTime = nil
    self.animationState.initialX = nil
    self.animationState.initialY = nil
end

function EmployeeCard:_createTooltip()
    local mouseX, mouseY = love.mouse.getPosition()
    local cardData = _getEffectiveCardData(self.data, self.gameState)
    local stats = Employee:calculateStatsWithPosition(cardData, self.gameState.hiredEmployees, self.gameState.deskAssignments, self.gameState.purchasedPermanentUpgrades, self.gameState.desks, self.gameState)
    local log = stats.calculationLog
    local description = cardData.description or "No description."
    if cardData.variant == 'remote' and cardData.remoteDescription then description = cardData.remoteDescription end
    if cardData.isSmithCopy then description = description .. "\n\n(This employee has been assimilated by Agent Smith)" end
    
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
    if #log.productivity > 1 then addTooltipLine("──────", {0.7, 0.7, 0.7}); addTooltipLine(tostring(stats.currentProductivity), {0.1, 0.65, 0.35}) end
    addTooltipLine("", nil); addTooltipLine("", nil)
    
    addTooltipLine("FOCUS:", {0.25, 0.55, 0.9})
    for _, line in ipairs(log.focus) do addTooltipLine(line, {1, 1, 1}) end
    if #log.focus > 1 then addTooltipLine("──────", {0.7, 0.7, 0.7}); addTooltipLine(string.format("%.2fx", stats.currentFocus), {0.25, 0.55, 0.9}) end

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

function EmployeeCard:draw(context)
    if not self.data then return end

    if self.context == "remote_worker" and not (self.uiElementRects.remote and self.uiElementRects.remote[self.data.instanceId]) then return end

    if self.draggedItemState.item and self.draggedItemState.item.data and self.draggedItemState.item.data.instanceId == self.data.instanceId then
        love.graphics.setColor(0.5,0.5,0.5,0.5); Drawing.drawPanel(self.rect.x, self.rect.y, self.rect.w, self.rect.h, {0.8,0.8,0.8,0.5}); return
    end

    local rect = self.rect
    if self.context == 'remote_worker' then
        if self.uiElementRects.remote and self.uiElementRects.remote[self.data.instanceId] then rect = self.uiElementRects.remote[self.data.instanceId] else return end
    end
    
    if not rect or not rect.x then return end

    local mouseX, mouseY = love.mouse.getPosition()
    local anim = self.animationState
    local offsetY, shadowAlpha, shadowOffset = 0, 0.3, 2
    local isBeingDragged = self.draggedItemState.item and self.draggedItemState.item.data and self.draggedItemState.item.data.instanceId == self.data.instanceId
    
    if not isBeingDragged then
        if anim.pickupProgress > 0 then
            local easeProgress = 1 - (1 - anim.pickupProgress)^3
            offsetY = -8 * easeProgress; shadowAlpha = 0.3 + (0.4 * easeProgress); shadowOffset = 2 + (6 * easeProgress)
        end
        if anim.isDropping then
            local easeProgress = 1 - (1 - anim.dropProgress)^2
            local startX, startY = anim.dropTargetX, anim.dropTargetY
            rect = { x = startX + (rect.x - startX) * easeProgress, y = startY + (rect.y - startY) * easeProgress, w = rect.w, h = rect.h }
        end
    end

    love.graphics.push()
    if not isBeingDragged then
        love.graphics.setColor(0, 0, 0, shadowAlpha)
        love.graphics.rectangle("fill", rect.x + shadowOffset, rect.y + shadowOffset + offsetY, rect.w, rect.h, 3)
    end
    love.graphics.translate(rect.x, rect.y + offsetY)

    local cardData = _getEffectiveCardData(self.data, self.gameState)
    
    _drawCardBackgroundAndShaders(cardData, rect.w, rect.h, self.context, Drawing.foilShader, Drawing.holoShader)
    
    local isSelected = (not self.draggedItemState.item and self.gameState.selectedEmployeeForPlacementInstanceId == cardData.instanceId)
    local isCombineTarget = false
    local draggedItem = self.draggedItemState.item
    if draggedItem and (draggedItem.type == "shop_employee" or draggedItem.type == "placed_employee") then
        local sourceEmp = draggedItem.data
        if sourceEmp and sourceEmp.instanceId ~= cardData.instanceId then isCombineTarget = Placement:isPotentialCombineTarget(self.gameState, cardData, sourceEmp) end
    end
    
    _drawCardIndicatorsAndRings(cardData, rect.w, rect.h, isSelected, isCombineTarget)
    _drawCardTextContent(cardData, rect.w, rect.h, self.context, self.gameState)
    _drawCardContextualOverlays(cardData, rect.w, rect.h, self.context)
    _drawCardBattleAnimation(cardData, rect.w, rect.h, self.battleState)

    love.graphics.pop()
    
    if Drawing.isMouseOver(mouseX, mouseY, rect.x, rect.y + offsetY, rect.w, rect.h) then
        if not self.draggedItemState.item and self.gameState.gamePhase ~= "battle_active" then
            self:_createTooltip()
        end
    end
end

function EmployeeCard:handleMousePress(x, y, button)
    if button ~= 1 or not self.data or self.data.sold or self.gameState.gamePhase == 'battle_active' then return false end

    local rect = self.rect
    if self.context == 'remote_worker' and self.uiElementRects.remote[self.data.instanceId] then rect = self.uiElementRects.remote[self.data.instanceId] end

    if rect and Drawing.isMouseOver(x, y, rect.x, rect.y, rect.w, rect.h) then
        if self.gameState.temporaryEffectFlags.reOrgSwapModeActive and (self.context == 'desk_placed' or self.context == 'remote_worker') then
            local firstSelectionId = self.gameState.temporaryEffectFlags.reOrgFirstSelectionInstanceId
            if not firstSelectionId then
                self.gameState.temporaryEffectFlags.reOrgFirstSelectionInstanceId = self.data.instanceId
                local empType = (self.data.variant == 'remote' and "remote worker" or "office worker")
                self.modal:show("First Selection", self.data.name .. " selected. Now select a " .. empType .. ".")
            else
                local success, msg = Placement:performReOrgSwap(self.gameState, firstSelectionId, self.data.instanceId)
                self.modal:show(success and "Re-Org Complete" or "Re-Org Failed", msg)
                if success then self.gameState.temporaryEffectFlags.reOrgUsedThisSprint = true; _G.buildUIComponents() end
                self.gameState.temporaryEffectFlags.reOrgSwapModeActive = false; self.gameState.temporaryEffectFlags.reOrgFirstSelectionInstanceId = nil
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

        self.animationState.initialX = rect.x + rect.w/2; self.animationState.initialY = rect.y + rect.h/2; self.animationState.currentTime = 0
        self:startPickupAnimation()

        if self.context == 'shop_offer' then
            local finalHiringCost = Shop:getFinalHiringCost(self.gameState, self.data, self.gameState.purchasedPermanentUpgrades)
            self.draggedItemState.item = { type = "shop_employee", data = self.data, cost = finalHiringCost, originalShopInstanceId = self.data.instanceId }
            return true
        elseif self.context == 'desk_placed' then
            self.draggedItemState.item = { type = "placed_employee", data = self.data, originalDeskId = self.data.deskId }
            self.data.deskId = nil; self.gameState.deskAssignments[self.draggedItemState.item.originalDeskId] = nil
            return true
        elseif self.context == 'remote_worker' then
            self.draggedItemState.item = { type = "placed_employee", data = self.data, originalVariant = 'remote' }
            return true
        end
    end
    return false
end

function EmployeeCard:handleMouseDrop(x, y, droppedItem)
    local rect = self.rect
    if self.context == 'remote_worker' and self.uiElementRects.remote[self.data.instanceId] then rect = self.uiElementRects.remote[self.data.instanceId] end
    if not rect or not Drawing.isMouseOver(x, y, rect.x, rect.y, rect.w, rect.h) then return false end

    local targetEmployee, droppedEmployeeData = self.data, droppedItem.data
    if targetEmployee.instanceId == droppedEmployeeData.instanceId then return false end

    if droppedItem.type == "shop_employee" then
        if self.gameState.budget < droppedItem.cost then
            self.modal:show("Can't Afford", "Not enough budget. Need $" .. droppedItem.cost); return true
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
            Shop:markOfferSold(self.gameState.currentShopOffers, droppedItem.originalShopInstanceId, nil); return true
        elseif Placement:isPotentialCombineTarget(self.gameState, targetEmployee, droppedEmployeeData) then
            self.gameState.budget = self.gameState.budget - droppedItem.cost
            local tempNewEmployee = Employee:new(droppedEmployeeData.id, droppedEmployeeData.variant, droppedEmployeeData.fullName)
            table.insert(self.gameState.hiredEmployees, tempNewEmployee)
            local success, msg = Placement:combineAndLevelUpEmployees(self.gameState, targetEmployee.instanceId, tempNewEmployee.instanceId)
            if success then Shop:markOfferSold(self.gameState.currentShopOffers, droppedItem.originalShopInstanceId, nil)
            else self.gameState.budget = self.gameState.budget + droppedItem.cost; self.modal:show("Combine Failed", msg) end
            return true
        else
            self.modal:show("Cannot Combine", "These employees cannot be combined."); return false
        end
    elseif droppedItem.type == "placed_employee" then
        if targetEmployee.variant == 'remote' then
            return Placement:handleEmployeeDropOnRemoteEmployee(self.gameState, droppedEmployeeData, targetEmployee.instanceId, self.modal)
        else
            return Placement:handleEmployeeDropOnDesk(self.gameState, droppedEmployeeData, targetEmployee.deskId, droppedItem.originalDeskId, self.modal)
        end
    end

    return false
end

return EmployeeCard