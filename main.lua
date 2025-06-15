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
local SoundManager = require("sound_manager")
local CardSizing = require("card_sizing")
local battlePhaseManager


-- Component Imports
local Button = require("components/button")
local EmployeeCard = require("components/employee_card")
local UpgradeCard = require("components/upgrade_card")
local Checkbox = require("components/checkbox")
local Dropdown = require("components/dropdown")
local PurchasedUpgradeIcon = require("components/purchased_upgrade_icon")
local DeskSlot = require("components/desk_slot")
local DecorationCard = require("components/decoration_card")
local PlacedDecorationIcon = require("components/placed_decoration_icon")
local Modal = require("components/modal")
local modal = Modal:new()



local StateManager = require("game_states.state_manager")
local stateManager
local overlaysToDraw = {}








function _G.getCurrentMaxLevel(gameState)
    local eventArgs = { maxLevel = 3 }
    require("effects_dispatcher").dispatchEvent("onGetMaxLevel", gameState, eventArgs, { modal = modal })
    return eventArgs.maxLevel
end

local gameState
local tooltipsToDraw = {}
local overlaysToDraw = {}

-- UI Component Lists
local uiComponents = {}
local sprintOverviewComponents = {}

-- State variables are wrapped in tables to be passed by reference
local sprintOverviewState = { isVisible = false }
local sprintOverviewRects = {} -- To hold rects for the new panel UI

-- Timer system
local pendingTimers = {}

local function safeTimerAfter(delay, callback)
    table.insert(pendingTimers, {
        timeRemaining = delay,
        callback = callback
    })
end

local function updateTimers(dt)
    for i = #pendingTimers, 1, -1 do
        local timer = pendingTimers[i]
        timer.timeRemaining = timer.timeRemaining - dt
        if timer.timeRemaining <= 0 then
            timer.callback()
            table.remove(pendingTimers, i)
        end
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

function buildSprintOverviewUI()
    sprintOverviewComponents = {} -- Clear any existing components

    table.insert(sprintOverviewComponents, Button:new({
        -- The rect will be updated in love.draw
        rect = {x=0, y=0, w=0, h=0}, 
        text = "Back",
        style = "primary",
        onClick = function()
            sprintOverviewState.isVisible = false
        end
    }))
end

function calculateRemoteWorkerPositions(gameState, draggedItemState)
    local layout = Drawing.calculateRemoteWorkerLayout(panelRects.remoteWorkers, gameState, draggedItemState.item)
    return layout.positions
end

function _buildHiringPhaseUI()
    local shopRect = panelRects.shop
    local cardWidth = CardSizing.getCardWidth()
    local cardHeight = CardSizing.getCardHeight()
    local shopCardPadding = CardSizing.getStandardCardDimensions().shopPadding

    -- Buttons in Game Info panel
    local infoPanelRect = panelRects.gameInfo
    local btnWidth, btnHeight, btnX = infoPanelRect.width - 20, 35, infoPanelRect.x + 10
    local mainActionBtnY = infoPanelRect.y + infoPanelRect.height - btnHeight - 10
    local viewSprintBtnY = mainActionBtnY - btnHeight - 5
    table.insert(uiComponents, Button:new({ rect = {x=btnX, y=viewSprintBtnY, w=btnWidth, h=btnHeight}, text = "View Sprint Details", style = "info", onClick = function() sprintOverviewState.isVisible = true end }))
    table.insert(uiComponents, Button:new({ rect = {x=btnX, y=mainActionBtnY, w=btnWidth, h=btnHeight}, text = "Start Work Item", style = "secondary", onClick = function() setGamePhase("battle_active") end }))

    local currentY = shopRect.y + Drawing.UI.fontLarge:getHeight() + 20
    
    -- Employee cards in shop
    if gameState.currentShopOffers and gameState.currentShopOffers.employees then
        for i, empData in ipairs(gameState.currentShopOffers.employees) do
            if empData then
                table.insert(uiComponents, EmployeeCard:new({ data = empData, rect = {x=shopRect.x+shopCardPadding, y=currentY, w=cardWidth, h=cardHeight}, context = "shop_offer", gameState=gameState, battleState=battleState, draggedItemState=draggedItemState, uiElementRects=uiElementRects, battlePhaseManager = battlePhaseManager, modal = modal }))
                currentY = currentY + cardHeight + 5
            end
        end
    end
    
    -- Decoration cards in shop
    if gameState.currentShopOffers and gameState.currentShopOffers.decorations then
        currentY = currentY + 15
        for _, decoData in ipairs(gameState.currentShopOffers.decorations) do
            if decoData then
                table.insert(uiComponents, DecorationCard:new({ data = decoData, rect = {x = shopRect.x + shopCardPadding, y = currentY, w = cardWidth, h = 90}, gameState = gameState, draggedItemState = draggedItemState }))
                currentY = currentY + 90 + 5
            end
        end
    end
    
    -- Upgrade card in shop
    if gameState.currentShopOffers and gameState.currentShopOffers.upgrades and gameState.currentShopOffers.upgrades[1] then
        currentY = shopRect.y + shopRect.height - 35 - 10 - 110 - 15 -- Align from bottom
        table.insert(uiComponents, UpgradeCard:new({ data = gameState.currentShopOffers.upgrades[1], rect = {x=shopRect.x+shopCardPadding, y=currentY, w=cardWidth, h=110}, gameState = gameState, uiElementRects = uiElementRects, modal = modal }))
    end
    
    -- Restock button
    local restockBtnY = shopRect.y + shopRect.height - 35 - 10
    local restockButton = Button:new({ rect = {x = shopRect.x + shopCardPadding, y = restockBtnY, w = cardWidth, h = 35}, text = "Restock", style = "warning", isEnabled = function() local cost = Shop:getFinalRestockCost(gameState); return gameState.budget >= cost and not draggedItemState.item end, onClick = function() local success, msg = Shop:attemptRestock(gameState); if not success then modal:show("Restock Failed", msg) end; buildUIComponents() end })
    function restockButton:draw() self.text = "Restock ($" .. Shop:getFinalRestockCost(gameState) .. ")"; Button.draw(self); end
    table.insert(uiComponents, restockButton)
