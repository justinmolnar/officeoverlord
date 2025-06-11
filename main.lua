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

-- Component Imports
local Button = require("components.button")
local EmployeeCard = require("components.employee_card")
local UpgradeCard = require("components/upgrade_card")
local Checkbox = require("components/checkbox")
local Dropdown = require("components/dropdown")
local PurchasedUpgradeIcon = require("components/purchased_upgrade_icon")
local DeskSlot = require("components/desk_slot")

local StateManager = require("game_states.state_manager")
local stateManager





function _G.getCurrentMaxLevel(gameState)
    local eventArgs = { maxLevel = 3 }
    require("effects_dispatcher").dispatchEvent("onGetMaxLevel", gameState, eventArgs)
    return eventArgs.maxLevel
end

local gameState
local tooltipsToDraw = {}
local overlaysToDraw = {}

-- UI Component Lists
local uiComponents = {}
local debugComponents = {}

-- State variables are wrapped in tables to be passed by reference
local sprintOverviewState = { isVisible = false }
local sprintOverviewRects = {} -- To hold rects for the new panel UI

local debugMenuState = { isVisible = false }
local debug = {
    rect = {},
    employeeDropdown = { options = {}, selected = 1, isOpen = false, rect = {}, scrollOffset = 0 },
    upgradeDropdown = { options = {}, selected = 1, isOpen = false, rect = {}, scrollOffset = 0 },
    checkboxes = {
        remote = { checked = false, rect = {} },
        foil = { checked = false, rect = {} },
        holo = { checked = false, rect = {} }
    },
    buttons = {},
    hotkeyState = {
        plus = { timer = 0, initial = 0.4, repeatDelay = 0.1 },
        minus = { timer = 0, initial = 0.4, repeatDelay = 0.1 }
    }
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

function initializeDebugMenu()
    -- Populate employee options
    debug.employeeDropdown.options = {}
    for _, card in ipairs(GameData.BASE_EMPLOYEE_CARDS) do
        table.insert(debug.employeeDropdown.options, { name = card.name, id = card.id })
    end
    table.sort(debug.employeeDropdown.options, function(a, b) return a.name < b.name end)
    
    -- Populate upgrade options
    debug.upgradeDropdown.options = {}
    for _, upg in ipairs(GameData.ALL_UPGRADES) do
        table.insert(debug.upgradeDropdown.options, { name = upg.name, id = upg.id })
    end
    table.sort(debug.upgradeDropdown.options, function(a, b) return a.name < b.name end)
end

--- Clears and rebuilds ALL active UI components based on the current gameState.
function buildUIComponents()
   uiComponents = {}
   uiElementRects.desks = {}
   uiElementRects.remote = {}
   
   if gameState.gamePhase == "hiring_and_upgrades" then
       local infoPanelRect = panelRects.gameInfo
       local btnWidth, btnHeight, btnX = infoPanelRect.width - 20, 35, infoPanelRect.x + 10
       local mainActionBtnY = infoPanelRect.y + infoPanelRect.height - btnHeight - 10
       local viewSprintBtnY = mainActionBtnY - btnHeight - 5
       table.insert(uiComponents, Button:new({ rect = {x=btnX, y=viewSprintBtnY, w=btnWidth, h=btnHeight}, text = "View Sprint Details", style = "info", onClick = function() sprintOverviewState.isVisible = true end }))
       table.insert(uiComponents, Button:new({ rect = {x=btnX, y=mainActionBtnY, w=btnWidth, h=btnHeight}, text = "Start Work Item", style = "secondary", onClick = function() setGamePhase("battle_active") end }))

       local shopRect = panelRects.shop
       local cardPadding = 5
       local cardWidth = shopRect.width - 2 * cardPadding
       local currentY = shopRect.y + Drawing.UI.fontLarge:getHeight() + 28

       if gameState.currentShopOffers and gameState.currentShopOffers.employees then
           for i, empData in ipairs(gameState.currentShopOffers.employees) do
               if empData then
                   table.insert(uiComponents, EmployeeCard:new({ data = empData, rect = {x=shopRect.x+cardPadding, y=currentY, w=cardWidth, h=140}, context = "shop_offer", gameState=gameState, battleState=battleState, draggedItemState=draggedItemState, uiElementRects=uiElementRects }))
                   currentY = currentY + 140 + 5
               end
           end
       end
       currentY = shopRect.y + Drawing.UI.fontLarge:getHeight() + 28 + (140 + 5) * 3 + 15 + Drawing.UI.font:getHeight() + 8
       if gameState.currentShopOffers and gameState.currentShopOffers.upgrade then
           table.insert(uiComponents, UpgradeCard:new({ data = gameState.currentShopOffers.upgrade, rect = {x=shopRect.x+cardPadding, y=currentY, w=cardWidth, h=110}, gameState = gameState, uiElementRects = uiElementRects }))
       end
       local restockBtnY = shopRect.y + shopRect.height - 35 - 10
       local restockButton = Button:new({ rect = {x = shopRect.x + cardPadding, y = restockBtnY, w = cardWidth, h = 35}, text = "Restock", style = "warning", context = "shop_button", isEnabled = function() local cost = GameData.BASE_RESTOCK_COST * (2 ^ (gameState.currentShopOffers.restockCountThisWeek or 0)); return gameState.budget >= cost and not draggedItemState.item end, onClick = function() local success, msg = Shop:attemptRestock(gameState); if not success then Drawing.showModal("Restock Failed", msg) end end })
       function restockButton:draw() local cost = GameData.BASE_RESTOCK_COST * (2 ^ (gameState.currentShopOffers.restockCountThisWeek or 0)); if Shop:isUpgradePurchased(gameState.purchasedPermanentUpgrades, 'headhunter') then cost = cost * 2 end; self.text = "Restock ($" .. cost .. ")"; Button.draw(self); end
       restockButton.gameState = gameState
       table.insert(uiComponents, restockButton)
   end

   if gameState.gamePhase == "game_over" or gameState.gamePhase == "game_won" then
       local infoPanelRect = panelRects.gameInfo
       local btnWidth, btnHeight, btnX = infoPanelRect.width - 20, 35, infoPanelRect.x + 10
       local mainActionBtnY = infoPanelRect.y + infoPanelRect.height - btnHeight - 10
       local buttonText = (gameState.gamePhase == "game_won" and "Play Again?" or "Restart Game")
       local buttonStyle = (gameState.gamePhase == "game_won" and "primary" or "danger")
       table.insert(uiComponents, Button:new({ rect = {x=btnX, y=mainActionBtnY, w=btnWidth, h=btnHeight}, text = buttonText, style = buttonStyle, onClick = function() resetGameAndGlobals() end }))
   end

   local gridGeometry = Drawing._calculateDeskGridGeometry(panelRects.mainInteraction)
   for i, deskData in ipairs(gameState.desks) do
       local col = (i - 1) % GameData.GRID_WIDTH
       local row = math.floor((i - 1) / GameData.GRID_WIDTH)
       local deskRect = { x = gridGeometry.startX + col * (gridGeometry.width + gridGeometry.spacing), y = gridGeometry.startY + row * (gridGeometry.height + gridGeometry.spacing), w = gridGeometry.width, h = gridGeometry.height }
       uiElementRects.desks[i] = {id = deskData.id, x = deskRect.x, y = deskRect.y, w = deskRect.w, h = deskRect.h}
       table.insert(uiComponents, DeskSlot:new({rect = deskRect, data = deskData, gameState = gameState}))
       
       local empId = gameState.deskAssignments[deskData.id]
       if empId then
           local empData = Employee:getFromState(gameState, empId)
           if empData then
               local contextArgs = { employee = empData, context = "desk_placed" }
               EffectsDispatcher.dispatchEvent("onEmployeeContextCheck", gameState, contextArgs)
               
               local row = math.floor((tonumber(string.match(deskData.id, "%d+")) or 0) / GameData.GRID_WIDTH)
               local isDeskDisabled = (gameState.temporaryEffectFlags.isTopRowDisabled and row == 0)
               
               if empData.isTraining or isDeskDisabled then 
                   contextArgs.context = "worker_training"
               elseif gameState.gamePhase == "battle_active" then
                   local workerIndexInBattle = -1
                   for j, activeEmp in ipairs(battleState.activeEmployees) do 
                       if activeEmp.instanceId == empData.instanceId then 
                           workerIndexInBattle = j
                           break 
                       end 
                   end
                   if workerIndexInBattle ~= -1 and workerIndexInBattle < battleState.nextEmployeeIndex then 
                       contextArgs.context = "worker_done" 
                   end
               end
               
               table.insert(uiComponents, EmployeeCard:new({data = empData, rect = {x = deskRect.x+2, y=deskRect.y+2, w=deskRect.w-4, h=deskRect.h-4}, context = contextArgs.context, gameState=gameState, battleState=battleState, draggedItemState=draggedItemState, uiElementRects=uiElementRects}))
           end
       end
   end

    for _, empData in ipairs(gameState.hiredEmployees) do
        if empData.variant == 'remote' then
            local contextArgs = { employee = empData, context = "remote_worker" }
            EffectsDispatcher.dispatchEvent("onEmployeeContextCheck", gameState, contextArgs)
            
            if empData.isTraining or gameState.temporaryEffectFlags.isRemoteWorkDisabled then
                contextArgs.context = "worker_training"
            elseif gameState.gamePhase == "battle_active" then
                local isWorkerActive = false
                for _, activeEmp in ipairs(battleState.activeEmployees) do
                    if activeEmp.instanceId == empData.instanceId then isWorkerActive = true; break; end
                end
                if not isWorkerActive then contextArgs.context = "worker_done" end
            end
            
            table.insert(uiComponents, EmployeeCard:new({data = empData, rect = {}, context = contextArgs.context, gameState=gameState, battleState=battleState, draggedItemState=draggedItemState, uiElementRects=uiElementRects}))
        end
    end

   local upgRect = panelRects.purchasedUpgradesDisplay
   local currentX = upgRect.x + 10
   local iconY = upgRect.y + Drawing.UI.font:getHeight() + 10
   local iconSize = math.min(upgRect.height - (Drawing.UI.font:getHeight() + 15), 32)
   local iconPadding = 5
   for _, upgradeId in ipairs(gameState.purchasedPermanentUpgrades) do
       local upgData = nil
       for _, u in ipairs(GameData.ALL_UPGRADES) do if u.id == upgradeId then upgData = u; break; end end
       if upgData and (currentX + iconSize <= upgRect.x + upgRect.width - 10) then
           table.insert(uiComponents, PurchasedUpgradeIcon:new({ rect = { x = currentX, y = iconY, w = iconSize, h = iconSize }, upgData = upgData, gameState = gameState }))
           currentX = currentX + iconSize + iconPadding
       end
   end
end

function onMouseRelease(x, y, button)
    if button == 1 and draggedItemState.item then
        local successfullyProcessedDrop = false
        local draggedItem = draggedItemState.item

        -- Loop backwards through components so we check top-most items first (e.g., employee card before the desk slot under it)
        for i = #uiComponents, 1, -1 do
            local component = uiComponents[i]
            if component.handleMouseDrop then
                -- The component's method will do its own isMouseOver check
                if component:handleMouseDrop(x, y, draggedItem) then
                    successfullyProcessedDrop = true
                    break -- Drop was handled, exit the loop
                end
            end
        end

        -- Fallback for non-component drop targets, like the general remote panel area
        if not successfullyProcessedDrop then
            if draggedItem.data.variant == 'remote' and Drawing.isMouseOver(x, y, uiElementRects.remotePanelDropTarget.x, uiElementRects.remotePanelDropTarget.y, uiElementRects.remotePanelDropTarget.w, uiElementRects.remotePanelDropTarget.h) then
                if draggedItem.type == "shop_employee" then
                    if gameState.budget < draggedItem.cost then
                        Drawing.showModal("Can't Afford", "Not enough budget. Need $" .. draggedItem.cost)
                    elseif draggedItem.data.special and (draggedItem.data.special.type == 'haunt_target_on_hire' or draggedItem.data.special.type == 'slime_merge') then
                        Drawing.showModal("Invalid Placement", "This employee must be placed on top of another employee.")
                    else
                        gameState.budget = gameState.budget - draggedItem.cost
                        local newEmp = Employee:new(draggedItem.data.id, draggedItem.data.variant, draggedItem.data.fullName)
                        newEmp.instanceId = draggedItem.data.instanceId -- Preserve the shop offer's instanceId
                        table.insert(gameState.hiredEmployees, newEmp)
                        Shop:markOfferSold(gameState.currentShopOffers, draggedItem.originalShopInstanceId, nil) 
                        successfullyProcessedDrop = true
                    end
                elseif draggedItem.type == "placed_employee" then
                    successfullyProcessedDrop = Placement:handleEmployeeDropOnRemote(gameState, draggedItem.data, draggedItem.originalDeskId)
                end
            end
        end

        -- Finalize the drop action
        if successfullyProcessedDrop then
            -- Rebuild the UI to reflect any changes
            buildUIComponents()
        elseif draggedItem.type == "placed_employee" then
            -- This handles snapping back to the original position if the drop was invalid
                local originalEmp = Employee:getFromState(gameState, draggedItem.data.instanceId)            
                if originalEmp then
                if draggedItem.originalDeskId then
                    originalEmp.deskId = draggedItem.originalDeskId
                    gameState.deskAssignments[draggedItem.originalDeskId] = originalEmp.instanceId
                elseif draggedItem.originalVariant == 'remote' then
                    originalEmp.variant = 'remote'
                end
            end
        end
        
        -- End the drag operation
        draggedItemState.item = nil 
    end
end

function love.load()
   Drawing.foilShader = love.graphics.newShader("foil.fs") 
   Drawing.holoShader = love.graphics.newShader("holo.fs") 

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
   
   initializeDebugMenu() 

   -- Initialize the state manager
   stateManager = StateManager:new()

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

   local panelW, panelH = 400, 450
   local panelX, panelY = (love.graphics.getWidth() - panelW) / 2, (love.graphics.getHeight() - panelH) / 2
   local padding = 15
   local dbgW = panelW - padding * 2
   local dbgX = panelX + padding
   local currentY = panelY + 50
   
   table.insert(debugComponents, Dropdown:new({ rect = {x = dbgX, y = currentY, w = dbgW, h = 25}, state = debug.employeeDropdown }))
   currentY = currentY + 35
   
   local chkW = 80
   table.insert(debugComponents, Checkbox:new({ rect = {x=dbgX, y=currentY, w=chkW, h=20}, label="Remote", state=debug.checkboxes.remote, onToggle=function(c) if c then debug.checkboxes.foil.checked=false; debug.checkboxes.holo.checked=false end end }))
   table.insert(debugComponents, Checkbox:new({ rect = {x=dbgX + chkW + 10, y=currentY, w=chkW, h=20}, label="Foil", state=debug.checkboxes.foil, onToggle=function(c) if c then debug.checkboxes.remote.checked=false; debug.checkboxes.holo.checked=false end end }))
   table.insert(debugComponents, Checkbox:new({ rect = {x=dbgX + (chkW + 10) * 2, y=currentY, w=chkW, h=20}, label="Holo", state=debug.checkboxes.holo, onToggle=function(c) if c then debug.checkboxes.remote.checked=false; debug.checkboxes.foil.checked=false end end }))
   currentY = currentY + 30
   
   table.insert(debugComponents, Button:new({ rect = {x=dbgX, y=currentY, w=dbgW, h=30}, text="Spawn Employee in Shop", style="secondary", onClick=function() local sel=debug.employeeDropdown.options[debug.employeeDropdown.selected].id; local v="standard"; if debug.checkboxes.remote.checked then v="remote" elseif debug.checkboxes.foil.checked then v="foil" elseif debug.checkboxes.holo.checked then v="holo" end; Shop:forceAddEmployeeOffer(gameState.currentShopOffers, sel, v); buildUIComponents() end }))
   currentY = currentY + 50 + 20
   
   table.insert(debugComponents, Dropdown:new({ rect = {x = dbgX, y = currentY, w = dbgW, h = 25}, state = debug.upgradeDropdown }))
   currentY = currentY + 35
   
   table.insert(debugComponents, Button:new({ rect = {x=dbgX, y=currentY, w=dbgW, h=30}, text="Spawn Upgrade in Shop", style="secondary", onClick=function() local sel=debug.upgradeDropdown.options[debug.upgradeDropdown.selected].id; Shop:forceAddUpgradeOffer(gameState.currentShopOffers, sel); buildUIComponents() end }))
   currentY = currentY + 50
   
   local smallBtnW = (dbgW - 10) / 2
   table.insert(debugComponents, Button:new({ rect = {x=dbgX, y=currentY, w=smallBtnW, h=30}, text="+ $1000", style="primary", onClick=function() gameState.budget=gameState.budget+1000 end }))
   table.insert(debugComponents, Button:new({ rect = {x=dbgX + smallBtnW + 10, y=currentY, w=smallBtnW, h=30}, text="- $1000", style="primary", onClick=function() gameState.budget=gameState.budget-1000 end }))
   currentY = currentY + 35
   
   table.insert(debugComponents, Button:new({ rect = {x=dbgX, y=currentY, w=dbgW, h=30}, text="Restock Shop", style="warning", onClick=function() Shop:attemptRestock(gameState) end }))
   currentY = currentY + 35
   
   table.insert(debugComponents, Button:new({ rect = {x=dbgX, y=currentY, w=smallBtnW, h=30}, text="<< Prev Item", style="info", onClick=function() gameState.currentWorkItemIndex=gameState.currentWorkItemIndex-1; if gameState.currentWorkItemIndex<1 then gameState.currentSprintIndex=math.max(1,gameState.currentSprintIndex-1); gameState.currentWorkItemIndex=3 end; setGamePhase("hiring_and_upgrades") end }))
   table.insert(debugComponents, Button:new({ rect = {x=dbgX+smallBtnW+10, y=currentY, w=smallBtnW, h=30}, text="Next Item >>", style="info", onClick=function() gameState.currentWorkItemIndex=gameState.currentWorkItemIndex+1; if gameState.currentWorkItemIndex>3 then gameState.currentWorkItemIndex=1; gameState.currentSprintIndex=math.min(#GameData.ALL_SPRINTS,gameState.currentSprintIndex+1) end; setGamePhase("hiring_and_upgrades") end }))
   
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

-- Updated love.update function in main.lua
function love.update(dt)
    InputHandler.update(dt)
    local context = {
        panelRects = panelRects,
        uiElementRects = uiElementRects,
        draggedItemState = draggedItemState,
        sprintOverviewState = sprintOverviewState,
        updateBattle = updateBattle,
        buildUIComponents = buildUIComponents,
        setGamePhase = setGamePhase,
        getEmployeeFromGameState = getEmployeeFromGameState,
        Placement = Placement,
        Shop = Shop
    }
    stateManager:update(dt, gameState, battleState, context)
end

function love.keypressed(key)
    InputHandler.onKeyPress(key)
end

function love.mousewheelmoved(x, y)
    if debugMenuState.isVisible then
        for _, component in ipairs(debugComponents) do
            if component.handleMouseWheel and component:handleMouseWheel(y) then
                return -- Stop after the first component handles the scroll
            end
        end
    end
end

function love.mousepressed(x, y, button, istouch, presses)
    if debugMenuState.isVisible then
        local aDropdownIsHandlingInput = false
        for _, component in ipairs(debugComponents) do
            if component.state and component.state.isOpen and component.handleMousePress then
                if component:handleMousePress(x, y, button) then
                    aDropdownIsHandlingInput = true
                    break
                end
            end
        end
        if aDropdownIsHandlingInput then return end

        for i = #debugComponents, 1, -1 do
            local component = debugComponents[i]
            if not (component.state and component.state.isOpen) then
                if component.handleMousePress and component:handleMousePress(x, y, button) then
                    return 
                end
            end
        end
        if Drawing.isMouseOver(x,y,debug.rect.x, debug.rect.y, debug.rect.w, debug.rect.h) then return end
    end
    
    if sprintOverviewState.isVisible then
        if sprintOverviewRects.backButton and Drawing.isMouseOver(x, y, sprintOverviewRects.backButton.x, sprintOverviewRects.backButton.y, sprintOverviewRects.backButton.w, sprintOverviewRects.backButton.h) then
            sprintOverviewState.isVisible = false
        end
        return
    end

    if Drawing.modal.isVisible and Drawing.handleModalClick(x, y) then return end

    -- Create context for state manager
    local context = {
        uiComponents = uiComponents,
        panelRects = panelRects,
        uiElementRects = uiElementRects,
        draggedItemState = draggedItemState,
        Shop = Shop,
        Placement = Placement
    }
    
    -- Use state manager for input handling
    if stateManager:handleInput(x, y, button, gameState, battleState, context) then
        return
    end
    
    -- Fallback to the old handler for things not yet componentized
    InputHandler.onMousePress(x, y, button)
end

function love.mousereleased(x, y, button, istouch)
    onMouseRelease(x, y, button)
end

function love.draw()
    love.graphics.setBackgroundColor(Drawing.UI.colors.background)
    love.graphics.clear()

    tooltipsToDraw = {}
    Drawing.tooltipsToDraw = tooltipsToDraw 
    
    uiElementRects.shopLockButtons = {}

    -- Create context for state manager
    local context = {
        panelRects = panelRects,
        uiElementRects = uiElementRects,
        draggedItemState = draggedItemState,
        sprintOverviewState = sprintOverviewState,
        Placement = Placement,
        Shop = Shop
    }
    
    -- Use state manager for drawing
    stateManager:draw(gameState, battleState, context)
    
    for _, component in ipairs(uiComponents) do
        if component.draw then component:draw() end
    end
    
    if debugMenuState.isVisible then
        Drawing.drawDebugMenu(debug)
        for _, component in ipairs(debugComponents) do
            if component.draw then component:draw() end
        end
        for _, component in ipairs(debugComponents) do
            if component.drawOpenList then component:drawOpenList() end
        end
    end
    
    if draggedItemState.item then
        local itemDataToDraw = draggedItemState.item.data
        if itemDataToDraw then 
            local mouseX, mouseY = love.mouse.getPosition()
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
            local roundResult = Battle:endWorkCycleRound(gameState, 0, Drawing.showModal)
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
            local roundResult = Battle:endWorkCycleRound(gameState, battleState.salariesToPayThisRound, Drawing.showModal)
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
        updateBattle = updateBattle
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
