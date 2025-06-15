-- effects_dispatcher.lua
-- Dispatches game events to any entity (employee, upgrade, etc.) that is listening for them.

local GameData = require("data")

local EffectsDispatcher = {}

-- Define the order of execution for event phases.
local PHASES = {
    "PreCalculation",    -- For setup, flag setting, and initial modifications.
    "BaseApplication",   -- For the main, standard effects and calculations.
    "Amplification",     -- For effects that modify or enhance other effects.
    "PostCalculation"    -- For final adjustments, clean-up, and logging.
}

--- Gathers all listeners for a given event from all possible sources.
--- @param eventName string The name of the event.
--- @param gameState table The main game state.
--- @return table A list of all listener handler objects for the event.
local function collectListeners(eventName, gameState)
    local allListeners = {}

    local sources = {
        hiredEmployees = gameState.hiredEmployees or {},
        purchasedPermanentUpgrades = gameState.purchasedPermanentUpgrades or {},
        deskDecorations = gameState.deskDecorations or {},
        activeWorkItemModifier = gameState.activeWorkItemModifier -- NEW: Add active modifier
    }

    -- Collect from employees
    for _, emp in ipairs(sources.hiredEmployees) do
        if emp.listeners and emp.listeners[eventName] then
            for _, handler in ipairs(emp.listeners[eventName]) do
                table.insert(allListeners, { handler = handler, source = emp })
            end
        end
    end

    -- Collect from upgrades
    for _, upgradeId in ipairs(sources.purchasedPermanentUpgrades) do
        local upgradeData
        for _, upg in ipairs(GameData.ALL_UPGRADES) do
            if upg.id == upgradeId then upgradeData = upg; break; end
        end
        if upgradeData and upgradeData.listeners and upgradeData.listeners[eventName] then
            for _, handler in ipairs(upgradeData.listeners[eventName]) do
                table.insert(allListeners, { handler = handler, source = upgradeData })
            end
        end
    end

    -- Collect from desk decorations
    for deskId, decorationId in pairs(sources.deskDecorations) do
        if decorationId then
            local decorationData
            for _, deco in ipairs(GameData.ALL_DESK_DECORATIONS) do
                if deco.id == decorationId then decorationData = deco; break; end
            end
            if decorationData and decorationData.listeners and decorationData.listeners[eventName] then
                for _, handler in ipairs(decorationData.listeners[eventName]) do
                    local sourceWithDeskId = { data = decorationData, deskId = deskId }
                    table.insert(allListeners, { handler = handler, source = sourceWithDeskId })
                end
            end
        end
    end

    -- NEW: Collect from active work item modifier
    if sources.activeWorkItemModifier and sources.activeWorkItemModifier.listeners and sources.activeWorkItemModifier.listeners[eventName] then
        for _, handler in ipairs(sources.activeWorkItemModifier.listeners[eventName]) do
            table.insert(allListeners, { handler = handler, source = sources.activeWorkItemModifier })
        end
    end

    return allListeners
end

-- This new local function goes near the top of effects_dispatcher.lua
local function handleAllPositionalEffects(gameState, eventArgs)
    local targetEmployee = eventArgs.employee
    -- Only apply positional effects to employees on a desk
    if not targetEmployee.deskId then return end

    -- Lazily require these modules to avoid potential circular dependencies
    local Placement = require("placement")
    local GameData = require("data")

    -- Loop through ALL hired employees to see if any are a source of a positional effect
    for _, sourceEmployee in ipairs(gameState.hiredEmployees) do
        -- A source must be on a desk, not be the target, and have positional effects defined
        if sourceEmployee.deskId and sourceEmployee.instanceId ~= targetEmployee.instanceId and sourceEmployee.positionalEffects then
            
            for direction, effect in pairs(sourceEmployee.positionalEffects) do
                -- This handles "all_adjacent" or specific directions like "up", "down"
                local directionsToCheck = (direction == "all_adjacent" or direction == "sides") and {"up", "down", "left", "right"} or {direction}
                if direction == "sides" then directionsToCheck = {"left", "right"} end

                for _, dir in ipairs(directionsToCheck) do
                    -- Check if the target employee is in the specified neighboring position
                    if Placement:getNeighboringDeskId(sourceEmployee.deskId, dir, GameData.GRID_WIDTH, GameData.TOTAL_DESK_SLOTS, gameState.desks) == targetEmployee.deskId then
                        
                        -- Check for special conditions on the effect itself (e.g., The Synergist not affecting other Synergists)
                        if not (effect.condition_not_id and targetEmployee.id == effect.condition_not_id) then
                            -- Apply the generic effect based on what's in the positionalEffects table
                            local level_mult = (effect.scales_with_level and (sourceEmployee.level or 1) or 1)
                            
                            local prod_add = (effect.productivity_add or 0) * level_mult
                            local focus_add = (effect.focus_add or 0) * level_mult
                            local prod_mult = 1 + (((effect.productivity_mult or 1) - 1) * level_mult)
                            local focus_mult = 1 + (((effect.focus_mult or 1) - 1) * level_mult)
                            
                            -- Handle the Positional Inverter upgrade
                            if eventArgs.isPositionalInversionActive then
                                prod_add = -prod_add
                                focus_add = -focus_add
                                if prod_mult ~= 0 and prod_mult ~= 1 then prod_mult = 1 / prod_mult end
                                if focus_mult ~= 0 and focus_mult ~= 1 then focus_mult = 1 / focus_mult end
                            end

                            -- Apply bonuses and log them
                            if prod_add ~= 0 then
                                eventArgs.stats.productivity = eventArgs.stats.productivity + prod_add
                                table.insert(eventArgs.stats.log.productivity, string.format("%s%d from %s", prod_add > 0 and "+" or "", prod_add, sourceEmployee.name))
                                if eventArgs.bonusesApplied and eventArgs.bonusesApplied.positional then
                                    eventArgs.bonusesApplied.positional.prod = eventArgs.bonusesApplied.positional.prod + prod_add
                                end
                            end
                            if focus_add ~= 0 then
                                eventArgs.stats.focus = eventArgs.stats.focus + focus_add
                                table.insert(eventArgs.stats.log.focus, string.format("%s%.2fx from %s", focus_add > 0 and "+" or "", focus_add, sourceEmployee.name))
                                if eventArgs.bonusesApplied and eventArgs.bonusesApplied.positional then
                                    eventArgs.bonusesApplied.positional.focus = eventArgs.bonusesApplied.positional.focus + focus_add
                                end
                            end
                            if prod_mult ~= 1 then
                                eventArgs.stats.productivity = math.floor(eventArgs.stats.productivity * prod_mult)
                                table.insert(eventArgs.stats.log.productivity, string.format("*%.2fx from %s", prod_mult, sourceEmployee.name))
                            end
                             if focus_mult ~= 1 then
                                eventArgs.stats.focus = eventArgs.stats.focus * focus_mult
                                table.insert(eventArgs.stats.log.focus, string.format("*%.2fx from %s", focus_mult, sourceEmployee.name))
                            end
                        end
                        
                        -- For "all_adjacent" or "sides", we apply the effect once and then stop checking other directions for this source
                        if direction == "all_adjacent" or direction == "sides" then break end
                    end
                end
            end
        end
    end
