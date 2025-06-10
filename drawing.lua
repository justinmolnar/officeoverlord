-- drawing.lua
local Drawing = {}

local GameData = require("data") -- For constants like GRID_WIDTH, TOTAL_DESK_SLOTS
local Employee = require("employee") -- For calculating stats

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

-- Function to draw a styled button
function Drawing.drawButton(text, x, y, width, height, style, isEnabled, isHovered, buttonFont)
    local baseBgColor, hoverBgColor, currentTextColor
    local currentStyle = style or "primary"
    local fontToUse = buttonFont or Drawing.UI.font

    if currentStyle == "primary" then
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

    local bgColor = isEnabled and (isHovered and hoverBgColor or baseBgColor) or Drawing.UI.colors.button_disabled_bg
    currentTextColor = isEnabled and Drawing.UI.colors.button_text or Drawing.UI.colors.button_disabled_text
    
    love.graphics.setColor(bgColor)
    love.graphics.rectangle("fill", x, y, width, height, 5, 5) 

    love.graphics.setColor(currentTextColor)
    if fontToUse then love.graphics.setFont(fontToUse) end 
    local textHeight = fontToUse and fontToUse:getHeight() or 0
    love.graphics.printf(text, math.floor(x), math.floor(y + (height - textHeight) / 2), math.floor(width), "center")
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


-- Modal state and drawing functions
Drawing.UI = {}

-- Default font (will be set in love.load in main.lua)
Drawing.UI.font = nil
Drawing.UI.fontSmall = nil
Drawing.UI.fontLarge = nil
Drawing.UI.titleFont = nil -- For larger titles