end

function _buildCommonUIElements()
    local cardWidth = CardSizing.getCardWidth()
    local cardHeight = CardSizing.getCardHeight()

    -- Office Floor Desks and Placed Employees
    local gridGeometry = Drawing._calculateDeskGridGeometry(panelRects.mainInteraction)
    for i, deskData in ipairs(gameState.desks) do
        local col = (i - 1) % GameData.GRID_WIDTH
        local row = math.floor((i - 1) / GameData.GRID_WIDTH)
        local deskRect = { x = gridGeometry.startX + col * (gridGeometry.width + gridGeometry.spacing), y = gridGeometry.startY + row * (gridGeometry.height + gridGeometry.spacing), w = gridGeometry.width, h = gridGeometry.height }
        uiElementRects.desks[i] = {id = deskData.id, x = deskRect.x, y = deskRect.y, w = deskRect.w, h = deskRect.h}
        table.insert(uiComponents, DeskSlot:new({rect = deskRect, data = deskData, gameState = gameState, modal = modal}))
        
        local empId = gameState.deskAssignments[deskData.id]
        if empId then
            local empData = Employee:getFromState(gameState, empId)
            if empData then
                local cardContext = "desk_placed"
                if empData.isTraining then
                    cardContext = "worker_training"
                end
                local contextArgs = { employee = empData, context = cardContext }
                EffectsDispatcher.dispatchEvent("onEmployeeContextCheck", gameState, { modal = modal }, contextArgs)
                table.insert(uiComponents, EmployeeCard:new({data = empData, rect = {x = deskRect.x+2, y=deskRect.y+2, w=deskRect.w-4, h=deskRect.h-4}, context = contextArgs.context, gameState=gameState, battleState=battleState, draggedItemState=draggedItemState, uiElementRects=uiElementRects, battlePhaseManager = battlePhaseManager, modal = modal}))
            end
        end

        local decoration = Placement:getDecorationOnDesk(gameState, deskData.id)
        if decoration then
            local iconFont = Drawing.UI.titleFont or love.graphics.getFont()
            local iconSize = iconFont:getHeight()
            local iconX = deskRect.x + deskRect.w - iconSize - 4
            local iconY = deskRect.y + 4
            table.insert(uiComponents, PlacedDecorationIcon:new({ data = decoration, rect = { x = iconX, y = iconY, w = iconSize, h = iconSize } }))
        end
    end

    -- Remote Worker Cards
    local remoteWorkerPositions = calculateRemoteWorkerPositions(gameState, draggedItemState)
    for _, empData in ipairs(gameState.hiredEmployees) do
        if empData.variant == 'remote' then
            local cardContext = "remote_worker"
            if empData.isTraining then
                cardContext = "worker_training"
            end
            local contextArgs = { employee = empData, context = cardContext }
            EffectsDispatcher.dispatchEvent("onEmployeeContextCheck", gameState, { modal = modal }, contextArgs)
            local workerRect = remoteWorkerPositions[empData.instanceId] or {x = 0, y = 0, w = cardWidth, h = cardHeight}
            table.insert(uiComponents, EmployeeCard:new({data = empData, rect = workerRect, context = contextArgs.context, gameState=gameState, battleState=battleState, draggedItemState=draggedItemState, uiElementRects=uiElementRects, battlePhaseManager = battlePhaseManager, modal = modal}))
            uiElementRects.remote[empData.instanceId] = workerRect
        end
    end

    -- Purchased Upgrade Icons
    local officeRect = panelRects.mainInteraction
    local iconSize = 32
    local iconPadding = 5
    local currentX = officeRect.x + 10
    local iconY = officeRect.y + 10
    for _, upgradeId in ipairs(gameState.purchasedPermanentUpgrades) do
        local upgData = nil
        for _, u in ipairs(GameData.ALL_UPGRADES) do if u.id == upgradeId then upgData = u; break; end end
        if upgData and upgData.icon and (currentX + iconSize <= officeRect.x + officeRect.width - 10) then
            table.insert(uiComponents, PurchasedUpgradeIcon:new({ rect = { x = currentX, y = iconY, w = iconSize, h = iconSize }, upgData = upgData, gameState = gameState, battleState = battleState, modal = modal }))
            currentX = currentX + iconSize + iconPadding
        end
    end
end

function _buildEndGameUI()
    local infoPanelRect = panelRects.gameInfo
    local btnWidth, btnHeight, btnX = infoPanelRect.width - 20, 35, infoPanelRect.x + 10
    local mainActionBtnY = infoPanelRect.y + infoPanelRect.height - btnHeight - 10
    local buttonText = (gameState.gamePhase == "game_won" and "Play Again?" or "Restart Game")
    local buttonStyle = (gameState.gamePhase == "game_won" and "primary" or "danger")
    table.insert(uiComponents, Button:new({
        rect = {x=btnX, y=mainActionBtnY, w=btnWidth, h=btnHeight},
        text = buttonText,
        style = buttonStyle,
        onClick = function() resetGameAndGlobals() end
    }))
end

