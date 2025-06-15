-- effects_dispatcher.lua
-- Dispatches game events to any entity (employee, upgrade, etc.) that is listening for them.
-- MODIFIED: Only logs when actual changes occur

local GameData = require("data")

local EffectsDispatcher = {}

-- Define the order of execution for event phases.
local PHASES = {
    "PreCalculation",    -- For setup, flag setting, and initial modifications.
    "BaseApplication",   -- For the main, standard effects and calculations.
    "Amplification",     -- For effects that modify or enhance other effects.
    "PostCalculation"    -- For final adjustments, clean-up, and logging.
}

-- Logging configuration
local LOGGING_ENABLED = true
local LOG_PREFIX = "[EFFECTS] "

-- Events that should be logged and how to detect changes
local LOGGED_EVENTS = {
    onPurchase = "always", -- Always log purchases
    onHire = "always", -- Always log hires
    onPlacement = "always", -- Always log placement attempts
    onWorkItemStart = "always", -- Always log work item starts
    onWorkItemComplete = "always", -- Always log completions
    onSprintStart = "always", -- Always log sprint starts
    onBudgetDepleted = "always", -- Always log budget depletion
    onApply = "always", -- Always log ability applications
    onActivate = "always", -- Always log ability activations
    onBeforeContribution = "on_change", -- Only if contribution multiplier changes
    onAfterContribution = "on_change", -- Only if contribution value changes
    onCalculateStats = "on_change", -- Only if stats actually change
}

-- Track what we've logged this turn to avoid spam
local turnLogTracker = {}
local currentTurnId = nil

-- Helper function to generate a turn ID
local function generateTurnId(gameState)
    return (gameState.currentSprintIndex or 0) .. "-" .. 
           (gameState.currentWorkItemIndex or 0) .. "-" .. 
           (gameState.currentWeekCycles or 0)
end

-- Cache to track the last calculated result for each employee
local lastCalculatedStats = {}

-- Helper function to detect if onCalculateStats made meaningful changes
local function detectStatsChanges(beforeStats, afterStats, employeeId)
    if not beforeStats or not afterStats then return false end
    
    -- Check if this is actually a change from the base stats
    local prodChanged = math.abs((afterStats.productivity or 0) - (beforeStats.productivity or 0)) > 0.001
    local focusChanged = math.abs((afterStats.focus or 1.0) - (beforeStats.focus or 1.0)) > 0.001
    
    -- If no change from base stats, don't log
    if not prodChanged and not focusChanged then
        return false
    end
    
    -- Check if this result is different from the last time we calculated for this employee
    if employeeId then
        local lastResult = lastCalculatedStats[employeeId]
        if lastResult then
            local sameAsBefore = (
                math.abs((afterStats.productivity or 0) - (lastResult.productivity or 0)) < 0.001 and
                math.abs((afterStats.focus or 1.0) - (lastResult.focus or 1.0)) < 0.001
            )
            
            if sameAsBefore then
                return false -- Same result as last time, don't log
            end
        end
        
        -- Cache this result for next time
        lastCalculatedStats[employeeId] = {
            productivity = afterStats.productivity,
            focus = afterStats.focus
        }
    end
    
    return true -- This is a genuinely new/different result
end

-- Helper function to detect if contribution events made changes
local function detectContributionChanges(eventName, eventArgs, beforeValue)
    if eventName == "onBeforeContribution" then
        local afterMultiplier = eventArgs.contributionMultiplier or 1.0
        return math.abs(afterMultiplier - (beforeValue or 1.0)) > 0.001
    elseif eventName == "onAfterContribution" then
        local afterContribution = eventArgs.contribution or 0
        return afterContribution ~= (beforeValue or 0)
    end
    return false
end

-- Helper function to check if we should log this event
local function shouldLogEvent(eventName, gameState, eventArgs, changeDetected)
    if not LOGGING_ENABLED then return false end
    
    local logRule = LOGGED_EVENTS[eventName]
    if not logRule then return false end -- Not in our logged events list
    
    if logRule == "always" then 
        return true 
    elseif logRule == "on_change" then
        return changeDetected == true
    end
    
    return false
end

-- Helper function to safely get a name for logging
local function getSourceName(source)
    if source.data then
        return source.data.name or source.data.id or "Unknown Decoration"
    end
    return source.name or source.id or source.fullName or "Unknown Source"
