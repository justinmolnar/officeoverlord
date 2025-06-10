-- main.lua
-- Main game file for Office Overlord LÖVE 2D Edition - Single Screen Layout

local timer = require("love.timer") 

local GameData = require("data")
local GameState = require("game_state")
local Drawing = require("drawing") 
local Shop = require("shop")
local Placement = require("placement")
local Battle = require("battle")
local Employee = require("employee")
local EffectsDispatcher = require("effects_dispatcher")
local InputHandler = require("input_handler")

function _G.getCurrentMaxLevel(gameState)
    local eventArgs = { maxLevel = 3 }
    require("effects_dispatcher").dispatchEvent("onGetMaxLevel", gameState, eventArgs)
    return eventArgs.maxLevel
end

local gameState
local tooltipsToDraw = {}
local overlaysToDraw = {}

-- State variables are wrapped in tables to be passed by reference
local sprintOverviewState = { isVisible = false }
local sprintOverviewRects = {} -- To hold rects for the new panel UI

local debugMenuState = { isVisible = false }
local debug = {
    rect = {},
    employeeDropdown = { options = {}, selected = 1, isOpen = false, rect = {} },
    upgradeDropdown = { options = {}, selected = 1, isOpen = false, rect = {} },
    checkboxes = {
        remote = { checked = false, rect = {} },
        foil = { checked = false, rect = {} },
        holo = { checked = false, rect = {} }
    },
    buttons = {}
}

local function safeTimerAfter(delay, callback)
    local timerToUse = love.timer or timer
    if timerToUse and type(timerToUse.after) == "function" then
        timerToUse.after(delay, callback)
    else
        print("FATAL ERROR: Timer module is not available. Check conf.lua. Executing callback immediately.")
        callback()
    end
end

local panelRects = {
    gameInfo = {}, remoteWorkers = {}, mainInteraction = {}, 
    shop = {}, purchasedUpgradesDisplay = {}, workloadBar = {}
}

local uiElementRects = {
    desks = {}, permanentUpgrades = {}, remote = {}, 
    remotePanelDropTarget = {}, shopEmployees = {},
    shopUpgradeOffer = nil, shopRestock = nil, actionButtons = {}
}

-- draggedItem is now a table so it can be passed as a reference
local draggedItemState = { item = nil }

local battleState = {
    activeEmployees = {},
    nextEmployeeIndex = 1,
    currentWorkerId = nil,
    lastContribution = nil, -- For the turn-by-turn animation
    phase = 'idle',
    timer = 0,
    isShaking = false,
    -- Chip-away animation state
    chipAmountRemaining = 0,
    chipSpeed = 100,
    chipTimer = 0,
    -- New state for accumulate-then-apply logic
    roundTotalContribution = 0,
    lastRoundContributions = {}, -- Stores { [instanceId] = contributionObject }
    changedEmployeesForAnimation = {},
    nextChangedEmployeeIndex = 1
}
_G.battleState = battleState -- Make battleState global for Drawing module to access

_G.showMessage = function(title, message, buttons, customWidth)
    Drawing.showModal(title, message, buttons, customWidth) 
end

function getEmployeeFromGameState(gs, instanceId)
    if not gs or not gs.hiredEmployees or not instanceId then return nil end
    for _, emp in ipairs(gs.hiredEmployees) do
        if emp.instanceId == instanceId then return emp end
    end
    return nil
end
_G.getEmployeeFromGameState = getEmployeeFromGameState -- Make global for Drawing module to access

function initializeDebugMenu()
    -- Populate employee options
    debug.employeeDropdown.options = {}
    for _, card in ipairs(GameData.BASE_EMPLOYEE_CARDS) do
        table.insert(debug.employeeDropdown.options, { name = card.name, id = card.id })
    end
    table.sort(debug.employeeDropdown.options, function(a, b) return a.name < b.name end)
    debug.employeeDropdown.selected = 1
    debug.employeeDropdown.scrollOffset = 0

    -- Populate upgrade options
    debug.upgradeDropdown.options = {}
    for _, upg in ipairs(GameData.ALL_UPGRADES) do
        table.insert(debug.upgradeDropdown.options, { name = upg.name, id = upg.id })
    end
    table.sort(debug.upgradeDropdown.options, function(a, b) return a.name < b.name end)
    debug.upgradeDropdown.selected = 1
    debug.upgradeDropdown.scrollOffset = 0
    
    -- State for hotkey repeating (only for money keys)
    debug.hotkeyState = {
        plus = { timer = 0, initial = 0.4, repeatDelay = 0.1 },
        minus = { timer = 0, initial = 0.4, repeatDelay = 0.1 }
    }
end

