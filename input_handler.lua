-- input_handler.lua
-- Manages user input, delegating actions to the appropriate game modules.

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
            return
        end

        if InputHandler.sprintOverviewState.isVisible then
            if InputHandler.sprintOverviewRects.backButton and Drawing.isMouseOver(x, y, InputHandler.sprintOverviewRects.backButton.x, InputHandler.sprintOverviewRects.backButton.y, InputHandler.sprintOverviewRects.backButton.w, InputHandler.sprintOverviewRects.backButton.h) then
                InputHandler.sprintOverviewState.isVisible = false
            end
            return
        end

        if Drawing.modal.isVisible then
            return
        end

        if InputHandler.gameState.gamePhase == "battle_active" then return end
        if InputHandler.draggedItemState.item then return end

        if Drawing.isMouseOver(x, y, InputHandler.panelRects.workloadBar.x, InputHandler.panelRects.workloadBar.y, InputHandler.panelRects.workloadBar.width, InputHandler.panelRects.workloadBar.height) then
            local eventArgs = { wasHandled = false }
            require("effects_dispatcher").dispatchEvent("onWorkloadBarClick", InputHandler.gameState, eventArgs)
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
    -- All logic for this has been moved to the onMouseRelease function in main.lua
    -- to have access to the local uiComponents table. This function is now intentionally empty.
end

-- Keyboard input is separate from mouse clicks and remains unchanged.
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
            -- Use require("shop") instead of _G.Shop
            require("shop"):forceAddUpgradeOffer(InputHandler.gameState.currentShopOffers, nextUpgrade.id)
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

            -- Use require("shop") instead of _G.Shop
            require("shop"):forceAddEmployeeOffer(InputHandler.gameState.currentShopOffers, nextEmployee.id, variant)
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
                local originalEmp = Employee:getFromState(InputHandler.gameState, empData.instanceId)
                if originalEmp then
                    if InputHandler.draggedItemState.item.originalDeskId then
                        originalEmp.deskId = InputHandler.draggedItemState.item.originalDeskId
                        InputHandler.gameState.deskAssignments[InputHandler.draggedItemState.item.originalDeskId] = originalEmp.instanceId
                    elseif InputHandler.draggedItemState.item.originalVariant == 'remote' then
                        originalEmp.variant = 'remote'
                    end
                end
            end
            InputHandler.draggedItemState.item = nil 
        elseif Drawing.modal.isVisible then
             Drawing.hideModal()
        end
    end
end

-- This function is still needed as a non-component interaction.
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

return InputHandler