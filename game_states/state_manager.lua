-- game_states/state_manager.lua
local StateManager = {}

local HiringState = require("game_states.hiring_state")
local BattleState = require("game_states.battle_state")
local GameOverState = require("game_states.game_over_state")
local GameWonState = require("game_states.game_won_state")
local BattleOverState = require("game_states.battle_over_state")


function StateManager:new()
    local BattleOverState = require("game_states.battle_over_state")
    local instance = {
        states = {
            hiring_and_upgrades = HiringState:new(),
            battle_active = BattleState:new(),
            battle_over = BattleOverState:new(),
            game_over = GameOverState:new(),
            game_won = GameWonState:new()
        },
        currentState = nil,
        currentStateName = nil
    }
    setmetatable(instance, self)
    self.__index = self
    return instance
end

function StateManager:changeState(newStateName, gameState, battleState, context)
    local newState = self.states[newStateName]
    if not newState then
        print("ERROR: Unknown state: " .. tostring(newStateName))
        return false
    end
    
    -- Exit current state
    if self.currentState and self.currentState.exit then
        self.currentState:exit(gameState, battleState, context)
    end
    
    -- Change to new state
    self.currentState = newState
    self.currentStateName = newStateName
    
    -- Enter new state
    if self.currentState.enter then
        self.currentState:enter(gameState, battleState, context)
    end
    
    return true
end

function StateManager:update(dt, gameState, battleState, context)
    if self.currentState and self.currentState.update then
        self.currentState:update(dt, gameState, battleState, context)
    end
end

function StateManager:draw(gameState, battleState, context)
    if self.currentState and self.currentState.draw then
        self.currentState:draw(gameState, battleState, context)
    end
end

function StateManager:handleInput(x, y, button, gameState, battleState, context)
    if self.currentState and self.currentState.handleInput then
        return self.currentState:handleInput(x, y, button, gameState, battleState, context)
    end
    return false
end

function StateManager:getCurrentStateName()
    return self.currentStateName
end

return StateManager