function love.load()
    -- New shader variables
    Drawing.foilShader = love.graphics.newShader("foil.fs") 
    Drawing.holoShader = love.graphics.newShader("holo.fs") 

    gameState = GameState:new()
    _G.gameState = gameState
    love.window.setTitle("Office Overlord - Command Center v4.1 Sprints")

    local success
    
    -- Load the primary font and its emoji fallback for the regular size
    local primaryFont, emojiFont
    success, primaryFont = pcall(love.graphics.newFont, "Arial.ttf", 13)
    if not success then primaryFont = love.graphics.newFont(13); print("Arial.ttf not found, using default font 13pt.") end
    success, emojiFont = pcall(love.graphics.newFont, "NotoEmoji.ttf", 13)
    if success then
        primaryFont:setFallbacks(emojiFont)
        print("Emoji fallback font loaded for size 13.")
    else
        print("WARNING: NotoEmoji.ttf not found. Emojis will not render.")
    end
    Drawing.UI.font = primaryFont

    -- Load the primary font and its emoji fallback for the small size
    local primaryFontSmall, emojiFontSmall
    success, primaryFontSmall = pcall(love.graphics.newFont, "Arial.ttf", 9)
    if not success then primaryFontSmall = love.graphics.newFont(9); print("Arial.ttf not found, using default font 9pt.") end
    success, emojiFontSmall = pcall(love.graphics.newFont, "NotoEmoji.ttf", 9)
    if success then
        primaryFontSmall:setFallbacks(emojiFontSmall)
        print("Emoji fallback font loaded for size 9.")
    end
    Drawing.UI.fontSmall = primaryFontSmall

    -- Load the primary font and its emoji fallback for the large size
    local primaryFontLarge, emojiFontLarge
    success, primaryFontLarge = pcall(love.graphics.newFont, "Arial.ttf", 18)
    if not success then primaryFontLarge = love.graphics.newFont(18); print("Arial.ttf not found, using default font 18pt.") end
    success, emojiFontLarge = pcall(love.graphics.newFont, "NotoEmoji.ttf", 18)
    if success then
        primaryFontLarge:setFallbacks(emojiFontLarge)
        print("Emoji fallback font loaded for size 18.")
    end
    Drawing.UI.fontLarge = primaryFontLarge

    -- The title font can also have a fallback if you plan to use emojis in titles
    local primaryFontTitle, emojiFontTitle
    success, primaryFontTitle = pcall(love.graphics.newFont, "Arial.ttf", 24)
    if not success then primaryFontTitle = love.graphics.newFont(24); print("Arial.ttf not found, using default font 24pt.") end
    success, emojiFontTitle = pcall(love.graphics.newFont, "NotoEmoji.ttf", 24)
    if success then
        primaryFontTitle:setFallbacks(emojiFontTitle)
        print("Emoji fallback font loaded for size 24.")
    end
    Drawing.UI.titleFont = primaryFontTitle
    
    love.graphics.setFont(Drawing.UI.font) 
    _G.userId = "Player-" .. love.math.random(1000, 9999)

    definePanelRects()
    
    initializeDebugMenu() 

    InputHandler.init({
        gameState = gameState,
        uiElementRects = uiElementRects,
        draggedItemState = draggedItemState,
        battleState = battleState,
        panelRects = panelRects,
        sprintOverviewState = sprintOverviewState,
        sprintOverviewRects = sprintOverviewRects,
        debugMenuState = debugMenuState,
        debug = debug,
        callbacks = {
            setGamePhase = setGamePhase,
            resetGameAndGlobals = resetGameAndGlobals
        }
    })
    
    setGamePhase("hiring_and_upgrades")
    Placement:updateDeskAvailability(gameState.desks)
    love.math.setRandomSeed(os.time() + love.timer.getTime())
end

function definePanelRects()
    local screenW, screenH = love.graphics.getWidth(), love.graphics.getHeight()
    local padding = 10

    panelRects.shop = {width=math.floor(screenW*0.22), x=screenW-math.floor(screenW*0.22)-padding, y=padding, height=screenH-2*padding}
    local shopLeftEdge = panelRects.shop.x - padding

    panelRects.remoteWorkers = {x=padding, y=padding, width=shopLeftEdge - 2*padding, height=math.floor(screenH*0.15)}
    uiElementRects.remotePanelDropTarget = {x=panelRects.remoteWorkers.x, y=panelRects.remoteWorkers.y, w=panelRects.remoteWorkers.width, h=panelRects.remoteWorkers.height}
    panelRects.purchasedUpgradesDisplay = {x=padding, height=math.floor(screenH*0.10), y=screenH-math.floor(screenH*0.10)-padding, width=shopLeftEdge - 2*padding}
    panelRects.gameInfo = {x=padding, y=panelRects.remoteWorkers.y+panelRects.remoteWorkers.height+padding, width=math.floor(screenW*0.20), height=panelRects.purchasedUpgradesDisplay.y-panelRects.remoteWorkers.y-panelRects.remoteWorkers.height-2*padding}
    panelRects.workloadBar = {x=panelRects.gameInfo.x+panelRects.gameInfo.width+padding, y=panelRects.remoteWorkers.y+panelRects.remoteWorkers.height+padding, width=math.floor(screenW*0.04), height=panelRects.purchasedUpgradesDisplay.y-panelRects.remoteWorkers.y-panelRects.remoteWorkers.height-2*padding}
    panelRects.mainInteraction = {x=panelRects.workloadBar.x+panelRects.workloadBar.width+padding, y=panelRects.remoteWorkers.y+panelRects.remoteWorkers.height+padding, width=shopLeftEdge-panelRects.workloadBar.x-panelRects.workloadBar.width-2*padding, height=panelRects.purchasedUpgradesDisplay.y-panelRects.remoteWorkers.y-panelRects.remoteWorkers.height-2*padding}

    for _, p in pairs(panelRects) do
        if p.width <= 0 then p.width = 1 end
        if p.height <= 0 then p.height = 1 end
    end
end

function love.update(dt)
    InputHandler.update(dt) -- This line runs the key-hold detection logic
    if gameState.gamePhase == "battle_active" then
        updateBattle(dt)
    end
end

