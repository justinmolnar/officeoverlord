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
    
    local status = Battle:startChallenge(gameState, Drawing.showModal)
    if status ~= "battle_active" then
        if context.setGamePhase then
            context.setGamePhase(status)
        end
        return
    end

    battleState.activeEmployees = {}
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

    gameState.currentWeekCycles = 0
    gameState.totalSalariesPaidThisWeek = 0
    
    local placed, remote = {}, {}
    local topRowDeskIds = {"desk-0", "desk-1", "desk-2"}

    for _, emp in ipairs(gameState.hiredEmployees) do
        local isDisabled = false
        if emp.isTraining then isDisabled = true end
        if emp.special and emp.special.does_not_work then isDisabled = true end
        
        local availabilityArgs = { employee = emp, isDisabled = false, reason = "" }
        require("effects_dispatcher").dispatchEvent("onEmployeeAvailabilityCheck", gameState, availabilityArgs)
        if availabilityArgs.isDisabled then
            isDisabled = true
            if availabilityArgs.reason ~= "" then
                print(availabilityArgs.reason)
            end
        end
        
        if gameState.temporaryEffectFlags.isRemoteWorkDisabled and emp.variant == 'remote' then isDisabled = true end
        if gameState.temporaryEffectFlags.isTopRowDisabled and emp.deskId then
            for _, topDeskId in ipairs(topRowDeskIds) do 
                if emp.deskId == topDeskId then 
                    isDisabled = true 
                    break 
                end 
            end
        end
        if not isDisabled then
            if emp.variant == 'remote' then 
                table.insert(remote, emp) 
            elseif emp.deskId then 
                table.insert(placed, emp)
            end
        end
    end
    
    table.sort(placed, function(a, b) 
        return (tonumber(string.match(a.deskId, "desk%-(%d+)")) or 99) < (tonumber(string.match(b.deskId, "desk%-(%d+)")) or 99) 
    end)
    
    battleState.activeEmployees = {}
    for _, emp in ipairs(placed) do 
        table.insert(battleState.activeEmployees, emp) 
    end
    for _, emp in ipairs(remote) do 
        table.insert(battleState.activeEmployees, emp) 
    end
    
    local battleStartArgs = { 
        activeEmployees = battleState.activeEmployees, 
        remoteWorkers = remote,
        placedWorkers = placed
    }
    require("effects_dispatcher").dispatchEvent("onBattleStart", gameState, battleStartArgs)
    require("effects_dispatcher").dispatchEvent("onWorkOrderDetermined", gameState, battleStartArgs)
    
    battleState.activeEmployees = battleStartArgs.activeEmployees
    
    if #battleState.activeEmployees == 0 then
        Drawing.showModal("Stuck!", "No employees available to work. Any staff in training will be ready next cycle.")
        local timer = require("love.timer")
        if timer and timer.after then
            timer.after(1.0, function()
                local result = Battle:endWorkCycleRound(gameState, 0, Drawing.showModal)
                if result == "lost_budget" then 
                    if context.setGamePhase then context.setGamePhase("game_over") end
                elseif result == "lost_bailout" then 
                    if context.setGamePhase then context.setGamePhase("hiring_and_upgrades") end
                end
            end)
        end
    end
    
    if context.buildUIComponents then
        context.buildUIComponents()
    end
end

function BattleState:exit(gameState, battleState, context)
    print("Exiting Battle phase")
end

function BattleState:update(dt, gameState, battleState, context)
    if context.updateBattle then
        context.updateBattle(dt)
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
    Drawing.drawPurchasedUpgradesDisplay(panelRects.purchasedUpgradesDisplay, gameState, uiElementRects)
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