function buildUIComponents()
  uiComponents = {}
  uiElementRects.desks = {}
  uiElementRects.remote = {}

  -- Build UI based on the current game phase
  if gameState.gamePhase == "hiring_and_upgrades" then
      _buildHiringPhaseUI()
      _buildCommonUIElements()
  elseif gameState.gamePhase == "battle_active" or gameState.gamePhase == "battle_over" then
      _buildCommonUIElements()
      -- No extra buttons needed during battle, they are handled by battle phases
  elseif gameState.gamePhase == "game_over" or gameState.gamePhase == "game_won" then
      _buildEndGameUI()
  end
end

function love.resize(w, h)
    -- This function is called by LÖVE whenever the window is resized.
    -- We recalculate all panel positions and then rebuild the UI components
    -- to fit the new dimensions.
    definePanelRects()
    buildUIComponents()
end



function onMouseRelease(x, y, button)
    if button == 1 and draggedItemState.item then
        local successfullyProcessedDrop = false
        local draggedItem = draggedItemState.item
        local dropTargetX, dropTargetY = x, y

        -- Find the source component for animation BEFORE processing the drop
        local sourceComponent = nil
        if draggedItem and draggedItem.data then
            for _, component in ipairs(uiComponents) do
                if component.data and component.data.instanceId == draggedItem.data.instanceId then
                    sourceComponent = component
                    break
                end
            end
        end

        -- Loop backwards through components so we check top-most items first (e.g., employee card before the desk slot under it)
        for i = #uiComponents, 1, -1 do
            local component = uiComponents[i]
            if component.handleMouseDrop then
                -- The component's method will do its own isMouseOver check
                if component:handleMouseDrop(x, y, draggedItem) then
                    successfullyProcessedDrop = true
                    -- Store the drop target position for animation
                    if component.rect then
                        dropTargetX = component.rect.x + component.rect.w/2
                        dropTargetY = component.rect.y + component.rect.h/2
                    end
                    break -- Drop was handled, exit the loop
                end
            end
        end

        -- Fallback for non-component drop targets, like the general remote panel area
        if not successfullyProcessedDrop then
            if draggedItem.data.variant == 'remote' and Drawing.isMouseOver(x, y, uiElementRects.remotePanelDropTarget.x, uiElementRects.remotePanelDropTarget.y, uiElementRects.remotePanelDropTarget.w, uiElementRects.remotePanelDropTarget.h) then
                if draggedItem.type == "shop_employee" then
                    if gameState.budget < draggedItem.cost then
                        modal:show("Can't Afford", "Not enough budget. Need $" .. draggedItem.cost)
                        SoundManager:playEffect('error')
                    elseif draggedItem.data.special and (draggedItem.data.special.type == 'haunt_target_on_hire' or draggedItem.data.special.type == 'slime_merge') then
                        modal:show("Invalid Placement", "This employee must be placed on top of another employee.")
                        SoundManager:playEffect('error')
                    else
                        gameState.budget = gameState.budget - draggedItem.cost
                        local newEmp = Employee:new(draggedItem.data.id, draggedItem.data.variant, draggedItem.data.fullName)
                        newEmp.instanceId = draggedItem.data.instanceId -- Preserve the shop offer's instanceId
                        table.insert(gameState.hiredEmployees, newEmp)
                        Shop:markOfferSold(gameState.currentShopOffers, draggedItem.originalShopInstanceId, nil) 
                        SoundManager:playEffect('hire')
                        successfullyProcessedDrop = true
                        
                        -- Calculate where this employee will end up by simulating the layout
                        local cardWidth = CardSizing.getCardWidth()
                        local rect = uiElementRects.remotePanelDropTarget
                        
                        -- Count existing remote workers (excluding the one being dragged if it's a move)
                        local remoteCount = 0
                        for _, emp in ipairs(gameState.hiredEmployees) do
                            if emp.variant == 'remote' and emp.instanceId ~= draggedItem.data.instanceId then
                                remoteCount = remoteCount + 1
                            end
                        end
                        
                        -- The new employee will be at the end of the list
                        local totalCards = remoteCount + 1 -- +1 for the new employee
                        local availableWidth = rect.w - 20
                        local normalGap = 5
                        local normalStepSize = cardWidth + normalGap
                        local totalNormalWidth = (totalCards * cardWidth) + ((totalCards - 1) * normalGap)
                        
                        local stepSize = normalStepSize
                        if totalNormalWidth > availableWidth and totalCards > 1 then
                            local spaceForAllButLast = availableWidth - cardWidth
                            stepSize = spaceForAllButLast / (totalCards - 1)
                        end
                        
                        -- Calculate final position (new employee goes at the end)
                        dropTargetX = rect.x + 10 + (totalCards - 1) * stepSize + cardWidth/2
                        dropTargetY = rect.y + rect.h/2
                    end
                elseif draggedItem.type == "placed_employee" then
                    successfullyProcessedDrop = Placement:handleEmployeeDropOnRemote(gameState, draggedItem.data, draggedItem.originalDeskId)
                    if successfullyProcessedDrop then
                        SoundManager:playEffect('place')
                        
                        -- Calculate where this employee will end up by simulating the layout
                        local cardWidth = CardSizing.getCardWidth()
                        local rect = uiElementRects.remotePanelDropTarget
                        
                        -- Count existing remote workers
                        local remoteCount = 0
                        for _, emp in ipairs(gameState.hiredEmployees) do
                            if emp.variant == 'remote' then
                                remoteCount = remoteCount + 1
                            end
                        end
                        
                        -- Find the index of this employee in the remote worker list
                        local targetIndex = 1
                        local currentIndex = 1
                        for _, emp in ipairs(gameState.hiredEmployees) do
                            if emp.variant == 'remote' then
                                if emp.instanceId == draggedItem.data.instanceId then
                                    targetIndex = currentIndex
                                    break
                                end
                                currentIndex = currentIndex + 1
                            end
                        end
                        
                        -- Calculate layout
                        local availableWidth = rect.w - 20
                        local normalGap = 5
                        local normalStepSize = cardWidth + normalGap
                        local totalNormalWidth = (remoteCount * cardWidth) + ((remoteCount - 1) * normalGap)
                        
                        local stepSize = normalStepSize
                        if totalNormalWidth > availableWidth and remoteCount > 1 then
                            local spaceForAllButLast = availableWidth - cardWidth
                            stepSize = spaceForAllButLast / (remoteCount - 1)
                        end
                        
                        -- Calculate final position
                        dropTargetX = rect.x + 10 + (targetIndex - 1) * stepSize + cardWidth/2
                        dropTargetY = rect.y + rect.h/2
                    end
                end
            end
        end

        -- Finalize the drop action
        if successfullyProcessedDrop then
            -- Start drop animation for successful drops
            if sourceComponent and sourceComponent.startDropAnimation then
                -- Pass a callback that gets called when animation completes
                sourceComponent:startDropAnimation(dropTargetX, dropTargetY, function()
                    draggedItemState.item = nil
                    buildUIComponents()
                end)
            else
                -- No animation available, finish immediately
                draggedItemState.item = nil
                buildUIComponents()
            end
            
        else
            -- Cancel pickup animation and snap back for failed drops
            if sourceComponent and sourceComponent.cancelPickupAnimation then
                sourceComponent:cancelPickupAnimation()
            end
            
            -- Use the new helper function to restore the employee's state
            InputHandler.restoreDraggedEmployee(draggedItem, gameState)
            
            -- End the drag operation immediately for failed drops
            draggedItemState.item = nil
        end
    end
end



local function drawPositionalOverlays()
    if #overlaysToDraw > 0 then
        for _, overlay in ipairs(overlaysToDraw) do
            -- Find the desk rect for this overlay
            for _, deskRect in ipairs(uiElementRects.desks) do
                if deskRect.id == overlay.targetDeskId then
                    -- Draw the colored overlay
                    love.graphics.setColor(overlay.color)
                    love.graphics.rectangle("fill", deskRect.x, deskRect.y, deskRect.w, deskRect.h, 3)
                    
                    -- Draw the text
                    love.graphics.setFont(Drawing.UI.titleFont or Drawing.UI.fontLarge)
                    love.graphics.setColor(1, 1, 1, 0.9)
                    love.graphics.printf(overlay.text, deskRect.x, deskRect.y + (deskRect.h - (Drawing.UI.titleFont or Drawing.UI.fontLarge):getHeight()) / 2, deskRect.w, "center")
                    break
                end
            end
        end
    end
end

function love.load()
   Drawing.foilShader = love.graphics.newShader("foil.fs") 
   Drawing.holoShader = love.graphics.newShader("holo.fs") 

   -- Require the new manager
   local DebugManager = require("debug_manager")
   local BattlePhaseManager = require("battle_phase_manager")

   gameState = GameState:new()
   love.window.setTitle("Office Overlord - Command Center v4.1 Sprints")

   local success
   
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

   local primaryFontSmall, emojiFontSmall
   success, primaryFontSmall = pcall(love.graphics.newFont, "Arial.ttf", 9)
   if not success then primaryFontSmall = love.graphics.newFont(9); print("Arial.ttf not found, using default font 9pt.") end
   success, emojiFontSmall = pcall(love.graphics.newFont, "NotoEmoji.ttf", 9)
   if success then
       primaryFontSmall:setFallbacks(emojiFontSmall)
       print("Emoji fallback font loaded for size 9.")
   end
   Drawing.UI.fontSmall = primaryFontSmall
   
   local primaryFontMedium, emojiFontMedium
   success, primaryFontMedium = pcall(love.graphics.newFont, "Arial.ttf", 11)
   if not success then primaryFontMedium = love.graphics.newFont(11); print("Arial.ttf not found, using default font 11pt.") end
   success, emojiFontMedium = pcall(love.graphics.newFont, "NotoEmoji.ttf", 11)
   if success then
       primaryFontMedium:setFallbacks(emojiFontMedium)
       print("Emoji fallback font loaded for size 11.")
   end
   Drawing.UI.fontMedium = primaryFontMedium

   local primaryFontLarge, emojiFontLarge
   success, primaryFontLarge = pcall(love.graphics.newFont, "Arial.ttf", 18)
   if not success then primaryFontLarge = love.graphics.newFont(18); print("Arial.ttf not found, using default font 18pt.") end
   success, emojiFontLarge = pcall(love.graphics.newFont, "NotoEmoji.ttf", 18)
   if success then
       primaryFontLarge:setFallbacks(emojiFontLarge)
       print("Emoji fallback font loaded for size 18.")
   end
   Drawing.UI.fontLarge = primaryFontLarge

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

   definePanelRects()
   
   buildSprintOverviewUI()

   -- Initialize the state manager
   stateManager = StateManager:new()

   -- Initialize the new battle phase manager
   battlePhaseManager = BattlePhaseManager:new() 

   battlePhaseManager:init({ modal = modal }, {
       idle = require("phases.idle_phase"),
       turn_speed_check = require("phases.turn_speed_check_phase"),
       starting_turn = require("phases.starting_turn_phase"),
       showing_productivity = require("phases.showing_productivity_phase"),
       showing_focus = require("phases.showing_focus_phase"),
       showing_total = require("phases.showing_total_phase"),
       turn_over = require("phases.turn_over_phase"),
       pre_apply_contribution = require("phases.pre_apply_contribution_phase"),
       apply_round_contribution = require("phases.apply_round_contribution_phase"),
       chipping_workload = require("phases.chipping_workload_phase"),
       ending_round = require("phases.ending_round_phase"),
       paying_salaries = require("phases.paying_salaries_phase"),
       chipping_salaries = require("phases.chipping_salaries_phase"),
       pausing_between_rounds = require("phases.pausing_between_rounds_phase"),
       fast_recalculate_and_setup = require("phases.fast_recalculate_and_setup_phase"),
       animating_changes = require("phases.animating_changes_phase"),
       wait_for_apply = require("phases.wait_for_apply_phase")
   })

   InputHandler.init({
       gameState = gameState,
       uiElementRects = uiElementRects,
       draggedItemState = draggedItemState,
       battleState = battleState,
       panelRects = panelRects,
       sprintOverviewState = sprintOverviewState,
       sprintOverviewRects = sprintOverviewRects,
       -- REMOVED debug-related tables from here
       callbacks = {
           setGamePhase = setGamePhase,
           resetGameAndGlobals = resetGameAndGlobals
       },
       modal = modal
   })

    -- Initialize the Debug Manager, passing it the systems it needs to interact with
    DebugManager:init({
        gameState = gameState,
        shop = Shop,
        setGamePhase = setGamePhase -- Pass the function directly
    })
   
   setGamePhase("hiring_and_upgrades")
   Placement:updateDeskAvailability(gameState.desks)
   love.math.setRandomSeed(os.time() + love.timer.getTime())

   SoundManager:init()
   SoundManager:playMusic('main')
end

function definePanelRects()
    local screenW, screenH = love.graphics.getWidth(), love.graphics.getHeight()
    local padding = 10

    -- Define static-edge panels first
    panelRects.shop = {width=math.floor(screenW*0.16), x=screenW-math.floor(screenW*0.16)-padding, y=padding, height=screenH-2*padding}
    local shopLeftEdge = panelRects.shop.x - padding

    -- Set the remote worker panel height based on DYNAMIC card height + padding
    -- Use fallback height if CardSizing isn't available yet
    local cardHeight = 140 -- fallback
    local success, result = pcall(function() return CardSizing and CardSizing.getCardHeight and CardSizing.getCardHeight() end)
    if success and result and type(result) == "number" then
        cardHeight = result
    end
    local remoteWorkerHeight = (cardHeight or 140) + (padding * 2)
    panelRects.remoteWorkers = {x=padding, y=padding, width=shopLeftEdge - 2*padding, height=remoteWorkerHeight}
    uiElementRects.remotePanelDropTarget = {x=panelRects.remoteWorkers.x, y=panelRects.remoteWorkers.y, w=panelRects.remoteWorkers.width, h=panelRects.remoteWorkers.height}
    
    -- REMOVED: purchasedUpgradesDisplay panel - upgrades will be shown in office floor

    -- Define the middle row panels, which now start directly after remote workers
    local middleRowY = panelRects.remoteWorkers.y + panelRects.remoteWorkers.height + padding
    local middleRowHeight = screenH - middleRowY - padding

    panelRects.gameInfo = {x=padding, y=middleRowY, width=math.floor(screenW*0.12), height=middleRowHeight}
    local workloadBarWidth = math.floor(screenW * 0.04)
    local officeFloorX = panelRects.gameInfo.x + panelRects.gameInfo.width + padding
    local officeFloorWidth = shopLeftEdge - officeFloorX - workloadBarWidth - padding
    panelRects.mainInteraction = {x=officeFloorX, y=middleRowY, width=officeFloorWidth, height=middleRowHeight}
    panelRects.workloadBar = {x=panelRects.mainInteraction.x + panelRects.mainInteraction.width + padding, y=middleRowY, width=workloadBarWidth, height=middleRowHeight}

    -- Final check to prevent zero or negative dimensions
    for _, p in pairs(panelRects) do
        if not p.width or p.width <= 0 then p.width = 1 end
        if not p.height or p.height <= 0 then p.height = 1 end
    end
end

-- Updated drawing function to move "Office Floor" header to bottom
function Drawing.drawMainInteractionPanel(rect, gameState, uiElementRects, draggedItem, battleState, Placement, DrawingState) 
    -- 1. Draw the panel frame WITHOUT title at top
    Drawing.drawPanel(rect.x, rect.y, rect.width, rect.height, {0.88, 0.90, 0.92, 1}, {0.75,0.78,0.80,1})
    
    -- 2. Draw the "Office Floor" title at the BOTTOM of the panel
    love.graphics.setFont(Drawing.UI.fontLarge)
    love.graphics.setColor(Drawing.UI.colors.text)
    local titleY = rect.y + rect.height - Drawing.UI.fontLarge:getHeight() - 10
    love.graphics.printf("Office Floor", rect.x, titleY, rect.width, "center")

    -- The individual DeskSlot and EmployeeCard components now handle all other drawing,
    -- including overlays and hover effects. This function is now only a container.
end

function love.update(dt)
    local DebugManager = require("debug_manager")
    DebugManager:update(dt) -- Call the manager's update function

    updateTimers(dt) 
    InputHandler.update(dt)
    modal:update(dt)

    for _, component in ipairs(uiComponents) do
        if component.update then
            component:update(dt)
        end
    end
    
    if sprintOverviewState.isVisible then
        for _, component in ipairs(sprintOverviewComponents) do
            if component.update then
                component:update(dt)
            end
        end
    end

    local context = {
        panelRects = panelRects,
        uiElementRects = uiElementRects,
        draggedItemState = draggedItemState,
        sprintOverviewState = sprintOverviewState,
        battlePhaseManager = battlePhaseManager, -- ADD THIS
        buildUIComponents = buildUIComponents,
        setGamePhase = setGamePhase,
        getEmployeeFromGameState = getEmployeeFromGameState,
        Placement = Placement,
        Shop = Shop,
        modal = modal,
    }
    stateManager:update(dt, gameState, battleState, context)
end

function love.keypressed(key)
    local DebugManager = require("debug_manager")
    if DebugManager:handleKeyPress(key) then
        return -- Input was handled by the debug menu
    end
    InputHandler.onKeyPress(key)
end

function love.mousewheelmoved(x, y)
    local DebugManager = require("debug_manager")
    if DebugManager:isVisible() and DebugManager:handleMouseWheel(y) then
        return -- Input was handled by the debug menu
    end
end

function love.mousepressed(x, y, button, istouch, presses)
    local DebugManager = require("debug_manager")
    if DebugManager:isVisible() and DebugManager:handleMousePress(x, y, button) then
        return -- Input was handled by the debug menu
    end
    
    if sprintOverviewState.isVisible then
        for _, component in ipairs(sprintOverviewComponents) do
            if component.handleMousePress and component:handleMousePress(x, y, button) then
                return
            end
        end
        return
    end

    if modal:handleMouseClick(x, y) then return end

    local context = {
        uiComponents = uiComponents,
        panelRects = panelRects,
        uiElementRects = uiElementRects,
        draggedItemState = draggedItemState,
        Shop = Shop,
        Placement = Placement,
        modal = modal,
    }
    
    if stateManager:handleInput(x, y, button, gameState, battleState, context) then
        return
    end
    
    InputHandler.onMousePress(x, y, button)
end

function love.mousereleased(x, y, button, istouch)
    onMouseRelease(x, y, button)
end

function love.draw()
   love.graphics.setBackgroundColor(Drawing.UI.colors.background)
   love.graphics.clear()

   local DebugManager = require("debug_manager")

   tooltipsToDraw = {}
   Drawing.tooltipsToDraw = tooltipsToDraw 
   
   local overlaysToDraw = {}
   
   uiElementRects.shopLockButtons = {}

   local context = {
       panelRects = panelRects,
       uiElementRects = uiElementRects,
       draggedItemState = draggedItemState,
       sprintOverviewState = sprintOverviewState,
       Placement = Placement,
       Shop = Shop,
       overlaysToDraw = overlaysToDraw,
       modal = modal,
   }
   
   stateManager:draw(gameState, battleState, context)
   
   for _, component in ipairs(uiComponents) do
       if component.draw then 
           component:draw(context) 
       end
   end
   
   if #overlaysToDraw > 0 then
       for _, overlay in ipairs(overlaysToDraw) do
           for _, deskRect in ipairs(uiElementRects.desks) do
               if deskRect.id == overlay.targetDeskId then
                   love.graphics.setColor(overlay.color)
                   love.graphics.rectangle("fill", deskRect.x, deskRect.y, deskRect.w, deskRect.h, 3)
                   
                   love.graphics.setFont(Drawing.UI.titleFont or Drawing.UI.fontLarge)
                   love.graphics.setColor(1, 1, 1, 0.9)
                   love.graphics.printf(overlay.text, deskRect.x, deskRect.y + (deskRect.h - (Drawing.UI.titleFont or Drawing.UI.fontLarge):getHeight()) / 2, deskRect.w, "center")
                   break
               end
           end
       end
   end
   
   if DebugManager:isVisible() then
       DebugManager:draw()
   end
   
   if draggedItemState.item then
       local mouseX, mouseY = love.mouse.getPosition()
       if draggedItemState.item.type == "shop_decoration" then
           love.graphics.setFont(Drawing.UI.titleFont or Drawing.UI.fontLarge)
           love.graphics.setColor(1, 1, 1, 0.75)
           love.graphics.print(draggedItemState.item.data.icon or "?", mouseX - 16, mouseY - 16)
           love.graphics.setColor(1, 1, 1, 1)
       else
           local itemDataToDraw = draggedItemState.item.data
           if itemDataToDraw then 
               local cardWidth = CardSizing.getCardWidth()
               local cardHeight = CardSizing.getCardHeight()
               
               local sourceComponent = nil
               for _, component in ipairs(uiComponents) do
                   if component.data and component.data.instanceId == itemDataToDraw.instanceId then
                       sourceComponent = component
                       break
                   end
               end
               
               local cardX, cardY
               
               if sourceComponent and sourceComponent.animationState.isDropping then
                   local anim = sourceComponent.animationState
                   local progress = 1 - (1 - anim.dropProgress)^2
                   
                   cardX = anim.dropStartX + (anim.dropTargetX - anim.dropStartX) * progress - cardWidth/2
                   cardY = anim.dropStartY + (anim.dropTargetY - anim.dropStartY) * progress - cardHeight/2
                   
               elseif sourceComponent and sourceComponent.animationState.initialX and sourceComponent.animationState.initialY and not sourceComponent.animationState.isDropping then
                   local anim = sourceComponent.animationState
                   local animationDuration = 0.3
                   local progress = math.min(1.0, (anim.currentTime or 0) / animationDuration)
                   progress = 1 - (1 - progress)^3
                   
                   cardX = anim.initialX + (mouseX - anim.initialX) * progress - cardWidth/2
                   cardY = anim.initialY + (mouseY - anim.initialY) * progress - cardHeight/2
                   
                   if progress >= 1.0 then
                       cardX = mouseX - cardWidth/2
                       cardY = mouseY - cardHeight/2
                   end
               else
                   cardX = mouseX - cardWidth/2
                   cardY = mouseY - cardHeight/2
               end
               
               local offsetY = -8
               local shadowAlpha = 0.7
               local shadowOffset = 8
               
               cardY = cardY + offsetY
               
               love.graphics.setColor(0, 0, 0, shadowAlpha)
               love.graphics.rectangle("fill", cardX + shadowOffset, cardY + shadowOffset - offsetY, cardWidth, cardHeight, 3)
               
               -- Create a temporary EmployeeCard instance to render the dragged item
               local draggedCard = EmployeeCard:new({
                   data = itemDataToDraw,
                   rect = {x = cardX, y = cardY, w = cardWidth, h = cardHeight},
                   context = "dragged",
                   gameState = gameState,
                   battleState = battleState,
                   draggedItemState = {item = nil}, -- Prevent recursion
                   uiElementRects = uiElementRects
               })
               
               love.graphics.push()
               love.graphics.setColor(1, 1, 1, 0.9)
               draggedCard:draw(context) -- Use the component's own draw method
               love.graphics.pop()
               love.graphics.setColor(1, 1, 1, 1)
           end
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

   -- NEW: Draw modifier tooltips
   if uiElementRects.modifierTooltipArea then
       local modArea = uiElementRects.modifierTooltipArea
       local mouseX, mouseY = love.mouse.getPosition()
       
       if Drawing.isMouseOver(mouseX, mouseY, modArea.x, modArea.y, modArea.w, modArea.h) then
           local modifier = modArea.modifier
           if modifier then
               local tooltipText = modifier.name .. " (" .. modifier.rarity .. ")\n\n" .. modifier.description
               
               local textWidthForWrap = 250
               local wrappedHeight = Drawing.drawTextWrapped(tooltipText, 0, 0, textWidthForWrap, Drawing.UI.font, "left", nil, false)
               local tooltipWidth = textWidthForWrap + 16
               local tooltipHeight = wrappedHeight + 16
               local tipX = mouseX + 15
               local tipY = mouseY - tooltipHeight - 10
               
               -- Reposition if off screen
               if tipX + tooltipWidth > love.graphics.getWidth() then
                   tipX = mouseX - tooltipWidth - 15
               end
               if tipY < 0 then
                   tipY = mouseY + 15
               end
               
               -- Draw modifier tooltip with rarity-colored border
               local rarityColors = {
                   Common = {0.6, 0.6, 0.6, 1},
                   Uncommon = {0.2, 0.8, 0.2, 1},
                   Rare = {0.2, 0.4, 1, 1},
                   Legendary = {1, 0.8, 0.2, 1},
                   ["Cosmic Horror"] = {0.8, 0.2, 0.8, 1},
                   Experimental = {0.2, 0.8, 0.8, 1}
               }
               
               local borderColor = rarityColors[modifier.rarity] or {0.5, 0.5, 0.5, 1}
               Drawing.drawPanel(tipX, tipY, tooltipWidth, tooltipHeight, {0.1, 0.1, 0.1, 0.95}, borderColor, 5)
               
               love.graphics.setFont(Drawing.UI.font)
               love.graphics.setColor(1, 1, 1, 1)
               Drawing.drawTextWrapped(tooltipText, tipX + 8, tipY + 8, textWidthForWrap, Drawing.UI.font, "left")
           end
       end
   end

   Drawing.drawSprintOverviewPanel(sprintOverviewRects, sprintOverviewState.isVisible, gameState)
   
   if sprintOverviewState.isVisible then
       for _, component in ipairs(sprintOverviewComponents) do
           if sprintOverviewRects.backButton then
               component.rect = sprintOverviewRects.backButton
           end
           if component.draw then
               component:draw()
           end
       end
   end
   
   modal:draw()
end

function advanceToNextWorkItem()
    modal:hide()
    gameState.currentWorkItemIndex = gameState.currentWorkItemIndex + 1
    if gameState.currentWorkItemIndex > 3 then
        gameState.currentWorkItemIndex = 1
        gameState.currentSprintIndex = gameState.currentSprintIndex + 1
        
        EffectsDispatcher.dispatchEvent("onSprintStart", gameState, { modal = modal }, {})
        
        -- Clear sprint-long flags
        gameState.temporaryEffectFlags.motivationalSpeakerUsedThisSprint = nil
        gameState.temporaryEffectFlags.reOrgUsedThisSprint = nil
        gameState.temporaryEffectFlags.photocopierUsedThisSprint = nil
        gameState.temporaryEffectFlags.fourthWallUsedThisSprint = nil

        for _, emp in ipairs(gameState.hiredEmployees) do
            emp.contributionThisSprint = 0
        end

        if gameState.currentSprintIndex > #GameData.ALL_SPRINTS then
            setGamePhase("game_won")
            return
        else
            -- This logic for removing temporary upgrades seems to have a bug,
            -- as it's checking for 'duration_weeks' which is not a defined property.
            -- For now, we will leave it as is, but it's a candidate for a future fix.
            local permUpgrades = {}
            for _, upgId in ipairs(gameState.purchasedPermanentUpgrades) do 
                local isTemp = false
                for _, upgData in ipairs(GameData.ALL_UPGRADES) do 
                    if upgId == upgData.id and upgData.effect and upgData.effect.duration_weeks then 
                        isTemp = true
                        break 
                    end 
                end
                if not isTemp then 
                    table.insert(permUpgrades, upgId) 
                end 
            end
            gameState.purchasedPermanentUpgrades = permUpgrades
        end
    end
    gameState.currentShopOffers = {employees={}, upgrades={}, decorations={}, restockCountThisWeek=0}
    setGamePhase("hiring_and_upgrades")
end

function handleWinCondition()
    SoundManager:playEffect('win')
    local currentSprint = GameData.ALL_SPRINTS[gameState.currentSprintIndex]
    if not currentSprint then return end
    local currentWorkItem = currentSprint.workItems[gameState.currentWorkItemIndex]
    if not currentWorkItem then return end

    -- Dispatch a generic event for any on-win effects first
    local workItemCompleteArgs = { isBossItem = currentWorkItem.id:find("boss") }
    EffectsDispatcher.dispatchEvent("onWorkItemComplete", gameState, { modal = modal }, workItemCompleteArgs)

    -- Calculate rewards using the event system
    local rewardArgs = { 
        baseReward = currentWorkItem.reward, 
        efficiencyBonus = 0,
        otherBonus = 0,
        vampireDrain = workItemCompleteArgs.vampireDrain or 0
    }
    EffectsDispatcher.dispatchEvent("onCalculateWinReward", gameState, { modal = modal }, rewardArgs)
    
    gameState.budget = gameState.budget + rewardArgs.baseReward + rewardArgs.efficiencyBonus + rewardArgs.otherBonus - rewardArgs.vampireDrain

    -- Clean up battle state
    battleState.currentWorkerId = nil
    battleState.lastContribution = nil
    battleState.phase = 'idle'
    battleState.isShaking = false

    -- Reset employee training flags
    for _, emp in ipairs(gameState.hiredEmployees) do
        if emp.isTraining then emp.isTraining = false; print(emp.name .. " has finished training and is now available.") end
    end
    gameState.temporaryEffectFlags.focusFunnelTargetId = nil
    gameState.temporaryEffectFlags.focusFunnelTotalBonus = nil

    -- Prepare and show the results modal
    local totalRevenue = rewardArgs.baseReward + rewardArgs.efficiencyBonus + rewardArgs.otherBonus
    local totalProfit = totalRevenue - gameState.totalSalariesPaidThisWeek - rewardArgs.vampireDrain
    
    local resultLines = { "", "Base Reward:|+$" .. rewardArgs.baseReward }
    if rewardArgs.efficiencyBonus > 0 then table.insert(resultLines, "Efficiency Bonus:|+$" .. rewardArgs.efficiencyBonus) end
    if rewardArgs.otherBonus > 0 then table.insert(resultLines, "Other Bonuses:|+$" .. rewardArgs.otherBonus) end
    if rewardArgs.vampireDrain > 0 then table.insert(resultLines, "Vampire Tribute:|-$" .. rewardArgs.vampireDrain) end
    table.insert(resultLines, "Salaries Paid:|-$" .. gameState.totalSalariesPaidThisWeek); table.insert(resultLines, ""); table.insert(resultLines, "")
    local profitColor = totalProfit >= 0 and "GREEN" or "RED"; local profitSign = totalProfit >= 0 and "$" or "-$"
    table.insert(resultLines, "PROFIT:" .. profitColor .. ":|" .. profitSign .. math.abs(totalProfit))
    
    local resultMessage = table.concat(resultLines, "\n")
    local modalTitle = "WORK ITEM COMPLETE!\n" .. currentWorkItem.name

    setGamePhase('battle_over')
    
    -- The "Continue" button now calls our new, clean function
    modal:show(modalTitle, resultMessage, { {text = "Continue", onClick = advanceToNextWorkItem, style = "primary"} }, 400)
end

function setGamePhase(newPhase)
    local oldPhase = gameState.gamePhase
    GameState:setGamePhase(gameState, newPhase)
    print("Game phase transitioned from " .. oldPhase .. " to " .. newPhase)

    if newPhase == "battle_active" and oldPhase ~= "battle_active" then
        SoundManager:playMusic('battle')
        battlePhaseManager:changePhase('idle', gameState, battleState) 
    elseif (oldPhase == "battle_active" or oldPhase == "battle_over") and newPhase == "hiring_and_upgrades" then
        SoundManager:playMusic('main')
    end

    -- Reset battle state when leaving battle
    if (oldPhase == "battle_active" or oldPhase == "battle_over") and 
       (newPhase ~= "battle_active" and newPhase ~= "battle_over") then
        Battle:resetBattleState(battleState, gameState)
    end

    -- Create context for state manager
    local context = {
        panelRects = panelRects,
        uiElementRects = uiElementRects,
        draggedItemState = draggedItemState,
        sprintOverviewState = sprintOverviewState,
        buildUIComponents = buildUIComponents,
        setGamePhase = setGamePhase,
        getEmployeeFromGameState = getEmployeeFromGameState,
        Placement = Placement,
        Shop = Shop,
        updateBattle = updateBattle,
        modal = modal
    }
    
    -- Use state manager to change state
    stateManager:changeState(newPhase, gameState, battleState, context)
    
    draggedItemState.item = nil 
    
    -- Always rebuild the UI to match the new game state
    buildUIComponents()
end

function getEmployeeFromGameState(gs, instanceId)
    if not gs or not gs.hiredEmployees or not instanceId then return nil end
    for _, emp in ipairs(gs.hiredEmployees) do
        if emp.instanceId == instanceId then return emp end
    end
    return nil
end

function resetGameAndGlobals()
    print("Resetting game and globals...")
    gameState = GameState:new()
    draggedItemState.item = nil
    
    -- Reset the state manager
    stateManager = StateManager:new()
    
    setGamePhase("hiring_and_upgrades") 
    print("Game reset complete.")
end

_G.buildUIComponents = buildUIComponents