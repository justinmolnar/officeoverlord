-- game_states/hiring_state.lua
local BaseState = require("game_states.base_state")
local Drawing = require("drawing")
local Shop = require("shop")

local HiringState = setmetatable({}, BaseState)
HiringState.__index = HiringState

function HiringState:new()
    return setmetatable(BaseState:new(), self)
end

function HiringState:enter(gameState, battleState, context)
    print("Entering Hiring and Upgrades phase")
    
    -- Initialize shop offers if needed
    if gameState.currentShopOffers and gameState.currentShopOffers.restockCountThisWeek == 0 then
        Shop:populateOffers(gameState, gameState.currentShopOffers, gameState.purchasedPermanentUpgrades, false)
    end
    
    -- Clear any dragged items
    if context.draggedItemState then
        context.draggedItemState.item = nil
    end
    
    -- Rebuild UI components for this state
    if context.buildUIComponents then
        context.buildUIComponents()
    end
end

function HiringState:exit(gameState, battleState, context)
    print("Exiting Hiring and Upgrades phase")
end

function HiringState:update(dt, gameState, battleState, context)
    -- No special update logic needed for hiring phase
end

function HiringState:draw(gameState, battleState, context)
    -- Draw all the panels for hiring phase
    local panelRects = context.panelRects
    local uiElementRects = context.uiElementRects
    local draggedItemState = context.draggedItemState
    local sprintOverviewState = context.sprintOverviewState
    local Placement = context.Placement
    
    Drawing.drawRemoteWorkersPanel(panelRects.remoteWorkers, gameState, uiElementRects, draggedItemState.item, battleState, Placement)
    Drawing.drawGameInfoPanel(panelRects.gameInfo, gameState, uiElementRects, sprintOverviewState.isVisible, battleState)
    Drawing.drawWorkloadBar(panelRects.workloadBar, gameState, battleState)
    Drawing.drawShopPanel(panelRects.shop, gameState, uiElementRects, draggedItemState.item, Shop)
    Drawing.drawMainInteractionPanel(panelRects.mainInteraction, gameState, uiElementRects, draggedItemState.item, battleState, Placement, {overlaysToDraw = {}, tooltipsToDraw = Drawing.tooltipsToDraw})
    Drawing.drawPurchasedUpgradesDisplay(panelRects.purchasedUpgradesDisplay, gameState, uiElementRects)
end

return HiringState