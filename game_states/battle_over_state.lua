-- game_states/battle_over_state.lua
-- A state that pauses the game after a battle is won, showing the final UI but halting the simulation.

local BaseState = require("game_states.base_state")
local Drawing = require("drawing")

local BattleOverState = setmetatable({}, BaseState)
BattleOverState.__index = BattleOverState

function BattleOverState:new()
    return setmetatable(BaseState:new(), self)
end

function BattleOverState:enter(gameState, battleState, context)
    print("Entering Battle Over phase. Game logic is now paused.")
    -- Ensure the UI is up-to-date with the final state of the battle.
    if context.buildUIComponents then
        context.buildUIComponents()
    end
end

-- The update function is intentionally empty to pause the battle simulation.
function BattleOverState:update(dt, gameState, battleState, context)
    -- PAUSED
end

-- Draw the UI panels so they are visible behind the modal.
function BattleOverState:draw(gameState, battleState, context)
    local panelRects = context.panelRects
    local uiElementRects = context.uiElementRects
    local draggedItemState = context.draggedItemState
    local sprintOverviewState = context.sprintOverviewState
    local Placement = context.Placement
    local Shop = context.Shop
    
    Drawing.drawRemoteWorkersPanel(panelRects.remoteWorkers, gameState, uiElementRects, draggedItemState.item, battleState, Placement)
    Drawing.drawGameInfoPanel(panelRects.gameInfo, gameState, uiElementRects, sprintOverviewState.isVisible, battleState)
    Drawing.drawWorkloadBar(panelRects.workloadBar, gameState, battleState)
    Drawing.drawShopPanel(panelRects.shop, gameState, uiElementRects, draggedItemState.item, Shop)
    Drawing.drawMainInteractionPanel(panelRects.mainInteraction, gameState, uiElementRects, draggedItemState.item, battleState, Placement, {overlaysToDraw = {}, tooltipsToDraw = Drawing.tooltipsToDraw})
end

return BattleOverState