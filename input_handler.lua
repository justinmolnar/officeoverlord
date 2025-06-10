-- input_handler.lua
-- Manages all user input, delegating actions to the appropriate game modules.

local Drawing = require("drawing")
local Shop = require("shop")
local Placement = require("placement")
local Battle = require("battle")
local GameData = require("data")
local Employee = require("employee")
local EffectsDispatcher = require("effects_dispatcher")

local InputHandler = {}

-- Store references to game state and callbacks to avoid passing them constantly
InputHandler.gameState = nil
InputHandler.uiElementRects = nil
InputHandler.draggedItemState = nil
InputHandler.battleState = nil
InputHandler.panelRects = nil
InputHandler.sprintOverviewState = nil
InputHandler.sprintOverviewRects = nil
InputHandler.debugMenuState = nil
InputHandler.debug = nil
InputHandler.callbacks = {}


local function executeAddMoney(handler)
    handler.gameState.budget = handler.gameState.budget + 1000
    print("DEBUG: Added $1000. New budget: " .. handler.gameState.budget)
end

local function executeRemoveMoney(handler)
    handler.gameState.budget = handler.gameState.budget - 1000
    print("DEBUG: Removed $1000. New budget: " .. handler.gameState.budget)
end

function InputHandler.update(dt)
    -- Key-hold logic for adding money
    local plusState = InputHandler.debug.hotkeyState.plus
    if love.keyboard.isDown("=", "kp+") then
        plusState.timer = plusState.timer - dt
        if plusState.timer <= 0 then
            executeAddMoney(InputHandler)
            plusState.timer = plusState.repeatDelay
        end
    end

    -- Key-hold logic for removing money
    local minusState = InputHandler.debug.hotkeyState.minus
    if love.keyboard.isDown("-", "kp-") then
        minusState.timer = minusState.timer - dt
        if minusState.timer <= 0 then
            executeRemoveMoney(InputHandler)
            minusState.timer = minusState.repeatDelay
        end
    end
end

