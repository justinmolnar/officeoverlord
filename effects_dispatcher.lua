-- effects_dispatcher.lua
-- Dispatches game events to any entity (employee, upgrade, etc.) that is listening for them.

local EffectsDispatcher = {}

---Dispatches a named event to all listening entities.
---@param eventName string The name of the event to fire (e.g., "onWorkItemComplete").
---@param gameState table The entire current game state.
---@param eventArgs table|nil An optional table of arguments specific to this event.
function EffectsDispatcher.dispatchEvent(eventName, gameState, eventArgs)
    -- Ensure eventArgs is a table to avoid errors.
    eventArgs = eventArgs or {}

    -- Dispatch to all hired employees
    if gameState.hiredEmployees then
        for _, emp in ipairs(gameState.hiredEmployees) do
            -- Check if the employee has a 'listeners' table and a function for the specific event
            if emp.listeners and emp.listeners[eventName] then
                -- Call the listener function
                emp.listeners[eventName](emp, gameState, eventArgs)
            end
        end
    end

    -- Dispatch to all purchased upgrades
    if gameState.purchasedPermanentUpgrades then
        for _, upgradeId in ipairs(gameState.purchasedPermanentUpgrades) do
            -- Find the full upgrade data object
            local upgradeData
            for _, upg in ipairs(require("data").ALL_UPGRADES) do
                if upg.id == upgradeId then
                    upgradeData = upg
                    break
                end
            end

            -- Check if the upgrade has a listener for the event
            if upgradeData and upgradeData.listeners and upgradeData.listeners[eventName] then
                -- Call the listener function
                upgradeData.listeners[eventName](upgradeData, gameState, eventArgs)
            end
        end
    end
end

return EffectsDispatcher