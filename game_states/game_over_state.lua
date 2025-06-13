-- game_states/game_over_state.lua
local BaseState = require("game_states.base_state")
local Drawing = require("drawing")

local GameOverState = setmetatable({}, BaseState)
GameOverState.__index = GameOverState

function GameOverState:new()
    return setmetatable(BaseState:new(), self)
end

function GameOverState:enter(gameState, battleState, context)
    print("Entering Game Over phase")
    
    -- Rebuild UI for game over phase
    if context.buildUIComponents then
        context.buildUIComponents()
    end
end

function GameOverState:exit(gameState, battleState, context)
    print("Exiting Game Over phase")
end

function GameOverState:update(dt, gameState, battleState, context)
    -- No special update logic needed for game over
end

function GameOverState:draw(gameState, battleState, context)
    -- Draw minimal panels for game over phase
    local panelRects = context.panelRects
    local uiElementRects = context.uiElementRects
    local sprintOverviewState = context.sprintOverviewState
    
    Drawing.drawGameInfoPanel(panelRects.gameInfo, gameState, uiElementRects, false, battleState)
    
    -- Draw a game over overlay
    local screenW, screenH = love.graphics.getDimensions()
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle("fill", 0, 0, screenW, screenH)
    
    love.graphics.setFont(Drawing.UI.titleFont or Drawing.UI.fontLarge)
    love.graphics.setColor(1, 0.2, 0.2, 1)
    love.graphics.printf("GAME OVER", 0, screenH/2 - 50, screenW, "center")
    
    love.graphics.setFont(Drawing.UI.font)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.printf("Your company has failed.\nBetter luck next time!", 0, screenH/2, screenW, "center")
end

return GameOverState