-- Helper function to calculate insertion index from ghost zone position
local function calculateRemoteInsertionIndexFromGhost(x, y)
    if not InputHandler.uiElementRects.remoteGhostZone then return 1 end
    
    local rect = InputHandler.panelRects.remoteWorkers
    local cardWidth = 140
    
    local remoteWorkers = {}
    for _, empData in ipairs(InputHandler.gameState.hiredEmployees) do
        if empData.variant == 'remote' then
            if not (InputHandler.draggedItemState.item and InputHandler.draggedItemState.item.type == "placed_employee" and empData.instanceId == InputHandler.draggedItemState.item.data.instanceId) then
                table.insert(remoteWorkers, empData)
            end
        end
    end
    
    local availableWidth = rect.width - 20
    local normalGap = 5
    local normalStepSize = cardWidth + normalGap
    local currentTotalWidth = (#remoteWorkers * cardWidth) + ((#remoteWorkers - 1) * normalGap)
    
    local currentStepSize = normalStepSize
    if currentTotalWidth > availableWidth then
        local spaceForAllButLast = availableWidth - cardWidth
        currentStepSize = spaceForAllButLast / math.max(1, #remoteWorkers - 1)
    end
    
    local insertionIndex = #remoteWorkers + 1
    
    for i, empData in ipairs(remoteWorkers) do
        local cardX = rect.x + 10 + (i - 1) * currentStepSize
        local effectiveWidth = cardWidth
        
        if currentTotalWidth > availableWidth and i < #remoteWorkers then
            effectiveWidth = math.max(currentStepSize, cardWidth * 0.4)
        end
        
        if Drawing.isMouseOver(x, y, cardX, rect.y + Drawing.UI.font:getHeight() + 8, effectiveWidth, rect.height - (Drawing.UI.font:getHeight() + 15)) then
            insertionIndex = i
            break
        end
    end
    
    if insertionIndex == #remoteWorkers + 1 then
        local relativeMouseX = x - (rect.x + 10)
        
        if #remoteWorkers > 0 then
            local firstCardEffectiveWidth = currentTotalWidth > availableWidth and math.max(currentStepSize, cardWidth * 0.4) or cardWidth
            if relativeMouseX < firstCardEffectiveWidth then
                insertionIndex = 1
            else
                for i = 1, #remoteWorkers - 1 do
                    local currentCardStart = (i - 1) * currentStepSize
                    local currentCardEffectiveEnd = currentCardStart + (currentTotalWidth > availableWidth and math.max(currentStepSize, cardWidth * 0.4) or cardWidth)
                    local nextCardStart = i * currentStepSize
                    
                    if relativeMouseX >= currentCardEffectiveEnd and relativeMouseX < nextCardStart then
                        insertionIndex = i + 1
                        break
                    end
                end
            end
        else
            insertionIndex = 1
        end
    end
    
    return math.max(1, math.min(insertionIndex, #remoteWorkers + 1))
end

-- Helper function to insert a remote worker at a specific index among remote workers
local function insertRemoteWorkerAtIndex(employee, targetIndex)
    local remoteWorkers = {}
    local nonRemoteWorkers = {}
    
    -- Separate remote and non-remote workers
    for _, emp in ipairs(InputHandler.gameState.hiredEmployees) do
        if emp.variant == 'remote' then
            table.insert(remoteWorkers, emp)
        else
            table.insert(nonRemoteWorkers, emp)
        end
    end
    
    -- Insert the new employee at the target position among remote workers
    table.insert(remoteWorkers, targetIndex, employee)
    
    -- Rebuild the full employee list
    InputHandler.gameState.hiredEmployees = {}
    
    -- Add all non-remote workers first
    for _, emp in ipairs(nonRemoteWorkers) do
        table.insert(InputHandler.gameState.hiredEmployees, emp)
    end
    
    -- Add all remote workers in their new order
    for _, emp in ipairs(remoteWorkers) do
        table.insert(InputHandler.gameState.hiredEmployees, emp)
    end
end


-- Initialization function to be called once from main.lua's love.load
function InputHandler.init(references)
    InputHandler.gameState = references.gameState
    InputHandler.uiElementRects = references.uiElementRects
    InputHandler.draggedItemState = references.draggedItemState
    InputHandler.battleState = references.battleState
    InputHandler.panelRects = references.panelRects
    InputHandler.sprintOverviewState = references.sprintOverviewState
    InputHandler.sprintOverviewRects = references.sprintOverviewRects
    InputHandler.debugMenuState = references.debugMenuState
    InputHandler.debug = references.debug
    InputHandler.callbacks = references.callbacks
end

function InputHandler.onMousePress(x, y, button)
    if button == 1 then
        if InputHandler.debugMenuState.isVisible then
            if InputHandler.handleDebugMenuClicks(x, y) then return end
        end

        if InputHandler.sprintOverviewState.isVisible then
            if InputHandler.sprintOverviewRects.backButton and Drawing.isMouseOver(x, y, InputHandler.sprintOverviewRects.backButton.x, InputHandler.sprintOverviewRects.backButton.y, InputHandler.sprintOverviewRects.backButton.w, InputHandler.sprintOverviewRects.backButton.h) then
                InputHandler.sprintOverviewState.isVisible = false
            end
            return
        end

        if Drawing.modal.isVisible then
            if Drawing.handleModalClick(x, y) then return end
        end

        if InputHandler.gameState.gamePhase == "battle_active" then return end
        if InputHandler.draggedItemState.item then return end

        -- Check for special action modes first
        if InputHandler.gameState.temporaryEffectFlags.reOrgSwapModeActive or InputHandler.gameState.temporaryEffectFlags.photocopierCopyModeActive then
            InputHandler.handleMainInteractionPanelClicks(x, y)
            InputHandler.handleRemoteWorkersPanelClicks(x, y)
            return
        end

        if Drawing.isMouseOver(x, y, InputHandler.panelRects.gameInfo.x, InputHandler.panelRects.gameInfo.y, InputHandler.panelRects.gameInfo.width, InputHandler.panelRects.gameInfo.height) then
            InputHandler.handleGameInfoPanelClicks(x, y)
        elseif Drawing.isMouseOver(x, y, InputHandler.panelRects.shop.x, InputHandler.panelRects.shop.y, InputHandler.panelRects.shop.width, InputHandler.panelRects.shop.height) then
            InputHandler.handleShopPanelClicks(x, y)
        elseif Drawing.isMouseOver(x, y, InputHandler.panelRects.workloadBar.x, InputHandler.panelRects.workloadBar.y, InputHandler.panelRects.workloadBar.width, InputHandler.panelRects.workloadBar.height) then
            InputHandler.handleWorkloadBarClicks(x, y)
        elseif Drawing.isMouseOver(x, y, InputHandler.panelRects.mainInteraction.x, InputHandler.panelRects.mainInteraction.y, InputHandler.panelRects.mainInteraction.width, InputHandler.panelRects.mainInteraction.height) then
            InputHandler.handleMainInteractionPanelClicks(x, y)
        elseif Drawing.isMouseOver(x, y, InputHandler.panelRects.remoteWorkers.x, InputHandler.panelRects.remoteWorkers.y, InputHandler.panelRects.remoteWorkers.width, InputHandler.panelRects.remoteWorkers.height) then
            InputHandler.handleRemoteWorkersPanelClicks(x, y)
        elseif Drawing.isMouseOver(x, y, InputHandler.panelRects.purchasedUpgradesDisplay.x, InputHandler.panelRects.purchasedUpgradesDisplay.y, InputHandler.panelRects.purchasedUpgradesDisplay.width, InputHandler.panelRects.purchasedUpgradesDisplay.height) then
            InputHandler.handlePurchasedUpgradesPanelClicks(x, y)
        end
    elseif button == 2 and InputHandler.draggedItemState.item then
        if InputHandler.draggedItemState.item.type == "placed_employee" then
            local empData = InputHandler.draggedItemState.item.data
            if InputHandler.draggedItemState.item.originalDeskId then
                empData.deskId = InputHandler.draggedItemState.item.originalDeskId
                InputHandler.gameState.deskAssignments[InputHandler.draggedItemState.item.originalDeskId] = empData.instanceId
            elseif InputHandler.draggedItemState.item.originalVariant == 'remote' then
                empData.variant = 'remote'
            end
        end
        InputHandler.draggedItemState.item = nil
    end
end

function InputHandler.onMouseRelease(x, y, button)
    if button == 1 and InputHandler.draggedItemState.item then
        local empData = InputHandler.draggedItemState.item.data
        local successfullyProcessedDrop = false
        local draggedItem = InputHandler.draggedItemState.item

        local finalHiringCost = Shop:getFinalHiringCost(empData, InputHandler.gameState.purchasedPermanentUpgrades)

        for _, otherEmp in ipairs(InputHandler.gameState.hiredEmployees) do
            if otherEmp.instanceId ~= empData.instanceId then
                local empRect = nil
                if otherEmp.variant == 'remote' and InputHandler.uiElementRects.remote[otherEmp.instanceId] then
                    empRect = InputHandler.uiElementRects.remote[otherEmp.instanceId]
                elseif otherEmp.variant ~= 'remote' and otherEmp.deskId then
                    for i, deskRect in ipairs(InputHandler.uiElementRects.desks) do
                        if InputHandler.gameState.desks[i].id == otherEmp.deskId then empRect = deskRect; break; end
                    end
                end
                
                if empRect and Drawing.isMouseOver(x, y, empRect.x, empRect.y, empRect.w, empRect.h) then
                    if draggedItem.type == "shop_employee" then
                        if InputHandler.gameState.budget < finalHiringCost then
                            Drawing.showModal("Can't Afford", "Not enough budget. Need $" .. finalHiringCost)
                            successfullyProcessedDrop = true
                        elseif empData.special and (empData.special.type == 'haunt_target_on_hire' or empData.special.type == 'slime_merge') then
                            InputHandler.gameState.budget = InputHandler.gameState.budget - finalHiringCost
                            if empData.special.type == 'haunt_target_on_hire' then
                                otherEmp.baseProductivity = otherEmp.baseProductivity + (empData.special.prod_boost or 10)
                                otherEmp.baseFocus = otherEmp.baseFocus + (empData.special.focus_add or 0.5)
                                otherEmp.haunt_stacks = (otherEmp.haunt_stacks or 0) + 1
                            elseif empData.special.type == 'slime_merge' then
                                otherEmp.baseProductivity = otherEmp.baseProductivity * 2; otherEmp.baseFocus = otherEmp.baseFocus * 2; otherEmp.rarity = "Legendary"
                                otherEmp.slime_stacks = (otherEmp.slime_stacks or 0) + 1
                            end
                            Shop:markOfferSold(InputHandler.gameState.currentShopOffers, draggedItem.originalShopInstanceId, nil)
                            successfullyProcessedDrop = true
                        elseif Placement:isPotentialCombineTarget(InputHandler.gameState, otherEmp, empData) then
                            InputHandler.gameState.budget = InputHandler.gameState.budget - finalHiringCost
                            local tempNewEmployee = Employee:new(empData.id, empData.variant, empData.fullName) 
                            table.insert(InputHandler.gameState.hiredEmployees, tempNewEmployee)
                            local success, msg = Placement:combineAndLevelUpEmployees(InputHandler.gameState, otherEmp.instanceId, tempNewEmployee.instanceId)
                            if success then Shop:markOfferSold(InputHandler.gameState.currentShopOffers, draggedItem.originalShopInstanceId, nil)
                            else InputHandler.gameState.budget = InputHandler.gameState.budget + finalHiringCost; Drawing.showModal("Combine Failed", msg) end
                            successfullyProcessedDrop = true
                        end
                    elseif draggedItem.type == "placed_employee" then
                        if otherEmp.variant == 'remote' then
                            successfullyProcessedDrop = Placement:handleEmployeeDropOnRemoteEmployee(InputHandler.gameState, empData, otherEmp.instanceId)
                        else
                            successfullyProcessedDrop = Placement:handleEmployeeDropOnDesk(InputHandler.gameState, empData, otherEmp.deskId, draggedItem.originalDeskId)
                        end
                    end
                    if successfullyProcessedDrop then goto end_drop_check end
                end
            end
        end
        
        if InputHandler.uiElementRects.remoteGhostZone and Drawing.isMouseOver(x, y, InputHandler.uiElementRects.remoteGhostZone.x, InputHandler.uiElementRects.remoteGhostZone.y, InputHandler.uiElementRects.remoteGhostZone.w, InputHandler.uiElementRects.remoteGhostZone.h) then
            if empData.special and (empData.special.type == 'haunt_target_on_hire' or empData.special.type == 'slime_merge') then
                Drawing.showModal("Invalid Placement", "This employee must be placed on top of another employee.")
            elseif draggedItem.type == "shop_employee" and empData.variant == 'remote' then
                if InputHandler.gameState.budget >= finalHiringCost then
                    InputHandler.gameState.budget = InputHandler.gameState.budget - finalHiringCost
                    local insertionIndex = calculateRemoteInsertionIndexFromGhost(x, y) 
                    local newEmp = Employee:new(empData.id, empData.variant, empData.fullName) 
                    insertRemoteWorkerAtIndex(newEmp, insertionIndex)
                    Shop:markOfferSold(InputHandler.gameState.currentShopOffers, draggedItem.originalShopInstanceId, nil) 
                    successfullyProcessedDrop = true
                else Drawing.showModal("Can't Afford", "Not enough budget. Need $" .. finalHiringCost) end
            elseif draggedItem.type == "placed_employee" and empData.variant == 'remote' then
                local insertionIndex = calculateRemoteInsertionIndexFromGhost(x, y); local draggedEmpIndex; for i, emp in ipairs(InputHandler.gameState.hiredEmployees) do if emp.instanceId == empData.instanceId then draggedEmpIndex = i; break; end end; if draggedEmpIndex then local draggedEmployee = table.remove(InputHandler.gameState.hiredEmployees, draggedEmpIndex); insertRemoteWorkerAtIndex(draggedEmployee, insertionIndex); successfullyProcessedDrop = true; end
            end
            if successfullyProcessedDrop then goto end_drop_check end
        end

        for i, deskRect in ipairs(InputHandler.uiElementRects.desks) do
            if Drawing.isMouseOver(x,y, deskRect.x, deskRect.y, deskRect.w, deskRect.h) then
                if draggedItem.type == "shop_employee" then
                    if InputHandler.gameState.budget < finalHiringCost then
                        Drawing.showModal("Can't Afford", "Not enough budget to hire. Need $" .. finalHiringCost)
                    elseif empData.special and (empData.special.type == 'haunt_target_on_hire' or empData.special.type == 'slime_merge') then
                        Drawing.showModal("Invalid Placement", "This special unit must be placed on an existing employee, not an empty desk.")
                    else
                        local deskIndex = tonumber(string.match(deskRect.id, "desk%-(%d+)"))
                        if empData.special and empData.special.placement_restriction == 'not_top_row' and deskIndex and math.floor(deskIndex / GameData.GRID_WIDTH) == 0 then
                            Drawing.showModal("Placement Error", empData.name .. " cannot be placed in the top row.")
                        elseif InputHandler.gameState.deskAssignments[InputHandler.gameState.desks[i].id] then
                             Drawing.showModal("Placement Failed", "Desk is occupied. Drag onto another employee to combine or swap.")
                        else
                            InputHandler.gameState.budget = InputHandler.gameState.budget - finalHiringCost 
                            local newEmp = Employee:new(empData.id, empData.variant, empData.fullName) 
                            table.insert(InputHandler.gameState.hiredEmployees, newEmp) 
                            Placement:handleEmployeeDropOnDesk(InputHandler.gameState, newEmp, InputHandler.gameState.desks[i].id, nil)
                            Shop:markOfferSold(InputHandler.gameState.currentShopOffers, draggedItem.originalShopInstanceId, nil) 
                            successfullyProcessedDrop = true
                        end
                    end
                elseif draggedItem.type == "placed_employee" then
                    successfullyProcessedDrop = Placement:handleEmployeeDropOnDesk(InputHandler.gameState, empData, InputHandler.gameState.desks[i].id, draggedItem.originalDeskId)
                end
                if successfullyProcessedDrop then goto end_drop_check end
            end
        end

        if not successfullyProcessedDrop and empData.variant == 'remote' and Drawing.isMouseOver(x,y, InputHandler.uiElementRects.remotePanelDropTarget.x, InputHandler.uiElementRects.remotePanelDropTarget.y, InputHandler.uiElementRects.remotePanelDropTarget.w, InputHandler.uiElementRects.remotePanelDropTarget.h) then
             if InputHandler.gameState.budget < finalHiringCost then
                Drawing.showModal("Can't Afford", "Not enough budget. Need $" .. finalHiringCost)
             elseif empData.special and (empData.special.type == 'haunt_target_on_hire' or empData.special.type == 'slime_merge') then
                 Drawing.showModal("Invalid Placement", "This employee must be placed on top of another employee.")
            elseif draggedItem.type == "shop_employee" then
                 InputHandler.gameState.budget = InputHandler.gameState.budget - finalHiringCost
                 local newEmp = Employee:new(empData.id, empData.variant, empData.fullName) 
                 table.insert(InputHandler.gameState.hiredEmployees, newEmp)
                 Shop:markOfferSold(InputHandler.gameState.currentShopOffers, draggedItem.originalShopInstanceId, nil) 
                 successfullyProcessedDrop = true
            elseif draggedItem.type == "placed_employee" then
                successfullyProcessedDrop = Placement:handleEmployeeDropOnRemote(InputHandler.gameState, empData, draggedItem.originalDeskId)
            end
        end

        ::end_drop_check::
        if not successfullyProcessedDrop and draggedItem.type == "placed_employee" then
            local originalEmp = getEmployeeFromGameState(InputHandler.gameState, empData.instanceId)
            if originalEmp then
                if draggedItem.originalDeskId then originalEmp.deskId = draggedItem.originalDeskId; InputHandler.gameState.deskAssignments[draggedItem.originalDeskId] = originalEmp.instanceId
                elseif draggedItem.originalVariant == 'remote' then originalEmp.variant = 'remote' end
            end
        end
        InputHandler.draggedItemState.item = nil 
    end
end

function InputHandler.onKeyPress(key)
    if key == "`" then
        InputHandler.debugMenuState.isVisible = not InputHandler.debugMenuState.isVisible
        if not InputHandler.debugMenuState.isVisible then
            InputHandler.debug.employeeDropdown.isOpen = false
            InputHandler.debug.upgradeDropdown.isOpen = false
        end
        return
    end

    if key == "=" or key == "+" then
        executeAddMoney(InputHandler)
        InputHandler.debug.hotkeyState.plus.timer = InputHandler.debug.hotkeyState.plus.initial
        return
    elseif key == "-" then
        executeRemoveMoney(InputHandler)
        InputHandler.debug.hotkeyState.minus.timer = InputHandler.debug.hotkeyState.minus.initial
        return
    end

    if key == "u" then
        local dropdown = InputHandler.debug.upgradeDropdown
        local nextIndex = dropdown.selected + 1
        if nextIndex > #dropdown.options then
            nextIndex = 1
        end
        dropdown.selected = nextIndex
        
        local nextUpgrade = dropdown.options[nextIndex]
        if nextUpgrade then
            _G.Shop:forceAddUpgradeOffer(InputHandler.gameState.currentShopOffers, nextUpgrade.id)
            print("DEBUG: Spawned upgrade #" .. nextIndex .. ": " .. nextUpgrade.name)
        end
        return
    end

    if key == "i" then
        local dropdown = InputHandler.debug.employeeDropdown
        local nextIndex = dropdown.selected + 1
        if nextIndex > #dropdown.options then
            nextIndex = 1
        end
        dropdown.selected = nextIndex

        local nextEmployee = dropdown.options[nextIndex]
        if nextEmployee then
            local variant = "standard"
            if InputHandler.debug.checkboxes.remote.checked then variant = "remote"
            elseif InputHandler.debug.checkboxes.foil.checked then variant = "foil"
            elseif InputHandler.debug.checkboxes.holo.checked then variant = "holo" end

            _G.Shop:forceAddEmployeeOffer(InputHandler.gameState.currentShopOffers, nextEmployee.id, variant)
            print("DEBUG: Spawned employee #" .. nextIndex .. ": " .. nextEmployee.name .. " (" .. variant .. ")")
        end
        return
    end

    if key == "o" then
        print("DEBUG: Clearing office floor.")
        for i = #InputHandler.gameState.hiredEmployees, 1, -1 do
            local emp = InputHandler.gameState.hiredEmployees[i]
            if emp and emp.deskId then
                InputHandler.gameState.deskAssignments[emp.deskId] = nil
                table.remove(InputHandler.gameState.hiredEmployees, i)
            end
        end
        return
    end

    if InputHandler.debugMenuState.isVisible then
        local optionHeight = 20
        local d_emp = InputHandler.debug.employeeDropdown
        local d_upg = InputHandler.debug.upgradeDropdown
        local key_pressed = false

        if d_emp.isOpen then
            local listVisibleHeight = math.min(#d_emp.options * optionHeight, 200)
            local maxScroll = (#d_emp.options * optionHeight) - listVisibleHeight
            if maxScroll < 0 then maxScroll = 0 end

            if key == "down" then
                d_emp.scrollOffset = d_emp.scrollOffset + listVisibleHeight
                key_pressed = true
            elseif key == "up" then
                d_emp.scrollOffset = d_emp.scrollOffset - listVisibleHeight
                key_pressed = true
            end
            d_emp.scrollOffset = math.max(0, math.min(d_emp.scrollOffset, maxScroll))

        elseif d_upg.isOpen then
            local listVisibleHeight = math.min(#d_upg.options * optionHeight, 200)
            local maxScroll = (#d_upg.options * optionHeight) - listVisibleHeight
            if maxScroll < 0 then maxScroll = 0 end

            if key == "down" then
                d_upg.scrollOffset = d_upg.scrollOffset + listVisibleHeight
                key_pressed = true
            elseif key == "up" then
                d_upg.scrollOffset = d_upg.scrollOffset - listVisibleHeight
                key_pressed = true
            end
            d_upg.scrollOffset = math.max(0, math.min(d_upg.scrollOffset, maxScroll))
        end
        if key_pressed then return end
    end

    if key == "escape" then
        if InputHandler.sprintOverviewState.isVisible then
            InputHandler.sprintOverviewState.isVisible = false
        elseif InputHandler.draggedItemState.item then
            if InputHandler.draggedItemState.item.type == "placed_employee" then 
                local empData = InputHandler.draggedItemState.item.data
                if InputHandler.draggedItemState.item.originalDeskId then
                    empData.deskId = InputHandler.draggedItemState.item.originalDeskId
                    InputHandler.gameState.deskAssignments[InputHandler.draggedItemState.item.originalDeskId] = empData.instanceId
                elseif InputHandler.draggedItemState.item.originalVariant == 'remote' then
                    empData.variant = 'remote'
                end
            end
            InputHandler.draggedItemState.item = nil 
        elseif Drawing.modal.isVisible then
             Drawing.hideModal()
        end
    end
end

function InputHandler.onMouseWheelMoved(x, y)
    if not InputHandler.debugMenuState.isVisible then return end

    local mouseX, mouseY = love.mouse.getPosition()
    local optionHeight = 20
    local scrollSpeed = optionHeight * 2 -- Scroll 2 items at a time

    -- Handle Employee Dropdown Scroll
    local d_emp = InputHandler.debug.employeeDropdown
    if d_emp.isOpen then
        local listVisibleHeight = math.min(#d_emp.options * optionHeight, 200)
        local listRect = { x = d_emp.rect.x, y = d_emp.rect.y + d_emp.rect.h, w = d_emp.rect.w, h = listVisibleHeight }
        
        if Drawing.isMouseOver(mouseX, mouseY, listRect.x, listRect.y, listRect.w, listRect.h) then
            d_emp.scrollOffset = d_emp.scrollOffset - (y * scrollSpeed)
            
            local maxScroll = (#d_emp.options * optionHeight) - listVisibleHeight
            if maxScroll < 0 then maxScroll = 0 end
            d_emp.scrollOffset = math.max(0, math.min(d_emp.scrollOffset, maxScroll))
        end
    end

    -- Handle Upgrade Dropdown Scroll
    local d_upg = InputHandler.debug.upgradeDropdown
    if d_upg.isOpen then
        local listVisibleHeight = math.min(#d_upg.options * optionHeight, 200)
        local listRect = { x = d_upg.rect.x, y = d_upg.rect.y + d_upg.rect.h, w = d_upg.rect.w, h = listVisibleHeight }

        if Drawing.isMouseOver(mouseX, mouseY, listRect.x, listRect.y, listRect.w, listRect.h) then
            d_upg.scrollOffset = d_upg.scrollOffset - (y * scrollSpeed)
            
            local maxScroll = (#d_upg.options * optionHeight) - listVisibleHeight
            if maxScroll < 0 then maxScroll = 0 end
            d_upg.scrollOffset = math.max(0, math.min(d_upg.scrollOffset, maxScroll))
        end
    end
end

function InputHandler.handlePurchasedUpgradesPanelClicks(x, y)
    if InputHandler.uiElementRects.permanentUpgrades then
        for upgradeId, rectData in pairs(InputHandler.uiElementRects.permanentUpgrades) do
            if rectData and Drawing.isMouseOver(x, y, rectData.x, rectData.y, rectData.w, rectData.h) then
                local upgrade = rectData.data
                
                if upgrade.listeners and upgrade.listeners.onActivate then
                    -- The listener is responsible for checking conditions like game phase or if it has been used.
                    if upgrade.listeners.onActivate(upgrade, InputHandler.gameState) then
                        return true -- The click was handled by the listener.
                    end
                end

            end
        end
    end
    return false
end

function InputHandler.handleGameInfoPanelClicks(x, y)
    local mainActionRect = InputHandler.uiElementRects.actionButtons["main_phase_action"]
    local viewSprintRect = InputHandler.uiElementRects.actionButtons["view_sprint"]

    if mainActionRect and Drawing.isMouseOver(x, y, mainActionRect.x, mainActionRect.y, mainActionRect.w, mainActionRect.h) then
        if InputHandler.gameState.gamePhase == "hiring_and_upgrades" then
            -- Set the game phase first to prepare the battle state and flags.
            InputHandler.callbacks.setGamePhase("battle_active")
            -- Then, start the challenge to apply item-specific effects.
            local status = Battle:startChallenge(InputHandler.gameState)
            
            -- If startChallenge determines the game is over or won, update the phase again.
            if status ~= "battle_active" then
                InputHandler.callbacks.setGamePhase(status)
            end
        elseif InputHandler.gameState.gamePhase == "game_over" or InputHandler.gameState.gamePhase == "game_won" then
            InputHandler.callbacks.resetGameAndGlobals()
        end
        return true
    elseif viewSprintRect and Drawing.isMouseOver(x, y, viewSprintRect.x, viewSprintRect.y, viewSprintRect.w, viewSprintRect.h) then
        InputHandler.sprintOverviewState.isVisible = true
        return true
    end
    return false
end

function InputHandler.handleShopPanelClicks(x, y)
    if InputHandler.draggedItemState.item or InputHandler.gameState.temporaryEffectFlags.isShopDisabled then return false end

    local isBorgActive = Shop:isUpgradePurchased(InputHandler.gameState.purchasedPermanentUpgrades, 'borg_hivemind')

    if InputHandler.uiElementRects.shopLockButtons then
        for instanceId, rect in pairs(InputHandler.uiElementRects.shopLockButtons) do
            if Drawing.isMouseOver(x, y, rect.x, rect.y, rect.w, rect.h) then
                for _, empOffer in ipairs(InputHandler.gameState.currentShopOffers.employees) do
                    if empOffer and empOffer.instanceId == instanceId then
                        empOffer.isLocked = not empOffer.isLocked
                        return true
                    end
                end
                if InputHandler.gameState.currentShopOffers.upgrade and InputHandler.gameState.currentShopOffers.upgrade.instanceId == instanceId then
                    InputHandler.gameState.currentShopOffers.upgrade.isLocked = not InputHandler.gameState.currentShopOffers.upgrade.isLocked
                    return true
                end
            end
        end
    end

    if InputHandler.gameState.currentShopOffers and InputHandler.gameState.currentShopOffers.employees then
        for i, rectData in ipairs(InputHandler.uiElementRects.shopEmployees) do
            if rectData and Drawing.isMouseOver(x, y, rectData.x, rectData.y, rectData.w, rectData.h) then
                if rectData.data and not rectData.data.sold then
                    if isBorgActive then
                        local assimilationCost = math.floor(rectData.data.hiringBonus * 0.5)
                        if InputHandler.gameState.budget >= assimilationCost then
                            InputHandler.gameState.budget = InputHandler.gameState.budget - assimilationCost
                            local borgDrone = InputHandler.gameState.hiredEmployees[1]
                            if borgDrone then
                                borgDrone.baseProductivity = borgDrone.baseProductivity + rectData.data.baseProductivity
                                borgDrone.baseFocus = borgDrone.baseFocus + rectData.data.baseFocus
                                Drawing.showModal("Assimilated", rectData.data.name .. "'s distinctiveness has been added to the collective.")
                                Shop:markOfferSold(InputHandler.gameState.currentShopOffers, rectData.data.instanceId, nil)
                            end
                        else
                            Drawing.showModal("Cannot Assimilate", "Insufficient budget. Requires $" .. assimilationCost)
                        end
                    else
                        InputHandler.draggedItemState.item = { type = "shop_employee", data = rectData.data, originalShopInstanceId = rectData.data.instanceId }
                    end
                    return true
                end
            end
        end
    end
    if InputHandler.uiElementRects.shopUpgradeOffer and Drawing.isMouseOver(x, y, InputHandler.uiElementRects.shopUpgradeOffer.x, InputHandler.uiElementRects.shopUpgradeOffer.y, InputHandler.uiElementRects.shopUpgradeOffer.w, InputHandler.uiElementRects.shopUpgradeOffer.h) then
        local offerData = InputHandler.gameState.currentShopOffers.upgrade
        if offerData and not offerData.sold then
            local success, msg = Shop:buyUpgrade(InputHandler.gameState, offerData.id)
            if not success then Drawing.showModal("Can't Upgrade", msg)
            else Shop:markOfferSold(InputHandler.gameState.currentShopOffers, nil, offerData) end
            return true
        end
    end

    if InputHandler.uiElementRects.shopRestock and Drawing.isMouseOver(x, y, InputHandler.uiElementRects.shopRestock.x, InputHandler.uiElementRects.shopRestock.y, InputHandler.uiElementRects.shopRestock.w, InputHandler.uiElementRects.shopRestock.h) then
        local restockCost = GameData.BASE_RESTOCK_COST * (2 ^ InputHandler.gameState.currentShopOffers.restockCountThisWeek)
        if Shop:isUpgradePurchased(InputHandler.gameState.purchasedPermanentUpgrades, 'headhunter') then
            restockCost = restockCost * 2
        end
        if InputHandler.gameState.budget >= restockCost then
            local success, msg = Shop:attemptRestock(InputHandler.gameState)
            if not success then Drawing.showModal("Restock Failed", msg) end
        end
        return true
    end

    return false
end

function InputHandler.handleMainInteractionPanelClicks(x, y)
    if InputHandler.draggedItemState.item then return false end

    -- Handle special mode clicks first
    if InputHandler.gameState.temporaryEffectFlags.reOrgSwapModeActive then
        for i, rectData in ipairs(InputHandler.uiElementRects.desks) do
            if rectData and Drawing.isMouseOver(x, y, rectData.x, rectData.y, rectData.w, rectData.h) then
                local empId = InputHandler.gameState.deskAssignments[rectData.id]
                if empId then
                    local firstSelectionId = InputHandler.gameState.temporaryEffectFlags.reOrgFirstSelectionInstanceId
                    if not firstSelectionId then
                        InputHandler.gameState.temporaryEffectFlags.reOrgFirstSelectionInstanceId = empId
                        Drawing.showModal("First Selection", getEmployeeFromGameState(InputHandler.gameState, empId).name .. " selected. Now select a remote worker.")
                    else
                        local success, msg = Placement:performReOrgSwap(InputHandler.gameState, firstSelectionId, empId)
                        Drawing.showModal(success and "Re-Org Complete" or "Re-Org Failed", msg)
                        if success then InputHandler.gameState.temporaryEffectFlags.reOrgUsedThisSprint = true end
                        InputHandler.gameState.temporaryEffectFlags.reOrgSwapModeActive = false
                        InputHandler.gameState.temporaryEffectFlags.reOrgFirstSelectionInstanceId = nil
                    end
                end
                return true
            end
        end
    elseif InputHandler.gameState.temporaryEffectFlags.photocopierCopyModeActive then
        for i, rectData in ipairs(InputHandler.uiElementRects.desks) do
            if rectData and Drawing.isMouseOver(x, y, rectData.x, rectData.y, rectData.w, rectData.h) then
                local empId = InputHandler.gameState.deskAssignments[rectData.id]
                if empId then
                    local emp = getEmployeeFromGameState(InputHandler.gameState, empId)
                    if emp.rarity ~= 'Legendary' then
                        InputHandler.gameState.temporaryEffectFlags.photocopierTargetForNextItem = empId
                        InputHandler.gameState.temporaryEffectFlags.photocopierUsedThisSprint = true
                        Drawing.showModal("Target Acquired", emp.name .. " will be duplicated at the start of the next work item.")
                    else
                        Drawing.showModal("Copy Failed", "Cannot copy a Legendary employee.")
                    end
                    InputHandler.gameState.temporaryEffectFlags.photocopierCopyModeActive = false
                end
                return true
            end
        end
    end

    for i, rectData in ipairs(InputHandler.uiElementRects.desks) do
        if rectData and Drawing.isMouseOver(x, y, rectData.x, rectData.y, rectData.w, rectData.h) then
            local deskData = InputHandler.gameState.desks[i]
            local deskRow = math.floor((i - 1) / GameData.GRID_WIDTH)
            if InputHandler.gameState.temporaryEffectFlags.isTopRowDisabled and deskRow == 0 then return true end

            if deskData.status == "purchasable" then
                local success, msg = Placement:attemptBuyDesk(InputHandler.gameState, deskData.id)
                if not success then Drawing.showModal("Purchase Failed", msg)
                else Placement:updateDeskAvailability(InputHandler.gameState.desks) end
                return true
            elseif deskData.status == "owned" and InputHandler.gameState.deskAssignments[deskData.id] then
                local emp = getEmployeeFromGameState(InputHandler.gameState, InputHandler.gameState.deskAssignments[deskData.id])
                if emp then
                    if emp.special and emp.special.type == 'stapler_guy_placement' then
                        if love.math.random() < emp.special.move_risk_chance then
                            Drawing.showModal("ARSON!", emp.name .. " has burned the building down in a fit of rage over his stapler! Game Over.", { { text = "Restart", onClick = InputHandler.callbacks.resetGameAndGlobals, style = "danger" } })
                            InputHandler.callbacks.setGamePhase("game_over")
                            return true
                        else
                            Drawing.showModal("Close Call", emp.name .. " muttered something about his stapler, but allowed you to move him... this time.")
                        end
                    end

                    InputHandler.draggedItemState.item = { type = "placed_employee", data = emp, originalDeskId = deskData.id }
                    emp.deskId = nil
                    InputHandler.gameState.deskAssignments[deskData.id] = nil
                    return true
                end
            end
        end
    end
    return false
end

function InputHandler.handleRemoteWorkersPanelClicks(x, y)
    if InputHandler.draggedItemState.item or InputHandler.gameState.temporaryEffectFlags.isRemoteWorkDisabled then return false end

    if InputHandler.uiElementRects.remote then
        for empId, rectData in pairs(InputHandler.uiElementRects.remote) do
            if rectData and Drawing.isMouseOver(x, y, rectData.x, rectData.y, rectData.w, rectData.h) then
                if InputHandler.gameState.temporaryEffectFlags.reOrgSwapModeActive then
                    local firstSelectionId = InputHandler.gameState.temporaryEffectFlags.reOrgFirstSelectionInstanceId
                    if not firstSelectionId then
                        InputHandler.gameState.temporaryEffectFlags.reOrgFirstSelectionInstanceId = empId
                        Drawing.showModal("First Selection", getEmployeeFromGameState(InputHandler.gameState, empId).name .. " selected. Now select an office worker.")
                    else
                        local success, msg = Placement:performReOrgSwap(InputHandler.gameState, firstSelectionId, empId)
                        Drawing.showModal(success and "Re-Org Complete" or "Re-Org Failed", msg)
                        if success then InputHandler.gameState.temporaryEffectFlags.reOrgUsedThisSprint = true end
                        InputHandler.gameState.temporaryEffectFlags.reOrgSwapModeActive = false
                        InputHandler.gameState.temporaryEffectFlags.reOrgFirstSelectionInstanceId = nil
                    end
                    return true
                end

                local empData = getEmployeeFromGameState(InputHandler.gameState, empId)
                if empData and empData.variant == 'remote' and not InputHandler.draggedItemState.item then
                    InputHandler.draggedItemState.item = { type = "placed_employee", data = empData, originalVariant = 'remote' }
                    return true
                end
            end
        end
    end
    return false
end

function InputHandler.handleWorkloadBarClicks(x, y)
    if InputHandler.gameState.gamePhase ~= 'hiring_and_upgrades' then return false end

    local rect = InputHandler.panelRects.workloadBar
    if Drawing.isMouseOver(x, y, rect.x, rect.y, rect.width, rect.height) then
        if not Shop:isUpgradePurchased(InputHandler.gameState.purchasedPermanentUpgrades, "fourth_wall") then
            return false
        end

        if InputHandler.gameState.temporaryEffectFlags.fourthWallUsedThisSprint then
            Drawing.showModal("Already Used", "The 4th Wall can only be broken once per sprint.")
            return true
        end

        -- The upgrade is purchased and hasn't been used. Apply the effect.
        local sprintData = GameData.ALL_SPRINTS[InputHandler.gameState.currentSprintIndex]
        local workItemData = sprintData and sprintData.workItems[InputHandler.gameState.currentWorkItemIndex]
        if workItemData then
            local reduction = math.floor(workItemData.workload * 0.25)
            workItemData.workload = workItemData.workload - reduction
            InputHandler.gameState.temporaryEffectFlags.fourthWallUsedThisSprint = true
            Drawing.showModal("CRACK!", "You reached through the screen and pulled the workload bar down, reducing the upcoming workload by 25%!")
        end
        return true
    end
    return false
end

function InputHandler.handleDebugMenuClicks(x, y)
    local optionHeight = 20
    local debug = InputHandler.debug

    -- Handle Employee Dropdown Interaction
    if debug.employeeDropdown.isOpen then
        local d = debug.employeeDropdown
        local listVisibleHeight = math.min(#d.options * optionHeight, 200)
        local listRect = { x = d.rect.x, y = d.rect.y + d.rect.h, w = d.rect.w, h = listVisibleHeight }

        -- Check for click on an option
        if Drawing.isMouseOver(x, y, listRect.x, listRect.y, listRect.w - 10, listRect.h) then
            local clickedIndex = math.floor((y + d.scrollOffset - listRect.y) / optionHeight) + 1
            if clickedIndex >= 1 and clickedIndex <= #d.options then
                d.selected = clickedIndex
                d.isOpen = false
                return true
            end
        end

        -- Check for click on scrollbar
        if d.scrollbarRect and Drawing.isMouseOver(x, y, d.scrollbarRect.x, d.scrollbarRect.y, d.scrollbarRect.w, d.scrollbarRect.h) then
            if not Drawing.isMouseOver(x, y, d.scrollbarHandleRect.x, d.scrollbarHandleRect.y, d.scrollbarHandleRect.w, d.scrollbarHandleRect.h) then
                if y < d.scrollbarHandleRect.y then d.scrollOffset = d.scrollOffset - listVisibleHeight
                else d.scrollOffset = d.scrollOffset + listVisibleHeight end

                local maxScroll = (#d.options * optionHeight) - listVisibleHeight
                d.scrollOffset = math.max(0, math.min(d.scrollOffset, maxScroll))
            end
            return true
        end

        d.isOpen = false
        if Drawing.isMouseOver(x, y, d.rect.x, d.rect.y, d.rect.w, d.rect.h) then return true end
    end

    -- Handle Upgrade Dropdown Interaction (similar logic)
    if debug.upgradeDropdown.isOpen then
        local d = debug.upgradeDropdown
        local listVisibleHeight = math.min(#d.options * optionHeight, 200)
        local listRect = { x = d.rect.x, y = d.rect.y + d.rect.h, w = d.rect.w, h = listVisibleHeight }

        if Drawing.isMouseOver(x, y, listRect.x, listRect.y, listRect.w - 10, listRect.h) then
            local clickedIndex = math.floor((y + d.scrollOffset - listRect.y) / optionHeight) + 1
            if clickedIndex >= 1 and clickedIndex <= #d.options then
                d.selected = clickedIndex
                d.isOpen = false
                return true
            end
        end

        if d.scrollbarRect and Drawing.isMouseOver(x, y, d.scrollbarRect.x, d.scrollbarRect.y, d.scrollbarRect.w, d.scrollbarRect.h) then
            if not Drawing.isMouseOver(x, y, d.scrollbarHandleRect.x, d.scrollbarHandleRect.y, d.scrollbarHandleRect.w, d.scrollbarHandleRect.h) then
                if y < d.scrollbarHandleRect.y then d.scrollOffset = d.scrollOffset - listVisibleHeight
                else d.scrollOffset = d.scrollOffset + listVisibleHeight end

                local maxScroll = (#d.options * optionHeight) - listVisibleHeight
                d.scrollOffset = math.max(0, math.min(d.scrollOffset, maxScroll))
            end
            return true
        end

        d.isOpen = false
        if Drawing.isMouseOver(x, y, d.rect.x, d.rect.y, d.rect.w, d.rect.h) then return true end
    end


    -- Check dropdown toggles
    if Drawing.isMouseOver(x, y, debug.employeeDropdown.rect.x, debug.employeeDropdown.rect.y, debug.employeeDropdown.rect.w, debug.employeeDropdown.rect.h) then
        debug.employeeDropdown.isOpen = not debug.employeeDropdown.isOpen
        debug.upgradeDropdown.isOpen = false
        return true
    end
    if Drawing.isMouseOver(x, y, debug.upgradeDropdown.rect.x, debug.upgradeDropdown.rect.y, debug.upgradeDropdown.rect.w, debug.upgradeDropdown.rect.h) then
        debug.upgradeDropdown.isOpen = not debug.upgradeDropdown.isOpen
        debug.employeeDropdown.isOpen = false
        return true
    end

    -- Check checkboxes
    if Drawing.isMouseOver(x, y, debug.checkboxes.remote.rect.x, debug.checkboxes.remote.rect.y, debug.checkboxes.remote.rect.w, debug.checkboxes.remote.rect.h) then
        debug.checkboxes.remote.checked = not debug.checkboxes.remote.checked; if debug.checkboxes.remote.checked then debug.checkboxes.foil.checked = false; debug.checkboxes.holo.checked = false; end
        return true
    end
    if Drawing.isMouseOver(x, y, debug.checkboxes.foil.rect.x, debug.checkboxes.foil.rect.y, debug.checkboxes.foil.rect.w, debug.checkboxes.foil.rect.h) then
        debug.checkboxes.foil.checked = not debug.checkboxes.foil.checked; if debug.checkboxes.foil.checked then debug.checkboxes.remote.checked = false; debug.checkboxes.holo.checked = false; end
        return true
    end
    if Drawing.isMouseOver(x, y, debug.checkboxes.holo.rect.x, debug.checkboxes.holo.rect.y, debug.checkboxes.holo.rect.w, debug.checkboxes.holo.rect.h) then
        debug.checkboxes.holo.checked = not debug.checkboxes.holo.checked; if debug.checkboxes.holo.checked then debug.checkboxes.remote.checked = false; debug.checkboxes.foil.checked = false; end
        return true
    end

    -- Check Buttons
    if Drawing.isMouseOver(x, y, debug.buttons.spawnEmployee.x, debug.buttons.spawnEmployee.y, debug.buttons.spawnEmployee.w, debug.buttons.spawnEmployee.h) then
        local selectedId = debug.employeeDropdown.options[debug.employeeDropdown.selected].id
        local variant = "standard"
        if debug.checkboxes.remote.checked then variant = "remote"
        elseif debug.checkboxes.foil.checked then variant = "foil"
        elseif debug.checkboxes.holo.checked then variant = "holo" end
        Shop:forceAddEmployeeOffer(InputHandler.gameState.currentShopOffers, selectedId, variant)
        return true
    end
    if Drawing.isMouseOver(x, y, debug.buttons.spawnUpgrade.x, debug.buttons.spawnUpgrade.y, debug.buttons.spawnUpgrade.w, debug.buttons.spawnUpgrade.h) then
        local selectedId = debug.upgradeDropdown.options[debug.upgradeDropdown.selected].id
        Shop:forceAddUpgradeOffer(InputHandler.gameState.currentShopOffers, selectedId)
        return true
    end
    if Drawing.isMouseOver(x, y, debug.buttons.addMoney.x, debug.buttons.addMoney.y, debug.buttons.addMoney.w, debug.buttons.addMoney.h) then
        InputHandler.gameState.budget = InputHandler.gameState.budget + 1000
        return true
    end
    if Drawing.isMouseOver(x, y, debug.buttons.removeMoney.x, debug.buttons.removeMoney.y, debug.buttons.removeMoney.w, debug.buttons.removeMoney.h) then
        InputHandler.gameState.budget = InputHandler.gameState.budget - 1000
        return true
    end
    if Drawing.isMouseOver(x, y, debug.buttons.restock.x, debug.buttons.restock.y, debug.buttons.restock.w, debug.buttons.restock.h) then
        Shop:attemptRestock(InputHandler.gameState)
        return true
    end
    if Drawing.isMouseOver(x, y, debug.buttons.prevItem.x, debug.buttons.prevItem.y, debug.buttons.prevItem.w, debug.buttons.prevItem.h) then
        InputHandler.gameState.currentWorkItemIndex = InputHandler.gameState.currentWorkItemIndex - 1
        if InputHandler.gameState.currentWorkItemIndex < 1 then
            InputHandler.gameState.currentSprintIndex = math.max(1, InputHandler.gameState.currentSprintIndex - 1)
            InputHandler.gameState.currentWorkItemIndex = 3
        end
        InputHandler.callbacks.setGamePhase("hiring_and_upgrades")
        return true
    end
    if Drawing.isMouseOver(x, y, debug.buttons.nextItem.x, debug.buttons.nextItem.y, debug.buttons.nextItem.w, debug.buttons.nextItem.h) then
        InputHandler.gameState.currentWorkItemIndex = InputHandler.gameState.currentWorkItemIndex + 1
        if InputHandler.gameState.currentWorkItemIndex > 3 then
            InputHandler.gameState.currentWorkItemIndex = 1
            InputHandler.gameState.currentSprintIndex = math.min(#GameData.ALL_SPRINTS, InputHandler.gameState.currentSprintIndex + 1)
        end
        InputHandler.callbacks.setGamePhase("hiring_and_upgrades")
        return true
    end

    if Drawing.isMouseOver(x, y, debug.rect.x, debug.rect.y, debug.rect.w, debug.rect.h) then
        return true
    end

    return false
end


return InputHandler