-- Default colors (can be themed if desired)
Drawing.UI.colors = {
    text = {0.12, 0.12, 0.12, 1},      -- Near Black for general text
    text_light = {0.95, 0.95, 0.95, 1},-- Very Light Gray for dark backgrounds
    background = {0.94, 0.94, 0.96, 1},-- Light Gray page background (e.g., #F0F0F5)
    header_bg = {1, 1, 1, 1},         -- White for header background
    header_border = {0.85, 0.85, 0.85, 1}, -- Lighter gray border for header
    
    button_primary_bg = {0.25, 0.55, 0.9, 1}, -- Vibrant Blue
    button_primary_hover_bg = {0.35, 0.65, 1.0, 1},
    button_secondary_bg = {0.1, 0.65, 0.35, 1}, -- Green
    button_secondary_hover_bg = {0.2, 0.75, 0.45, 1},
    button_warning_bg = {0.95, 0.65, 0.15, 1}, -- Orange/Yellow
    button_warning_hover_bg = {1, 0.75, 0.25, 1},
    button_danger_bg = {0.85, 0.25, 0.25, 1}, -- Red
    button_danger_hover_bg = {0.95, 0.35, 0.35, 1},
    button_info_bg = {0.2, 0.7, 0.8, 1}, -- Sky Blue / Info
    button_info_hover_bg = {0.3, 0.8, 0.9, 1},
    button_text = {1, 1, 1, 1},           -- White text for buttons
    button_disabled_bg = {0.75, 0.75, 0.75, 1}, -- Medium Gray
    button_disabled_text = {0.5, 0.5, 0.5, 1},  -- Darker Gray

    card_bg = {1, 1, 1, 1},               -- White
    card_border = {0.88, 0.88, 0.88, 1},    -- Very Light Gray
    card_sold_overlay_bg = {0.1, 0.1, 0.1, 0.75}, -- Dark overlay for sold items
    card_sold_overlay_text = {1, 1, 1, 1},         -- White text for sold overlay

    desk_owned_bg = {0.9, 0.92, 0.94, 1},   -- Very light blue-gray for owned empty desks
    desk_owned_border = {0.75, 0.78, 0.8, 1},
    desk_purchasable_bg = {0.88, 0.98, 0.88, 1},-- Light green
    desk_purchasable_border = {0.45, 0.75, 0.45, 1},
    desk_locked_bg = {0.98, 0.88, 0.88, 1},  -- Light red
    desk_locked_border = {0.75, 0.45, 0.45, 1},
    desk_text = {0.25, 0.25, 0.25, 1},       -- Darker gray for desk text
    
    selection_ring = {0.2, 0.55, 0.95, 1},      -- Bright blue for selection
    combine_target_ring = {0.15, 0.75, 0.3, 1}, -- Bright green for combine target
    placement_target_ring = {0.35, 0.65, 1.0, 1},  -- Lighter blue for placement target desk

    rarity_common_bg = {1, 1, 1, 1},                    -- White (unchanged)
    rarity_uncommon_bg = {0.95, 1, 0.95, 1},            -- Very light green tint
    rarity_rare_bg = {0.95, 0.98, 1, 1},                -- Very light blue tint
    rarity_legendary_bg = {1, 0.98, 0.92, 1},           -- Very light orange/gold tint
}

Drawing.modal = {
    isVisible = false,
    title = "",
    message = "",
    x = 0, y = 0, width = 0, height = 0,
    buttons = {} 
}

function Drawing.showModal(title, message, buttons, customWidth)
    Drawing.modal.title = title or "Notification"
    Drawing.modal.message = message or ""
    Drawing.modal.buttons = buttons or { {text = "OK", onClick = function() Drawing.hideModal() end, style = "primary"} } 
    Drawing.modal.isVisible = true
    
    -- Basic modal sizing and positioning
    local screenWidth, screenHeight = love.graphics.getDimensions()
    
    -- Use custom width if provided, otherwise use default logic
    if customWidth then
        Drawing.modal.width = math.min(customWidth, screenWidth - 40)
    else
        Drawing.modal.width = math.min(500, screenWidth - 40)
    end
    
    -- Count message lines for better height calculation
    local messageLines = {}
    for line in Drawing.modal.message:gmatch("[^\n]*") do
        table.insert(messageLines, line)
    end
    
    -- Calculate height based on actual content
    local titleFont = Drawing.UI.titleFont or Drawing.UI.fontLarge or Drawing.UI.font
    local messageFont = Drawing.UI.font or love.graphics.getFont()
    
    local titleHeight = titleFont:getHeight()
    local messageHeight = (#messageLines) * messageFont:getHeight()
    local buttonHeight = (#Drawing.modal.buttons > 0) and 60 or 20
    local padding = 80 -- Extra padding for spacing
    
    Drawing.modal.height = titleHeight + messageHeight + buttonHeight + padding
    Drawing.modal.height = math.min(Drawing.modal.height, screenHeight - 40)

    Drawing.modal.x = (screenWidth - Drawing.modal.width) / 2
    Drawing.modal.y = (screenHeight - Drawing.modal.height) / 2

    -- Position buttons within the modal
    if Drawing.modal.buttons and #Drawing.modal.buttons > 0 then
        local btnWidth = 100
        local btnHeight = 30
        local btnSpacing = 10
        local totalBtnWidth = (#Drawing.modal.buttons * btnWidth) + (math.max(0, #Drawing.modal.buttons - 1) * btnSpacing)
        local startX = Drawing.modal.x + (Drawing.modal.width - totalBtnWidth) / 2
        local btnY = Drawing.modal.y + Drawing.modal.height - btnHeight - 15

        for i, btnData in ipairs(Drawing.modal.buttons) do
            btnData.x = startX + (i-1) * (btnWidth + btnSpacing)
            btnData.y = btnY
            btnData.w = btnWidth
            btnData.h = btnHeight
        end
    end
end

-- Update the global showMessage function to accept width parameter
_G.showMessage = function(title, message, buttons, customWidth)
    Drawing.showModal(title, message, buttons, customWidth)
end

function Drawing.hideModal()
    Drawing.modal.isVisible = false
end

function Drawing.drawModal()
    if not Drawing.modal.isVisible then return end

    -- Full screen overlay
    love.graphics.setColor(0,0,0,0.7)
    love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())

    -- Modal Panel
    Drawing.drawPanel(Drawing.modal.x, Drawing.modal.y, Drawing.modal.width, Drawing.modal.height, Drawing.UI.colors.card_bg, Drawing.UI.colors.header_border, 8)

    local currentY = Drawing.modal.y + 20
    
    -- Handle title (may be two lines)
    local titleLines = {}
    for line in Drawing.modal.title:gmatch("[^\n]*") do
        if line ~= "" then
            table.insert(titleLines, line)
        end
    end
    
    if #titleLines >= 2 then
        -- First line (WORK ITEM COMPLETE!) in large font
        local titleFont = Drawing.UI.titleFont or Drawing.UI.fontLarge or Drawing.UI.font
        love.graphics.setFont(titleFont)
        love.graphics.setColor(Drawing.UI.colors.text)
        love.graphics.printf(titleLines[1], Drawing.modal.x, currentY, Drawing.modal.width, "center")
        currentY = currentY + titleFont:getHeight() + 5
        
        -- Second line (work item name) in smaller font
        local subtitleFont = Drawing.UI.font
        love.graphics.setFont(subtitleFont)
        love.graphics.printf(titleLines[2], Drawing.modal.x, currentY, Drawing.modal.width, "center")
        currentY = currentY + subtitleFont:getHeight() + 15
    else
        -- Single line title
        local titleFont = Drawing.UI.titleFont or Drawing.UI.fontLarge or Drawing.UI.font
        love.graphics.setFont(titleFont)
        love.graphics.setColor(Drawing.UI.colors.text)
        love.graphics.printf(Drawing.modal.title, Drawing.modal.x, currentY, Drawing.modal.width, "center")
        currentY = currentY + titleFont:getHeight() + 15
    end

    -- Handle message content
    local messageFont = Drawing.UI.font or love.graphics.getFont()
    love.graphics.setFont(messageFont)
    
    local messageLines = {}
    for line in Drawing.modal.message:gmatch("[^\n]*") do
        table.insert(messageLines, line)
    end
    
    local lineHeight = messageFont:getHeight()
    
    for _, line in ipairs(messageLines) do
        if line:match("|") then
            -- Handle lines with pipe separator for right alignment
            local leftPart = line:match("^(.-)%|")
            local rightPart = line:match("|(.-)$")
            
            if leftPart and rightPart then
                if line:match("^PROFIT:") then
                    -- Handle colored profit line
                    local colorMatch = leftPart:match("PROFIT:(%w+):")
                    leftPart = leftPart:gsub("PROFIT:%w+:", "PROFIT:")
                    
                    if colorMatch == "GREEN" then
                        love.graphics.setColor(0.1, 0.8, 0.1, 1)
                    elseif colorMatch == "RED" then
                        love.graphics.setColor(0.8, 0.1, 0.1, 1)
                    else
                        love.graphics.setColor(Drawing.UI.colors.text)
                    end
                    love.graphics.setFont(Drawing.UI.fontLarge) -- Make profit line larger
                    love.graphics.print(leftPart, Drawing.modal.x + 20, currentY)
                    love.graphics.printf(rightPart, Drawing.modal.x + 20, currentY, Drawing.modal.width - 40, "right")
                    love.graphics.setFont(messageFont) -- Reset font
                else
                    love.graphics.setColor(Drawing.UI.colors.text)
                    love.graphics.print(leftPart, Drawing.modal.x + 20, currentY)
                    love.graphics.printf(rightPart, Drawing.modal.x + 20, currentY, Drawing.modal.width - 40, "right")
                end
            else
                love.graphics.setColor(Drawing.UI.colors.text)
                love.graphics.printf(line, Drawing.modal.x + 20, currentY, Drawing.modal.width - 40, "left")
            end
        else
            love.graphics.setColor(Drawing.UI.colors.text)
            love.graphics.printf(line, Drawing.modal.x + 20, currentY, Drawing.modal.width - 40, "left")
        end
        currentY = currentY + lineHeight
    end
    
    if Drawing.modal.buttons then
        for i, btnData in ipairs(Drawing.modal.buttons) do
            local mouseX, mouseY = love.mouse.getPosition()
            Drawing.drawButton(btnData.text, btnData.x, btnData.y, btnData.w, btnData.h, btnData.style or "primary", true, Drawing.isMouseOver(mouseX, mouseY, btnData.x, btnData.y, btnData.w, btnData.h))
        end
    end
end

function Drawing.handleModalClick(mouseX, mouseY)
    if not Drawing.modal.isVisible then return false end
    if Drawing.modal.buttons then
        for _, btnData in ipairs(Drawing.modal.buttons) do
            if Drawing.isMouseOver(mouseX, mouseY, btnData.x, btnData.y, btnData.w, btnData.h) then
                if btnData.onClick then btnData.onClick() end
                return true -- Click was handled by a modal button
            end
        end
    end
    -- If click was inside modal panel but not on a button, consider it handled (prevents underlying UI clicks)
    if Drawing.isMouseOver(mouseX, mouseY, Drawing.modal.x, Drawing.modal.y, Drawing.modal.width, Drawing.modal.height) then
        return true
    end
    return false 
end


function Drawing.drawRemoteWorkersPanel(rect, gameState, uiElementRects, draggedItem, battleState)
    Drawing.drawPanel(rect.x, rect.y, rect.width, rect.height, {0.2, 0.2, 0.25, 1}, {0.4,0.4,0.45,1})
    love.graphics.setFont(Drawing.UI.font)
    love.graphics.setColor(Drawing.UI.colors.text_light)
    love.graphics.print("Remote Workers", rect.x + 10, rect.y + 5)
    
    if gameState.temporaryEffectFlags.isRemoteWorkDisabled then
        love.graphics.setFont(Drawing.UI.fontLarge)
        love.graphics.setColor(1,0.2,0.2,1)
        love.graphics.printf("REMOTE WORKERS DISABLED", rect.x, rect.y + rect.height/2 - Drawing.UI.fontLarge:getHeight()/2, rect.width, "center")
        return
    end

    uiElementRects.remote = {}
    uiElementRects.remoteGhostZone = nil

    local remoteWorkers = {}
    for _, empData in ipairs(gameState.hiredEmployees) do
        if empData.variant == 'remote' then
            if not (draggedItem and draggedItem.type == "placed_employee" and empData.instanceId == draggedItem.data.instanceId) then
                table.insert(remoteWorkers, empData)
            end
        end
    end

    local cardY = rect.y + Drawing.UI.font:getHeight() + 8
    local cardWidth = 140 
    local cardHeight = rect.height - (Drawing.UI.font:getHeight() + 15)
    cardHeight = math.max(25, cardHeight)

    local ghostZoneIndex = nil
    local showingGhostZone = false
    
    if draggedItem and draggedItem.data.variant == 'remote' then
        local mouseX, mouseY = love.mouse.getPosition()
        if Drawing.isMouseOver(mouseX, mouseY, rect.x, rect.y, rect.width, rect.height) then
            
            local canCombineWithHovered = false
            local availableWidth = rect.width - 20
            local normalGap = 5
            local normalStepSize = cardWidth + normalGap
            local currentTotalWidth = (#remoteWorkers * cardWidth) + ((#remoteWorkers - 1) * normalGap)
            
            local currentStepSize = normalStepSize
            if currentTotalWidth > availableWidth then
                local spaceForAllButLast = availableWidth - cardWidth
                currentStepSize = spaceForAllButLast / math.max(1, #remoteWorkers - 1)
            end
            
            for i, empData in ipairs(remoteWorkers) do
                local cardX = rect.x + 10 + (i - 1) * currentStepSize
                local effectiveWidth = cardWidth
                
                if currentTotalWidth > availableWidth and i < #remoteWorkers then
                    effectiveWidth = math.max(currentStepSize, cardWidth * 0.4)
                end
                
                if Drawing.isMouseOver(mouseX, mouseY, cardX, cardY, effectiveWidth, cardHeight) then
                    if draggedItem.type == "shop_employee" then
                        if _G.Placement:isPotentialCombineTarget(gameState, empData, draggedItem.data) then
                            canCombineWithHovered = true
                            break
                        end
                    elseif draggedItem.type == "placed_employee" then
                        if _G.Placement:isPotentialCombineTarget(gameState, empData, draggedItem.data) then
                            canCombineWithHovered = true
                            break
                        end
                    end
                    if draggedItem.type == "shop_employee" and draggedItem.data.special then
                        if draggedItem.data.special.type == 'haunt_target_on_hire' or draggedItem.data.special.type == 'slime_merge' then
                            canCombineWithHovered = true
                            break
                        end
                    end
                end
            end
            
            if not canCombineWithHovered then
                showingGhostZone = true
                
                ghostZoneIndex = #remoteWorkers + 1
                
                -- Check if we're directly over any card first
                for i, empData in ipairs(remoteWorkers) do
                    local cardX = rect.x + 10 + (i - 1) * currentStepSize
                    local effectiveWidth = cardWidth
                    
                    if currentTotalWidth > availableWidth and i < #remoteWorkers then
                        effectiveWidth = math.max(currentStepSize, cardWidth * 0.4)
                    end
                    
                    if Drawing.isMouseOver(mouseX, mouseY, cardX, cardY, effectiveWidth, cardHeight) then
                        ghostZoneIndex = i
                        break
                    end
                end
                
                -- If not over a card, use simple proportional positioning
                if ghostZoneIndex == #remoteWorkers + 1 then
                    local relativeMouseX = mouseX - (rect.x + 10)
                    local totalWidth = availableWidth
                    
                    -- Simple proportion: where are we in the available space?
                    local proportion = math.max(0, math.min(1, relativeMouseX / totalWidth))
                    ghostZoneIndex = math.floor(proportion * (#remoteWorkers + 1)) + 1
                    ghostZoneIndex = math.max(1, math.min(ghostZoneIndex, #remoteWorkers + 1))
                end
            end
        end
    end

    local layoutItems = {}
    local ghostZoneX = nil
    
    if showingGhostZone then
        for i = 1, #remoteWorkers + 1 do
            if i == ghostZoneIndex then
                table.insert(layoutItems, {type = "ghost", data = nil})
            end
            if i <= #remoteWorkers then
                local adjustedIndex = i
                if i >= ghostZoneIndex then
                    adjustedIndex = i
                end
                table.insert(layoutItems, {type = "employee", data = remoteWorkers[adjustedIndex]})
            end
        end
    else
        for i, empData in ipairs(remoteWorkers) do
            table.insert(layoutItems, {type = "employee", data = empData})
        end
    end
    
    local totalCards = #layoutItems
    local availableWidth = rect.width - 20
    local normalGap = 5
    local normalStepSize = cardWidth + normalGap
    local totalNormalWidth = (totalCards * cardWidth) + ((totalCards - 1) * normalGap)
    
    local stepSize = normalStepSize
    local needsOverlapping = totalNormalWidth > availableWidth
    if needsOverlapping then
        local spaceForAllButLast = availableWidth - cardWidth
        stepSize = spaceForAllButLast / math.max(1, totalCards - 1)
    end

    local mouseX, mouseY = love.mouse.getPosition()
    local frontCardIndex = nil
    
    if not showingGhostZone then
        for i, item in ipairs(layoutItems) do
            if item.type == "employee" then
                local cardX = rect.x + 10 + (i - 1) * stepSize
                if Drawing.isMouseOver(mouseX, mouseY, cardX, cardY, cardWidth, cardHeight) then
                    frontCardIndex = i
                    break
                end
            end
        end
        
        if not frontCardIndex and battleState.currentWorkerId then
            for i, item in ipairs(layoutItems) do
                if item.type == "employee" and item.data.instanceId == battleState.currentWorkerId then
                    frontCardIndex = i
                    break
                end
            end
        end
    end

    for pass = 1, 2 do
        for i, item in ipairs(layoutItems) do
            local cardX = rect.x + 10 + (i - 1) * stepSize
            
            if item.type == "ghost" then
                if pass == 1 then
                    ghostZoneX = cardX
                    uiElementRects.remoteGhostZone = {x = cardX, y = cardY, w = cardWidth, h = cardHeight}
                    
                    love.graphics.setColor(0.3, 0.8, 0.3, 0.3)
                    Drawing.drawPanel(cardX, cardY, cardWidth, cardHeight, {0.3, 0.8, 0.3, 0.3}, {0.3, 0.8, 0.3, 0.6}, 5)
                    
                    love.graphics.setColor(0.2, 0.6, 0.2, 0.8)
                    love.graphics.setFont(Drawing.UI.fontSmall)
                    love.graphics.printf("DROP\nHERE", cardX, cardY + cardHeight/2 - Drawing.UI.fontSmall:getHeight(), cardWidth, "center")
                end
            else
                local empData = item.data
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
                
                local shouldDrawThisPass = (pass == 1 and i ~= frontCardIndex) or (pass == 2 and i == frontCardIndex)
                
                if shouldDrawThisPass then
                    uiElementRects.remote[empData.instanceId] = {x = cardX, y = cardY, w = cardWidth, h = cardHeight}
                    
                    -- Highlight for Re-Org mode
                    if gameState.temporaryEffectFlags.reOrgSwapModeActive then
                        local firstSelection = _G.getEmployeeFromGameState(gameState, gameState.temporaryEffectFlags.reOrgFirstSelectionInstanceId)
                        if not firstSelection or firstSelection.variant ~= empData.variant then
                           love.graphics.setColor(0.2, 0.7, 0.8, 0.6)
                           love.graphics.rectangle("fill", cardX, cardY, cardWidth, cardHeight, 5)
                           love.graphics.setFont(Drawing.UI.titleFont)
                           love.graphics.setColor(1, 1, 1, 0.9)
                           love.graphics.printf("SWAP?", cardX, cardY + (cardHeight - Drawing.UI.titleFont:getHeight()) / 2, cardWidth, "center")
                        end
                    end

                    local needsClipping = needsOverlapping and (i < totalCards) and (i ~= frontCardIndex)
                    
                    if needsClipping then
                        love.graphics.push()
                        local visibleWidth = math.max(stepSize, cardWidth * 0.4)
                        love.graphics.setScissor(cardX, cardY, visibleWidth, cardHeight)
                        Drawing.drawEmployeeCard(empData, cardX, cardY, cardWidth, cardHeight, empContext, gameState, battleState, Drawing.tooltipsToDraw, Drawing.foilShader, Drawing.holoShader)
                        love.graphics.pop()
                        love.graphics.setScissor()
                    else
                        Drawing.drawEmployeeCard(empData, cardX, cardY, cardWidth, cardHeight, empContext, gameState, battleState, Drawing.tooltipsToDraw, Drawing.foilShader, Drawing.holoShader)
                    end
                end
            end
        end
    end
end

function Drawing.drawGameInfoPanel(rect, gameState, uiElementRects, sprintOverviewVisible)
    Drawing.drawPanel(rect.x, rect.y, rect.width, rect.height, {0.92, 0.92, 0.90, 1}, {0.8,0.8,0.78,1})
    love.graphics.setFont(Drawing.UI.fontLarge); love.graphics.setColor(Drawing.UI.colors.text)
    local currentY = rect.y + 10
    love.graphics.printf("Game Info", rect.x, currentY, rect.width, "center")
    currentY = currentY + Drawing.UI.fontLarge:getHeight() + 15

    love.graphics.setFont(Drawing.UI.font)
    love.graphics.print("Sprint: " .. gameState.currentSprintIndex .. "/8", rect.x + 10, currentY); currentY = currentY + 20
    love.graphics.print("Work Item: " .. gameState.currentWorkItemIndex .. "/3", rect.x + 10, currentY); currentY = currentY + 20
    
    -- Budget Line
    local budgetY = currentY
    love.graphics.print("Budget: $" .. gameState.budget, rect.x + 10, budgetY)
    -- New: Draw the salary chipping animation value
    if gameState.gamePhase == "battle_active" and _G.battleState.phase == "chipping_salaries" then
        love.graphics.setFont(Drawing.UI.fontLarge)
        love.graphics.setColor(1, 0.2, 0.2, 1)
        love.graphics.printf("- $" .. math.floor(_G.battleState.salaryChipAmountRemaining), rect.x + 10, budgetY, rect.width - 20, "right")
        love.graphics.setFont(Drawing.UI.font)
    end
    currentY = currentY + 20


    local sprint = GameData.ALL_SPRINTS[gameState.currentSprintIndex]
    if sprint then
        local workItem = sprint.workItems[gameState.currentWorkItemIndex]
        if workItem then
            if gameState.gamePhase == "hiring_and_upgrades" then
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
            else
                love.graphics.print("Workload: " .. gameState.currentWeekWorkload .. "/" .. gameState.initialWorkloadForBar, rect.x + 10, currentY)
                currentY = currentY + 20
            end
        end

        local hasTimeTraveler, hasAdmiral = false, false
        for _, emp in ipairs(gameState.hiredEmployees) do
            if emp.special then
                if emp.special.type == 'reveals_modifier' then hasTimeTraveler = true end
                if emp.special.type == 'reveals_next_sprint_modifier' then hasAdmiral = true end
            end
        end

        if hasTimeTraveler then
            local bossWorkItem = sprint.workItems[3]
            if bossWorkItem and bossWorkItem.modifier then
                love.graphics.setColor(0.2, 0.6, 0.8, 1)
                love.graphics.print("Future Insight:", rect.x + 10, currentY); currentY = currentY + 20
                love.graphics.setColor(Drawing.UI.colors.text)
                currentY = currentY + Drawing.drawTextWrapped("This Sprint's Boss: "..bossWorkItem.modifier.description, rect.x + 10, currentY, rect.width - 20, Drawing.UI.fontSmall, "left") + 5
            end
        end
        if hasAdmiral and gameState.currentSprintIndex < #GameData.ALL_SPRINTS then
            local nextSprint = GameData.ALL_SPRINTS[gameState.currentSprintIndex + 1]
            if nextSprint then
                local nextBoss = nextSprint.workItems[3]
                if nextBoss and nextBoss.modifier then
                    love.graphics.setColor(0.8, 0.2, 0.6, 1)
                    love.graphics.print("Admiral's Intel:", rect.x + 10, currentY); currentY = currentY + 20
                    love.graphics.setColor(Drawing.UI.colors.text)
                    currentY = currentY + Drawing.drawTextWrapped("Next Sprint's Boss: "..nextBoss.modifier.description, rect.x + 10, currentY, rect.width - 20, Drawing.UI.fontSmall, "left") + 5
                end
            end
        end
    end
    
    if gameState.gamePhase == "battle_active" then
        love.graphics.print("Cycle: " .. gameState.currentWeekCycles + 1, rect.x + 10, currentY); currentY = currentY + 20
    else
        love.graphics.print("Bailouts: " .. gameState.bailOutsRemaining, rect.x + 10, currentY); currentY = currentY + 20
    end
    currentY = currentY + 20 -- Extra spacing

    uiElementRects.actionButtons = {} 
    local btnWidth = rect.width - 20; local btnHeight = 35
    local btnX = rect.x + 10; 
    
    local mainActionBtnY = rect.y + rect.height - btnHeight - 10
    local viewSprintBtnY = mainActionBtnY - btnHeight - 5
    
    if gameState.gamePhase == "hiring_and_upgrades" then
        uiElementRects.actionButtons["view_sprint"] = {x=btnX, y=viewSprintBtnY, w=btnWidth, h=btnHeight}
        Drawing.drawButton("View Sprint Details", btnX, viewSprintBtnY, btnWidth, btnHeight, "info", true, Drawing.isMouseOver(love.mouse.getX(), love.mouse.getY(), btnX, viewSprintBtnY, btnWidth, btnHeight))
    end
    
    local mainAction = nil
    if gameState.gamePhase == "hiring_and_upgrades" then
        mainAction = { text = "Start Work Item", style = "secondary" }
    elseif gameState.gamePhase == "game_over" or gameState.gamePhase == "game_won" then
        mainAction = { text = (gameState.gamePhase == "game_won" and "Play Again?" or "Restart Game"), 
                       style = (gameState.gamePhase == "game_won" and "primary" or "danger") }
    end
    
    if mainAction then
        uiElementRects.actionButtons["main_phase_action"] = {x=btnX, y=mainActionBtnY, w=btnWidth, h=btnHeight}
        Drawing.drawButton(mainAction.text, btnX, mainActionBtnY, btnWidth, btnHeight, mainAction.style, true, Drawing.isMouseOver(love.mouse.getX(), love.mouse.getY(), btnX, mainActionBtnY, btnWidth, btnHeight))
    end
end

function Drawing.drawWorkloadBar(rect, gameState, battleState)
    Drawing.drawPanel(rect.x, rect.y, rect.width, rect.height, {0.3, 0.3, 0.35, 1}, {0.5, 0.5, 0.55, 1})

    local progress = 0
    if gameState.gamePhase == "hiring_and_upgrades" then
        progress = 1.0
    elseif gameState.gamePhase == "battle_active" or gameState.gamePhase == "battle_over" then
        if gameState.initialWorkloadForBar > 0 then
            progress = math.max(0, gameState.currentWeekWorkload / gameState.initialWorkloadForBar)
        end
    else
        return
    end
    
    local barFillHeight = rect.height * progress
    local barFillY = rect.y + (rect.height - barFillHeight)

    love.graphics.setColor(0.4, 0.8, 0.5, 1)
    love.graphics.rectangle("fill", rect.x, barFillY, rect.width, barFillHeight)

    -- New: Draw progress markers for each completed cycle
    if battleState.progressMarkers and #battleState.progressMarkers > 0 then
        love.graphics.setLineWidth(2)
        love.graphics.setColor(1, 0.2, 0.2, 0.9) -- A noticeable red

        for _, progressValue in ipairs(battleState.progressMarkers) do
            local markerY = rect.y + rect.height - (rect.height * progressValue)
            love.graphics.line(rect.x - 2, markerY, rect.x + rect.width + 2, markerY)
        end

        love.graphics.setLineWidth(1) -- Reset line width for other UI elements
    end


    -- New: Draw the accumulating round total
    if gameState.gamePhase == "battle_active" and battleState.roundTotalContribution > 0 then
        love.graphics.setFont(Drawing.UI.fontLarge)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.printf(tostring(battleState.roundTotalContribution), rect.x + rect.width + 5, rect.y, 100, "left")
    end

    love.graphics.setFont(Drawing.UI.fontLarge)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.push()
    love.graphics.translate(rect.x + rect.width / 2, rect.y + rect.height / 2)
    love.graphics.rotate(-math.pi / 2)
    love.graphics.printf("WORK", 0, 0, rect.height, "center")
    love.graphics.pop()
end

function Drawing.drawShopPanel(rect, gameState, uiElementRects, draggedItem, Shop)
    Drawing.drawPanel(rect.x, rect.y, rect.width, rect.height, {0.95, 0.93, 0.90, 1}, {0.82, 0.80, 0.78,1})
    love.graphics.setFont(Drawing.UI.fontLarge); love.graphics.setColor(Drawing.UI.colors.text)
    local currentY = rect.y + 10
    love.graphics.printf("Shop", rect.x, currentY, rect.width, "center")
    currentY = currentY + Drawing.UI.fontLarge:getHeight() + 10

    if gameState.temporaryEffectFlags.isShopDisabled then
        love.graphics.setFont(Drawing.UI.fontLarge)
        love.graphics.setColor(1,0.2,0.2,1)
        love.graphics.printf("SHOP DISABLED\n(Modifier Active)", rect.x, rect.y + rect.height/2 - Drawing.UI.fontLarge:getHeight(), rect.width, "center")
        return
    end

    local cardPadding = 5; local cardWidth = rect.width - 2 * cardPadding
    local cardHeight = 140

    uiElementRects.shopEmployees = {}
    uiElementRects.shopUpgradeOffer = nil
    uiElementRects.shopRestock = nil
    
    love.graphics.setFont(Drawing.UI.font)
    love.graphics.setColor(Drawing.UI.colors.text)
    love.graphics.printf("Looking for Work", rect.x, currentY, rect.width, "center")
    currentY = currentY + Drawing.UI.font:getHeight() + 8

    if gameState.currentShopOffers and gameState.currentShopOffers.employees then
        for i = 1, 3 do
            local empData = gameState.currentShopOffers.employees[i]
            if empData then 
                if currentY + cardHeight > rect.y + rect.height - 45 then break end 
                uiElementRects.shopEmployees[i] = {x = rect.x + cardPadding, y = currentY, w = cardWidth, h = cardHeight, data = empData, originalIndexInShop = i}
                
                if draggedItem and draggedItem.originalShopInstanceId == empData.instanceId then
                    love.graphics.setColor(0.5,0.5,0.5,0.5)
                    Drawing.drawPanel(rect.x+cardPadding, currentY, cardWidth, cardHeight, {0.8,0.8,0.8,0.5})
                else
                    -- MODIFICATION: Pass uiElementRects to the card drawing function
                    Drawing.drawEmployeeCard(empData, rect.x + cardPadding, currentY, cardWidth, cardHeight, "shop_offer", gameState, _G.battleState, Drawing.tooltipsToDraw, Drawing.foilShader, Drawing.holoShader, uiElementRects)
                end
                currentY = currentY + cardHeight + 5
            end
        end
    end
    
    currentY = currentY + 15
    
    love.graphics.setFont(Drawing.UI.font)
    love.graphics.setColor(Drawing.UI.colors.text)
    love.graphics.printf("Office Upgrades", rect.x, currentY, rect.width, "center")
    currentY = currentY + Drawing.UI.font:getHeight() + 8
    
    if gameState.currentShopOffers and gameState.currentShopOffers.upgrade then
        local upgradeCardHeight = 110
        if currentY + upgradeCardHeight <= rect.y + rect.height - 45 then
             local upgData = gameState.currentShopOffers.upgrade
             uiElementRects.shopUpgradeOffer = {x = rect.x + cardPadding, y = currentY, w = cardWidth, h = upgradeCardHeight, data = upgData}
             
             -- MODIFICATION: Pass uiElementRects to the card drawing function
             Drawing.drawUpgradeCard(upgData, rect.x + cardPadding, currentY, cardWidth, upgradeCardHeight, "shop_offer", gameState, Shop, uiElementRects)
        end
    end

    local restockBtnY = rect.y + rect.height - 35 - 10
    local restockCost = GameData.BASE_RESTOCK_COST * (2 ^ (gameState.currentShopOffers.restockCountThisWeek or 0))
    if Shop:isUpgradePurchased(gameState.purchasedPermanentUpgrades, 'headhunter') then
        restockCost = restockCost * 2
    end

    uiElementRects.shopRestock = {x = rect.x + cardPadding, y = restockBtnY, w = cardWidth, h = 35}
    Drawing.drawButton("Restock ($" .. restockCost .. ")", uiElementRects.shopRestock.x, uiElementRects.shopRestock.y, uiElementRects.shopRestock.w, uiElementRects.shopRestock.h, "warning", gameState.budget >= restockCost and not draggedItem, Drawing.isMouseOver(love.mouse.getX(), love.mouse.getY(), uiElementRects.shopRestock.x, uiElementRects.shopRestock.y, uiElementRects.shopRestock.w, uiElementRects.shopRestock.h))
end


function Drawing.drawMainInteractionPanel(rect, gameState, uiElementRects, draggedItem, battleState, Placement, DrawingState) 
    Drawing.drawPanel(rect.x, rect.y, rect.width, rect.height, {0.88, 0.90, 0.92, 1}, {0.75,0.78,0.80,1})
    love.graphics.setFont(Drawing.UI.fontLarge); love.graphics.setColor(Drawing.UI.colors.text)
    love.graphics.printf("Office Floor", rect.x, rect.y + 10, rect.width, "center")

    local deskSectionHeight = rect.height - (Drawing.UI.fontLarge:getHeight() + 20) 
    local deskSpacing = 5
    local deskWidth = math.floor((rect.width - 2 * 10 - (GameData.GRID_WIDTH - 1) * deskSpacing) / GameData.GRID_WIDTH)
    local deskHeight = math.floor((deskSectionHeight - (GameData.GRID_WIDTH - 1) * deskSpacing) / GameData.GRID_WIDTH)

    local deskAreaStartX = rect.x + (rect.width - (GameData.GRID_WIDTH * deskWidth + (GameData.GRID_WIDTH - 1) * deskSpacing)) / 2
    local deskAreaStartY = rect.y + Drawing.UI.fontLarge:getHeight() + 20 + (deskSectionHeight - (GameData.GRID_WIDTH * deskHeight + (GameData.GRID_WIDTH - 1) * deskSpacing)) / 2

    uiElementRects.desks = {}
    DrawingState.overlaysToDraw = {}
    local mouseX, mouseY = love.mouse.getPosition()

    -- FIRST PASS: Draw desks, employees, and determine which overlays are needed
    for i, deskData in ipairs(gameState.desks) do
        local col = (i - 1) % GameData.GRID_WIDTH
        local row = math.floor((i - 1) / GameData.GRID_WIDTH)
        local deskX_abs = deskAreaStartX + col * (deskWidth + deskSpacing)
        local deskY_abs = deskAreaStartY + row * (deskHeight + deskSpacing)
        local deskRect = { x = deskX_abs, y = deskY_abs, w = deskWidth, h = deskHeight, id = deskData.id }
        uiElementRects.desks[i] = deskRect
        
        local isDeskDisabled = (gameState.temporaryEffectFlags.isTopRowDisabled and row == 0)
        Drawing.drawDeskSlot(deskData, deskX_abs, deskY_abs, deskWidth, deskHeight, isDeskDisabled)
        
        local empId = gameState.deskAssignments[deskData.id]
        local emp = empId and _G.getEmployeeFromGameState(gameState, empId)
        
        if emp then
            local empContext = "desk_placed"
            if emp.isTraining or isDeskDisabled then empContext = "worker_training"
            elseif gameState.gamePhase == "battle_active" then
                local workerIndexInBattle = -1
                for j, activeEmp in ipairs(battleState.activeEmployees) do if activeEmp.instanceId == emp.instanceId then workerIndexInBattle = j; break; end end
                if workerIndexInBattle ~= -1 and workerIndexInBattle < battleState.nextEmployeeIndex then empContext = "worker_done" end
            end
            if not (draggedItem and draggedItem.data.instanceId == emp.instanceId) then
                 -- MODIFICATION: Pass uiElementRects to the card drawing function
                 Drawing.drawEmployeeCard(emp, deskX_abs + 2, deskY_abs + 2, deskWidth - 4, deskHeight - 4, empContext, gameState, battleState, DrawingState.tooltipsToDraw, Drawing.foilShader, Drawing.holoShader, uiElementRects)
            end

            -- Highlight for Re-Org or Photocopier modes
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

        local isMouseOverDesk = Drawing.isMouseOver(mouseX, mouseY, deskRect.x, deskRect.y, deskRect.w, deskRect.h)

        if isMouseOverDesk then
            if draggedItem and emp and Placement:isPotentialCombineTarget(gameState, emp, draggedItem.data) then
                local fakeLeveledUpEmployee = {}
                for k, v in pairs(emp) do fakeLeveledUpEmployee[k] = v end
                fakeLeveledUpEmployee.level = (emp.level or 1) + 1
                generatePositionalOverlays(DrawingState, fakeLeveledUpEmployee, deskData.id, gameState)

            elseif draggedItem and (draggedItem.type == "placed_employee" or draggedItem.type == "shop_employee") then
                generatePositionalOverlays(DrawingState, draggedItem.data, deskData.id, gameState)

            elseif not draggedItem and emp then
                generatePositionalOverlays(DrawingState, emp, deskData.id, gameState)
            end
        end
    end

    -- SECOND PASS: Draw the overlays on top of the grid
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

function Drawing.drawPurchasedUpgradesDisplay(rect, gameState, uiElementRects)
    Drawing.drawPanel(rect.x, rect.y, rect.width, rect.height, {0.25, 0.25, 0.2, 1}, {0.45,0.45,0.4,1}) 
    love.graphics.setFont(Drawing.UI.font)
    love.graphics.setColor(Drawing.UI.colors.text_light)
    love.graphics.print("Acquired Office Upgrades", rect.x + 10, rect.y + 5)
    
    local currentX = rect.x + 10
    local iconY = rect.y + Drawing.UI.font:getHeight() + 10
    local iconSize = math.min(rect.height - (Drawing.UI.font:getHeight() + 15), 32)
    local iconPadding = 5

    uiElementRects.permanentUpgrades = {}

    if #gameState.purchasedPermanentUpgrades == 0 then
        love.graphics.setFont(Drawing.UI.fontSmall); love.graphics.printf("None yet.", rect.x + 10, iconY, rect.width - 20, "left"); return
    end

    local mouseX, mouseY = love.mouse.getPosition()

    for _, upgradeId in ipairs(gameState.purchasedPermanentUpgrades) do
        local upgData = nil
        for _,u in ipairs(GameData.ALL_UPGRADES) do if u.id == upgradeId then upgData=u; break; end end
        if upgData then
            if currentX + iconSize > rect.x + rect.width - 10 then break end
            
            local isClickable = (upgData.id == 'motivational_speaker' and gameState.gamePhase == 'hiring_and_upgrades' and not gameState.temporaryEffectFlags.motivationalSpeakerUsedThisSprint and gameState.budget >= 1000) or
                                (upgData.id == 'the_reorg' and gameState.gamePhase == 'hiring_and_upgrades' and not gameState.temporaryEffectFlags.reOrgUsedThisSprint) or
                                (upgData.id == 'sentient_photocopier' and gameState.gamePhase == 'hiring_and_upgrades' and not gameState.temporaryEffectFlags.photocopierUsedThisSprint) or
                                (upgData.id == 'multiverse_merger' and gameState.temporaryEffectFlags.multiverseMergerAvailable)

            local isHovered = Drawing.isMouseOver(mouseX, mouseY, currentX, iconY, iconSize, iconSize)

            if isClickable and isHovered then
                love.graphics.setColor(0.2, 0.8, 0.2, 0.4)
                love.graphics.rectangle("fill", currentX - 2, iconY - 2, iconSize + 4, iconSize + 4, 3)
            end

            love.graphics.setFont(Drawing.UI.titleFont or Drawing.UI.fontLarge) 
            love.graphics.setColor(Drawing.UI.colors.text_light)
            love.graphics.print(upgData.icon or "?", currentX, iconY)

            uiElementRects.permanentUpgrades[upgradeId] = {x = currentX, y = iconY, w = iconSize, h = iconSize, data = upgData}

            if isHovered then
                local tooltipText = upgData.name .. ": " .. upgData.description
                if isClickable then
                    tooltipText = tooltipText .. "\n\n(Click to Activate)"
                end
                local textWidthForWrap = 200
                -- MODIFICATION: Calculate height using the standard font for consistency
                local wrappedHeight = Drawing.drawTextWrapped(tooltipText, 0,0, textWidthForWrap, Drawing.UI.font, "left", nil, false) 
                local tooltipWidth = textWidthForWrap + 10
                local tooltipHeight = wrappedHeight + 6
                local tipX = mouseX + 5; local tipY = mouseY - tooltipHeight - 2
                if tipX + tooltipWidth > love.graphics.getWidth() then tipX = mouseX - tooltipWidth - 5 end
                table.insert(Drawing.tooltipsToDraw, { text = tooltipText, x = tipX, y = tipY, w = tooltipWidth, h = tooltipHeight })
            end
            currentX = currentX + iconSize + iconPadding
        end
    end
end

function Drawing.drawEmployeeCard(employeeData, x, y, width, height, context, gameState, battleState, tooltipsToDraw, foilShader, holoShader, uiElementRects)
    local cardData = employeeData
    if employeeData.copiedState then
        cardData = {}
        for k, v in pairs(employeeData) do cardData[k] = v end
        for k, v in pairs(employeeData.copiedState) do cardData[k] = v end
    end

    local shakeX, shakeY = 0, 0
    if battleState.currentWorkerId == cardData.instanceId and battleState.isShaking then
        shakeX, shakeY = love.math.random(-2, 2), love.math.random(-2, 2)
    end
    love.graphics.push(); love.graphics.translate(x + shakeX, y + shakeY)

    local isSelected = (not _G.draggedItem and gameState.selectedEmployeeForPlacementInstanceId == cardData.instanceId)
    local isCombineTarget = false
    if not isSelected then
        local sourceEmpForCombine = _G.draggedItem and _G.draggedItem.data or _G.getEmployeeFromGameState(gameState, gameState.selectedEmployeeForPlacementInstanceId)
        if sourceEmpForCombine and sourceEmpForCombine.instanceId ~= cardData.instanceId then
            isCombineTarget = _G.Placement:isPotentialCombineTarget(gameState, cardData, sourceEmpForCombine)
        end
    end
    
    local agentSmithData = nil
    if cardData.isSmithCopy then
        for _, card in ipairs(GameData.BASE_EMPLOYEE_CARDS) do
            if card.id == 'agent_smith1' then
                agentSmithData = card
                break
            end
        end
    end

    local rarity = (cardData.copiedState and cardData.copiedState.rarity) or cardData.rarity or 'Common'
    if agentSmithData then rarity = agentSmithData.rarity end

    local bgColor = Drawing.UI.colors.rarity_common_bg
    
    if rarity == 'Common' then bgColor = Drawing.UI.colors.rarity_common_bg
    elseif rarity == 'Uncommon' then bgColor = Drawing.UI.colors.rarity_uncommon_bg
    elseif rarity == 'Rare' then bgColor = Drawing.UI.colors.rarity_rare_bg
    elseif rarity == 'Legendary' then bgColor = Drawing.UI.colors.rarity_legendary_bg end

    if context == "worker_done" or context == "worker_training" then bgColor = {0.7, 0.7, 0.7, 1} end
    if cardData.isRebooted then bgColor = {0.7, 0.9, 1, 1} end 
    if cardData.snackBoostActive then bgColor = {1, 0.9, 0.7, 1} end 
    if employeeData.id == 'mimic1' and not employeeData.copiedState then bgColor = {0.8, 0.7, 1.0, 1} end
    if employeeData.isSlimeHybrid then bgColor = {0.7, 1.0, 0.7, 1} end
    
    local borderColor = Drawing.UI.colors.card_border
    if cardData.isNepotismBaby then
        borderColor = {1, 0.84, 0, 1} 
    end
    
    if cardData.variant == 'foil' then
        love.graphics.setShader(foilShader)
        foilShader:send("time", love.timer.getTime())
    elseif cardData.variant == 'holo' then
        love.graphics.setShader(holoShader)
        holoShader:send("time", love.timer.getTime())
    end
    
    Drawing.drawPanel(0, 0, width, height, bgColor, borderColor, 5)

    love.graphics.setShader()

    if cardData.positionalEffects and cardData.variant ~= 'remote' then
        local bonusIndicatorWidth = 4
        for direction, effect in pairs(cardData.positionalEffects) do
            local directionsToDraw = {}; if direction == "all_adjacent" then directionsToDraw = {"up", "down", "left", "right"} else table.insert(directionsToDraw, direction) end
            for _, dir in ipairs(directionsToDraw) do
                local effectColor = {0,0,0,1}
                if effect.productivity_add or effect.productivity_mult then effectColor = {0.1, 0.65, 0.35, 1} elseif effect.focus_add or effect.focus_mult then effectColor = {0.25, 0.55, 0.9, 1} end
                love.graphics.setColor(effectColor)
                if dir == "up" then love.graphics.rectangle("fill", 0, 0, width, bonusIndicatorWidth, 5, 5, 0, 0)
                elseif dir == "down" then love.graphics.rectangle("fill", 0, height - bonusIndicatorWidth, width, bonusIndicatorWidth, 0, 0, 5, 5)
                elseif dir == "left" then love.graphics.rectangle("fill", 0, 0, bonusIndicatorWidth, height, 5, 0, 0, 5)
                elseif dir == "right" then love.graphics.rectangle("fill", width - bonusIndicatorWidth, 0, bonusIndicatorWidth, height, 0, 5, 5, 0)
                end
            end
        end
    end
    love.graphics.setLineWidth(1)

    if isSelected then love.graphics.setLineWidth(3); love.graphics.setColor(Drawing.UI.colors.selection_ring); love.graphics.rectangle("line", -1, -1, width+2, height+2, 6,6)
    elseif isCombineTarget then love.graphics.setLineWidth(3); love.graphics.setColor(Drawing.UI.colors.combine_target_ring); love.graphics.rectangle("line", -1, -1, width+2, height+2, 6,6)
    end; love.graphics.setLineWidth(1)

    local padding = 5; 
    love.graphics.setColor(Drawing.UI.colors.text)
    
    local icon = (agentSmithData and agentSmithData.icon) or (cardData.icon or "❓")
    love.graphics.setFont(Drawing.UI.titleFont)
    local iconWidth = Drawing.UI.titleFont:getWidth(icon)
    love.graphics.printf(icon, 0, padding, width - padding, "right")

    local textWrapWidth = width - iconWidth - (padding * 2)
    local currentYDraw = padding

    local displayName = (agentSmithData and agentSmithData.name) or (cardData.fullName or cardData.name)
    local titleName = (agentSmithData and agentSmithData.name) or cardData.name

    love.graphics.setFont(Drawing.UI.font)
    Drawing.drawTextWrapped(displayName, padding, currentYDraw, textWrapWidth, Drawing.UI.font, "left", 1)
    currentYDraw = currentYDraw + Drawing.UI.font:getHeight() + 2

    love.graphics.setFont(Drawing.UI.fontSmall)
    love.graphics.setColor(0.4, 0.4, 0.4, 1)
    love.graphics.print(titleName, padding, currentYDraw)
    currentYDraw = currentYDraw + Drawing.UI.fontSmall:getHeight() + 2


    if context == "shop_offer" or context == "desk_placed" or context == "remote_worker" then
        local stats = Employee:calculateStatsWithPosition(employeeData, gameState.hiredEmployees, gameState.deskAssignments, gameState.purchasedPermanentUpgrades, gameState.desks, gameState)
        local variantY = currentYDraw + 4
        
        love.graphics.setFont(Drawing.UI.fontSmall)
        if cardData.variant == 'remote' then
            love.graphics.setColor(0.6,0.3,0.8,1)
            love.graphics.print("REMOTE", padding, variantY)
        elseif cardData.variant == 'foil' then
            love.graphics.setColor(0.8, 0.7, 0.1, 1)
            love.graphics.print("FOIL", padding, variantY)
        elseif cardData.variant == 'holo' then
            love.graphics.setColor(0.2, 0.7, 0.9, 1)
            love.graphics.print("HOLO", padding, variantY)
        end
        
        if context == "shop_offer" then
            love.graphics.setColor(0.85, 0.25, 0.25, 1)
            local finalCost = _G.Shop:getFinalHiringCost(cardData, gameState.purchasedPermanentUpgrades)
            love.graphics.printf("Hire: $" .. finalCost, padding, variantY, width - padding * 2, "right")

            love.graphics.setFont(Drawing.UI.fontLarge)
            if cardData.isLocked then love.graphics.setColor(1, 0.85, 0, 1)
            else love.graphics.setColor(0.6, 0.6, 0.6, 1) end
            
            local lockText = "🔒"
            local lockY = height - (Drawing.UI.fontLarge:getHeight() * 2) - padding
            love.graphics.printf(lockText, 0, lockY, width, "center")

            local lockWidth = Drawing.UI.fontLarge:getWidth(lockText)
            local lockHeight = Drawing.UI.fontLarge:getHeight()
            uiElementRects.shopLockButtons[cardData.instanceId] = {
                x = x + (width - lockWidth) / 2,
                y = y + lockY,
                w = lockWidth,
                h = lockHeight
            }
        end
        
        love.graphics.setFont(Drawing.UI.fontLarge)
        love.graphics.setColor(0.1, 0.65, 0.35, 1)
        love.graphics.print(tostring(stats.currentProductivity), padding, height - padding - Drawing.UI.fontLarge:getHeight())
        
        love.graphics.setColor(0.25, 0.55, 0.9, 1)
        love.graphics.print(string.format("%.1f", stats.currentFocus), padding + 35, height - padding - Drawing.UI.fontLarge:getHeight())
        
        love.graphics.setColor(0.85, 0.25, 0.25, 1)
        love.graphics.printf("$" .. ((agentSmithData and agentSmithData.weeklySalary) or cardData.weeklySalary), width - 80, height - padding - Drawing.UI.fontLarge:getHeight(), 40, "right")
        
        love.graphics.setColor(Drawing.UI.colors.text)
        love.graphics.printf("L" .. (cardData.level or 1), width - 35, height - padding - Drawing.UI.fontLarge:getHeight(), 30, "right")
        
    else
        love.graphics.printf("L"..(cardData.level or 1), padding, currentYDraw + 5, 25, "left")

        love.graphics.setFont(Drawing.UI.fontSmall)
        local stats = Employee:calculateStatsWithPosition(employeeData, gameState.hiredEmployees, gameState.deskAssignments, gameState.purchasedPermanentUpgrades, gameState.desks, gameState)
        love.graphics.print("Sal: $" .. ((agentSmithData and agentSmithData.weeklySalary) or cardData.weeklySalary), padding, currentYDraw + 25)
        love.graphics.print("Prod: " .. stats.currentProductivity, padding, currentYDraw + 35)
        love.graphics.print("Focus: " .. string.format("%.2f", stats.currentFocus) .. "x", padding, currentYDraw + 45)
    end

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

    if battleState.currentWorkerId == cardData.instanceId and battleState.lastContribution then
        love.graphics.setColor(0,0,0,0.7); love.graphics.rectangle("fill", 0, 0, width, height, 5,5)
        local font = Drawing.UI.titleFont or Drawing.UI.fontLarge; love.graphics.setFont(font); love.graphics.setColor(1,1,1,1)
        
        local contrib = battleState.lastContribution; local textToShow = ""
        if battleState.phase == 'showing_productivity' then textToShow = tostring(contrib.productivity)
        elseif battleState.phase == 'showing_focus' then textToShow = "x " .. string.format("%.2f", contrib.focus)
        elseif battleState.phase == 'showing_total' then textToShow = "= " .. tostring(contrib.totalContribution)
        elseif battleState.phase == 'animating_changes' then 
             local changedInfo = battleState.changedEmployeesForAnimation[battleState.nextChangedEmployeeIndex]
             if changedInfo then
                 textToShow = tostring(changedInfo.new.totalContribution)
             end
        end
        love.graphics.printf(textToShow, 0, height/2 - font:getHeight()/2, width, "center")
    end

    love.graphics.pop()

    local mouseX, mouseY = love.mouse.getPosition()
    if not _G.draggedItem and not (gameState.gamePhase == "battle_active") and Drawing.isMouseOver(mouseX, mouseY, x, y, width, height) then
        local stats = Employee:calculateStatsWithPosition(employeeData, gameState.hiredEmployees, gameState.deskAssignments, gameState.purchasedPermanentUpgrades, gameState.desks, gameState)
        local log = stats.calculationLog

        local description = (agentSmithData and agentSmithData.description) or (employeeData.description or "No description.")
        if employeeData.variant == 'remote' and employeeData.remoteDescription then
            description = employeeData.remoteDescription
        end
        if employeeData.copiedState and employeeData.copiedState.description then
            description = employeeData.copiedState.description
        end
        if agentSmithData then
            description = description .. "\n\n(This employee has been assimilated by Agent Smith)"
        end
        
        local tooltipLines = {}
        
        local function addTooltip(text, color)
            local colorStr = ""
            if color then colorStr = string.format("[%.1f,%.1f,%.1f]", color[1], color[2], color[3]) end
            table.insert(tooltipLines, colorStr .. text)
        end
        
        local textWidthForWrap = 280
        
        local _, wrappedDescText = Drawing.UI.font:getWrap(description, textWidthForWrap - 16)
        for _, line in ipairs(wrappedDescText) do addTooltip(line, {1, 1, 1}) end
        addTooltip("", nil); addTooltip("", nil)
        
        addTooltip("PRODUCTIVITY:", {0.1, 0.65, 0.35})
        if #log.productivity == 1 then
            addTooltip(tostring(stats.currentProductivity), {0.1, 0.65, 0.35})
        else
            for _, line in ipairs(log.productivity) do addTooltip(line, {1, 1, 1}) end
            addTooltip("──────", {0.7, 0.7, 0.7})
            addTooltip(tostring(stats.currentProductivity), {0.1, 0.65, 0.35})
        end
        
        addTooltip("", nil); addTooltip("", nil)
        
        addTooltip("FOCUS:", {0.25, 0.55, 0.9})
        if #log.focus == 1 then
            addTooltip(string.format("%.2fx", stats.currentFocus), {0.25, 0.55, 0.9})
        else
            for _, line in ipairs(log.focus) do addTooltip(line, {1, 1, 1}) end
            addTooltip("──────", {0.7, 0.7, 0.7})
            addTooltip(string.format("%.2fx", stats.currentFocus), {0.25, 0.55, 0.9})
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
        
        table.insert(tooltipsToDraw, { text = tooltipText, x = tipX, y = tipY, w = tooltipWidth, h = tooltipHeight, coloredLines = tooltipLines })
    end
end

function Drawing.drawUpgradeCard(upgradeData, x, y, width, height, context, gameState, Shop, uiElementRects) 
    love.graphics.push(); love.graphics.translate(x, y)
    local bgColor = upgradeData.sold and {0.6,0.6,0.6,1} or Drawing.UI.colors.card_bg
    Drawing.drawPanel(0,0, width, height, bgColor, Drawing.UI.colors.card_border, 3)
    
    love.graphics.setColor(upgradeData.sold and {0.4,0.4,0.4,1} or Drawing.UI.colors.text)
    local padding = 4
    
    love.graphics.setFont(Drawing.UI.titleFont)
    local iconWidth = Drawing.UI.titleFont:getWidth(upgradeData.icon or "❓")
    love.graphics.printf(upgradeData.icon or "❓", 0, padding, width - padding, "right")

    local textWrapWidth = width - iconWidth - (padding * 2)
    local currentYDraw = padding

    love.graphics.setFont(Drawing.UI.font)
    currentYDraw = currentYDraw + Drawing.drawTextWrapped(upgradeData.name, padding, currentYDraw, textWrapWidth, Drawing.UI.font, "left", 2) + 5

    love.graphics.setFont(Drawing.UI.fontSmall)
    
    local finalCost = Shop:getModifiedUpgradeCost(upgradeData, gameState.hiredEmployees)
    love.graphics.printf("Cost: $" .. finalCost, padding, currentYDraw, textWrapWidth, "left")
    
    currentYDraw = currentYDraw + Drawing.UI.fontSmall:getHeight() + 2
    Drawing.drawTextWrapped(upgradeData.description or "", padding, currentYDraw, textWrapWidth, Drawing.UI.fontSmall, "left", 3)
    
    if context == "shop_offer" then
        love.graphics.setFont(Drawing.UI.fontLarge)
        if upgradeData.isLocked then love.graphics.setColor(1, 0.85, 0, 1)
        else love.graphics.setColor(0.6, 0.6, 0.6, 1) end

        local lockText = "🔒"
        local lockY = height - Drawing.UI.fontLarge:getHeight() - padding
        love.graphics.printf(lockText, 0, lockY, width, "center")

        -- MODIFICATION: Use the passed-in uiElementRects table, not the global one
        local lockWidth = Drawing.UI.fontLarge:getWidth(lockText)
        local lockHeight = Drawing.UI.fontLarge:getHeight()
        uiElementRects.shopLockButtons[upgradeData.instanceId] = {
            x = x + (width - lockWidth) / 2,
            y = y + lockY,
            w = lockWidth,
            h = lockHeight
        }
    end
    
    if upgradeData.sold then
        love.graphics.setColor(Drawing.UI.colors.card_sold_overlay_bg); love.graphics.rectangle("fill",0,0,width,height,3,3)
        love.graphics.setFont(Drawing.UI.fontLarge); love.graphics.setColor(Drawing.UI.colors.card_sold_overlay_text); love.graphics.printf("SOLD", 0, height/2 - Drawing.UI.fontLarge:getHeight()/2, width, "center")
    end
    love.graphics.pop()
end

function Drawing.drawDeskSlot(deskData, x, y, width, height, isDisabled)
    local bgColor, borderColor
    if isDisabled then
        bgColor, borderColor = {0.4, 0.4, 0.4, 1}, {0.2, 0.2, 0.2, 1}
    elseif deskData.status == "owned" then bgColor, borderColor = Drawing.UI.colors.desk_owned_bg, Drawing.UI.colors.desk_owned_border
    elseif deskData.status == "purchasable" then bgColor, borderColor = Drawing.UI.colors.desk_purchasable_bg, Drawing.UI.colors.desk_purchasable_border
    else bgColor, borderColor = Drawing.UI.colors.desk_locked_bg, Drawing.UI.colors.desk_locked_border end

    Drawing.drawPanel(x,y,width,height,bgColor,borderColor,3)

    love.graphics.setFont(Drawing.UI.fontSmall)
    if isDisabled then
        love.graphics.setColor(1,0.2,0.2,1)
        love.graphics.printf("DISABLED", x, y + height/2 - Drawing.UI.fontSmall:getHeight()/2, width, "center")
    elseif not _G.gameState.deskAssignments[deskData.id] then
        love.graphics.setColor(Drawing.UI.colors.desk_text)
        if deskData.status == "owned" then love.graphics.printf("Empty", x, y + height/2 - Drawing.UI.fontSmall:getHeight()/2, width, "center")
        elseif deskData.status == "purchasable" then love.graphics.printf("Buy\n$" .. deskData.cost, x, y + height/2 - Drawing.UI.fontSmall:getHeight(), width, "center")
        elseif deskData.status == "locked" then love.graphics.printf("Locked", x, y + height/2 - Drawing.UI.fontSmall:getHeight()/2, width, "center") 
        end
    end
end


function Drawing.drawDebugMenu(debug, foilShader, holoShader)
    local screenW, screenH = love.graphics.getDimensions()
    local w, h = 400, 450
    local x, y = (screenW - w) / 2, (screenH - h) / 2
    debug.rect = {x=x, y=y, w=w, h=h}

    -- Draw background panel
    Drawing.drawPanel(x, y, w, h, {0.2, 0.2, 0.2, 0.95}, {0.5, 0.5, 0.5, 1}, 8)

    love.graphics.setFont(Drawing.UI.fontLarge)
    love.graphics.setColor(Drawing.UI.colors.text_light)
    love.graphics.printf("Debug Menu", x, y + 10, w, "center")

    local currentY = y + 50
    local padding = 15
    local controlW = w - padding * 2
    local smallBtnW = (controlW - 10) / 2

    love.graphics.setFont(Drawing.UI.font)
    love.graphics.print("Spawn Employee:", x + padding, currentY)
    currentY = currentY + 20

    -- Draw Employee Dropdown (closed state only)
    debug.employeeDropdown.rect = {x = x + padding, y = currentY, w = controlW, h = 25}
    Drawing.drawDropdown(debug.employeeDropdown.rect, debug.employeeDropdown)
    currentY = currentY + 35

    -- Checkboxes
    local chkW = 80
    debug.checkboxes.remote.rect = {x = x + padding, y = currentY, w = chkW, h = 20}
    Drawing.drawCheckbox(debug.checkboxes.remote.rect, "Remote", debug.checkboxes.remote.checked)
    
    debug.checkboxes.foil.rect = {x = x + padding + chkW + 10, y = currentY, w = chkW, h = 20}
    Drawing.drawCheckbox(debug.checkboxes.foil.rect, "Foil", debug.checkboxes.foil.checked)
    
    debug.checkboxes.holo.rect = {x = x + padding + (chkW + 10) * 2, y = currentY, w = chkW, h = 20}
    Drawing.drawCheckbox(debug.checkboxes.holo.rect, "Holo", debug.checkboxes.holo.checked)
    currentY = currentY + 30

    -- Spawn Employee Button
    debug.buttons.spawnEmployee = {x = x + padding, y = currentY, w = controlW, h = 30}
    Drawing.drawButton("Spawn Employee in Shop", debug.buttons.spawnEmployee.x, debug.buttons.spawnEmployee.y, debug.buttons.spawnEmployee.w, debug.buttons.spawnEmployee.h, "secondary", true, Drawing.isMouseOver(love.mouse.getX(), love.mouse.getY(), debug.buttons.spawnEmployee.x, debug.buttons.spawnEmployee.y, debug.buttons.spawnEmployee.w, debug.buttons.spawnEmployee.h))
    currentY = currentY + 50

    -- Spawn Upgrade (closed state only)
    love.graphics.print("Spawn Upgrade:", x + padding, currentY)
    currentY = currentY + 20
    debug.upgradeDropdown.rect = {x = x + padding, y = currentY, w = controlW, h = 25}
    Drawing.drawDropdown(debug.upgradeDropdown.rect, debug.upgradeDropdown)
    currentY = currentY + 35
    
    debug.buttons.spawnUpgrade = {x = x + padding, y = currentY, w = controlW, h = 30}
    Drawing.drawButton("Spawn Upgrade in Shop", debug.buttons.spawnUpgrade.x, debug.buttons.spawnUpgrade.y, debug.buttons.spawnUpgrade.w, debug.buttons.spawnUpgrade.h, "secondary", true, Drawing.isMouseOver(love.mouse.getX(), love.mouse.getY(), debug.buttons.spawnUpgrade.x, debug.buttons.spawnUpgrade.y, debug.buttons.spawnUpgrade.w, debug.buttons.spawnUpgrade.h))
    currentY = currentY + 50
    
    -- Cheats
    debug.buttons.addMoney = {x = x + padding, y = currentY, w = smallBtnW, h = 30}
    Drawing.drawButton("+ $1000", debug.buttons.addMoney.x, debug.buttons.addMoney.y, debug.buttons.addMoney.w, debug.buttons.addMoney.h, "primary", true, Drawing.isMouseOver(love.mouse.getX(), love.mouse.getY(), debug.buttons.addMoney.x, debug.buttons.addMoney.y, debug.buttons.addMoney.w, debug.buttons.addMoney.h))
    
    debug.buttons.removeMoney = {x = x + padding + smallBtnW + 10, y = currentY, w = smallBtnW, h = 30}
    Drawing.drawButton("- $1000", debug.buttons.removeMoney.x, debug.buttons.removeMoney.y, debug.buttons.removeMoney.w, debug.buttons.removeMoney.h, "primary", true, Drawing.isMouseOver(love.mouse.getX(), love.mouse.getY(), debug.buttons.removeMoney.x, debug.buttons.removeMoney.y, debug.buttons.removeMoney.w, debug.buttons.removeMoney.h))
    currentY = currentY + 35
    
    debug.buttons.restock = {x = x + padding, y = currentY, w = controlW, h = 30}
    Drawing.drawButton("Restock Shop", debug.buttons.restock.x, debug.buttons.restock.y, debug.buttons.restock.w, debug.buttons.restock.h, "warning", true, Drawing.isMouseOver(love.mouse.getX(), love.mouse.getY(), debug.buttons.restock.x, debug.buttons.restock.y, debug.buttons.restock.w, debug.buttons.restock.h))
    currentY = currentY + 35

    debug.buttons.prevItem = {x = x + padding, y = currentY, w = smallBtnW, h = 30}
    Drawing.drawButton("<< Prev Item", debug.buttons.prevItem.x, debug.buttons.prevItem.y, debug.buttons.prevItem.w, debug.buttons.prevItem.h, "info", true, Drawing.isMouseOver(love.mouse.getX(), love.mouse.getY(), debug.buttons.prevItem.x, debug.buttons.prevItem.y, debug.buttons.prevItem.w, debug.buttons.prevItem.h))
    
    debug.buttons.nextItem = {x = x + padding + smallBtnW + 10, y = currentY, w = smallBtnW, h = 30}
    Drawing.drawButton("Next Item >>", debug.buttons.nextItem.x, debug.buttons.nextItem.y, debug.buttons.nextItem.w, debug.buttons.nextItem.h, "info", true, Drawing.isMouseOver(love.mouse.getX(), love.mouse.getY(), debug.buttons.nextItem.x, debug.buttons.nextItem.y, debug.buttons.nextItem.w, debug.buttons.nextItem.h))

    -- SECOND PASS: Draw open dropdowns on top of everything else in the menu
    Drawing.drawOpenDropdownList(debug.employeeDropdown.rect, debug.employeeDropdown)
    Drawing.drawOpenDropdownList(debug.upgradeDropdown.rect, debug.upgradeDropdown)
end


function Drawing.drawSprintOverviewPanel(sprintOverviewRects, sprintOverviewVisible, gameState)
    if not sprintOverviewVisible then return end

    local screenW, screenH = love.graphics.getDimensions()
    local panelW, panelH = screenW * 0.7, screenH * 0.8
    local panelX, panelY = (screenW - panelW) / 2, (screenH - panelH) / 2

    Drawing.drawPanel(panelX, panelY, panelW, panelH, {0.15, 0.15, 0.2, 0.95}, {0.3, 0.3, 0.4, 1}, 8)
    love.graphics.setFont(Drawing.UI.titleFont)
    love.graphics.setColor(Drawing.UI.colors.text_light)
    love.graphics.printf("Sprint Overview", panelX, panelY + 15, panelW, "center")

    local currentY = panelY + 60
    local padding = 20

    for i, sprintData in ipairs(GameData.ALL_SPRINTS) do
        local sprintTitle = string.format("Sprint %d: %s", i, sprintData.sprintName)
        love.graphics.setFont(Drawing.UI.fontLarge)
        love.graphics.setColor(Drawing.UI.colors.button_info_bg)
        Drawing.drawTextWrapped(sprintTitle, panelX + padding, currentY, panelW - 2 * padding, Drawing.UI.fontLarge)
        currentY = currentY + Drawing.UI.fontLarge:getHeight() + 5

        love.graphics.setFont(Drawing.UI.font)
        love.graphics.setColor(Drawing.UI.colors.text_light)

        for j, workItem in ipairs(sprintData.workItems) do
            local itemText = string.format("  - Item %d: %s (Workload: %d, Reward: $%d)", j, workItem.name, workItem.workload, workItem.reward)
            Drawing.drawTextWrapped(itemText, panelX + padding, currentY, panelW - 2 * padding, Drawing.UI.font)
            currentY = currentY + Drawing.UI.font:getHeight()

            if workItem.modifier then
                local modifierText = "    Modifier: " .. workItem.modifier.description
                love.graphics.setColor(0.8, 0.4, 0.4, 1) -- Reddish for modifiers
                Drawing.drawTextWrapped(modifierText, panelX + padding, currentY, panelW - 2 * padding, Drawing.UI.fontSmall)
                love.graphics.setColor(Drawing.UI.colors.text_light) -- Reset color
                currentY = currentY + Drawing.UI.fontSmall:getHeight()
            end
        end
        currentY = currentY + 15 -- Spacing between sprints
    end

    -- Back button
    local btnW, btnH = 120, 40
    local btnX = panelX + (panelW - btnW) / 2
    local btnY = panelY + panelH - btnH - 15
    sprintOverviewRects.backButton = {x = btnX, y = btnY, w = btnW, h = btnH}
    Drawing.drawButton("Back", btnX, btnY, btnW, btnH, "primary", true, Drawing.isMouseOver(love.mouse.getX(), love.mouse.getY(), btnX, btnY, btnW, btnH))
end


return Drawing