function love.keypressed(key)
    InputHandler.onKeyPress(key)
end

function love.mousewheelmoved(x, y)
    InputHandler.onMouseWheelMoved(x, y)
end

function love.mousepressed(x, y, button, istouch, presses)
    InputHandler.onMousePress(x, y, button)
end

function love.mousereleased(x, y, button, istouch)
    InputHandler.onMouseRelease(x, y, button)
end

function love.draw()
    love.graphics.setBackgroundColor(Drawing.UI.colors.background)
    love.graphics.clear()

    tooltipsToDraw = {}
    Drawing.tooltipsToDraw = tooltipsToDraw -- Pass to Drawing module
    
    uiElementRects.shopLockButtons = {}

    local draggedItem = draggedItemState.item 

    Drawing.drawRemoteWorkersPanel(panelRects.remoteWorkers, gameState, uiElementRects, draggedItem, battleState)
    Drawing.drawGameInfoPanel(panelRects.gameInfo, gameState, uiElementRects, sprintOverviewState.isVisible)
    Drawing.drawWorkloadBar(panelRects.workloadBar, gameState, battleState)
    Drawing.drawShopPanel(panelRects.shop, gameState, uiElementRects, draggedItem, Shop)
    Drawing.drawMainInteractionPanel(panelRects.mainInteraction, gameState, uiElementRects, draggedItem, battleState, Placement, {overlaysToDraw = overlaysToDraw, tooltipsToDraw = tooltipsToDraw}) 
    Drawing.drawPurchasedUpgradesDisplay(panelRects.purchasedUpgradesDisplay, gameState, uiElementRects)
    
    if draggedItem then
        local itemDataToDraw = draggedItem.data
        if itemDataToDraw then 
            local mouseX, mouseY = love.mouse.getPosition()
            -- MODIFICATION: Pass uiElementRects to the dragged item's card drawing function
            Drawing.drawEmployeeCard(itemDataToDraw, mouseX - 40, mouseY - 50, 80, 100, "dragged", gameState, battleState, tooltipsToDraw, Drawing.foilShader, Drawing.holoShader, uiElementRects)
        end
    end
    
    if #tooltipsToDraw > 0 then
        for _, tip in ipairs(tooltipsToDraw) do
            Drawing.drawPanel(tip.x, tip.y, tip.w, tip.h, {0.1, 0.1, 0.1, 0.95}, {0.3, 0.3, 0.3, 1})
            
            if tip.coloredLines then
                love.graphics.setFont(Drawing.UI.font)
                local currentY = tip.y + 8
                local lineHeight = Drawing.UI.font:getHeight()
                
                for _, line in ipairs(tip.coloredLines) do
                    if line:match("^%[") then
                        local colorEnd = line:find("%]")
                        if colorEnd then
                            local colorStr = line:sub(2, colorEnd - 1)
                            local text = line:sub(colorEnd + 1)
                            local r, g, b = colorStr:match("([%d%.]+),([%d%.]+),([%d%.]+)")
                            if r and g and b then
                                love.graphics.setColor(tonumber(r), tonumber(g), tonumber(b), 1)
                            else
                                love.graphics.setColor(1, 1, 1, 1)
                            end
                            love.graphics.print(text, tip.x + 8, currentY)
                        else
                            love.graphics.setColor(1, 1, 1, 1)
                            love.graphics.print(line, tip.x + 8, currentY)
                        end
                    else
                        love.graphics.setColor(1, 1, 1, 1)
                        love.graphics.print(line, tip.x + 8, currentY)
                    end
                    currentY = currentY + lineHeight
                end
            else
                love.graphics.setFont(Drawing.UI.font)
                love.graphics.setColor(1, 1, 1, 1)
                Drawing.drawTextWrapped(tip.text, tip.x + 5, tip.y + 3, tip.w - 10, Drawing.UI.font, "left")
            end
        end
    end

    Drawing.drawSprintOverviewPanel(sprintOverviewRects, sprintOverviewState.isVisible, gameState)

    Drawing.drawModal()

    if debugMenuState.isVisible then
        Drawing.drawDebugMenu(debug, Drawing.foilShader, Drawing.holoShader)
    end
end

