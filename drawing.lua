-- drawing.lua
-- Manages all drawing and visual UI component logic for the game.
-- This file consolidates all view-related functions, including helpers previously in ui.lua.

local Drawing = {}

local GameData = require("data") -- For constants like GRID_WIDTH, TOTAL_DESK_SLOTS
local Employee = require("employee") -- For calculating stats
local CardSizing = require("card_sizing")

-- Helper function to generate positional overlays.
-- This function is internal to drawing.lua now.
local function generatePositionalOverlays(drawingState, sourceEmployee, sourceDeskId, gameState)
    if not sourceEmployee or not sourceEmployee.positionalEffects or not sourceDeskId then
        return
    end

    for direction, effect in pairs(sourceEmployee.positionalEffects) do
        local directionsToParse = (direction == "all_adjacent" or direction == "sides") and {"up", "down", "left", "right"} or {direction}
        if direction == "sides" then directionsToParse = {"left", "right"} end

        for _, dir in ipairs(directionsToParse) do
            local targetDeskId = Employee:getNeighboringDeskId(sourceDeskId, dir, GameData.GRID_WIDTH, GameData.TOTAL_DESK_SLOTS, gameState.desks)
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
                    table.insert(drawingState.overlaysToDraw, { targetDeskId = targetDeskId, text = bonusText, color = bonusColor })
                end
            end
        end
    end
end


-- Function to draw text with wrapping capabilities
-- ADDED: new parameter 'drawEnabled' to optionally disable drawing for height calculation
function Drawing.drawTextWrapped(text, x, y, wrapLimit, font, align, maxLines, drawEnabled)
    local shouldDraw = (drawEnabled == nil) and true or drawEnabled -- Default to true
    local currentFont = font or Drawing.UI.font
    if not currentFont or not text then return 0 end 

    love.graphics.setFont(currentFont)
    local alignMode = align or "left"
    local lines = {}
    local currentLine = ""
    local currentLineWidth = 0
    local spaceWidth = currentFont:getWidth(" ")
    local lineLimit = maxLines or math.huge

    -- Split text into words and wrap
    for word in string.gmatch(text .. " ", "(%S*)%s*") do 
        if word == "" then goto continue end
        
        local wordWidth = currentFont:getWidth(word)
        if currentLine == "" then
            currentLine = word
            currentLineWidth = wordWidth
        elseif currentLineWidth + spaceWidth + wordWidth <= wrapLimit then
            currentLine = currentLine .. " " .. word
            currentLineWidth = currentLineWidth + spaceWidth + wordWidth
        else
            table.insert(lines, {text = currentLine, width = currentLineWidth})
            if #lines >= lineLimit then break end
            currentLine = word
            currentLineWidth = wordWidth
        end
        ::continue::
    end
    
    if currentLine ~= "" and #lines < lineLimit then
        table.insert(lines, {text = currentLine, width = currentLineWidth})
    end

    local lineHeight = currentFont:getHeight()
    local totalHeight = #lines * lineHeight
    
    -- Only draw if enabled
    if shouldDraw then
        for i, lineInfo in ipairs(lines) do
            local lineX = x
            if alignMode == "center" then
                lineX = x + (wrapLimit - lineInfo.width) / 2
            elseif alignMode == "right" then
                lineX = x + wrapLimit - lineInfo.width
            end
            love.graphics.print(lineInfo.text, math.floor(lineX), math.floor(y + (i - 1) * lineHeight))
        end
    end
    return totalHeight 
end

