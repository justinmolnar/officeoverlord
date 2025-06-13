-- game_states/game_won_state.lua
local BaseState = require("game_states.base_state")
local Drawing = require("drawing")

local GameWonState = setmetatable({}, BaseState)
GameWonState.__index = GameWonState

function GameWonState:new()
    return setmetatable(BaseState:new(), self)
end

function GameWonState:enter(gameState, battleState, context)
    print("Entering Game Won phase")
    
    -- Rebuild UI for game won phase
    if context.buildUIComponents then
        context.buildUIComponents()
    end
end

function GameWonState:exit(gameState, battleState, context)
    print("Exiting Game Won phase")
end

function GameWonState:update(dt, gameState, battleState, context)
    -- No special update logic needed for game won
end

function GameWonState:draw(gameState, battleState, context)
    -- Draw minimal panels for game won phase
    local panelRects = context.panelRects
    local uiElementRects = context.uiElementRects
    local sprintOverviewState = context.sprintOverviewState
    
    Drawing.drawGameInfoPanel(panelRects.gameInfo, gameState, uiElementRects, false, battleState)
    
    -- Draw a victory overlay
    local screenW, screenH = love.graphics.getDimensions()
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle("fill", 0, 0, screenW, screenH)
    
    love.graphics.setFont(Drawing.UI.titleFont or Drawing.UI.fontLarge)
    love.graphics.setColor(0.2, 1, 0.2, 1)
    love.graphics.printf("CONGRATULATIONS!", 0, screenH/2 - 50, screenW, "center")
    
    love.graphics.setFont(Drawing.UI.font)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.printf("You have successfully completed all sprints!\nYour company is a resounding success!", 0, screenH/2, screenW, "center")
end

return GameWonState