function updateBattle(dt)
    if battleState.phase == 'idle' or battleState.phase == 'fast_recalculate_and_setup' then
        for _, emp in ipairs(battleState.activeEmployees) do
            emp.isFirstMover = nil
            emp.isAutomated = nil
        end
    end

    battleState.timer = battleState.timer - dt

    if battleState.phase == 'idle' then
        if battleState.nextEmployeeIndex > #battleState.activeEmployees then
            battleState.phase = 'pre_apply_contribution'
        else
            local currentEmployee = battleState.activeEmployees[battleState.nextEmployeeIndex]
            if currentEmployee then
                if gameState.temporaryEffectFlags.automatedEmployeeId == currentEmployee.instanceId then
                    currentEmployee.isAutomated = true
                end

                EffectsDispatcher.dispatchEvent("onTurnStart", gameState, { currentEmployee = currentEmployee })
            end
            battleState.phase = 'starting_turn'
        end

    elseif battleState.phase == 'starting_turn' then
        local currentEmployee = battleState.activeEmployees[battleState.nextEmployeeIndex]
        battleState.currentWorkerId = currentEmployee.instanceId
        battleState.lastContribution = Battle:calculateEmployeeContribution(currentEmployee, gameState)
        battleState.phase = 'showing_productivity'; battleState.timer = 0.5 

    elseif battleState.phase == 'showing_productivity' then
        if battleState.timer <= 0 then battleState.phase = 'showing_focus'; battleState.timer = 0.6; battleState.isShaking = true end
    elseif battleState.phase == 'showing_focus' then
        if battleState.timer <= 0 then battleState.isShaking = false; battleState.phase = 'showing_total'; battleState.timer = 0.8; battleState.isShaking = true end

    elseif battleState.phase == 'showing_total' then
        if battleState.timer <= 0 then
            battleState.isShaking = false
            battleState.roundTotalContribution = battleState.roundTotalContribution + battleState.lastContribution.totalContribution
            battleState.lastRoundContributions[battleState.currentWorkerId] = battleState.lastContribution
            battleState.phase = 'turn_over'; battleState.timer = 0.3
        end

    elseif battleState.phase == 'turn_over' then
        if battleState.timer <= 0 then
            battleState.currentWorkerId = nil; battleState.lastContribution = nil
            battleState.nextEmployeeIndex = battleState.nextEmployeeIndex + 1
            battleState.phase = 'idle'
        end

    elseif battleState.phase == 'fast_recalculate_and_setup' then
        battleState.roundTotalContribution = 0
        battleState.changedEmployeesForAnimation = {}
        local currentRoundContributions = {}
        for _, emp in ipairs(battleState.activeEmployees) do
            local newContrib = Battle:calculateEmployeeContribution(emp, gameState)
            currentRoundContributions[emp.instanceId] = newContrib
            local oldContrib = battleState.lastRoundContributions[emp.instanceId]
            if not oldContrib or newContrib.totalContribution ~= oldContrib.totalContribution then
                table.insert(battleState.changedEmployeesForAnimation, {emp = emp, new = newContrib, old = oldContrib})
            end
        end
        battleState.lastRoundContributions = currentRoundContributions
        
        for _, contrib in pairs(currentRoundContributions) do
            battleState.roundTotalContribution = battleState.roundTotalContribution + contrib.totalContribution
        end
        
        battleState.nextChangedEmployeeIndex = 1
        
        if #battleState.changedEmployeesForAnimation == 0 then
            battleState.timer = 0.4 
            battleState.phase = 'wait_for_apply'
        else
            battleState.phase = 'animating_changes'
            battleState.timer = 0
        end

    elseif battleState.phase == 'wait_for_apply' then
        if battleState.timer <= 0 then
            battleState.phase = 'pre_apply_contribution'
        end

    elseif battleState.phase == 'animating_changes' then
        if battleState.timer <= 0 then
            if battleState.currentWorkerId then
                battleState.nextChangedEmployeeIndex = battleState.nextChangedEmployeeIndex + 1
            end
            if battleState.nextChangedEmployeeIndex > #battleState.changedEmployeesForAnimation then
                battleState.currentWorkerId = nil; battleState.lastContribution = nil
                battleState.phase = 'pre_apply_contribution'
            else
                local changeInfo = battleState.changedEmployeesForAnimation[battleState.nextChangedEmployeeIndex]
                battleState.currentWorkerId = changeInfo.emp.instanceId
                battleState.lastContribution = changeInfo.new
                battleState.isShaking = true
                battleState.timer = 0.5
            end
        end
        
    elseif battleState.phase == 'pre_apply_contribution' then
        local endOfRoundEventArgs = { pyramidSchemeActive = false }
        EffectsDispatcher.dispatchEvent("onEndOfRound", gameState, endOfRoundEventArgs)

        if endOfRoundEventArgs.pyramidSchemeActive then
            local contributions = {}
            for instId, contribData in pairs(battleState.lastRoundContributions) do
                contributions[instId] = contribData.totalContribution
            end
            
            local transfers = Battle:calculatePyramidSchemeTransfers(gameState, contributions)
            for instId, amount in pairs(transfers) do
                if battleState.lastRoundContributions[instId] then
                    battleState.lastRoundContributions[instId].totalContribution = battleState.lastRoundContributions[instId].totalContribution + amount
                end
            end
        end
        
        battleState.roundTotalContribution = 0
        for _, contribData in pairs(battleState.lastRoundContributions) do
            battleState.roundTotalContribution = battleState.roundTotalContribution + contribData.totalContribution
        end

        battleState.phase = 'apply_round_contribution'

    elseif battleState.phase == 'apply_round_contribution' then
        battleState.chipAmountRemaining = battleState.roundTotalContribution
        if battleState.chipAmountRemaining > 0 then
            local speedMultiplier = math.min(2 ^ gameState.currentWeekCycles, 16)
            battleState.chipSpeed = math.max(150, battleState.chipAmountRemaining * 2.5) * speedMultiplier
            battleState.chipTimer = 0
            battleState.phase = 'chipping_workload'
        else
            battleState.phase = 'ending_round'
        end
        battleState.roundTotalContribution = 0

    elseif battleState.phase == 'chipping_workload' then
        if battleState.chipAmountRemaining > 0 and gameState.currentWeekWorkload > 0 then
            battleState.chipTimer = battleState.chipTimer + dt
            local chipsToProcess = math.floor(battleState.chipTimer * battleState.chipSpeed)
            if chipsToProcess > 0 then
                local amountToChipThisFrame = math.min(battleState.chipAmountRemaining, chipsToProcess, gameState.currentWeekWorkload)
                gameState.currentWeekWorkload = gameState.currentWeekWorkload - amountToChipThisFrame
                battleState.chipAmountRemaining = battleState.chipAmountRemaining - amountToChipThisFrame
                battleState.chipTimer = battleState.chipTimer - (chipsToProcess / battleState.chipSpeed)
            end
        else
            battleState.isShaking = false; battleState.currentWorkerId = nil; battleState.lastContribution = nil
            if gameState.currentWeekWorkload <= 0 then handleWinCondition(); return end
            battleState.phase = 'ending_round'
        end

    elseif battleState.phase == 'ending_round' then
        if gameState.initialWorkloadForBar > 0 then
            local progress = math.max(0, gameState.currentWeekWorkload / gameState.initialWorkloadForBar)
            table.insert(battleState.progressMarkers, progress)
        end
        
        battleState.salariesToPayThisRound = Battle:calculateTotalSalariesForRound(gameState)
        battleState.phase = 'paying_salaries'

    elseif battleState.phase == 'paying_salaries' then
        battleState.salaryChipAmountRemaining = battleState.salariesToPayThisRound
        if battleState.salaryChipAmountRemaining > 0 then
            local speedMultiplier = math.min(2 ^ gameState.currentWeekCycles, 16)
            battleState.chipSpeed = math.max(150, battleState.salaryChipAmountRemaining * 3.0) * speedMultiplier
            battleState.chipTimer = 0
            battleState.phase = 'chipping_salaries'
        else
            local roundResult = Battle:endWorkCycleRound(gameState, 0)
            if roundResult == "lost_budget" then setGamePhase("game_over"); return end
            if roundResult == "lost_bailout" then 
                 local currentSprintData = GameData.ALL_SPRINTS[gameState.currentSprintIndex]; if currentSprintData then local currentWorkItemData = currentSprintData.workItems[gameState.currentWorkItemIndex]; if currentWorkItemData then gameState.currentWeekWorkload = currentWorkItemData.workload; gameState.initialWorkloadForBar = currentWorkItemData.workload; end; end
                 gameState.currentWeekCycles = 0; gameState.totalSalariesPaidThisWeek = 0; gameState.currentShopOffers = {employees={}, upgrade=nil, restockCountThisWeek=0}
                 setGamePhase("hiring_and_upgrades"); return 
            end
            local speedMultiplier = math.min(2 ^ gameState.currentWeekCycles, 16)
            battleState.timer = 1.0 / speedMultiplier
            battleState.phase = 'pausing_between_rounds'
        end

    elseif battleState.phase == 'chipping_salaries' then
        if battleState.salaryChipAmountRemaining > 0 then
             battleState.chipTimer = battleState.chipTimer + dt
             local chipsToProcess = math.floor(battleState.chipTimer * battleState.chipSpeed)
             if chipsToProcess > 0 then
                 local amountToChipThisFrame = math.min(battleState.salaryChipAmountRemaining, chipsToProcess)
                 gameState.budget = gameState.budget - amountToChipThisFrame
                 gameState.totalSalariesPaidThisWeek = gameState.totalSalariesPaidThisWeek + amountToChipThisFrame
                 battleState.salaryChipAmountRemaining = battleState.salaryChipAmountRemaining - amountToChipThisFrame
                 battleState.chipTimer = battleState.chipTimer - (chipsToProcess / battleState.chipSpeed)
             end
        else
            local roundResult = Battle:endWorkCycleRound(gameState, battleState.salariesToPayThisRound)
            if roundResult == "lost_budget" then setGamePhase("game_over"); return end
            if roundResult == "lost_bailout" then 
                 local currentSprintData = GameData.ALL_SPRINTS[gameState.currentSprintIndex]; if currentSprintData then local currentWorkItemData = currentSprintData.workItems[gameState.currentWorkItemIndex]; if currentWorkItemData then gameState.currentWeekWorkload = currentWorkItemData.workload; gameState.initialWorkloadForBar = currentWorkItemData.workload; end; end
                 gameState.currentWeekCycles = 0; gameState.totalSalariesPaidThisWeek = 0; gameState.currentShopOffers = {employees={}, upgrade=nil, restockCountThisWeek=0}
                 setGamePhase("hiring_and_upgrades"); return 
            end
            local speedMultiplier = math.min(2 ^ gameState.currentWeekCycles, 16)
            battleState.timer = 1.0 / speedMultiplier
            battleState.phase = 'pausing_between_rounds'
        end
    
    elseif battleState.phase == 'pausing_between_rounds' then
        if battleState.timer <= 0 then
            gameState.currentWeekCycles = gameState.currentWeekCycles + 1
            battleState.nextEmployeeIndex = 1
            battleState.phase = 'fast_recalculate_and_setup'
        end
    end
