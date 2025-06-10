-- game_state.lua
-- Manages the dynamic state of the game.

local GameData = require("data") -- Load static data

local GameState = {}

-- Creates and returns a new, initialized game state table.
function GameState:new()
    local state = {
        -- Core Player Resources
        budget = GameData.STARTING_BUDGET,
        bailOutsRemaining = GameData.STARTING_BAILOUTS,

        -- Office Layout & Employees
        desks = self:initializeDeskData(), -- Array of desk objects {id, status, cost, uiRect}
        hiredEmployees = {}, -- Table of employee instances {baseId, instanceId, level, isRemote, edition, baseProductivity, baseFocus, weeklySalary, deskId, uiRect}
        deskAssignments = {}, -- { deskId = employeeInstanceId }

        -- Game Progression
        currentSprintIndex = 1,     -- 1-based index for the current sprint (1-8)
        currentWorkItemIndex = 1,   -- 1-based index for the work item within a sprint (1-3)
        gamePhase = "loading",      -- "loading", "hiring_and_upgrades", "battle_active", "battle_over", "game_over", "game_won"
        
        -- Shop State
        currentShopOffers = {
            employees = {}, -- Table of employee data for current shop offers (copies with instanceId)
            upgrade = nil,  -- Current single upgrade offer data (a copy with instanceId if needed)
            restockCountThisWeek = 0
        },
        purchasedPermanentUpgrades = {}, -- Table to store IDs of purchased permanent upgrades

        -- Transient State for Current Operations
        currentWeekWorkload = 0, -- Stores the workload for the active challenge
        initialWorkloadForBar = 0, -- NEW: Stores the workload at the start of battle for the UI bar calculation.
        totalSalariesPaidThisWeek = 0,
        currentWeekCycles = 0, 
        selectedEmployeeForPlacementInstanceId = nil,
        temporaryEffectFlags = { -- For one-time effects like Office Dog, one-week boosts, and work item modifiers
            disabledUpgrades = {}
        }, 

        -- Miscellaneous
        runId = "run-" .. os.time() .. "-" .. love.math.random(1000,9999) -- A unique ID for this game run
    }
    return state
end

-- Initializes the 3x3 desk grid with their default states and costs.
function GameState:initializeDeskData()
    local desks = {}
    for i = 0, GameData.TOTAL_DESK_SLOTS - 1 do
        local deskEntry = {
            id = "desk-" .. i,
            status = "locked", -- "locked", "purchasable", "owned"
            cost = GameData.DESK_PURCHASE_COST,
            uiRect = { x = 0, y = 0, width = 0, height = 0 } 
        }

        if i == 0 or i == 1 or i == 3 or i == 4 then
            deskEntry.status = "owned"
            deskEntry.cost = 0
        elseif i == 2 or i == 5 or i == 6 or i == 7 then
            deskEntry.status = "purchasable"
        end
        
        table.insert(desks, deskEntry)
    end
    return desks
end

-- Helper function to set the game phase and perform any related setup.
function GameState:setGamePhase(gs, newPhase)
    print("Transitioning to phase: " .. newPhase)
    gs.gamePhase = newPhase

    gs.temporaryEffectFlags.reOrgSwapModeActive = nil
    gs.temporaryEffectFlags.reOrgFirstSelectionInstanceId = nil
    gs.temporaryEffectFlags.photocopierCopyModeActive = nil

    if newPhase ~= "shop_placement" then
        gs.selectedEmployeeForPlacementInstanceId = nil
    end

    if newPhase == "battle_active" then
        local sprintDurationFlags = {
            teamBuildingActiveThisWeek = gs.temporaryEffectFlags.teamBuildingActiveThisWeek,
            penTesterUsedInSprint = gs.temporaryEffectFlags.penTesterUsedInSprint,
            reOrgUsedThisSprint = gs.temporaryEffectFlags.reOrgUsedThisSprint,
            photocopierUsedThisSprint = gs.temporaryEffectFlags.photocopierUsedThisSprint,
            fourthWallUsedThisSprint = gs.temporaryEffectFlags.fourthWallUsedThisSprint,
            motivationalSpeakerUsedThisSprint = gs.temporaryEffectFlags.motivationalSpeakerUsedThisSprint,
            -- New flags for this step
            specialistId = nil,
            focusFunnelTotalBonus = nil,
            focusFunnelTargetId = nil,
            hiveMindStats = nil
        }
        
        if gs.currentWorkItemIndex == 1 then
            sprintDurationFlags.disabledUpgrades = {}
        else
            sprintDurationFlags.disabledUpgrades = gs.temporaryEffectFlags.disabledUpgrades or {}
        end

        gs.temporaryEffectFlags = sprintDurationFlags
    end
end

return GameState