end


--- Dispatches a named event to all listening entities in a phased, prioritized order.
--- @param eventName string The name of the event to fire.
--- @param gameState table The entire current game state.
--- @param services table A table of shared services like modal.
--- @param eventArgs table An optional table of arguments specific to this event.
function EffectsDispatcher.dispatchEvent(eventName, gameState, services, eventArgs)
   eventArgs = eventArgs or {}
   services = services or {}

    if eventName == "onCalculateStats" then
        handleAllPositionalEffects(gameState, eventArgs)
    end

   local allListeners = collectListeners(eventName, gameState)
   if #allListeners == 0 then return end

   -- Iterate through each phase in the defined order
   for _, phaseName in ipairs(PHASES) do
       local phaseListeners = {}

       -- Collect all listeners belonging to the current phase
       for _, listenerInfo in ipairs(allListeners) do
           if listenerInfo.handler.phase == phaseName then
               table.insert(phaseListeners, listenerInfo)
           end
       end

       -- If there are listeners for this phase, sort and execute them
       if #phaseListeners > 0 then
           -- Sort listeners by priority (lower number = higher priority = runs first)
           table.sort(phaseListeners, function(a, b)
               return (a.handler.priority or 50) < (b.handler.priority or 50)
           end)

           -- Execute the callbacks for this phase
           for _, listenerInfo in ipairs(phaseListeners) do
               local source = listenerInfo.source
               local callback = listenerInfo.handler.callback
               local handler = listenerInfo.handler
               
               -- Special handling for positional focus effects when neutralized
               if eventName == "onCalculateStats" and eventArgs.neutralizePositionalFocus and source.positionalEffects then
                   local hasPositionalFocusEffect = false
                   for _, effect in pairs(source.positionalEffects) do
                       if effect.focus_add or effect.focus_mult then
                           hasPositionalFocusEffect = true
                           break
                       end
                   end
                   -- Skip this listener if it has positional focus effects and they're neutralized
                   if hasPositionalFocusEffect then
                       goto continue
                   end
               end
               
               -- WRAP CALLBACK EXECUTION IN ERROR HANDLING
               local success, errorMsg = pcall(function()
                   -- Special handling for desk decorations to pass the deskId
                   if source.data and source.deskId then
                        callback(source.data, gameState, services, eventArgs, source.deskId)
                   else
                        callback(source, gameState, services, eventArgs)
                   end
               end)
               
               -- HANDLE ERRORS WITH MODAL
               if not success then
                   -- Build descriptive error info
                   local sourceName = source.name or source.id or "Unknown Entity"
                   local sourceType = source.data and "Decoration" or "Employee/Upgrade"
                   local phase = handler.phase or "Unknown Phase"
                   local priority = handler.priority or "No Priority"
                   
                   local listenerInfo = string.format("%s - %s (Phase: %s, Priority: %s)", 
                       sourceName, eventName, phase, priority)
                   
                   local errorTitle = "Listener Error"
                   local errorMessage = string.format("Error in listener:\n%s\n\nError: %s", 
                       listenerInfo, errorMsg)
                   
                   if services and services.modal then
                       -- PAUSE BATTLE BEFORE SHOWING MODAL
                       if services.battlePhaseManager then
                           local currentPhase = services.battlePhaseManager:getCurrentPhaseName()
                           if currentPhase and currentPhase ~= "idle" then
                               services.battlePhaseManager:changePhase("idle", gameState, battleState)
                           end
                       end
                       
                       services.modal:show(errorTitle, errorMessage, {
                           {text = "OK", onClick = function() 
                               -- Just close modal and continue - battle stays paused in idle
                           end, style = "primary"}
                       })
                   else
                       print("ERROR: " .. errorMessage) -- Fallback if modal not available
                   end
                   
                   -- Continue to next listener - this one is ignored
               end
               
               ::continue::
           end
       end
   end
end

return EffectsDispatcher