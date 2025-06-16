-- debug_manager.lua
-- A self-contained module to manage all logic and UI for the debug menu.

local GameData = require("data")
local Shop = require("shop")
local Drawing = require("drawing")
local Button = require("components/button")
local Checkbox = require("components/checkbox")
local Dropdown = require("components/dropdown")

local DebugManager = {}

DebugManager._isVisible = false
DebugManager._state = {
    rect = {},
    employeeDropdown = { options = {}, selected = 1, isOpen = false, rect = {}, scrollOffset = 0 },
    upgradeDropdown = { options = {}, selected = 1, isOpen = false, rect = {}, scrollOffset = 0 },
    decorationDropdown = { options = {}, selected = 1, isOpen = false, rect = {}, scrollOffset = 0 },
    checkboxes = {
        remote = { checked = false, rect = {} },
        laminated = { checked = false, rect = {} },
        embossed = { checked = false, rect = {} }
    },
    hotkeyState = {
        plus = { timer = 0, initial = 0.4, repeatDelay = 0.1 },
        minus = { timer = 0, initial = 0.4, repeatDelay = 0.1 }
    }
}
DebugManager._components = {}
DebugManager._services = {}

local function _drawPanelAndTitle(self)
    local screenW, screenH = love.graphics.getDimensions()
    local w, h = 400, 550 -- Increased height for new dropdown
    local x, y = (screenW - w) / 2, (screenH - h) / 2
    self._state.rect = {x=x, y=y, w=w, h=h}
    Drawing.drawPanel(x, y, w, h, {0.2, 0.2, 0.2, 0.95}, {0.5, 0.5, 0.5, 1}, 8)
    love.graphics.setFont(Drawing.UI.titleFont)
    love.graphics.setColor(Drawing.UI.colors.text_light)
    love.graphics.printf("Debug Menu", x, y + 10, w, "center")
    return self._state.rect
end