end

-- Helper function to log event dispatch
local function logEventStart(eventName, gameState, eventArgs, hasListeners)
    local context = ""
    if eventArgs.employee then
        context = string.format(" [Employee: %s]", eventArgs.employee.name or eventArgs.employee.id or "Unknown")
    elseif eventArgs.workItem then
        context = string.format(" [WorkItem: %s]", eventArgs.workItem.name or "Unknown")
    end
    
    print(LOG_PREFIX .. "=== EVENT START: " .. eventName .. context .. " (" .. (hasListeners or 0) .. " listeners) ===")
end

-- Helper function to log detailed stat calculation ONLY when changes occur
local function logStatCalculation(eventName, gameState, eventArgs, beforeStats, afterStats, changesDetected)
    if eventName ~= "onCalculateStats" or not changesDetected then return end
    
    local employee = eventArgs.employee
    if not employee then return end
    
    local empName = employee.name or employee.id or "Unknown"
    local baseProd = employee.baseProductivity or 0
    local baseFocus = employee.baseFocus or 1.0
    
    print(LOG_PREFIX .. string.format("STAT CHANGE: %s", empName))
    print(LOG_PREFIX .. string.format("  Base: %d Prod, %.2fx Focus", baseProd, baseFocus))
    print(LOG_PREFIX .. string.format("  Final: %d Prod, %.2fx Focus", afterStats.productivity, afterStats.focus))
    
    -- Show what changed
    local prodChange = afterStats.productivity - baseProd
    local focusChange = afterStats.focus - baseFocus
    
    if math.abs(prodChange) > 0.001 then
        print(LOG_PREFIX .. string.format("  Prod Change: %+d", prodChange))
    end
    if math.abs(focusChange) > 0.001 then
        print(LOG_PREFIX .. string.format("  Focus Change: %+.3fx", focusChange))
    end
    
    -- Show all modifiers that were applied (only non-base entries)
    if afterStats.log and afterStats.log.productivity and #afterStats.log.productivity > 1 then
        local modifiers = {}
        for i = 2, #afterStats.log.productivity do -- Skip base entry
            table.insert(modifiers, afterStats.log.productivity[i])
        end
        if #modifiers > 0 then
            print(LOG_PREFIX .. "  Prod Modifiers: " .. table.concat(modifiers, ", "))
        end
    end
    if afterStats.log and afterStats.log.focus and #afterStats.log.focus > 1 then
        local modifiers = {}
        for i = 2, #afterStats.log.focus do -- Skip base entry
            table.insert(modifiers, afterStats.log.focus[i])
        end
        if #modifiers > 0 then
            print(LOG_PREFIX .. "  Focus Modifiers: " .. table.concat(modifiers, ", "))
        end
    end
end

