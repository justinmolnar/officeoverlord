-- input_handler.lua
-- Manages user input, delegating actions to the appropriate game modules.

local Drawing = require("drawing")
local Shop = require("shop")
local Placement = require("placement")
local GameData = require("data")
local Employee = require("employee")
local EffectsDispatcher = require("effects_dispatcher")

local InputHandler = {}

-- Store references to game state and callbacks
InputHandler.gameState = nil
InputHandler.uiElementRects = nil
InputHandler.draggedItemState = nil
InputHandler.battleState = nil
InputHandler.panelRects = nil
InputHandler.sprintOverviewState = nil
InputHandler.sprintOverviewRects = nil
InputHandler.callbacks = {}
InputHandler.modal = nil

-- The update function is now empty as its only job was debug hotkeys.
function InputHandler.update(dt)
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
    InputHandler.callbacks = references.callbacks
    InputHandler.modal = references.modal
end

function InputHandler.onMousePress(x, y, button)
    if button == 1 then
        if InputHandler.sprintOverviewState.isVisible then return end
        if InputHandler.modal.isVisible and InputHandler.modal:handleMouseClick(x, y) then return end
        if InputHandler.gameState.gamePhase == "battle_active" then return end
        if InputHandler.draggedItemState.item then return end

        if Drawing.isMouseOver(x, y, InputHandler.panelRects.workloadBar.x, InputHandler.panelRects.workloadBar.y, InputHandler.panelRects.workloadBar.width, InputHandler.panelRects.workloadBar.height) then
            local eventArgs = { wasHandled = false }
            require("effects_dispatcher").dispatchEvent("onWorkloadBarClick", InputHandler.gameState, { modal = InputHandler.modal }, eventArgs)
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
    -- This logic remains in main.lua
end

-- Keyboard input is now only for game-related actions
function InputHandler.onKeyPress(key)
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
        elseif InputHandler.modal.isVisible then
             InputHandler.modal:hide()
        end
    end
end

return InputHandler