end


function assimilateTeamIntoBorg(gameState)
    if #gameState.hiredEmployees == 0 then
        Drawing.showModal("Assimilation Failed", "There is no one to assimilate.")
        return
    end

    local totalProd, totalFocus = 0, 0
    for _, emp in ipairs(gameState.hiredEmployees) do
        totalProd = totalProd + emp.baseProductivity
        totalFocus = totalFocus + emp.baseFocus
    end

    gameState.hiredEmployees = {}
    gameState.deskAssignments = {}

    local borgDrone = Employee:new('borg_drone', 'standard', "Borg Drone")
    borgDrone.baseProductivity = totalProd
    borgDrone.baseFocus = totalFocus
    
    table.insert(gameState.hiredEmployees, borgDrone)
    Placement:handleEmployeeDropOnDesk(gameState, borgDrone, "desk-4", nil)

    Drawing.showModal("Resistance is Futile", "Your team has been assimilated into a single Borg Drone. You are now the Hivemind.")
end
_G.assimilateTeamIntoBorg = assimilateTeamIntoBorg -- Make global for Shop module

function performMultiverseMerger(gameState)
    local confirmSwap = function()
        local numEmployees = #gameState.hiredEmployees
        if numEmployees == 0 then
            Drawing.showModal("Merger Failed", "There is no team to merge with the multiverse.")
            return
        end
        
        gameState.hiredEmployees = {}
        gameState.deskAssignments = {}
        
        local newTeam = {}
        for i = 1, numEmployees do
            table.insert(newTeam, Shop:_generateRandomEmployeeOffer())
        end
        
        gameState.hiredEmployees = newTeam

        local officeWorkers = {}
        for _, emp in ipairs(gameState.hiredEmployees) do
            if emp.variant ~= 'remote' then
                table.insert(officeWorkers, emp)
            end
        end

        for _, desk in ipairs(gameState.desks) do
            if #officeWorkers == 0 then break end
            if desk.status == 'owned' then
                local worker = table.remove(officeWorkers, 1)
                Placement:handleEmployeeDropOnDesk(gameState, worker, desk.id, nil)
            end
        end

        gameState.temporaryEffectFlags.multiverseMergerAvailable = false
        Drawing.showModal("Worlds Collide!", "Your team has been swapped with one from an alternate reality!")
    end

    Drawing.showModal("Confirm Merger", "Are you sure you want to swap your entire team with a random one from another dimension? This cannot be undone.", {
        {text = "Yes, Do It!", onClick = confirmSwap, style="danger"},
        {text = "No, Too Risky", onClick = function() Drawing.hideModal() end, style="primary"}
    })