function DebugManager:init(services)
   self._services = services
   -- Populate Employee Dropdown
   self._state.employeeDropdown.options = {}
   for _, card in ipairs(GameData.BASE_EMPLOYEE_CARDS) do
       table.insert(self._state.employeeDropdown.options, { name = card.name, id = card.id })
   end
   table.sort(self._state.employeeDropdown.options, function(a, b) return a.name < b.name end)
   
   -- Populate Upgrade Dropdown
   self._state.upgradeDropdown.options = {}
   for _, upg in ipairs(GameData.ALL_UPGRADES) do
       table.insert(self._state.upgradeDropdown.options, { name = upg.name, id = upg.id })
   end
   table.sort(self._state.upgradeDropdown.options, function(a, b) return a.name < b.name end)

   -- Populate Decoration Dropdown
   self._state.decorationDropdown.options = {}
   for _, deco in ipairs(GameData.ALL_DESK_DECORATIONS) do
       table.insert(self._state.decorationDropdown.options, { name = deco.name, id = deco.id })
   end
   table.sort(self._state.decorationDropdown.options, function(a, b) return a.name < b.name end)

   -- NEW: Populate Modifier Dropdown
   self._state.modifierDropdown = { options = {}, selected = 1, isOpen = false, rect = {}, scrollOffset = 0 }
   for _, modifier in ipairs(GameData.ALL_MODIFIERS) do
       table.insert(self._state.modifierDropdown.options, { name = modifier.name, id = modifier.id, rarity = modifier.rarity })
   end
   table.sort(self._state.modifierDropdown.options, function(a, b) return a.name < b.name end)

   self._components = {}
   local panelW, panelH = 400, 650 -- Increased height for new dropdown
   local panelX, panelY = (love.graphics.getWidth() - panelW) / 2, (love.graphics.getHeight() - panelH) / 2
   local padding = 15
   local dbgW = panelW - padding * 2
   local dbgX = panelX + padding
   local currentY = panelY + 50

   -- Employee Spawner
   table.insert(self._components, Dropdown:new({ rect = {x = dbgX, y = currentY, w = dbgW, h = 25}, state = self._state.employeeDropdown }))
   currentY = currentY + 35
   local chkW = 80
   table.insert(self._components, Checkbox:new({ rect = {x=dbgX, y=currentY, w=chkW, h=20}, label="Remote", state=self._state.checkboxes.remote, onToggle=function(c) if c then self._state.checkboxes.laminated.checked=false; self._state.checkboxes.embossed.checked=false end end }))
   table.insert(self._components, Checkbox:new({ rect = {x=dbgX + chkW + 10, y=currentY, w=chkW, h=20}, label="Laminated", state=self._state.checkboxes.laminated, onToggle=function(c) if c then self._state.checkboxes.remote.checked=false; self._state.checkboxes.embossed.checked=false end end }))
   table.insert(self._components, Checkbox:new({ rect = {x=dbgX + (chkW + 10) * 2, y=currentY, w=chkW, h=20}, label="Embossed", state=self._state.checkboxes.embossed, onToggle=function(c) if c then self._state.checkboxes.remote.checked=false; self._state.checkboxes.laminated.checked=false end end }))
   currentY = currentY + 30
   table.insert(self._components, Button:new({ rect = {x=dbgX, y=currentY, w=dbgW, h=30}, text="Spawn Employee in Shop", style="secondary", onClick=function() local sel=self._state.employeeDropdown.options[self._state.employeeDropdown.selected].id; local v="standard"; if self._state.checkboxes.remote.checked then v="remote" elseif self._state.checkboxes.laminated.checked then v="laminated" elseif self._state.checkboxes.embossed.checked then v="embossed" end; self._services.shop:forceAddItemOffer('employee', sel, self._services.gameState.currentShopOffers, v); _G.buildUIComponents() end }))
   currentY = currentY + 50

   -- Upgrade Spawner
   table.insert(self._components, Dropdown:new({ rect = {x = dbgX, y = currentY, w = dbgW, h = 25}, state = self._state.upgradeDropdown }))
   currentY = currentY + 35
   table.insert(self._components, Button:new({ rect = {x=dbgX, y=currentY, w=dbgW, h=30}, text="Spawn Upgrade in Shop", style="secondary", onClick=function() local sel=self._state.upgradeDropdown.options[self._state.upgradeDropdown.selected].id; self._services.shop:forceAddItemOffer('upgrade', sel, self._services.gameState.currentShopOffers); _G.buildUIComponents() end }))
   currentY = currentY + 50
   
   -- Decoration Spawner
   table.insert(self._components, Dropdown:new({ rect = {x = dbgX, y = currentY, w = dbgW, h = 25}, state = self._state.decorationDropdown }))
   currentY = currentY + 35
   table.insert(self._components, Button:new({ rect = {x=dbgX, y=currentY, w=dbgW, h=30}, text="Spawn Decoration in Shop", style="secondary", onClick=function() local sel=self._state.decorationDropdown.options[self._state.decorationDropdown.selected].id; self._services.shop:forceAddItemOffer('decoration', sel, self._services.gameState.currentShopOffers); _G.buildUIComponents() end }))
   currentY = currentY + 50

   -- NEW: Modifier Spawner
   table.insert(self._components, Dropdown:new({ rect = {x = dbgX, y = currentY, w = dbgW, h = 25}, state = self._state.modifierDropdown }))
   currentY = currentY + 35
   table.insert(self._components, Button:new({ rect = {x=dbgX, y=currentY, w=dbgW, h=30}, text="Apply Modifier to Current Work Item", style="warning", onClick=function() 
       local sel = self._state.modifierDropdown.options[self._state.modifierDropdown.selected]
       if sel then
           local ModifierManager = require("modifier_manager")
           local workItem = ModifierManager:getWorkItemWithModifier(self._services.gameState, self._services.gameState.currentSprintIndex, self._services.gameState.currentWorkItemIndex)
           if workItem then
               -- Find the full modifier data
               local fullModifier = nil
               for _, modifier in ipairs(GameData.ALL_MODIFIERS) do
                   if modifier.id == sel.id then
                       fullModifier = modifier
                       break
                   end
               end
               
               if fullModifier then
                   -- Create a copy of the modifier
                   local modifierInstance = {}
                   for k, v in pairs(fullModifier) do
                       if type(v) == "table" then
                           modifierInstance[k] = {}
                           for nk, nv in pairs(v) do
                               if type(nv) == "table" then
                                   modifierInstance[k][nk] = {}
                                   for nnk, nnv in pairs(nv) do
                                       modifierInstance[k][nk][nnk] = nnv
                                   end
                               else
                                   modifierInstance[k][nk] = nv
                               end
                           end
                       else
                           modifierInstance[k] = v
                       end
                   end
                   
                   -- Apply the modifier to the current work item
                   workItem.modifier = modifierInstance
                   print("DEBUG: Applied modifier '" .. fullModifier.name .. "' (" .. fullModifier.rarity .. ") to current work item")
                   _G.buildUIComponents()
               else
                   print("DEBUG ERROR: Could not find modifier data for " .. sel.id)
               end
           else
               print("DEBUG ERROR: Could not find current work item")
           end
       end
   end }))
   currentY = currentY + 50

   -- General Buttons
   local smallBtnW = (dbgW - 10) / 2
   table.insert(self._components, Button:new({ rect = {x=dbgX, y=currentY, w=smallBtnW, h=30}, text="+ $1000", style="primary", onClick=function() self._services.gameState.budget=self._services.gameState.budget+1000 end }))
   table.insert(self._components, Button:new({ rect = {x=dbgX + smallBtnW + 10, y=currentY, w=smallBtnW, h=30}, text="- $1000", style="primary", onClick=function() self._services.gameState.budget=self._services.gameState.budget-1000 end }))
   currentY = currentY + 35
   table.insert(self._components, Button:new({ rect = {x=dbgX, y=currentY, w=dbgW, h=30}, text="Restock Shop", style="warning", onClick=function() local success, msg = self._services.shop:attemptRestock(self._services.gameState); if not success then self._services.modal:show("Restock Failed", msg) end end }))
   currentY = currentY + 35
   table.insert(self._components, Button:new({ rect = {x=dbgX, y=currentY, w=smallBtnW, h=30}, text="<< Prev Item", style="info", onClick=function() self._services.gameState.currentWorkItemIndex=self._services.gameState.currentWorkItemIndex-1; if self._services.gameState.currentWorkItemIndex<1 then self._services.gameState.currentSprintIndex=math.max(1,self._services.gameState.currentSprintIndex-1); self._services.gameState.currentWorkItemIndex=3 end; self._services.setGamePhase("hiring_and_upgrades") end }))
   table.insert(self._components, Button:new({ rect = {x=dbgX+smallBtnW+10, y=currentY, w=smallBtnW, h=30}, text="Next Item >>", style="info", onClick=function() self._services.gameState.currentWorkItemIndex=self._services.gameState.currentWorkItemIndex+1; if self._services.gameState.currentWorkItemIndex>3 then self._services.gameState.currentWorkItemIndex=1; self._services.gameState.currentSprintIndex=math.min(#GameData.ALL_SPRINTS,self._services.gameState.currentSprintIndex+1) end; self._services.setGamePhase("hiring_and_upgrades") end }))
   
   print("DebugManager Initialized with modifier support.")
end

function DebugManager:toggleVisibility()
    self._isVisible = not self._isVisible
    if not self._isVisible then
        self._state.employeeDropdown.isOpen = false
        self._state.upgradeDropdown.isOpen = false
        self._state.decorationDropdown.isOpen = false
    end
end

function DebugManager:isVisible()
    return self._isVisible
end

function DebugManager:update(dt)
    if not self:isVisible() then return end

    -- Update components
    for _, component in ipairs(self._components) do
        if component.update then
            component:update(dt)
        end
    end

    -- Update hotkey holds
    local plusState = self._state.hotkeyState.plus
    if love.keyboard.isDown("=", "kp+") then
        plusState.timer = plusState.timer - dt
        if plusState.timer <= 0 then
            self._services.gameState.budget = self._services.gameState.budget + 1000
            plusState.timer = plusState.repeatDelay
        end
    end

    local minusState = self._state.hotkeyState.minus
    if love.keyboard.isDown("-", "kp-") then
        minusState.timer = minusState.timer - dt
        if minusState.timer <= 0 then
            self._services.gameState.budget = self._services.gameState.budget - 1000
            minusState.timer = minusState.repeatDelay
        end
    end
end

function DebugManager:draw()
    if not self:isVisible() then return end
    
    _drawPanelAndTitle(self)
    for _, component in ipairs(self._components) do
        if component.draw then component:draw() end
    end
    for _, component in ipairs(self._components) do
        if component.drawOpenList then component:drawOpenList() end
    end
end

function DebugManager:handleKeyPress(key)
    if key == "`" then
        self:toggleVisibility()
        return true
    end

    if not self:isVisible() then return false end

    -- Page up/down for dropdown navigation (like pageup/pagedown)
    if key == "up" or key == "pageup" or key == "down" or key == "pagedown" then
        for _, dropdownState in ipairs({self._state.employeeDropdown, self._state.upgradeDropdown, self._state.decorationDropdown, self._state.modifierDropdown}) do
            if dropdownState.isOpen then
                local optionHeight = 20
                local listVisibleHeight = math.min(#dropdownState.options * optionHeight, 200)
                
                if key == "up" or key == "pageup" then
                    dropdownState.scrollOffset = math.max(0, dropdownState.scrollOffset - listVisibleHeight)
                else -- down or pagedown
                    local maxScroll = math.max(0, (#dropdownState.options * optionHeight) - listVisibleHeight)
                    dropdownState.scrollOffset = math.min(maxScroll, dropdownState.scrollOffset + listVisibleHeight)
                end
                return true -- Input handled
            end
        end
    end

    -- Budget hotkeys
    if key == "=" or key == "kp+" then
        self._services.gameState.budget = self._services.gameState.budget + 1000
        self._state.hotkeyState.plus.timer = self._state.hotkeyState.plus.initial
        return true
    elseif key == "-" or key == "kp-" then
        self._services.gameState.budget = self._services.gameState.budget - 1000
        self._state.hotkeyState.minus.timer = self._state.hotkeyState.minus.initial
        return true
    end

    -- Employee cycling hotkey
    if key == "i" then
        local dropdown = self._state.employeeDropdown
        dropdown.selected = (dropdown.selected % #dropdown.options) + 1
        local nextEmployee = dropdown.options[dropdown.selected]
        if nextEmployee then
            local variant = "standard"
            if self._state.checkboxes.remote.checked then variant = "remote"
            elseif self._state.checkboxes.laminated.checked then variant = "laminated"
            elseif self._state.checkboxes.embossed.checked then variant = "embossed" end
            self._services.shop:forceAddItemOffer('employee', nextEmployee.id, self._services.gameState.currentShopOffers, variant)
            print("DEBUG: Spawned employee #" .. dropdown.selected .. ": " .. nextEmployee.name .. " (" .. variant .. ")")
            _G.buildUIComponents()
        end
        return true
    end

    -- Upgrade cycling hotkey
    if key == "u" then
        local dropdown = self._state.upgradeDropdown
        dropdown.selected = (dropdown.selected % #dropdown.options) + 1
        local nextUpgrade = dropdown.options[dropdown.selected]
        if nextUpgrade then
            self._services.shop:forceAddItemOffer('upgrade', nextUpgrade.id, self._services.gameState.currentShopOffers)
            print("DEBUG: Spawned upgrade #" .. dropdown.selected .. ": " .. nextUpgrade.name)
            _G.buildUIComponents()
        end
        return true
    end

    -- Decoration cycling hotkey
    if key == "d" then
        if not self._state.decorationDropdown then
            -- Initialize decoration dropdown if it doesn't exist
            self._state.decorationDropdown = { options = {}, selected = 1, isOpen = false, rect = {}, scrollOffset = 0 }
            for _, deco in ipairs(GameData.ALL_DESK_DECORATIONS) do
                table.insert(self._state.decorationDropdown.options, { name = deco.name, id = deco.id })
            end
            table.sort(self._state.decorationDropdown.options, function(a, b) return a.name < b.name end)
        end
        
        local dropdown = self._state.decorationDropdown
        dropdown.selected = (dropdown.selected % #dropdown.options) + 1
        local nextDecoration = dropdown.options[dropdown.selected]
        if nextDecoration then
            self._services.shop:forceAddItemOffer('decoration', nextDecoration.id, self._services.gameState.currentShopOffers)
            print("DEBUG: Spawned decoration #" .. dropdown.selected .. ": " .. nextDecoration.name)
            _G.buildUIComponents()
        end
        return true
    end

    -- Shop restock hotkey
    if key == "r" then
        local success, msg = self._services.shop:attemptRestock(self._services.gameState)
        if not success then
            print("DEBUG: Restock failed - " .. msg)
        else
            print("DEBUG: Shop restocked")
        end
        return true
    end

    -- Work item navigation hotkeys
    if key == "," then -- Previous work item
        self._services.gameState.currentWorkItemIndex = self._services.gameState.currentWorkItemIndex - 1
        if self._services.gameState.currentWorkItemIndex < 1 then
            self._services.gameState.currentSprintIndex = math.max(1, self._services.gameState.currentSprintIndex - 1)
            self._services.gameState.currentWorkItemIndex = 3
        end
        self._services.setGamePhase("hiring_and_upgrades")
        print("DEBUG: Previous work item - Sprint " .. self._services.gameState.currentSprintIndex .. ", Item " .. self._services.gameState.currentWorkItemIndex)
        return true
    elseif key == "." then -- Next work item
        self._services.gameState.currentWorkItemIndex = self._services.gameState.currentWorkItemIndex + 1
        if self._services.gameState.currentWorkItemIndex > 3 then
            self._services.gameState.currentWorkItemIndex = 1
            self._services.gameState.currentSprintIndex = math.min(#GameData.ALL_SPRINTS, self._services.gameState.currentSprintIndex + 1)
        end
        self._services.setGamePhase("hiring_and_upgrades")
        print("DEBUG: Next work item - Sprint " .. self._services.gameState.currentSprintIndex .. ", Item " .. self._services.gameState.currentWorkItemIndex)
        return true
    end

    -- Variant toggle hotkeys
    if key == "1" then
        self._state.checkboxes.remote.checked = false
        self._state.checkboxes.laminated.checked = false
        self._state.checkboxes.embossed.checked = false
        print("DEBUG: Variant set to Standard")
        return true
    elseif key == "2" then
        self._state.checkboxes.remote.checked = true
        self._state.checkboxes.laminated.checked = false
        self._state.checkboxes.embossed.checked = false
        print("DEBUG: Variant set to Remote")
        return true
    elseif key == "3" then
        self._state.checkboxes.remote.checked = false
        self._state.checkboxes.laminated.checked = true
        self._state.checkboxes.embossed.checked = false
        print("DEBUG: Variant set to Laminated")
        return true
    elseif key == "4" then
        self._state.checkboxes.remote.checked = false
        self._state.checkboxes.laminated.checked = false
        self._state.checkboxes.embossed.checked = true
        print("DEBUG: Variant set to Embossed")
        return true
    end

    -- Modifier cycling hotkey
if key == "m" then
    local dropdown = self._state.modifierDropdown
    dropdown.selected = (dropdown.selected % #dropdown.options) + 1
    local nextModifier = dropdown.options[dropdown.selected]
    if nextModifier then
        local ModifierManager = require("modifier_manager")
        local workItem = ModifierManager:getWorkItemWithModifier(self._services.gameState, self._services.gameState.currentSprintIndex, self._services.gameState.currentWorkItemIndex)
        if workItem then
            -- Find the full modifier data
            local fullModifier = nil
            for _, modifier in ipairs(GameData.ALL_MODIFIERS) do
                if modifier.id == nextModifier.id then
                    fullModifier = modifier
                    break
                end
            end
            
            if fullModifier then
                -- Create a copy of the modifier
                local modifierInstance = {}
                for k, v in pairs(fullModifier) do
                    if type(v) == "table" then
                        modifierInstance[k] = {}
                        for nk, nv in pairs(v) do
                            if type(nv) == "table" then
                                modifierInstance[k][nk] = {}
                                for nnk, nnv in pairs(nv) do
                                    modifierInstance[k][nk][nnk] = nnv
                                end
                            else
                                modifierInstance[k][nk] = nv
                            end
                        end
                    else
                        modifierInstance[k] = v
                    end
                end
                
                -- Apply the modifier to the current work item
                workItem.modifier = modifierInstance
                print("DEBUG: Applied modifier #" .. dropdown.selected .. ": " .. fullModifier.name .. " (" .. fullModifier.rarity .. ")")
                _G.buildUIComponents()
            end
        end
    end
    return true
end

    return false
end

function DebugManager:handleMousePress(x, y, button)
    if not self:isVisible() then return false end

    -- Give open dropdowns priority
    for _, component in ipairs(self._components) do
        if component.state and component.state.isOpen and component:handleMousePress(x, y, button) then
            return true
        end
    end
    -- Handle other components
    for _, component in ipairs(self._components) do
        if component.handleMousePress and component:handleMousePress(x, y, button) then
            return true
        end
    end
    -- If click is inside the panel, consume it so it doesn't click through
    if Drawing.isMouseOver(x, y, self._state.rect.x, self._state.rect.y, self._state.rect.w, self._state.rect.h) then
        return true
    end
    return false
end

function DebugManager:handleMouseWheel(y)
    if not self:isVisible() then return false end
    
    for _, component in ipairs(self._components) do
        if component.handleMouseWheel and component:handleMouseWheel(y) then
            return true
        end
    end
    return false
end

return DebugManager