-- components/modal.lua
-- A self-contained, reusable Modal component.

local Drawing = require("drawing")
local Button = require("components/button")

local Modal = {}
Modal.__index = Modal

function Modal:new()
    local instance = setmetatable({}, Modal)
    instance.isVisible = false
    instance.title = ""
    instance.message = ""
    instance.x = 0
    instance.y = 0
    instance.width = 0
    instance.height = 0
    instance.buttons = {}
    return instance
end

function Modal:update(dt)
    if self.isVisible and self.buttons then
        for _, buttonComponent in ipairs(self.buttons) do
            if buttonComponent.update then
                buttonComponent:update(dt)
            end
        end
    end
end

function Modal:show(title, message, buttons, customWidth)
    self.title = title or "Notification"
    self.message = message or ""
    self.isVisible = true

    local screenWidth, screenHeight = love.graphics.getDimensions()
    self.width = customWidth and math.min(customWidth, screenWidth - 40) or math.min(500, screenWidth - 40)
    
    local messageLines = {}
    for line in self.message:gmatch("[^\n]*") do table.insert(messageLines, line) end
    
    local titleFont = Drawing.UI.titleFont or Drawing.UI.font
    local messageFont = Drawing.UI.font
    
    local _, titleLineCount = self.title:gsub("\n", "\n")
    local titleHeight = titleFont:getHeight() * (titleLineCount + 1)
    local messageHeight = (#messageLines) * messageFont:getHeight()
    
    -- If no buttons provided, create a default "OK" button
    if not buttons or #buttons == 0 then
        buttons = {{text = "OK", onClick = function() self:hide() end}}
    end
    
    local hasButtons = buttons and #buttons > 0
    local buttonRowHeight = hasButtons and 60 or 20
    local padding = 80
    
    self.height = titleHeight + messageHeight + buttonRowHeight + padding
    self.height = math.min(self.height, screenHeight - 40)

    self.x = (screenWidth - self.width) / 2
    self.y = (screenHeight - self.height) / 2

    -- Convert button data into real Button components
    self.buttons = {}
    if hasButtons then
        local btnWidth = 100; local btnHeight = 30; local btnSpacing = 10
        local totalBtnWidth = (#buttons * btnWidth) + (math.max(0, #buttons - 1) * btnSpacing)
        local startX = self.x + (self.width - totalBtnWidth) / 2
        local btnY = self.y + self.height - btnHeight - 20

        for i, btnData in ipairs(buttons) do
            local btnRect = {
                x = startX + (i-1) * (btnWidth + btnSpacing),
                y = btnY,
                w = btnWidth,
                h = btnHeight
            }
            local newButton = Button:new({
                rect = btnRect,
                text = btnData.text,
                style = btnData.style or "primary",
                onClick = btnData.onClick or function() self:hide() end
            })
            table.insert(self.buttons, newButton)
        end
    end
end

function Modal:hide()
    self.isVisible = false
end

function Modal:handleMouseClick(mouseX, mouseY)
    if not self.isVisible then return false end
    
    if self.buttons then
        for _, btnComponent in ipairs(self.buttons) do
            if btnComponent:handleMousePress(mouseX, mouseY, 1) then
                return true
            end
        end
    end
    
    if Drawing.isMouseOver(mouseX, mouseY, self.x, self.y, self.width, self.height) then
        return true
    end

    return false 
end

-- Private helper to draw title
local function _drawModalTitle(modalState)
    local currentY = modalState.y + 20
    local titleLines = {}
    for line in modalState.title:gmatch("[^\n]*") do
        if line ~= "" then table.insert(titleLines, line) end
    end
    
    love.graphics.setColor(Drawing.UI.colors.text)
    
    if #titleLines >= 2 then
        local titleFont = Drawing.UI.titleFont or Drawing.UI.fontLarge or Drawing.UI.font
        love.graphics.setFont(titleFont)
        love.graphics.printf(titleLines[1], modalState.x, currentY, modalState.width, "center")
        currentY = currentY + titleFont:getHeight() + 5
        
        local subtitleFont = Drawing.UI.font
        love.graphics.setFont(subtitleFont)
        love.graphics.printf(titleLines[2], modalState.x, currentY, modalState.width, "center")
        currentY = currentY + subtitleFont:getHeight() + 15
    else
        local titleFont = Drawing.UI.titleFont or Drawing.UI.fontLarge or Drawing.UI.font
        love.graphics.setFont(titleFont)
        love.graphics.printf(modalState.title, modalState.x, currentY, modalState.width, "center")
        currentY = currentY + titleFont:getHeight() + 15
    end
    
    return currentY
end

-- Private helper to draw message
local function _drawModalMessage(modalState, currentY)
    local messageFont = Drawing.UI.font or love.graphics.getFont()
    love.graphics.setFont(messageFont)
    
    local messageLines = {}
    for line in modalState.message:gmatch("[^\n]*") do table.insert(messageLines, line) end
    
    local lineHeight = messageFont:getHeight()
    
    for _, line in ipairs(messageLines) do
        if line:match("|") then
            local leftPart, rightPart = line:match("^(.-)%|(.-)$")
            
            if leftPart and rightPart and line:match("^PROFIT:") then
                local colorMatch = leftPart:match("PROFIT:(%w+):")
                leftPart = leftPart:gsub("PROFIT:%w+:", "PROFIT:")
                
                if colorMatch == "GREEN" then love.graphics.setColor(0.1, 0.8, 0.1, 1)
                elseif colorMatch == "RED" then love.graphics.setColor(0.8, 0.1, 0.1, 1)
                else love.graphics.setColor(Drawing.UI.colors.text) end
                
                love.graphics.setFont(Drawing.UI.fontLarge)
                love.graphics.print(leftPart, modalState.x + 20, currentY)
                love.graphics.printf(rightPart, modalState.x + 20, currentY, modalState.width - 40, "right")
                love.graphics.setFont(messageFont)
                love.graphics.setColor(Drawing.UI.colors.text)
            elseif leftPart and rightPart then
                love.graphics.setColor(Drawing.UI.colors.text)
                love.graphics.print(leftPart, modalState.x + 20, currentY)
                love.graphics.printf(rightPart, modalState.x + 20, currentY, modalState.width - 40, "right")
            else
                love.graphics.setColor(Drawing.UI.colors.text)
                love.graphics.printf(line, modalState.x + 20, currentY, modalState.width - 40, "left")
            end
        else
            love.graphics.setColor(Drawing.UI.colors.text)
            love.graphics.printf(line, modalState.x + 20, currentY, modalState.width - 40, "left")
        end
        currentY = currentY + lineHeight
    end
end

-- Private helper to draw buttons
local function _drawModalButtons(modalState)
    if modalState.buttons then
        for _, btnComponent in ipairs(modalState.buttons) do
            btnComponent:draw()
        end
    end
end

function Modal:draw()
    if not self.isVisible then return end

    love.graphics.setColor(0,0,0,0.7)
    love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())
    Drawing.drawPanel(self.x, self.y, self.width, self.height, Drawing.UI.colors.card_bg, Drawing.UI.colors.header_border, 8)

    local contentY = _drawModalTitle(self)
    _drawModalMessage(self, contentY)
    _drawModalButtons(self)
end

return Modal