end

function enactCorporatePersonhood(gameState)
    -- Evict anyone from the center desk to make room
    if gameState.deskAssignments['desk-4'] then
        local evictedEmployee = getEmployeeFromGameState(gameState, gameState.deskAssignments['desk-4'])
        if evictedEmployee then
            evictedEmployee.variant = 'remote' -- Move them to remote as a fallback
            evictedEmployee.deskId = nil
            Drawing.showModal("Eviction Notice", evictedEmployee.name .. " was moved to remote work to make way for The Corporation.")
        end
        gameState.deskAssignments['desk-4'] = nil
    end

    -- Create the corporation as a new, permanent employee
    local corporation = Employee:new('corporate_personhood_employee', 'standard', "The Corporation")
    if corporation then
        -- Calculate its initial stats
        local ownedDesks = Placement:getOwnedDeskCount(gameState)
        corporation.baseProductivity = (ownedDesks * 20) + (#gameState.purchasedPermanentUpgrades * 10)
        corporation.baseFocus = 1.0 + (ownedDesks * 0.1)

        table.insert(gameState.hiredEmployees, corporation)
        Placement:handleEmployeeDropOnDesk(gameState, corporation, "desk-4", nil)
        Drawing.showModal("Manifestation!", "The Office itself has become a sentient entity, taking its rightful place at the center of power.")
    else
        print("ERROR: Corporate Personhood is owned, but could not create 'corporate_personhood_employee'. Check its definition in data.lua.")
    end
end
_G.enactCorporatePersonhood = enactCorporatePersonhood -- Make global for Shop module


function handleWinCondition()
    local currentSprint = GameData.ALL_SPRINTS[gameState.currentSprintIndex]
    if not currentSprint then return end
    local currentWorkItem = currentSprint.workItems[gameState.currentWorkItemIndex]
    if not currentWorkItem then return end

    for i = #gameState.hiredEmployees, 1, -1 do
        local emp = gameState.hiredEmployees[i]
        if emp.isTemporaryClone then
            print("Removing temporary clone: " .. emp.fullName)
            if emp.deskId and gameState.deskAssignments[emp.deskId] then
                gameState.deskAssignments[emp.deskId] = nil
            end
            table.remove(gameState.hiredEmployees, i)
        end
    end

    battleState.currentWorkerId = nil
    battleState.lastContribution = nil
    battleState.phase = 'idle'
    battleState.isShaking = false

    local efficiencyBonus = math.max(0, 5000 - (gameState.currentWeekCycles * 1000))
    local totalBudgetBonus = 0
    local workItemReward = currentWorkItem.reward
    local vampireBudgetDrain = 0

    if not gameState.ventureCapitalActive then
        if gameState.purchasedPermanentUpgrades then
            for _, upgId in ipairs(gameState.purchasedPermanentUpgrades) do
                if not (gameState.temporaryEffectFlags.disabledUpgrades and gameState.temporaryEffectFlags.disabledUpgrades[upgId]) then
                    for _, upgData in ipairs(GameData.ALL_UPGRADES) do
                        if upgId == upgData.id and upgData.effect and upgData.effect.type == 'budget_generation_per_win' then
                            totalBudgetBonus = totalBudgetBonus + upgData.effect.value
                        end
                    end
                end
            end
        end
        
        local eventArgs = { vampireDrain = 0, budgetBonus = 0, isBossItem = currentWorkItem.id:find("boss") }
        EffectsDispatcher.dispatchEvent("onWorkItemComplete", gameState, eventArgs)
        
        totalBudgetBonus = totalBudgetBonus + eventArgs.budgetBonus
        vampireBudgetDrain = eventArgs.vampireDrain

        gameState.budget = gameState.budget + workItemReward + efficiencyBonus + totalBudgetBonus

        if vampireBudgetDrain > 0 then
            gameState.budget = gameState.budget - vampireBudgetDrain
            print("Vampire tribute applied: $" .. vampireBudgetDrain .. ". Budget is now $" .. gameState.budget)
        end
    else
        efficiencyBonus = 0
        totalBudgetBonus = 0
        workItemReward = 0
        vampireBudgetDrain = 0
        local eventArgs = { vampireDrain = 0, budgetBonus = 0, isBossItem = currentWorkItem.id:find("boss") }
        EffectsDispatcher.dispatchEvent("onWorkItemComplete", gameState, eventArgs) 
        print("Venture Capital active: Forfeiting all budget rewards.")
    end
    
    for _, emp in ipairs(gameState.hiredEmployees) do
        if emp.isTraining then emp.isTraining = false; print(emp.name .. " has finished training and is now available.") end
    end

    gameState.temporaryEffectFlags.focusFunnelTargetId = nil
    gameState.temporaryEffectFlags.focusFunnelTotalBonus = nil

    local totalRevenue = workItemReward + efficiencyBonus + totalBudgetBonus
    local totalProfit = totalRevenue - gameState.totalSalariesPaidThisWeek - vampireBudgetDrain
    
    local resultLines = { "", "Base Reward:|+$" .. workItemReward }
    if efficiencyBonus > 0 then table.insert(resultLines, "Efficiency Bonus:|+$" .. efficiencyBonus) end
    if totalBudgetBonus > 0 then table.insert(resultLines, "Other Bonuses:|+$" .. totalBudgetBonus) end
    if vampireBudgetDrain > 0 then table.insert(resultLines, "Vampire Tribute:|-$" .. vampireBudgetDrain) end
    table.insert(resultLines, "Salaries Paid:|-$" .. gameState.totalSalariesPaidThisWeek); table.insert(resultLines, ""); table.insert(resultLines, "")
    local profitColor = totalProfit >= 0 and "GREEN" or "RED"; local profitSign = totalProfit >= 0 and "$" or "-$"
    table.insert(resultLines, "PROFIT:" .. profitColor .. ":|" .. profitSign .. math.abs(totalProfit))
    
    local resultMessage = table.concat(resultLines, "\n")
    
    GameState:setGamePhase(gameState, 'battle_over')
    
    local nextActionCallback = function()
        Drawing.hideModal()
        gameState.currentWorkItemIndex = gameState.currentWorkItemIndex + 1
        if gameState.currentWorkItemIndex > 3 then
            gameState.currentWorkItemIndex = 1
            gameState.currentSprintIndex = gameState.currentSprintIndex + 1
            
            EffectsDispatcher.dispatchEvent("onSprintStart", gameState)
            
            gameState.temporaryEffectFlags.motivationalSpeakerUsedThisSprint = nil
            gameState.temporaryEffectFlags.reOrgUsedThisSprint = nil
            gameState.temporaryEffectFlags.photocopierUsedThisSprint = nil
            gameState.temporaryEffectFlags.fourthWallUsedThisSprint = nil

            for _, emp in ipairs(gameState.hiredEmployees) do
                emp.isSecretlyBuffed = nil; if emp.id == 'mimic1' then emp.copiedState = nil end; if emp.isSmithCopy then emp.isSmithCopy = nil end
                emp.contributionThisSprint = 0
            end

            if gameState.currentSprintIndex > #GameData.ALL_SPRINTS then
                local finalWinCallback = function() Drawing.hideModal(); resetGameAndGlobals() end
                Drawing.showModal("Project Complete!", "You have cleared all 8 Sprints! Congratulations!", { {text = "Play Again?", onClick = finalWinCallback, style = "primary"} })
                return
            else
                local permUpgrades = {}; for _, upgId in ipairs(gameState.purchasedPermanentUpgrades) do local isTemp = false; for _, upgData in ipairs(GameData.ALL_UPGRADES) do if upgId == upgData.id and upgData.effect.duration_weeks then isTemp = true; break end; end; if not isTemp then table.insert(permUpgrades, upgId) end; end
                gameState.purchasedPermanentUpgrades = permUpgrades
            end
        end
        gameState.currentShopOffers = {employees={}, upgrade=nil, restockCountThisWeek=0}
        setGamePhase("hiring_and_upgrades")
    end

    local modalTitle = "WORK ITEM COMPLETE!\n" .. currentWorkItem.name
    Drawing.showModal(modalTitle, resultMessage, { {text = "Continue", onClick = nextActionCallback, style = "primary"} }, 400)
end

function setGamePhase(newPhase)
    local oldPhase = gameState.gamePhase
    GameState:setGamePhase(gameState, newPhase)
    print("Game phase transitioned from " .. oldPhase .. " to " .. newPhase)

    if newPhase == "hiring_and_upgrades" then 
        if gameState.currentShopOffers and gameState.currentShopOffers.restockCountThisWeek == 0 then
            Shop:populateOffers(gameState.currentShopOffers, gameState.purchasedPermanentUpgrades, false)
        end
        draggedItemState.item = nil 
    
    elseif newPhase == "battle_active" then
        battleState = {
            activeEmployees = {}, nextEmployeeIndex = 1, currentWorkerId = nil,
            lastContribution = nil, phase = 'idle', timer = 0, isShaking = false,
            chipAmountRemaining = 0, chipSpeed = 100, chipTimer = 0,
            roundTotalContribution = 0, lastRoundContributions = {},
            changedEmployeesForAnimation = {}, nextChangedEmployeeIndex = 1,
            progressMarkers = {}
        }
        _G.battleState = battleState

        gameState.currentWeekCycles = 0
        gameState.totalSalariesPaidThisWeek = 0
        
        local placed, remote = {}, {}
        local topRowDeskIds = {"desk-0", "desk-1", "desk-2"}

        for _, emp in ipairs(gameState.hiredEmployees) do
            local isDisabled = false
            if emp.isTraining then isDisabled = true end
            if emp.special and emp.special.does_not_work then isDisabled = true end
            if emp.special and emp.special.type == 'ron_swanson_behavior' and gameState.budget > emp.special.upper_budget_threshold then
                isDisabled = true; print(emp.name .. " refuses to work; the government has too much money.")
            end
            if gameState.temporaryEffectFlags.isRemoteWorkDisabled and emp.variant == 'remote' then isDisabled = true end
            if gameState.temporaryEffectFlags.isTopRowDisabled and emp.deskId then
                for _, topDeskId in ipairs(topRowDeskIds) do if emp.deskId == topDeskId then isDisabled = true; break end end
            end
            if not isDisabled then
                if emp.variant == 'remote' then table.insert(remote, emp) 
                elseif emp.deskId then table.insert(placed, emp)
                end
            end
        end
        table.sort(placed, function(a, b) return (tonumber(string.match(a.deskId, "desk%-(%d+)")) or 99) < (tonumber(string.match(b.deskId, "desk%-(%d+)")) or 99) end)
        
        battleState.activeEmployees = {}; for _, emp in ipairs(placed) do table.insert(battleState.activeEmployees, emp) end; for _, emp in ipairs(remote) do table.insert(battleState.activeEmployees, emp) end
        
        if Shop:isUpgradePurchased(gameState.purchasedPermanentUpgrades, 'focus_funnel', gameState) and #battleState.activeEmployees > 0 then
            local target = battleState.activeEmployees[love.math.random(#battleState.activeEmployees)]
            gameState.temporaryEffectFlags.focusFunnelTargetId = target.instanceId
            print(target.name .. " is the Focus Funnel target for this item.")
        end

        local lumberghs = {}; for _, emp in ipairs(gameState.hiredEmployees) do if emp.special and emp.special.type == 'forces_double_work' then table.insert(lumberghs, emp); end; end
        if #lumberghs > 0 then
            for _, lumbergh in ipairs(lumberghs) do
                local victims = {}
                if lumbergh.deskId then
                    local directions = {"up", "down", "left", "right"}; for _, dir in ipairs(directions) do local neighborDeskId = Employee:getNeighboringDeskId(lumbergh.deskId, dir, GameData.GRID_WIDTH, GameData.TOTAL_DESK_SLOTS, gameState.desks); if neighborDeskId and gameState.deskAssignments[neighborDeskId] then local neighbor = getEmployeeFromGameState(gameState, gameState.deskAssignments[neighborDeskId]); if neighbor then table.insert(victims, neighbor) end; end; end
                    for _, victim in ipairs(victims) do for i = 1, (lumbergh.level or 1) do table.insert(battleState.activeEmployees, victim); end; end
                elseif lumbergh.variant == 'remote' then
                    local potentialVictims = {}; for _, e in ipairs(remote) do if e.instanceId ~= lumbergh.instanceId then table.insert(potentialVictims, e) end end
                    for i = 1, 2 do if #potentialVictims > 0 then local victim = table.remove(potentialVictims, love.math.random(#potentialVictims)); for j = 1, (lumbergh.level or 1) do table.insert(battleState.activeEmployees, victim); end; end; end
                end
            end
        end
        local agileCoach = nil; for _, emp in ipairs(gameState.hiredEmployees) do if emp.special and emp.special.type == 'randomize_work_order' then agileCoach = emp; break; end; end
        if agileCoach and #battleState.activeEmployees > 0 then
            for i = #battleState.activeEmployees, 2, -1 do local j = love.math.random(i); battleState.activeEmployees[i], battleState.activeEmployees[j] = battleState.activeEmployees[j], battleState.activeEmployees[i]; end
            if battleState.activeEmployees[1] then battleState.activeEmployees[1].agileFirstTurnBoost = agileCoach.special.first_worker_mult; print("Agile Coach randomized work order. First worker is " .. battleState.activeEmployees[1].name); end
        end
        
        if #battleState.activeEmployees == 0 then
            Drawing.showModal("Stuck!", "No employees available to work. Any staff in training will be ready next cycle.")
            safeTimerAfter(1.0, function()
                local result = Battle:endWorkCycleRound(gameState, 0)
                if result == "lost_budget" then setGamePhase("game_over") elseif result == "lost_bailout" then setGamePhase("hiring_and_upgrades") end
            end)
        end
    end
end

function resetGameAndGlobals()
    print("Resetting game and globals...")
    gameState = GameState:new()
    _G.gameState = gameState
    draggedItemState.item = nil
    setGamePhase("hiring_and_upgrades") 
    print("Game reset complete.")
end

_G.setGamePhase = setGamePhase
_G.Placement = Placement -- Make Placement global for Drawing module to access
_G.Shop = Shop -- Make Shop global for Drawing module to access