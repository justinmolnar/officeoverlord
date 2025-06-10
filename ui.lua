-- ui.lua
-- Helper functions for drawing UI elements.

local UI = {}

-- Default font (will be set in love.load in main.lua)
UI.font = nil
UI.fontSmall = nil
UI.fontLarge = nil
UI.titleFont = nil -- For larger titles

-- Default colors (can be themed if desired)
UI.colors = {
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

-- Function to draw text with wrapping capabilities
-- ADDED: new parameter 'drawEnabled' to optionally disable drawing for height calculation
function UI.drawTextWrapped(text, x, y, wrapLimit, font, align, maxLines, drawEnabled)
    local shouldDraw = (drawEnabled == nil) and true or drawEnabled -- Default to true
    local currentFont = font or UI.font
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
function UI.drawButton(text, x, y, width, height, style, isEnabled, isHovered, buttonFont)
    local baseBgColor, hoverBgColor, currentTextColor
    local currentStyle = style or "primary"
    local fontToUse = buttonFont or UI.font

    if currentStyle == "primary" then
        baseBgColor = UI.colors.button_primary_bg; hoverBgColor = UI.colors.button_primary_hover_bg;
    elseif currentStyle == "secondary" then
        baseBgColor = UI.colors.button_secondary_bg; hoverBgColor = UI.colors.button_secondary_hover_bg;
    elseif currentStyle == "warning" then
        baseBgColor = UI.colors.button_warning_bg; hoverBgColor = UI.colors.button_warning_hover_bg;
    elseif currentStyle == "danger" then
        baseBgColor = UI.colors.button_danger_bg; hoverBgColor = UI.colors.button_danger_hover_bg;
    elseif currentStyle == "info" then
         baseBgColor = UI.colors.button_info_bg; hoverBgColor = UI.colors.button_info_hover_bg;
    else 
        baseBgColor = UI.colors.button_primary_bg; hoverBgColor = UI.colors.button_primary_hover_bg;
    end

    local bgColor = isEnabled and (isHovered and hoverBgColor or baseBgColor) or UI.colors.button_disabled_bg
    currentTextColor = isEnabled and UI.colors.button_text or UI.colors.button_disabled_text
    
    love.graphics.setColor(bgColor)
    love.graphics.rectangle("fill", x, y, width, height, 5, 5) 

    love.graphics.setColor(currentTextColor)
    if fontToUse then love.graphics.setFont(fontToUse) end 
    local textHeight = fontToUse and fontToUse:getHeight() or 0
    love.graphics.printf(text, math.floor(x), math.floor(y + (height - textHeight) / 2), math.floor(width), "center")
end

-- Function to check if mouse is over a rectangular area
function UI.isMouseOver(mouseX, mouseY, x, y, width, height)
    if not x or not y or not width or not height then return false end 
    return mouseX >= x and mouseX <= x + width and mouseY >= y and mouseY <= y + height
end

-- Function to draw a simple panel or box
function UI.drawPanel(x, y, width, height, bgColor, borderColor, cornerRadius)
    local bg = bgColor or UI.colors.card_bg 
    local border = borderColor or UI.colors.card_border
    local cr = cornerRadius or 5

    love.graphics.setColor(bg)
    love.graphics.rectangle("fill", x, y, width, height, cr, cr)
    love.graphics.setColor(border)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", x, y, width, height, cr, cr)
end

-- NEW: Function to draw a checkbox
function UI.drawCheckbox(rect, label, isChecked)
    local x, y, w, h = rect.x, rect.y, rect.w, rect.h
    local boxSize = h - 2
    
    -- Draw box
    love.graphics.setColor(UI.colors.text_light)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", x, y + 1, boxSize, boxSize, 3, 3)

    -- Draw checkmark if checked
    if isChecked then
        love.graphics.setLineWidth(2)
        love.graphics.line(x + 3, y + h/2, x + boxSize/2, y + h - 4)
        love.graphics.line(x + boxSize/2, y + h - 4, x + boxSize - 2, y + 4)
    end
    
    -- Draw label
    love.graphics.setFont(UI.font)
    love.graphics.print(label, x + boxSize + 5, y + (h - UI.font:getHeight()) / 2)
end

function UI.drawDropdown(rect, dropdownState)
    local x, y, w, h = rect.x, rect.y, rect.w, rect.h
    local mouseX, mouseY = love.mouse.getPosition()
    
    -- Draw main box
    local bgColor = {0.3, 0.3, 0.3, 1}
    if UI.isMouseOver(mouseX, mouseY, x, y, w, h) then
        bgColor = {0.4, 0.4, 0.4, 1}
    end
    UI.drawPanel(x, y, w, h, bgColor, {0.6, 0.6, 0.6, 1}, 3)

    -- Draw selected text
    love.graphics.setColor(UI.colors.text_light)
    love.graphics.setFont(UI.font)
    local selectedName = (dropdownState.options[dropdownState.selected] and dropdownState.options[dropdownState.selected].name) or "None"
    love.graphics.printf(selectedName, x + 5, y + (h - UI.font:getHeight())/2, w - 20, "left")

    -- Draw arrow
    local arrowX, arrowY = x + w - 15, y + h/2
    love.graphics.polygon("fill", arrowX, arrowY - 2, arrowX + 8, arrowY - 2, arrowX + 4, arrowY + 4)
end

function UI.drawOpenDropdownList(rect, dropdownState)
    if not dropdownState.isOpen then return end

    local x, y, w, h = rect.x, rect.y, rect.w, rect.h
    local mouseX, mouseY = love.mouse.getPosition()
    
    local optionHeight = 20
    local listVisibleHeight = math.min(#dropdownState.options * optionHeight, 200)
    local listY = y + h
    
    -- Draw the background for the list
    UI.drawPanel(x, listY, w, listVisibleHeight, {0.1, 0.1, 0.1, 1}, {0.6, 0.6, 0.6, 1})

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
        local isMouseOverOption = UI.isMouseOver(mouseX, mouseY + dropdownState.scrollOffset, x, optY, w, optionHeight)
                                and UI.isMouseOver(mouseX, mouseY, x, listY, w, listVisibleHeight)

        if isMouseOverOption then
            love.graphics.setColor(0.5, 0.5, 0.5, 1)
            love.graphics.rectangle("fill", x, optY, w - 10, optionHeight)
        end

        love.graphics.setColor(UI.colors.text_light)
        love.graphics.setFont(UI.font)
        love.graphics.print(option.name, x + 5, optY + 3)
    end
    love.graphics.pop()
    love.graphics.setScissor()
end


-- Modal state and drawing functions
UI.modal = {
    isVisible = false,
    title = "",
    message = "",
    x = 0, y = 0, width = 0, height = 0,
    buttons = {} 
}

function UI.showModal(title, message, buttons, customWidth)
    UI.modal.title = title or "Notification"
    UI.modal.message = message or ""
    UI.modal.buttons = buttons or { {text = "OK", onClick = function() UI.hideModal() end, style = "primary"} } 
    UI.modal.isVisible = true
    
    -- Basic modal sizing and positioning
    local screenWidth, screenHeight = love.graphics.getDimensions()
    
    -- Use custom width if provided, otherwise use default logic
    if customWidth then
        UI.modal.width = math.min(customWidth, screenWidth - 40)
    else
        UI.modal.width = math.min(500, screenWidth - 40)
    end
    
    -- Count message lines for better height calculation
    local messageLines = {}
    for line in UI.modal.message:gmatch("[^\n]*") do
        table.insert(messageLines, line)
    end
    
    -- Calculate height based on actual content
    local titleFont = UI.titleFont or UI.fontLarge or UI.font
    local messageFont = UI.font or love.graphics.getFont()
    
    local titleHeight = titleFont:getHeight()
    local messageHeight = (#messageLines) * messageFont:getHeight()
    local buttonHeight = (#UI.modal.buttons > 0) and 60 or 20
    local padding = 80 -- Extra padding for spacing
    
    UI.modal.height = titleHeight + messageHeight + buttonHeight + padding
    UI.modal.height = math.min(UI.modal.height, screenHeight - 40)

    UI.modal.x = (screenWidth - UI.modal.width) / 2
    UI.modal.y = (screenHeight - UI.modal.height) / 2

    -- Position buttons within the modal
    if UI.modal.buttons and #UI.modal.buttons > 0 then
        local btnWidth = 100
        local btnHeight = 30
        local btnSpacing = 10
        local totalBtnWidth = (#UI.modal.buttons * btnWidth) + (math.max(0, #UI.modal.buttons - 1) * btnSpacing)
        local startX = UI.modal.x + (UI.modal.width - totalBtnWidth) / 2
        local btnY = UI.modal.y + UI.modal.height - btnHeight - 15

        for i, btnData in ipairs(UI.modal.buttons) do
            btnData.x = startX + (i-1) * (btnWidth + btnSpacing)
            btnData.y = btnY
            btnData.w = btnWidth
            btnData.h = btnHeight
        end
    end
end

-- Update the global showMessage function to accept width parameter
_G.showMessage = function(title, message, buttons, customWidth)
    UI.showModal(title, message, buttons, customWidth)
end

function UI.hideModal()
    UI.modal.isVisible = false
end

function UI.drawModal()
    if not UI.modal.isVisible then return end

    -- Full screen overlay
    love.graphics.setColor(0,0,0,0.7)
    love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())

    -- Modal Panel
    UI.drawPanel(UI.modal.x, UI.modal.y, UI.modal.width, UI.modal.height, UI.colors.card_bg, UI.colors.header_border, 8)

    local currentY = UI.modal.y + 20
    
    -- Handle title (may be two lines)
    local titleLines = {}
    for line in UI.modal.title:gmatch("[^\n]*") do
        if line ~= "" then
            table.insert(titleLines, line)
        end
    end
    
    if #titleLines >= 2 then
        -- First line (WORK ITEM COMPLETE!) in large font
        local titleFont = UI.titleFont or UI.fontLarge or UI.font
        love.graphics.setFont(titleFont)
        love.graphics.setColor(UI.colors.text)
        love.graphics.printf(titleLines[1], UI.modal.x, currentY, UI.modal.width, "center")
        currentY = currentY + titleFont:getHeight() + 5
        
        -- Second line (work item name) in smaller font
        local subtitleFont = UI.font
        love.graphics.setFont(subtitleFont)
        love.graphics.printf(titleLines[2], UI.modal.x, currentY, UI.modal.width, "center")
        currentY = currentY + subtitleFont:getHeight() + 15
    else
        -- Single line title
        local titleFont = UI.titleFont or UI.fontLarge or UI.font
        love.graphics.setFont(titleFont)
        love.graphics.setColor(UI.colors.text)
        love.graphics.printf(UI.modal.title, UI.modal.x, currentY, UI.modal.width, "center")
        currentY = currentY + titleFont:getHeight() + 15
    end

    -- Handle message content
    local messageFont = UI.font or love.graphics.getFont()
    love.graphics.setFont(messageFont)
    
    local messageLines = {}
    for line in UI.modal.message:gmatch("[^\n]*") do
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
                        love.graphics.setColor(UI.colors.text)
                    end
                    love.graphics.setFont(UI.fontLarge) -- Make profit line larger
                    love.graphics.print(leftPart, UI.modal.x + 20, currentY)
                    love.graphics.printf(rightPart, UI.modal.x + 20, currentY, UI.modal.width - 40, "right")
                    love.graphics.setFont(messageFont) -- Reset font
                else
                    love.graphics.setColor(UI.colors.text)
                    love.graphics.print(leftPart, UI.modal.x + 20, currentY)
                    love.graphics.printf(rightPart, UI.modal.x + 20, currentY, UI.modal.width - 40, "right")
                end
            else
                love.graphics.setColor(UI.colors.text)
                love.graphics.printf(line, UI.modal.x + 20, currentY, UI.modal.width - 40, "left")
            end
        else
            love.graphics.setColor(UI.colors.text)
            love.graphics.printf(line, UI.modal.x + 20, currentY, UI.modal.width - 40, "left")
        end
        currentY = currentY + lineHeight
    end
    
    if UI.modal.buttons then
        for i, btnData in ipairs(UI.modal.buttons) do
            local mouseX, mouseY = love.mouse.getPosition()
            UI.drawButton(btnData.text, btnData.x, btnData.y, btnData.w, btnData.h, btnData.style or "primary", true, UI.isMouseOver(mouseX, mouseY, btnData.x, btnData.y, btnData.w, btnData.h))
        end
    end
end

function UI.handleModalClick(mouseX, mouseY)
    if not UI.modal.isVisible then return false end
    if UI.modal.buttons then
        for _, btnData in ipairs(UI.modal.buttons) do
            if UI.isMouseOver(mouseX, mouseY, btnData.x, btnData.y, btnData.w, btnData.h) then
                if btnData.onClick then btnData.onClick() end
                return true -- Click was handled by a modal button
            end
        end
    end
    -- If click was inside modal panel but not on a button, consider it handled (prevents underlying UI clicks)
    if UI.isMouseOver(mouseX, mouseY, UI.modal.x, UI.modal.y, UI.modal.width, UI.modal.height) then
        return true
    end
    return false 
end

return UI