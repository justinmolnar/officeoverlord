-- phases/turn_speed_check_phase.lua
-- Checks if battle should speed up based on turn count

local TurnSpeedCheckPhase = {}
TurnSpeedCheckPhase.__index = TurnSpeedCheckPhase

function TurnSpeedCheckPhase:new(manager)
    local instance = setmetatable({}, self)
    instance.manager = manager
    return instance
end

function TurnSpeedCheckPhase:enter(gameState, battleState)
    -- Increment turn counter
    battleState.totalTurnsThisItem = (battleState.totalTurnsThisItem or 0) + 1
    
    -- Check if we should speed up (every 3 turns)
    if battleState.totalTurnsThisItem > 0 and battleState.totalTurnsThisItem % 3 == 0 then
        battleState.speedMultiplier = (battleState.speedMultiplier or 1.0) * 1.5
        print("Battle speed increased! Turn " .. battleState.totalTurnsThisItem .. ", Speed: " .. string.format("%.1fx", battleState.speedMultiplier))
    end
    
    -- NEW: Move current contribution to fading if it exists
    if battleState.currentWorkerId and battleState.lastContribution then
        if not battleState.fadingContributions then
            battleState.fadingContributions = {}
        end
        
        -- Create the display text based on current phase
        local textToShow = "= " .. tostring(battleState.lastContribution.totalContribution)
        local multiplierText = battleState.lastContribution.multiplierText or ""
        if multiplierText ~= "" then
            textToShow = textToShow .. " " .. multiplierText
        end
        
        battleState.fadingContributions[battleState.currentWorkerId] = {
            text = textToShow,
            alpha = 1.0
        }
    end
    
    -- Immediately proceed to the actual turn start
    self.manager:changePhase("starting_turn", gameState, battleState)
end

function TurnSpeedCheckPhase:update(dt, gameState, battleState)
    -- This phase should immediately transition, so no update needed
end

function TurnSpeedCheckPhase:exit(gameState, battleState)
    -- Nothing to clean up
end

return TurnSpeedCheckPhase