--- Gathers all listeners for a given event from all possible sources.
local function collectListeners(eventName, gameState)
    local allListeners = {}

    local sources = {
        hiredEmployees = gameState.hiredEmployees or {},
        purchasedPermanentUpgrades = gameState.purchasedPermanentUpgrades or {},
        deskDecorations = gameState.deskDecorations or {},
        activeWorkItemModifier = gameState.activeWorkItemModifier
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

    -- Collect from active work item modifier
    if sources.activeWorkItemModifier and sources.activeWorkItemModifier.listeners and sources.activeWorkItemModifier.listeners[eventName] then
        for _, handler in ipairs(sources.activeWorkItemModifier.listeners[eventName]) do
            table.insert(allListeners, { handler = handler, source = sources.activeWorkItemModifier })
        end
    end

    return allListeners
end

-- Handle positional effects (unchanged from original)
local function handleAllPositionalEffects(gameState, eventArgs)
    local targetEmployee = eventArgs.employee
    if not targetEmployee.deskId then return end

    -- Require modules
    local Placement = require("placement")
    local GameData = require("data")

    -- Check all employees for positional effects on this target
    for _, sourceEmployee in ipairs(gameState.hiredEmployees) do
        if sourceEmployee.deskId and sourceEmployee.instanceId ~= targetEmployee.instanceId and sourceEmployee.positionalEffects then
            
            for direction, effect in pairs(sourceEmployee.positionalEffects) do
                local directionsToCheck = (direction == "all_adjacent" or direction == "sides") and {"up", "down", "left", "right"} or {direction}
                if direction == "sides" then directionsToCheck = {"left", "right"} end

                for _, dir in ipairs(directionsToCheck) do
                    if Placement:getNeighboringDeskId(sourceEmployee.deskId, dir, GameData.GRID_WIDTH, GameData.TOTAL_DESK_SLOTS, gameState.desks) == targetEmployee.deskId then
                        
                        if not (effect.condition_not_id and targetEmployee.id == effect.condition_not_id) then
                            local level_mult = (effect.scales_with_level and (sourceEmployee.level or 1) or 1)
                            
                            local prod_add = (effect.productivity_add or 0) * level_mult
                            local focus_add = (effect.focus_add or 0) * level_mult
                            local prod_mult = 1 + (((effect.productivity_mult or 1) - 1) * level_mult)
                            local focus_mult = 1 + (((effect.focus_mult or 1) - 1) * level_mult)
                            
                            -- Handle Positional Inverter
                            if eventArgs.isPositionalInversionActive then
                                prod_add = -prod_add
                                focus_add = -focus_add
                                if prod_mult ~= 0 and prod_mult ~= 1 then prod_mult = 1 / prod_mult end
                                if focus_mult ~= 0 and focus_mult ~= 1 then focus_mult = 1 / focus_mult end
                            end

                            -- Apply effects
                            if prod_add ~= 0 then
                                eventArgs.stats.productivity = eventArgs.stats.productivity + prod_add
                                table.insert(eventArgs.stats.log.productivity, string.format("%s%d from %s", prod_add > 0 and "+" or "", prod_add, sourceEmployee.name))
                            end
                            if focus_add ~= 0 then
                                eventArgs.stats.focus = eventArgs.stats.focus + focus_add
                                table.insert(eventArgs.stats.log.focus, string.format("%s%.2fx from %s", focus_add > 0 and "+" or "", focus_add, sourceEmployee.name))
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
                        
                        if direction == "all_adjacent" or direction == "sides" then break end
                    end
                end
            end
        end
    end
end

--- Dispatches a named event to all listening entities in a phased, prioritized order.
--- MODIFIED: Only logs when actual changes are detected
function EffectsDispatcher.dispatchEvent(eventName, gameState, services, eventArgs)
    eventArgs = eventArgs or {}
    services = services or {}

    local allListeners = collectListeners(eventName, gameState)
    
    -- Early exit if no listeners and this isn't a logged event
    if #allListeners == 0 and not LOGGED_EVENTS[eventName] then
        return
    end

    -- Capture initial state for change detection
    local beforeStats = nil
    local beforeContributionValue = nil
    
    if eventName == "onCalculateStats" and eventArgs.stats then
        beforeStats = {
            productivity = eventArgs.stats.productivity,
            focus = eventArgs.stats.focus
        }
    elseif eventName == "onBeforeContribution" then
        beforeContributionValue = eventArgs.contributionMultiplier or 1.0
    elseif eventName == "onAfterContribution" then
        beforeContributionValue = eventArgs.contribution or 0
    end

    -- Handle positional effects for onCalculateStats
    if eventName == "onCalculateStats" then
        handleAllPositionalEffects(gameState, eventArgs)
    end

    -- Early exit if no listeners
    if #allListeners == 0 then
        -- Still need to check for changes in onCalculateStats even with no listeners
        if eventName == "onCalculateStats" and eventArgs.stats and beforeStats then
            local employeeId = eventArgs.employee and eventArgs.employee.instanceId
            local changesDetected = detectStatsChanges(beforeStats, eventArgs.stats, employeeId)
            if changesDetected and shouldLogEvent(eventName, gameState, eventArgs, true) then
                logEventStart(eventName, gameState, eventArgs, 0)
                logStatCalculation(eventName, gameState, eventArgs, beforeStats, eventArgs.stats, true)
                print(LOG_PREFIX .. "=== EVENT END: " .. eventName .. " (no listeners, but changes detected) ===")
            end
        end
        return 
    end

    -- Iterate through each phase in the defined order
    local anyListenerExecuted = false
    
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
                
                -- Execute callback with error handling
                local success, errorMsg = pcall(function()
                    -- Special handling for desk decorations to pass the deskId
                    if source.data and source.deskId then
                         callback(source.data, gameState, services, eventArgs, source.deskId)
                    else
                         callback(source, gameState, services, eventArgs)
                    end
                end)
                
                if success then
                    anyListenerExecuted = true
                else
                    -- Handle errors with modal (unchanged from original)
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
                        -- Pause battle before showing modal
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
                end
                
                ::continue::
            end
        end
    end
    
    -- NOW detect if changes actually occurred and log accordingly
    local changesDetected = false
    local employeeId = nil
    
    if eventName == "onCalculateStats" and eventArgs.stats and beforeStats then
        employeeId = eventArgs.employee and eventArgs.employee.instanceId
        changesDetected = detectStatsChanges(beforeStats, eventArgs.stats, employeeId)
    elseif eventName == "onBeforeContribution" or eventName == "onAfterContribution" then
        changesDetected = detectContributionChanges(eventName, eventArgs, beforeContributionValue)
    else
        -- For "always" logged events, we always consider them as having changes
        changesDetected = LOGGED_EVENTS[eventName] == "always"
    end
    
    -- Only log if we should log this event AND changes were detected (or it's an "always" event)
    if shouldLogEvent(eventName, gameState, eventArgs, changesDetected) then
        logEventStart(eventName, gameState, eventArgs, #allListeners)
        
        -- Log execution details for non-stats events
        if changesDetected and eventName ~= "onCalculateStats" then
            print(LOG_PREFIX .. string.format("Processed %d listeners across %d phases", #allListeners, #PHASES))
            
            -- Log specific changes for contribution events
            if eventName == "onBeforeContribution" and eventArgs.contributionMultiplier then
                print(LOG_PREFIX .. string.format("Final Contribution Multiplier: %.3fx (was %.3fx)", 
                    eventArgs.contributionMultiplier, beforeContributionValue or 1.0))
            elseif eventName == "onAfterContribution" and eventArgs.contribution then
                print(LOG_PREFIX .. string.format("Final Contribution: %d (was %d)", 
                    eventArgs.contribution, beforeContributionValue or 0))
            end
        end
        
        -- Log the stat calculation details
        if eventName == "onCalculateStats" then
            logStatCalculation(eventName, gameState, eventArgs, beforeStats, eventArgs.stats, changesDetected)
        end
        
        print(LOG_PREFIX .. "=== EVENT END: " .. eventName .. " ===")
    end
end

-- Control functions (unchanged)
function EffectsDispatcher.setLogging(enabled)
    LOGGING_ENABLED = enabled
    print(LOG_PREFIX .. "Logging " .. (enabled and "ENABLED" or "DISABLED"))
end

function EffectsDispatcher.setEventLogging(eventName, enabled)
    if enabled == true then
        LOGGED_EVENTS[eventName] = "always"
    elseif enabled == false then
        LOGGED_EVENTS[eventName] = nil
    else
        LOGGED_EVENTS[eventName] = enabled -- Allows setting to "on_change"
    end
    print(LOG_PREFIX .. "Event " .. eventName .. " logging set to " .. tostring(LOGGED_EVENTS[eventName]))
end

function EffectsDispatcher.isLoggingEnabled()
    return LOGGING_ENABLED
end

-- NEW: Function to clear stat cache (call when employees change, levels up, etc.)
function EffectsDispatcher.clearStatCache(employeeId)
    if employeeId then
        lastCalculatedStats[employeeId] = nil
        print(LOG_PREFIX .. "Cleared stat cache for " .. tostring(employeeId))
    else
        lastCalculatedStats = {}
        print(LOG_PREFIX .. "Cleared all stat cache")
    end
end

-- NEW: Function to get current cache state for debugging
function EffectsDispatcher.getStatCacheInfo()
    local count = 0
    for _ in pairs(lastCalculatedStats) do count = count + 1 end
    return count, lastCalculatedStats
end

-- NEW: Function to get current logging configuration
function EffectsDispatcher.getLoggingConfig()
    return LOGGED_EVENTS
end

-- NEW: Function to enable change-only logging for an event
function EffectsDispatcher.setChangeOnlyLogging(eventName)
    LOGGED_EVENTS[eventName] = "on_change"
    print(LOG_PREFIX .. "Event " .. eventName .. " set to change-only logging")
end

return EffectsDispatcher