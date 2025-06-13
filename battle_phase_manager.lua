-- battle_phase_manager.lua
-- Manages the state machine for the different phases within a battle round.

local BattlePhaseManager = {}
BattlePhaseManager.__index = BattlePhaseManager

function BattlePhaseManager:new()
    local instance = setmetatable({}, self)
    instance.phases = {} -- Will be populated with phase objects
    instance.currentState = nil
    instance.currentStateName = nil
    instance.services = {} -- To hold references to modal, etc.
    return instance
end

function BattlePhaseManager:init(services, phaseFiles)
    self.services = services
    for name, phaseClass in pairs(phaseFiles) do
        self.phases[name] = phaseClass:new(self) -- Pass manager reference to phases
    end
end

function BattlePhaseManager:changePhase(newPhaseName, gameState, battleState)
    local newPhase = self.phases[newPhaseName]
    if not newPhase then
        print("ERROR (BattlePhaseManager): Unknown phase: " .. tostring(newPhaseName))
        return false
    end

    if self.currentState and self.currentState.exit then
        self.currentState:exit(gameState, battleState)
    end

    self.currentState = newPhase
    self.currentStateName = newPhaseName
    print("Battle phase changed to: " .. self.currentStateName)

    if self.currentState.enter then
        self.currentState:enter(gameState, battleState)
    end

    return true
end

function BattlePhaseManager:update(dt, gameState, battleState)
    if self.currentState and self.currentState.update then
        self.currentState:update(dt, gameState, battleState)
    end
end

function BattlePhaseManager:getCurrentPhaseName()
    return self.currentStateName
end

return BattlePhaseManager