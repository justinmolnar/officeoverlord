-- effects_dispatcher.lua
-- Dispatches game events to any entity (employee, upgrade, etc.) that is listening for them.

local GameData = require("data") -- Moved require to the top of the file

local EffectsDispatcher = {}

---Dispatches a named event to all listening entities.
---@param eventName string The name of the event to fire (e.g., "onWorkItemComplete").
---@param gameState table The entire current game state.
---@param eventArgs table|nil An optional table of arguments specific to this event.
function EffectsDispatcher.dispatchEvent(eventName, gameState, services, eventArgs)
    eventArgs = eventArgs or {}
    services = services or {} -- Safety check for the new services table

    if gameState.hiredEmployees then
        for _, emp in ipairs(gameState.hiredEmployees) do
            if emp.listeners and emp.listeners[eventName] then
                emp.listeners[eventName](emp, gameState, services, eventArgs)
            end
        end
    end

    if gameState.purchasedPermanentUpgrades then
        for _, upgradeId in ipairs(gameState.purchasedPermanentUpgrades) do
            local upgradeData
            for _, upg in ipairs(GameData.ALL_UPGRADES) do
                if upg.id == upgradeId then
                    upgradeData = upg
                    break
                end
            end

            if upgradeData and upgradeData.listeners and upgradeData.listeners[eventName] then
                upgradeData.listeners[eventName](upgradeData, gameState, services, eventArgs)
            end
        end
    end

    if gameState.deskDecorations then
        for deskId, decorationId in pairs(gameState.deskDecorations) do
            if decorationId then
                local decorationData
                for _, deco in ipairs(GameData.ALL_DESK_DECORATIONS) do
                    if deco.id == decorationId then
                        decorationData = deco
                        break
                    end
                end

                if decorationData and decorationData.listeners and decorationData.listeners[eventName] then
                    decorationData.listeners[eventName](decorationData, gameState, services, eventArgs, deskId)
                end
            end
        end
    end

    -- The dispatcher is no longer responsible for showing the modal. This has been deleted.
end

return EffectsDispatcher