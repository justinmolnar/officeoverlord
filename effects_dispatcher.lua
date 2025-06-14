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
        deskDecorations = gameState.deskDecorations or {}
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
                    -- Add deskId to the source so the listener knows where it is
                    local sourceWithDeskId = { data = decorationData, deskId = deskId }
                    table.insert(allListeners, { handler = handler, source = sourceWithDeskId })
                end
            end
        end
    end

    return allListeners
end


--- Dispatches a named event to all listening entities in a phased, prioritized order.
--- @param eventName string The name of the event to fire.
--- @param gameState table The entire current game state.
--- @param services table A table of shared services like modal.
--- @param eventArgs table An optional table of arguments specific to this event.
function EffectsDispatcher.dispatchEvent(eventName, gameState, services, eventArgs)
   eventArgs = eventArgs or {}
   services = services or {}

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