function Drawing.calculateRemoteWorkerLayout(rect, gameState, draggedItem)
    local cardWidth = CardSizing.getCardWidth()
    local cardHeight = CardSizing.getCardHeight()

    local layout = {
        items = {},
        positions = {},
        stepSize = cardWidth + 5,
        frontCardIndex = nil,
        needsOverlapping = false,
        ghostZoneIndex = nil
    }

    -- 1. Filter for active remote workers
    local remoteWorkers = {}
    for _, empData in ipairs(gameState.hiredEmployees) do
        if empData.variant == 'remote' then
            if not (draggedItem and draggedItem.type == "placed_employee" and empData.instanceId == draggedItem.data.instanceId) then
                table.insert(remoteWorkers, empData)
            end
        end
    end

    -- 2. Determine ghost zone position if dragging a remote worker
    local showGhostZone = false
    if draggedItem and draggedItem.data.variant == 'remote' then
        local mouseX, mouseY = love.mouse.getPosition()
        if Drawing.isMouseOver(mouseX, mouseY, rect.x, rect.y, rect.width, rect.height) then
            local canCombine = false
            for _, empData in ipairs(remoteWorkers) do
                if require("placement"):isPotentialCombineTarget(gameState, empData, draggedItem.data) then canCombine = true; break; end
                if draggedItem.type == "shop_employee" and draggedItem.data.special and 
                   (draggedItem.data.special.type == 'haunt_target_on_hire' or draggedItem.data.special.type == 'slime_merge') then
                    canCombine = true; break;
                end
            end
            if not canCombine then showGhostZone = true end
        end
    end

    -- 3. Build the final list of items to be laid out (employees + ghost)
    if showGhostZone then
        local relativeMouseX = love.mouse.getX() - (rect.x + 10)
        local proportion = math.max(0, math.min(1, relativeMouseX / (rect.width - 20)))
        layout.ghostZoneIndex = math.floor(proportion * (#remoteWorkers + 1)) + 1
        layout.ghostZoneIndex = math.max(1, math.min(layout.ghostZoneIndex, #remoteWorkers + 1))

        local tempWorkers = {}
        for i, emp in ipairs(remoteWorkers) do table.insert(tempWorkers, {type="employee", data=emp}) end
        table.insert(tempWorkers, layout.ghostZoneIndex, {type="ghost"})
        layout.items = tempWorkers
    else
        for _, emp in ipairs(remoteWorkers) do table.insert(layout.items, {type="employee", data=emp}) end
    end

    -- 4. Calculate step size for potential overlapping
    local totalCards = #layout.items
    local availableWidth = rect.width - 20
    local totalNormalWidth = (totalCards * cardWidth) + ((totalCards - 1) * 5)  
    
    layout.needsOverlapping = totalNormalWidth > availableWidth
    if layout.needsOverlapping and totalCards > 1 then
        local spaceForAllButLast = availableWidth - cardWidth 
        layout.stepSize = spaceForAllButLast / (totalCards - 1)
    end
    
    -- 5. Calculate positions for each item
    for i, item in ipairs(layout.items) do
        local cardX = rect.x + 10 + (i - 1) * layout.stepSize
        local cardY = rect.y + (rect.height - cardHeight) / 2
        
        if item.type == "employee" then
            layout.positions[item.data.instanceId] = {
                x = cardX,
                y = cardY,
                w = cardWidth,
                h = cardHeight
            }
        elseif item.type == "ghost" then
            layout.ghostZoneRect = {
                x = cardX,
                y = cardY,
                w = cardWidth,
                h = cardHeight
            }
        end
    end
    
    -- 6. Determine which card should be drawn in the front
    if not showGhostZone then
        local mouseX, mouseY = love.mouse.getPosition()
        for i, item in ipairs(layout.items) do
            if item.type == "employee" and layout.positions[item.data.instanceId] then
                local pos = layout.positions[item.data.instanceId]
                if Drawing.isMouseOver(mouseX, mouseY, pos.x, pos.y, pos.w, pos.h) then
                    layout.frontCardIndex = i
                    break
                end
            end
        end
    end

    return layout
end

function Drawing.drawButton(text, x, y, width, height, style, isEnabled, isHovered, buttonFont, isPressed)
    local baseBgColor, hoverBgColor, currentTextColor
    local currentStyle = style or "primary"
    local fontToUse = buttonFont or Drawing.UI.font
    
    -- Handle press state parameter (defaults to false if not provided)
    local pressed = isPressed or false

    if currentStyle == "clear" then
        -- This is a special style for invisible buttons, so do nothing.
        -- It will still be clickable because the component exists.
        return
    elseif currentStyle == "primary" then
        baseBgColor = Drawing.UI.colors.button_primary_bg; hoverBgColor = Drawing.UI.colors.button_primary_hover_bg;
    elseif currentStyle == "secondary" then
        baseBgColor = Drawing.UI.colors.button_secondary_bg; hoverBgColor = Drawing.UI.colors.button_secondary_hover_bg;
    elseif currentStyle == "warning" then
        baseBgColor = Drawing.UI.colors.button_warning_bg; hoverBgColor = Drawing.UI.colors.button_warning_hover_bg;
    elseif currentStyle == "danger" then
        baseBgColor = Drawing.UI.colors.button_danger_bg; hoverBgColor = Drawing.UI.colors.button_danger_hover_bg;
    elseif currentStyle == "info" then
         baseBgColor = Drawing.UI.colors.button_info_bg; hoverBgColor = Drawing.UI.colors.button_info_hover_bg;
    else 
        baseBgColor = Drawing.UI.colors.button_primary_bg; hoverBgColor = Drawing.UI.colors.button_primary_hover_bg;
    end

    -- Calculate button position (raised or pressed)
    local shadowOffset = 4
    local buttonY = y
    local shadowY = y + shadowOffset
    
    if pressed then
        -- Button is pressed down
        buttonY = y + shadowOffset - 1
        shadowY = y + shadowOffset
        shadowOffset = 1
    else
        -- Button is raised
        buttonY = y
        shadowY = y + shadowOffset
    end

    -- Draw shadow first (behind button)
    if isEnabled then
        love.graphics.setColor(0, 0, 0, 0.3)
        love.graphics.rectangle("fill", x + 2, shadowY + 2, width, height, 5, 5)
    end

    -- Choose button color based on state
    local bgColor = baseBgColor
    if isEnabled then
        if pressed then
            -- Darker when pressed
            bgColor = {baseBgColor[1] * 0.8, baseBgColor[2] * 0.8, baseBgColor[3] * 0.8, baseBgColor[4]}
        elseif isHovered then
            bgColor = hoverBgColor
        end
    else
        bgColor = Drawing.UI.colors.button_disabled_bg
    end
    
    currentTextColor = isEnabled and Drawing.UI.colors.button_text or Drawing.UI.colors.button_disabled_text
    
    -- Draw button
    love.graphics.setColor(bgColor)
    love.graphics.rectangle("fill", x, buttonY, width, height, 5, 5) 

    -- Draw text
    love.graphics.setColor(currentTextColor)
    if fontToUse then love.graphics.setFont(fontToUse) end 
    local textHeight = fontToUse and fontToUse:getHeight() or 0
    love.graphics.printf(text, math.floor(x), math.floor(buttonY + (height - textHeight) / 2), math.floor(width), "center")
end

-- Function to check if mouse is over a rectangular area
function Drawing.isMouseOver(mouseX, mouseY, x, y, width, height)
    if not x or not y or not width or not height then return false end 
    return mouseX >= x and mouseX <= x + width and mouseY >= y and mouseY <= y + height
end

-- Function to draw a simple panel or box
function Drawing.drawPanel(x, y, width, height, bgColor, borderColor, cornerRadius)
    local bg = bgColor or Drawing.UI.colors.card_bg 
    local border = borderColor or Drawing.UI.colors.card_border
    local cr = cornerRadius or 5

    love.graphics.setColor(bg)
    love.graphics.rectangle("fill", x, y, width, height, cr, cr)
    love.graphics.setColor(border)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", x, y, width, height, cr, cr)
end

-- NEW: Function to draw a checkbox
function Drawing.drawCheckbox(rect, label, isChecked)
    local x, y, w, h = rect.x, rect.y, rect.w, rect.h
    local boxSize = h - 2
    
    -- Draw box
    love.graphics.setColor(Drawing.UI.colors.text_light)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", x, y + 1, boxSize, boxSize, 3, 3)

    -- Draw checkmark if checked
    if isChecked then
        love.graphics.setLineWidth(2)
        love.graphics.line(x + 3, y + h/2, x + boxSize/2, y + h - 4)
        love.graphics.line(x + boxSize/2, y + h - 4, x + boxSize - 2, y + 4)
    end
    
    -- Draw label
    love.graphics.setFont(Drawing.UI.font)
    love.graphics.print(label, x + boxSize + 5, y + (h - Drawing.UI.font:getHeight()) / 2)
end

function Drawing.drawDropdown(rect, dropdownState)
    local x, y, w, h = rect.x, rect.y, rect.w, rect.h
    local mouseX, mouseY = love.mouse.getPosition()
    
    -- Draw main box
    local bgColor = {0.3, 0.3, 0.3, 1}
    if Drawing.isMouseOver(mouseX, mouseY, x, y, w, h) then
        bgColor = {0.4, 0.4, 0.4, 1}
    end
    Drawing.drawPanel(x, y, w, h, bgColor, {0.6, 0.6, 0.6, 1}, 3)

    -- Draw selected text
    love.graphics.setColor(Drawing.UI.colors.text_light)
    love.graphics.setFont(Drawing.UI.font)
    local selectedName = (dropdownState.options[dropdownState.selected] and dropdownState.options[dropdownState.selected].name) or "None"
    love.graphics.printf(selectedName, x + 5, y + (h - Drawing.UI.font:getHeight())/2, w - 20, "left")

    -- Draw arrow
    local arrowX, arrowY = x + w - 15, y + h/2
    love.graphics.polygon("fill", arrowX, arrowY - 2, arrowX + 8, arrowY - 2, arrowX + 4, arrowY + 4)
end

function Drawing.drawOpenDropdownList(rect, dropdownState)
    if not dropdownState.isOpen then return end

    local x, y, w, h = rect.x, rect.y, rect.w, rect.h
    local mouseX, mouseY = love.mouse.getPosition()
    
    local optionHeight = 20
    local listVisibleHeight = math.min(#dropdownState.options * optionHeight, 200)
    local listY = y + h
    
    -- Draw the background for the list
    Drawing.drawPanel(x, listY, w, listVisibleHeight, {0.1, 0.1, 0.1, 1}, {0.6, 0.6, 0.6, 1})

    -- Draw the scrollbar if needed
    local totalContentHeight = #dropdownState.options * optionHeight
    if totalContentHeight > listVisibleHeight then
        local trackX = x + w - 8
        local trackW = 6
        local trackH = listVisibleHeight
        love.graphics.setColor(0.3, 0.3, 0.3, 1)
        love.graphics.rectangle("fill", trackX, listY, trackW, trackH, 3)

        local handleH = math.max(trackH * (listVisibleHeight / totalContentHeight), 15)
        local maxScroll = totalContentHeight - listVisibleHeight
        local scrollPercentage = dropdownState.scrollOffset / maxScroll
        local handleY = listY + scrollPercentage * (trackH - handleH)
        
        love.graphics.setColor(0.7, 0.7, 0.7, 1)
        love.graphics.rectangle("fill", trackX, handleY, trackW, handleH, 3)
        
        dropdownState.scrollbarRect = {x = trackX, y = listY, w = trackW, h = trackH}
        dropdownState.scrollbarHandleRect = {x = trackX, y = handleY, w = trackW, h = handleH}
    else
        dropdownState.scrollbarRect = nil
        dropdownState.scrollbarHandleRect = nil
    end

    love.graphics.push()
    love.graphics.setScissor(x, listY, w - 10, listVisibleHeight)
    love.graphics.translate(0, -dropdownState.scrollOffset)

    for i, option in ipairs(dropdownState.options) do
        local optY = listY + (i-1) * optionHeight
        local isMouseOverOption = Drawing.isMouseOver(mouseX, mouseY + dropdownState.scrollOffset, x, optY, w, optionHeight)
                                and Drawing.isMouseOver(mouseX, mouseY, x, listY, w, listVisibleHeight)

        if isMouseOverOption then
            love.graphics.setColor(0.5, 0.5, 0.5, 1)
            love.graphics.rectangle("fill", x, optY, w - 10, optionHeight)
        end

        love.graphics.setColor(Drawing.UI.colors.text_light)
        love.graphics.setFont(Drawing.UI.font)
        love.graphics.print(option.name, x + 5, optY + 3)
    end
    love.graphics.pop()
    love.graphics.setScissor()
end


-- UI constants and Modal system
Drawing.UI = {}

-- Default fonts (will be set in love.load in main.lua)
Drawing.UI.font = nil
Drawing.UI.fontSmall = nil
Drawing.UI.fontLarge = nil
Drawing.UI.titleFont = nil 

-- Default colors
Drawing.UI.colors = {
    text = {0.12, 0.12, 0.12, 1},
    text_light = {0.95, 0.95, 0.95, 1},
    background = {0.94, 0.94, 0.96, 1},
    header_bg = {1, 1, 1, 1},
    header_border = {0.85, 0.85, 0.85, 1},
    
    button_primary_bg = {0.25, 0.55, 0.9, 1},
    button_primary_hover_bg = {0.35, 0.65, 1.0, 1},
    button_secondary_bg = {0.1, 0.65, 0.35, 1},
    button_secondary_hover_bg = {0.2, 0.75, 0.45, 1},
    button_warning_bg = {0.95, 0.65, 0.15, 1},
    button_warning_hover_bg = {1, 0.75, 0.25, 1},
    button_danger_bg = {0.85, 0.25, 0.25, 1},
    button_danger_hover_bg = {0.95, 0.35, 0.35, 1},
    button_info_bg = {0.2, 0.7, 0.8, 1},
    button_info_hover_bg = {0.3, 0.8, 0.9, 1},
    button_text = {1, 1, 1, 1},
    button_disabled_bg = {0.75, 0.75, 0.75, 1},
    button_disabled_text = {0.5, 0.5, 0.5, 1},

    card_bg = {1, 1, 1, 1},
    card_border = {0.88, 0.88, 0.88, 1},
    card_sold_overlay_bg = {0.1, 0.1, 0.1, 0.75},
    card_sold_overlay_text = {1, 1, 1, 1},

    desk_owned_bg = {0.9, 0.92, 0.94, 1},
    desk_owned_border = {0.75, 0.78, 0.8, 1},
    desk_purchasable_bg = {0.88, 0.98, 0.88, 1},
    desk_purchasable_border = {0.45, 0.75, 0.45, 1},
    desk_locked_bg = {0.98, 0.88, 0.88, 1},
    desk_locked_border = {0.75, 0.45, 0.45, 1},
    desk_text = {0.25, 0.25, 0.25, 1},
    
    selection_ring = {0.2, 0.55, 0.95, 1},
    combine_target_ring = {0.15, 0.75, 0.3, 1},
    placement_target_ring = {0.35, 0.65, 1.0, 1},

    rarity_common_bg = {1, 1, 1, 1},
    rarity_uncommon_bg = {0.95, 1, 0.95, 1},
    rarity_rare_bg = {0.95, 0.98, 1, 1},
    rarity_legendary_bg = {1, 0.98, 0.92, 1},
}

local function _getRemoteWorkerLayout(rect, gameState, draggedItem, Placement)
    -- Just delegate to the main layout function
    return Drawing.calculateRemoteWorkerLayout(rect, gameState, draggedItem)
end

-- local helper to draw a single card within the remote worker panel.
local function _drawRemoteWorkerCard(item, index, layout, rect, uiElementRects, gameState, battleState)
    local cardWidth = CardSizing.getCardHeight()
    local cardHeight = rect.height - (Drawing.UI.font:getHeight() + 15)
    local cardX = rect.x + 10 + (index - 1) * layout.stepSize
    local cardY = rect.y + Drawing.UI.font:getHeight() + 8
    
    local empData = item.data
    uiElementRects.remote[empData.instanceId] = {x = cardX, y = cardY, w = cardWidth, h = cardHeight}
    
    local empContext = "remote_worker"
    if empData.isTraining then
        empContext = "worker_training"
    elseif gameState.gamePhase == "battle_active" then
        local isWorkerActive = false
        for _, activeEmp in ipairs(battleState.activeEmployees) do
            if activeEmp.instanceId == empData.instanceId then isWorkerActive = true; break; end
        end
        if not isWorkerActive then empContext = "worker_done" end
    end

    local needsClipping = layout.needsOverlapping and (index < #layout.items) and (index ~= layout.frontCardIndex)
    if needsClipping then
        love.graphics.push()
        local visibleWidth = math.max(layout.stepSize, cardWidth * 0.4)
        love.graphics.setScissor(cardX, cardY, visibleWidth, cardHeight)
        -- The component handles its own drawing now, this helper is obsolete in the new architecture
        love.graphics.pop()
        love.graphics.setScissor()
    else
        -- The component handles its own drawing now, this helper is obsolete in the new architecture
    end
    
    if gameState.temporaryEffectFlags.reOrgSwapModeActive then
        local firstSelection = Employee:getFromState(gameState, gameState.temporaryEffectFlags.reOrgFirstSelectionInstanceId)
        if not firstSelection or firstSelection.variant ~= empData.variant then
           love.graphics.setColor(0.2, 0.7, 0.8, 0.6)
           love.graphics.rectangle("fill", cardX, cardY, cardWidth, cardHeight, 5)
           love.graphics.setFont(Drawing.UI.titleFont)
           love.graphics.setColor(1, 1, 1, 0.9)
           love.graphics.printf("SWAP?", cardX, cardY + (cardHeight - Drawing.UI.titleFont:getHeight()) / 2, cardWidth, "center")
        end
    end
end

-- local helper to draw the green ghost drop zone.
local function _drawGhostZone(index, layout, rect, uiElementRects)
    local cardWidth = CardSizing.getCardWidth()
    local cardHeight = CardSizing.getCardHeight()

    local cardHeight = rect.height - (Drawing.UI.font:getHeight() + 15)
    local cardX = rect.x + 10 + (index - 1) * layout.stepSize
    local cardY = rect.y + Drawing.UI.font:getHeight() + 8
    
    uiElementRects.remoteGhostZone = {x = cardX, y = cardY, w = cardWidth, h = cardHeight}  
    
    love.graphics.setColor(0.3, 0.8, 0.3, 0.3)
    Drawing.drawPanel(cardX, cardY, cardWidth, cardHeight, {0.3, 0.8, 0.3, 0.3}, {0.3, 0.8, 0.3, 0.6}, 5)  
    
    love.graphics.setColor(0.2, 0.6, 0.2, 0.8)
    love.graphics.setFont(Drawing.UI.fontSmall)
    love.graphics.printf("DROP\nHERE", cardX, cardY + cardHeight/2 - Drawing.UI.fontSmall:getHeight(), cardWidth, "center") 
end


function Drawing.drawRemoteWorkersPanel(rect, gameState, uiElementRects, draggedItem, battleState, Placement)
    local cardWidth = CardSizing.getCardWidth()
    local cardHeight = CardSizing.getCardHeight()

    -- 1. Draw the main panel frame and background title
    Drawing.drawPanel(rect.x, rect.y, rect.width, rect.height, {0.2, 0.2, 0.25, 1}, {0.4,0.4,0.45,1})
    love.graphics.setFont(Drawing.UI.titleFont)
    love.graphics.setColor(0.5, 0.5, 0.5, 0.15)
    love.graphics.printf("Remote Workers", rect.x, rect.y + (rect.height - Drawing.UI.titleFont:getHeight()) / 2, rect.width, "center")

    -- 2. Draw highlight if dragging a remote worker
    if draggedItem and (draggedItem.type == "shop_employee" or draggedItem.type == "placed_employee") and draggedItem.data.variant == 'remote' then
        love.graphics.setLineWidth(3)
        love.graphics.setColor(Drawing.UI.colors.combine_target_ring)
        love.graphics.rectangle("line", rect.x, rect.y, rect.width, rect.height, 5)
        love.graphics.setLineWidth(1)
    end
    
    -- 3. Handle disabled state
    if gameState.temporaryEffectFlags.isRemoteWorkDisabled then
        love.graphics.setFont(Drawing.UI.fontLarge)
        love.graphics.setColor(1,0.2,0.2,1)
        love.graphics.printf("REMOTE WORKERS DISABLED", rect.x, rect.y + rect.height/2 - Drawing.UI.fontLarge:getHeight()/2, rect.width, "center")
        return
    end

    -- 4. Use the centralized layout calculation
    local layout = Drawing.calculateRemoteWorkerLayout(rect, gameState, draggedItem)
    
    -- 5. Store positions in uiElementRects for consistency
    uiElementRects.remote = layout.positions
    
    -- 6. Store ghost zone if it exists
    if layout.ghostZoneRect then
        uiElementRects.remoteGhostZone = layout.ghostZoneRect
    end
end

-- local helper to draw the panel frame and title.
local function _drawGameInfoPanelFrame(rect)
    Drawing.drawPanel(rect.x, rect.y, rect.width, rect.height, {0.92, 0.92, 0.90, 1}, {0.8,0.8,0.78,1})
    love.graphics.setFont(Drawing.UI.fontLarge)
    love.graphics.setColor(Drawing.UI.colors.text)
    local currentY = rect.y + 10
    love.graphics.printf("Game Info", rect.x, currentY, rect.width, "center")
    currentY = currentY + Drawing.UI.fontLarge:getHeight() + 15
    love.graphics.setFont(Drawing.UI.font)
    return currentY
end

-- local helper to draw the core stats (Sprint, Work Item, Budget).
local function _drawCoreStats(rect, currentY, gameState, battleState)
    love.graphics.print("Sprint: " .. gameState.currentSprintIndex .. "/8", rect.x + 10, currentY); currentY = currentY + 20
    love.graphics.print("Work Item: " .. gameState.currentWorkItemIndex .. "/3", rect.x + 10, currentY); currentY = currentY + 20
    
    local budgetY = currentY
    love.graphics.print("Budget: $" .. gameState.budget, rect.x + 10, budgetY)
    
    if gameState.gamePhase == "battle_active" and battleState.phase == "chipping_salaries" then
        love.graphics.setFont(Drawing.UI.fontLarge)
        love.graphics.setColor(1, 0.2, 0.2, 1)
        love.graphics.printf("- $" .. math.floor(battleState.salaryChipAmountRemaining), rect.x + 10, budgetY, rect.width - 20, "right")
        love.graphics.setFont(Drawing.UI.font)
    end
    currentY = currentY + 20
    return currentY
end

-- local helper to draw phase-specific information and action buttons.
local function _drawPhaseSpecificInfo(rect, currentY, gameState, uiElementRects)
    local sprint = GameData.ALL_SPRINTS[gameState.currentSprintIndex]
    local workItem = sprint and sprint.workItems[gameState.currentWorkItemIndex]

    if gameState.gamePhase == "hiring_and_upgrades" then
        if workItem then
            love.graphics.print("Next Workload:", rect.x + 10, currentY)
            love.graphics.printf(workItem.workload, rect.x, currentY, rect.width - 20, "right")
            currentY = currentY + 20
            love.graphics.print("Next Reward:", rect.x + 10, currentY)
            love.graphics.printf("$" .. workItem.reward, rect.x, currentY, rect.width - 20, "right")
            currentY = currentY + 20
            if workItem.modifier then
                love.graphics.setColor(0.8, 0.1, 0.1, 1)
                love.graphics.print("Modifier:", rect.x + 10, currentY); currentY = currentY + 20
                love.graphics.setColor(Drawing.UI.colors.text)
                currentY = currentY + Drawing.drawTextWrapped(workItem.modifier.description, rect.x + 10, currentY, rect.width - 20, Drawing.UI.fontSmall, "left") + 5
            end
        end
        love.graphics.print("Bailouts: " .. gameState.bailOutsRemaining, rect.x + 10, currentY); currentY = currentY + 20
    else -- battle_active phase
        if workItem then
            love.graphics.print("Workload: " .. gameState.currentWeekWorkload .. "/" .. gameState.initialWorkloadForBar, rect.x + 10, currentY)
            currentY = currentY + 20
        end
        love.graphics.print("Cycle: " .. gameState.currentWeekCycles + 1, rect.x + 10, currentY); currentY = currentY + 20
    end
    
    return currentY
end

-- local helper to draw special intel from employees like the Time Traveler or Admiral.
local function _drawSpecialIntel(rect, currentY, gameState)
    local hasTimeTraveler, hasAdmiral = false, false
    for _, emp in ipairs(gameState.hiredEmployees) do
        if emp.special then
            if emp.special.type == 'reveals_modifier' then hasTimeTraveler = true end
            if emp.special.type == 'reveals_next_sprint_modifier' then hasAdmiral = true end
        end
    end

    if hasTimeTraveler then
        local sprint = GameData.ALL_SPRINTS[gameState.currentSprintIndex]
        local bossWorkItem = sprint and sprint.workItems[3]
        if bossWorkItem and bossWorkItem.modifier then
            love.graphics.setColor(0.2, 0.6, 0.8, 1)
            love.graphics.print("Future Insight:", rect.x + 10, currentY); currentY = currentY + 20
            love.graphics.setColor(Drawing.UI.colors.text)
            currentY = currentY + Drawing.drawTextWrapped("This Sprint's Boss: "..bossWorkItem.modifier.description, rect.x + 10, currentY, rect.width - 20, Drawing.UI.fontSmall, "left") + 5
        end
    end
    
    if hasAdmiral and gameState.currentSprintIndex < #GameData.ALL_SPRINTS then
        local nextSprint = GameData.ALL_SPRINTS[gameState.currentSprintIndex + 1]
        local nextBoss = nextSprint and nextSprint.workItems[3]
        if nextBoss and nextBoss.modifier then
            love.graphics.setColor(0.8, 0.2, 0.6, 1)
            love.graphics.print("Admiral's Intel:", rect.x + 10, currentY); currentY = currentY + 20
            love.graphics.setColor(Drawing.UI.colors.text)
            currentY = currentY + Drawing.drawTextWrapped("Next Sprint's Boss: "..nextBoss.modifier.description, rect.x + 10, currentY, rect.width - 20, Drawing.UI.fontSmall, "left") + 5
        end
    end
    return currentY
end

-- local helper to draw the main action buttons at the bottom of the panel.
-- Attaching to the Drawing table to ensure correct scope.
function Drawing._drawActionButtons(rect, gameState, uiElementRects)
    uiElementRects.actionButtons = {} 
    local btnWidth = rect.width - 20
    local btnHeight = 35
    local btnX = rect.x + 10
    
    local mainActionBtnY = rect.y + rect.height - btnHeight - 10
    local viewSprintBtnY = mainActionBtnY - btnHeight - 5
    
    if gameState.gamePhase == "hiring_and_upgrades" then
        uiElementRects.actionButtons["view_sprint"] = {x=btnX, y=viewSprintBtnY, w=btnWidth, h=btnHeight}
        local isHovered = Drawing.isMouseOver(love.mouse.getX(), love.mouse.getY(), btnX, viewSprintBtnY, btnWidth, btnHeight)
        Drawing.drawButton("View Sprint Details", btnX, viewSprintBtnY, btnWidth, btnHeight, "info", true, isHovered)
    end
    
    local mainAction = nil
    if gameState.gamePhase == "hiring_and_upgrades" then
        mainAction = { text = "Start Work Item", style = "secondary" }
    elseif gameState.gamePhase == "game_over" or gameState.gamePhase == "game_won" then
        mainAction = { 
            text = (gameState.gamePhase == "game_won" and "Play Again?" or "Restart Game"), 
            style = (gameState.gamePhase == "game_won" and "primary" or "danger") 
        }
    end
    
    if mainAction then
        uiElementRects.actionButtons["main_phase_action"] = {x=btnX, y=mainActionBtnY, w=btnWidth, h=btnHeight}
        local isHovered = Drawing.isMouseOver(love.mouse.getX(), love.mouse.getY(), btnX, mainActionBtnY, btnWidth, btnHeight)
        Drawing.drawButton(mainAction.text, btnX, mainActionBtnY, btnWidth, btnHeight, mainAction.style, true, isHovered)
    end
end


function Drawing.drawGameInfoPanel(rect, gameState, uiElementRects, sprintOverviewVisible, battleState)
    local currentY = _drawGameInfoPanelFrame(rect)
    currentY = _drawCoreStats(rect, currentY, gameState, battleState)
    currentY = _drawPhaseSpecificInfo(rect, currentY, gameState, uiElementRects)
    currentY = _drawSpecialIntel(rect, currentY + 20, gameState)
    -- Buttons are now components and will be drawn in the main loop
end

-- local helper to calculate the progress percentage of the workload bar.
local function _calculateWorkloadProgress(gameState)
    if gameState.gamePhase == "hiring_and_upgrades" then
        return 1.0
    elseif gameState.gamePhase == "battle_active" or gameState.gamePhase == "battle_over" then
        if gameState.initialWorkloadForBar > 0 then
            return math.max(0, gameState.currentWeekWorkload / gameState.initialWorkloadForBar)
        end
    end
    return 0
end

-- local helper to draw the colored fill of the workload bar based on progress.
local function _drawWorkloadFill(rect, progress)
    local barFillHeight = rect.height * progress
    local barFillY = rect.y + (rect.height - barFillHeight)

    love.graphics.setColor(0.4, 0.8, 0.5, 1)
    love.graphics.rectangle("fill", rect.x, barFillY, rect.width, barFillHeight)
end

-- local helper to draw the red markers indicating progress from previous rounds.
local function _drawProgressMarkers(rect, battleState)
    if not battleState.progressMarkers or #battleState.progressMarkers == 0 then return end
    
    love.graphics.setLineWidth(2)
    love.graphics.setColor(1, 0.2, 0.2, 0.9) -- A noticeable red

    for _, progressValue in ipairs(battleState.progressMarkers) do
        local markerY = rect.y + rect.height - (rect.height * progressValue)
        love.graphics.line(rect.x - 2, markerY, rect.x + rect.width + 2, markerY)
    end

    love.graphics.setLineWidth(1) -- Reset line width for other UI elements
end

-- local helper to draw the text showing the total contribution for the current round.
local function _drawRoundTotalText(rect, gameState, battleState)
    if gameState.gamePhase == "battle_active" and battleState.roundTotalContribution > 0 then
        love.graphics.setFont(Drawing.UI.fontLarge)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.printf(tostring(battleState.roundTotalContribution), rect.x + rect.width + 5, rect.y, 100, "left")
    end
end

-- local helper to draw the vertical "WORK" label in the center of the bar.
local function _drawVerticalLabel(rect)
    love.graphics.setFont(Drawing.UI.fontLarge)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.push()
    love.graphics.translate(rect.x + rect.width / 2, rect.y + rect.height / 2)
    love.graphics.rotate(-math.pi / 2)
    love.graphics.printf("WORK", 0, 0, rect.height, "center")
    love.graphics.pop()
end


--- Draws the vertical workload progress bar.
function Drawing.drawWorkloadBar(rect, gameState, battleState)
    if gameState.gamePhase == "loading" or gameState.gamePhase == "game_over" or gameState.gamePhase == "game_won" then
        return -- Don't draw the bar in these states
    end

    -- 1. Draw the panel frame for the bar
    Drawing.drawPanel(rect.x, rect.y, rect.width, rect.height, {0.3, 0.3, 0.35, 1}, {0.5, 0.5, 0.55, 1})

    -- 2. Calculate and draw the main progress fill
    local progress = _calculateWorkloadProgress(gameState)
    _drawWorkloadFill(rect, progress)

    -- 3. Draw visual indicators and text labels
    _drawProgressMarkers(rect, battleState)
    _drawRoundTotalText(rect, gameState, battleState)
    
    -- 4. Draw a more readable title and value
    love.graphics.setFont(Drawing.UI.font)
    love.graphics.setColor(1, 1, 1, 0.8)
    love.graphics.printf("Workload", rect.x, rect.y + 5, rect.width, "center")
    
    love.graphics.setFont(Drawing.UI.fontSmall)
    local workloadText = gameState.currentWeekWorkload .. " / " .. gameState.initialWorkloadForBar
    if gameState.gamePhase == "hiring_and_upgrades" then
        local sprint = GameData.ALL_SPRINTS[gameState.currentSprintIndex]
        local workItem = sprint and sprint.workItems[gameState.currentWorkItemIndex]
        if workItem then
            workloadText = workItem.workload
        end
    end
    love.graphics.printf(workloadText, rect.x, rect.y + rect.height - Drawing.UI.fontSmall:getHeight() - 5, rect.width, "center")

end

--- Draws the shop panel frame and titles. The actual content is drawn by components.
function Drawing.drawShopPanel(rect, gameState, uiElementRects, draggedItem, Shop)
    -- 1. Draw the panel frame and main title
    Drawing.drawPanel(rect.x, rect.y, rect.width, rect.height, {0.95, 0.93, 0.90, 1}, {0.82, 0.80, 0.78,1})
    love.graphics.setFont(Drawing.UI.fontLarge)
    love.graphics.setColor(Drawing.UI.colors.text)
    love.graphics.printf("Shop", rect.x, rect.y + 10, rect.width, "center")

    -- 2. Handle the disabled state
    if gameState.temporaryEffectFlags.isShopDisabled then
        love.graphics.setFont(Drawing.UI.fontLarge)
        love.graphics.setColor(1,0.2,0.2,1)
        love.graphics.printf("SHOP DISABLED\n(Modifier Active)", rect.x, rect.y + rect.height/2 - Drawing.UI.fontLarge:getHeight(), rect.width, "center")
        return
    end
end


function Drawing._calculateDeskGridGeometry(rect)
    local cardWidth = CardSizing.getCardWidth()
    local cardHeight = CardSizing.getCardHeight()
    
    -- Use card dimensions for desk size
    local deskWidth = cardWidth
    local deskHeight = cardHeight
    local deskSpacing = 5

    -- Calculate how many desks can fit and center them
    local totalWidthNeeded = (GameData.GRID_WIDTH * deskWidth) + ((GameData.GRID_WIDTH - 1) * deskSpacing)
    local totalHeightNeeded = (GameData.GRID_WIDTH * deskHeight) + ((GameData.GRID_WIDTH - 1) * deskSpacing)
    
    -- Center the desk grid in the available area (accounting for upgrade icons at top and title at bottom)
    local upgradeIconSpace = 32 + 20 -- icon height + padding
    local titleSpace = Drawing.UI.titleFont:getHeight() + 20 -- title height + padding
    local availableHeight = rect.height - upgradeIconSpace - titleSpace
    
    local deskAreaStartX = rect.x + (rect.width - totalWidthNeeded) / 2
    local deskAreaStartY = rect.y + upgradeIconSpace + (availableHeight - totalHeightNeeded) / 2
    
    return {
        startX = deskAreaStartX,
        startY = deskAreaStartY,
        width = deskWidth,
        height = deskHeight,
        spacing = deskSpacing
    }
end


-- local helper to generate overlays for special modes (Re-Org, Photocopier) and mouse hover effects.
local function _generateHoverAndModeOverlays(deskData, deskRect, gameState, draggedItem, Placement, DrawingState)
    local empId = gameState.deskAssignments[deskData.id]
    local emp = empId and _G.getEmployeeFromGameState(gameState, empId)
    local mouseX, mouseY = love.mouse.getPosition()

    -- Generate overlays for active special modes
    if emp then
        if gameState.temporaryEffectFlags.reOrgSwapModeActive then
            local firstSelection = _G.getEmployeeFromGameState(gameState, gameState.temporaryEffectFlags.reOrgFirstSelectionInstanceId)
            if not firstSelection or firstSelection.variant ~= emp.variant then
                table.insert(DrawingState.overlaysToDraw, { targetDeskId = deskData.id, text = "SWAP?", color = {0.2, 0.7, 0.8, 0.6} })
            end
        elseif gameState.temporaryEffectFlags.photocopierCopyModeActive then
            if emp.rarity ~= 'Legendary' then
                table.insert(DrawingState.overlaysToDraw, { targetDeskId = deskData.id, text = "COPY?", color = {0.8, 0.8, 0.2, 0.6} })
            end
        end
    end

    -- Generate positional bonus overlays on mouse hover
    if Drawing.isMouseOver(mouseX, mouseY, deskRect.x, deskRect.y, deskRect.w, deskRect.h) then
        local sourceEmployeeForOverlay = nil
        if draggedItem and (draggedItem.type == "placed_employee" or draggedItem.type == "shop_employee") then
            sourceEmployeeForOverlay = draggedItem.data
        elseif not draggedItem and emp then
            sourceEmployeeForOverlay = emp
        elseif draggedItem and emp and Placement:isPotentialCombineTarget(gameState, emp, draggedItem.data) then
            -- Create a temporary "leveled-up" version to preview its new positional effects
            local fakeLeveledUpEmployee = {}
            for k, v in pairs(emp) do fakeLeveledUpEmployee[k] = v end
            fakeLeveledUpEmployee.level = (emp.level or 1) + 1
            sourceEmployeeForOverlay = fakeLeveledUpEmployee
        end

        if sourceEmployeeForOverlay then
            generatePositionalOverlays(DrawingState, sourceEmployeeForOverlay, deskData.id, gameState)
        end
    end
end

-- local helper to draw all the overlays that were queued during the main drawing pass.
local function _drawQueuedOverlays(uiElementRects, DrawingState)
    if #DrawingState.overlaysToDraw > 0 then
        for _, overlay in ipairs(DrawingState.overlaysToDraw) do
            for _, deskRect in ipairs(uiElementRects.desks) do
                if deskRect.id == overlay.targetDeskId then
                    love.graphics.setColor(overlay.color)
                    love.graphics.rectangle("fill", deskRect.x, deskRect.y, deskRect.w, deskRect.h, 3)
                    
                    love.graphics.setFont(Drawing.UI.titleFont)
                    love.graphics.setColor(1, 1, 1, 0.9)
                    love.graphics.printf(overlay.text, deskRect.x, deskRect.y + (deskRect.h - Drawing.UI.titleFont:getHeight()) / 2, deskRect.w, "center")
                    break
                end
            end
        end
    end
end


function Drawing.drawMainInteractionPanel(rect, gameState, uiElementRects, draggedItem, battleState, Placement, DrawingState) 
    -- 1. Draw the panel frame WITHOUT title at top
    Drawing.drawPanel(rect.x, rect.y, rect.width, rect.height, {0.88, 0.90, 0.92, 1}, {0.75,0.78,0.80,1})
    
    -- 2. Draw the "Office Floor" title at the BOTTOM of the panel using titleFont
    love.graphics.setFont(Drawing.UI.titleFont)
    love.graphics.setColor(Drawing.UI.colors.text)
    local titleY = rect.y + rect.height - Drawing.UI.titleFont:getHeight() - 10
    love.graphics.printf("Office Floor", rect.x, titleY, rect.width, "center")

    -- The individual DeskSlot, EmployeeCard, and PurchasedUpgradeIcon components now handle all other drawing.
    -- The loop that was previously here is now redundant and has been removed.
end

-- local helper to draw the panel frame and title for the purchased upgrades display.
local function _drawPurchasedUpgradesFrame(rect)
    Drawing.drawPanel(rect.x, rect.y, rect.width, rect.height, {0.25, 0.25, 0.2, 1}, {0.45,0.45,0.4,1}) 
    love.graphics.setFont(Drawing.UI.font)
    love.graphics.setColor(Drawing.UI.colors.text_light)
    love.graphics.print("Acquired Office Upgrades", rect.x + 10, rect.y + 5)
end

-- local helper to determine if a given upgrade is currently clickable.
local function _isUpgradeClickable(upgData, gameState)
    if not upgData or not upgData.id then return false end
    
    -- Each condition checks if a specific upgrade can be activated based on the current game state.
    local conditions = {
        motivational_speaker = gameState.gamePhase == 'hiring_and_upgrades' and not gameState.temporaryEffectFlags.motivationalSpeakerUsedThisSprint and gameState.budget >= 1000,
        the_reorg = gameState.gamePhase == 'hiring_and_upgrades' and not gameState.temporaryEffectFlags.reOrgUsedThisSprint,
        sentient_photocopier = gameState.gamePhase == 'hiring_and_upgrades' and not gameState.temporaryEffectFlags.photocopierUsedThisSprint,
        multiverse_merger = gameState.temporaryEffectFlags.multiverseMergerAvailable
    }
    
    return conditions[upgData.id] or false
end

-- local helper to draw a single upgrade icon and its hover effects.
local function _drawSingleUpgradeIcon(upgData, currentX, iconY, iconSize, isClickable)
    local mouseX, mouseY = love.mouse.getPosition()
    local isHovered = Drawing.isMouseOver(mouseX, mouseY, currentX, iconY, iconSize, iconSize)

    -- Draw a highlight if the icon is clickable and the mouse is over it.
    if isClickable and isHovered then
        love.graphics.setColor(0.2, 0.8, 0.2, 0.4)
        love.graphics.rectangle("fill", currentX - 2, iconY - 2, iconSize + 4, iconSize + 4, 3)
    end

    love.graphics.setFont(Drawing.UI.titleFont or Drawing.UI.fontLarge) 
    love.graphics.setColor(Drawing.UI.colors.text_light)
    love.graphics.print(upgData.icon or "?", currentX, iconY)

    return isHovered
end

-- local helper to create and queue the tooltip for a hovered upgrade icon.
local function _createUpgradeTooltip(upgData, isClickable)
    local mouseX, mouseY = love.mouse.getPosition()
    local tooltipText = upgData.name .. ": " .. upgData.description
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

-- local helper to draw the main frame and title for the sprint overview panel.
local function _drawSprintOverviewFrame(gameState)
    local screenW, screenH = love.graphics.getDimensions()
    local panelW, panelH = screenW * 0.5, screenH * 0.6  -- Smaller panel since we're showing less content
    local panelX, panelY = (screenW - panelW) / 2, (screenH - panelH) / 2

    Drawing.drawPanel(panelX, panelY, panelW, panelH, {0.15, 0.15, 0.2, 0.95}, {0.3, 0.3, 0.4, 1}, 8)
    
    -- Show current sprint info in title
    local currentSprint = GameData.ALL_SPRINTS[gameState.currentSprintIndex]
    local sprintTitle = string.format("Sprint %d: %s", gameState.currentSprintIndex, currentSprint.sprintName)
    
    love.graphics.setFont(Drawing.UI.titleFont)
    love.graphics.setColor(Drawing.UI.colors.text_light)
    love.graphics.printf(sprintTitle, panelX, panelY + 15, panelW, "center")

    return { x = panelX, y = panelY, w = panelW, h = panelH }
end

-- local helper to draw a single work item in Balatro ante style (horizontal card layout)
local function _drawWorkItem(workItem, itemIndex, x, y, cardWidth, cardHeight, gameState)
    -- Determine item status
    local isCompleted = gameState.currentWorkItemIndex > itemIndex
    local isCurrent = gameState.currentWorkItemIndex == itemIndex
    local isPending = gameState.currentWorkItemIndex < itemIndex
    
    -- Set colors based on status
    local itemColor, statusText
    if isCompleted then
        itemColor = {0.2, 0.8, 0.2, 1} -- Green for completed
        statusText = "DEFEATED"
    elseif isCurrent then
        itemColor = {0.9, 0.7, 0.1, 1} -- Gold for current
        statusText = "UPCOMING"
    else
        itemColor = {0.6, 0.6, 0.6, 1} -- Gray for pending
        statusText = "UPCOMING"
    end
    
    -- Draw card background
    love.graphics.setColor(itemColor[1], itemColor[2], itemColor[3], 0.3)
    love.graphics.rectangle("fill", x, y, cardWidth, cardHeight, 10)
    love.graphics.setColor(itemColor)
    love.graphics.setLineWidth(3)
    love.graphics.rectangle("line", x, y, cardWidth, cardHeight, 10)
    love.graphics.setLineWidth(1)
    
    -- Draw status banner at top
    love.graphics.setColor(itemColor)
    love.graphics.rectangle("fill", x, y, cardWidth, 30, 10, 10, 0, 0)
    love.graphics.setFont(Drawing.UI.fontSmall)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.printf(statusText, x, y + 8, cardWidth, "center")
    
    -- Draw item title
    love.graphics.setFont(Drawing.UI.fontLarge)
    love.graphics.setColor(Drawing.UI.colors.text_light)
    local itemTitle = string.format("Item %d", itemIndex)
    love.graphics.printf(itemTitle, x, y + 50, cardWidth, "center")
    
    -- Draw work item name
    love.graphics.setFont(Drawing.UI.font)
    love.graphics.printf(workItem.name, x + 10, y + 80, cardWidth - 20, "center")
    
    -- Draw workload
    love.graphics.setFont(Drawing.UI.titleFont)
    love.graphics.setColor(0.4, 0.8, 1, 1) -- Blue for workload
    love.graphics.printf("Workload: " .. workItem.workload, x, y + 120, cardWidth, "center")
    
    -- Draw reward
    love.graphics.setColor(1, 0.8, 0.2, 1) -- Gold for reward
    love.graphics.printf("Reward: $" .. workItem.reward, x, y + 150, cardWidth, "center")
    
    -- Draw modifier if present
    if workItem.modifier then
        love.graphics.setFont(Drawing.UI.font)
        love.graphics.setColor(0.9, 0.4, 0.4, 1) -- Red for modifiers
        love.graphics.printf("MODIFIER:", x, y + 190, cardWidth, "center")
        love.graphics.printf(workItem.modifier.description, x + 5, y + 210, cardWidth - 10, "center")
    end
end

-- local helper to draw the detailed information for a single sprint.
local function _drawSingleSprintDetails(sprintData, sprintIndex, panelRect, currentY)
    local padding = 20
    local contentWidth = panelRect.w - 2 * padding
    
    -- Draw the sprint title
    local sprintTitle = string.format("Sprint %d: %s", sprintIndex, sprintData.sprintName)
    love.graphics.setFont(Drawing.UI.fontLarge)
    love.graphics.setColor(Drawing.UI.colors.button_info_bg)
    Drawing.drawTextWrapped(sprintTitle, panelRect.x + padding, currentY, contentWidth, Drawing.UI.fontLarge)
    currentY = currentY + Drawing.UI.fontLarge:getHeight() + 5

    -- Draw the work items within the sprint
    love.graphics.setFont(Drawing.UI.font)
    love.graphics.setColor(Drawing.UI.colors.text_light)

    for j, workItem in ipairs(sprintData.workItems) do
        local itemText = string.format("  - Item %d: %s (Workload: %d, Reward: $%d)", j, workItem.name, workItem.workload, workItem.reward)
        Drawing.drawTextWrapped(itemText, panelRect.x + padding, currentY, contentWidth, Drawing.UI.font)
        currentY = currentY + Drawing.UI.font:getHeight()

        if workItem.modifier then
            local modifierText = "    Modifier: " .. workItem.modifier.description
            love.graphics.setColor(0.8, 0.4, 0.4, 1) -- Reddish color for modifiers
            Drawing.drawTextWrapped(modifierText, panelRect.x + padding, currentY, contentWidth, Drawing.UI.fontSmall)
            love.graphics.setColor(Drawing.UI.colors.text_light) -- Reset color for the next item
            currentY = currentY + Drawing.UI.fontSmall:getHeight()
        end
    end
    
    return currentY + 15 -- Return the next Y position with spacing
end

-- local helper to draw the back button at the bottom of the panel.
local function _drawSprintOverviewBackButton(panelRect, sprintOverviewRects)
    local btnW, btnH = 120, 40
    local btnX = panelRect.x + (panelRect.w - btnW) / 2 
    local btnY = panelRect.y + panelRect.h - btnH - 15
    sprintOverviewRects.backButton = {x = btnX, y = btnY, w = btnW, h = btnH}
    
    local isHovered = Drawing.isMouseOver(love.mouse.getX(), love.mouse.getY(), btnX, btnY, btnW, btnH)
    Drawing.drawButton("Back", btnX, btnY, btnW, btnH, "primary", true, isHovered)
end


--- Draws the current sprint overview panel, showing only the 3 work items for the current sprint.
--- Draws the current sprint overview panel in Balatro ante style - 3 cards horizontally
function Drawing.drawSprintOverviewPanel(sprintOverviewRects, sprintOverviewVisible, gameState)
    if not sprintOverviewVisible then return end

    local screenW, screenH = love.graphics.getDimensions()
    local panelW, panelH = screenW * 0.8, screenH * 0.7
    local panelX, panelY = (screenW - panelW) / 2, (screenH - panelH) / 2

    -- Draw main panel
    Drawing.drawPanel(panelX, panelY, panelW, panelH, {0.15, 0.15, 0.2, 0.95}, {0.3, 0.3, 0.4, 1}, 8)
    
    -- Draw title
    local currentSprint = GameData.ALL_SPRINTS[gameState.currentSprintIndex]
    if not currentSprint then return end
    
    local sprintTitle = string.format("Sprint %d: %s", gameState.currentSprintIndex, currentSprint.sprintName)
    love.graphics.setFont(Drawing.UI.titleFont)
    love.graphics.setColor(Drawing.UI.colors.text_light)
    love.graphics.printf(sprintTitle, panelX, panelY + 20, panelW, "center")
    
    -- Calculate card layout (3 cards horizontal like Balatro antes)
    local cardWidth = 220
    local cardHeight = 280
    local cardSpacing = 40
    local totalWidth = (cardWidth * 3) + (cardSpacing * 2)
    local startX = panelX + (panelW - totalWidth) / 2
    local cardY = panelY + 80
    
    -- Draw the 3 work item cards horizontally
    for i, workItem in ipairs(currentSprint.workItems) do
        local cardX = startX + (i - 1) * (cardWidth + cardSpacing)
        _drawWorkItem(workItem, i, cardX, cardY, cardWidth, cardHeight, gameState)
    end
    
    -- ONLY CALCULATE the back button's position. Do not draw it here.
    local btnW, btnH = 120, 40
    local btnX = panelX + (panelW - btnW) / 2 
    local btnY = panelY + panelH - btnH - 20
    sprintOverviewRects.backButton = {x = btnX, y = btnY, w = btnW, h = btnH}
end

return Drawing