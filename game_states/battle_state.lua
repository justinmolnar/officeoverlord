-- Updated game_states/battle_state.lua
local BaseState = require("game_states.base_state")
local Drawing = require("drawing")
local Battle = require("battle")

local BattleState = setmetatable({}, BaseState)
BattleState.__index = BattleState

function BattleState:new()
    return setmetatable(BaseState:new(), self)
end

function BattleState:enter(gameState, battleState, context)
    print("Entering Battle phase")
    
    local status = Battle:startChallenge(gameState, function(...) context.modal:show(...) end)
    if status ~= "battle_active" then
        if context.setGamePhase then
            context.setGamePhase(status)
        end
        return
    end

    battleState.nextEmployeeIndex = 1
    battleState.currentWorkerId = nil
    battleState.lastContribution = nil
    battleState.phase = 'idle'
    battleState.timer = 0
    battleState.isShaking = false
    battleState.chipAmountRemaining = 0
    battleState.chipSpeed = 100
    battleState.chipTimer = 0
    battleState.roundTotalContribution = 0
    battleState.lastRoundContributions = {}
    battleState.changedEmployeesForAnimation = {}
    battleState.nextChangedEmployeeIndex = 1
    battleState.progressMarkers = {}
    
    -- NEW: Turn tracking for speed progression
    battleState.totalTurnsThisItem = 0
    battleState.speedMultiplier = 1.0
    
    -- NEW: Fading contributions system
    battleState.fadingContributions = {}

    gameState.currentWeekCycles = 0
    gameState.totalSalariesPaidThisWeek = 0
    
    -- The complex filtering logic is now replaced with a single function call
    battleState.activeEmployees = Battle:getActiveEmployees(gameState)

    -- The rest of the original logic remains to sort and dispatch events
    local placed, remote = {}, {}
    for _, emp in ipairs(battleState.activeEmployees) do
        if emp.variant == 'remote' then
            table.insert(remote, emp)
        elseif emp.deskId then
            table.insert(placed, emp)
        end
    end
    
    table.sort(placed, function(a, b) 
        return (tonumber(string.match(a.deskId, "desk%-(%d+)")) or 99) < (tonumber(string.match(b.deskId, "desk%-(%d+)")) or 99) 
    end)
    
    battleState.activeEmployees = {}
    for _, emp in ipairs(placed) do table.insert(battleState.activeEmployees, emp) end
    for _, emp in ipairs(remote) do table.insert(battleState.activeEmployees, emp) end
    
    local battleStartArgs = { 
        activeEmployees = battleState.activeEmployees, 
        remoteWorkers = remote,
        placedWorkers = placed
    }
    require("effects_dispatcher").dispatchEvent("onBattleStart", gameState, { modal = context.modal, battlePhaseManager = context.battlePhaseManager }, battleStartArgs)
    require("effects_dispatcher").dispatchEvent("onWorkOrderDetermined", gameState, { modal = context.modal, battlePhaseManager = context.battlePhaseManager }, battleStartArgs)
    
    battleState.activeEmployees = battleStartArgs.activeEmployees
    
    if #battleState.activeEmployees == 0 then
        context.modal:show("No Active Staff!", "You need to hire and place at least one employee to start work. The hiring phase will continue.", {
            {text = "Back to Hiring", onClick = function() 
                context.modal:hide()
                if context.setGamePhase then 
                    context.setGamePhase("hiring_and_upgrades") 
                end
            end, style = "primary"}
        })
        return
    end
    
    if context.buildUIComponents then
        context.buildUIComponents()
    end
end

function BattleState:exit(gameState, battleState, context)
    print("Exiting Battle phase")
end

function BattleState:update(dt, gameState, battleState, context)
    if context.battlePhaseManager then
        context.battlePhaseManager:update(dt, gameState, battleState)
    end
    
    -- NEW: Update fading contributions
    if battleState.fadingContributions then
        local fadeSpeed = 0.8 -- Fade out over ~1.25 seconds
        for instanceId, fadeData in pairs(battleState.fadingContributions) do
            fadeData.alpha = fadeData.alpha - (fadeSpeed * dt * (battleState.speedMultiplier or 1.0))
            if fadeData.alpha <= 0 then
                battleState.fadingContributions[instanceId] = nil
            end
        end
    end
end

function BattleState:draw(gameState, battleState, context)
    -- Draw all the panels for battle phase
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

function BattleState:handleInput(x, y, button, gameState, battleState, context)
    -- In battle phase, most inputs should be disabled
    if button == 1 and gameState.gamePhase == "battle_active" then
        return false -- Don't allow interactions during battle
    end
    
    -- Fall back to default component handling
    return BaseState.handleInput(self, x, y, button, gameState, battleState, context)
end

return BattleState