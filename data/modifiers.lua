-- data/modifiers.lua
-- Contains all work item modifiers organized by rarity

-- COMMON MODIFIERS (Low Impact)
return {

    {
        id = "casual_friday_extended",
        name = "Casual Friday Extended",
        rarity = "Common",
        description = "All employees get +0.2x Focus but salaries for this work item increase by 10%",
        listeners = {
            onApply = {
                {
                    phase = 'BaseApplication',
                    priority = 50,
                    callback = function(self, gameState)
                        gameState.temporaryEffectFlags.globalFocusMultiplier = 1.2
                        gameState.temporaryEffectFlags.globalSalaryMultiplier = 1.1
                    end
                }
            },
            onCalculateStats = {
                {
                    phase = 'BaseApplication',
                    priority = 60,
                    callback = function(self, gameState, services, eventArgs)
                        if gameState.temporaryEffectFlags.globalFocusMultiplier then
                            eventArgs.stats.focus = eventArgs.stats.focus * gameState.temporaryEffectFlags.globalFocusMultiplier
                            table.insert(eventArgs.stats.log.focus, string.format("*%.1fx from Casual Friday", gameState.temporaryEffectFlags.globalFocusMultiplier))
                        end
                    end
                }
            }
        }
    },
    {
        id = "coffee_machine_broken",
        name = "Coffee Machine Broken",
        rarity = "Common",
        description = "All employees lose 0.1x Focus but gain +3 Productivity for this work item",
        listeners = {
            onCalculateStats = {
                {
                    phase = 'BaseApplication',
                    priority = 60,
                    callback = function(self, gameState, services, eventArgs)
                        eventArgs.stats.focus = eventArgs.stats.focus - 0.1
                        eventArgs.stats.productivity = eventArgs.stats.productivity + 3
                        table.insert(eventArgs.stats.log.focus, "-0.1x from broken coffee machine")
                        table.insert(eventArgs.stats.log.productivity, "+3 from caffeine withdrawal motivation")
                    end
                }
            }
        }
    },
    {
        id = "open_door_policy",
        name = "Open Door Policy",
        rarity = "Common", 
        description = "Adjacent employees share 25% of their Productivity bonuses for this work item",
        listeners = {
            onCalculateStats = {
                {
                    phase = 'Amplification',
                    priority = 60,
                    callback = function(self, gameState, services, eventArgs)
                        if not eventArgs.employee.deskId then return end
                        
                        local GameData = require("data")
                        local Placement = require("placement")
                        local Employee = require("employee")
                        
                        local directions = {"up", "down", "left", "right"}
                        local sharedBonus = 0
                        
                        for _, dir in ipairs(directions) do
                            local neighborDeskId = Placement:getNeighboringDeskId(eventArgs.employee.deskId, dir, GameData.GRID_WIDTH, GameData.TOTAL_DESK_SLOTS, gameState.desks)
                            if neighborDeskId and gameState.deskAssignments[neighborDeskId] then
                                local neighbor = Employee:getFromState(gameState, gameState.deskAssignments[neighborDeskId])
                                if neighbor then
                                    local neighborStats = Employee:calculateStatsWithPosition(neighbor, gameState.hiredEmployees, gameState.deskAssignments, gameState.purchasedPermanentUpgrades, gameState.desks, gameState)
                                    local neighborBonus = neighborStats.currentProductivity - neighbor.baseProductivity
                                    sharedBonus = sharedBonus + math.floor(neighborBonus * 0.25)
                                end
                            end
                        end
                        
                        if sharedBonus > 0 then
                            eventArgs.stats.productivity = eventArgs.stats.productivity + sharedBonus
                            table.insert(eventArgs.stats.log.productivity, string.format("+%d from shared productivity", sharedBonus))
                        end
                    end
                }
            }
        }
    },
    {
        id = "mandatory_fun_day",
        name = "Mandatory Fun Day",
        rarity = "Common",
        description = "First employee each round gets +50% stats, others get -10% Focus",
        listeners = {
            onBeforeContribution = {
                {
                    phase = 'PreCalculation',
                    priority = 50,
                    callback = function(self, gameState, eventArgs)
                        if eventArgs.employee.isFirstMover then
                            eventArgs.productivityMultiplier = eventArgs.productivityMultiplier * 1.5
                            eventArgs.focusMultiplier = eventArgs.focusMultiplier * 1.5
                        else
                            eventArgs.focusMultiplier = eventArgs.focusMultiplier * 0.9
                        end
                    end
                }
            }
        }
    },
    {
        id = "supply_shortage",
        name = "Supply Shortage", 
        rarity = "Common",
        description = "All Productivity bonuses are halved, but Focus bonuses are doubled",
        listeners = {
            onCalculateStats = {
                {
                    phase = 'PostCalculation',
                    priority = 90,
                    callback = function(self, gameState, services, eventArgs)
                        local baseProd = eventArgs.employee.baseProductivity
                        local baseFocus = eventArgs.employee.baseFocus
                        
                        local prodBonus = eventArgs.stats.productivity - baseProd
                        local focusBonus = eventArgs.stats.focus - baseFocus
                        
                        eventArgs.stats.productivity = baseProd + math.floor(prodBonus * 0.5)
                        eventArgs.stats.focus = baseFocus + (focusBonus * 2)
                        
                        table.insert(eventArgs.stats.log.productivity, "Productivity bonuses halved (supply shortage)")
                        table.insert(eventArgs.stats.log.focus, "Focus bonuses doubled (supply shortage)")
                    end
                }
            }
        }
    },
    {
        id = "new_intern_wave",
        name = "New Intern Wave",
        rarity = "Common",
        description = "All Common employees get +5 Productivity for this work item",
        listeners = {
            onCalculateStats = {
                {
                    phase = 'BaseApplication',
                    priority = 60,
                    callback = function(self, gameState, services, eventArgs)
                        if eventArgs.employee.rarity == 'Common' then
                            eventArgs.stats.productivity = eventArgs.stats.productivity + 5
                            table.insert(eventArgs.stats.log.productivity, "+5 from intern enthusiasm")
                        end
                    end
                }
            }
        }
    },
    {
        id = "bring_pet_to_work",
        name = "Bring Your Pet to Work",
        rarity = "Common",
        description = "Random employee each round gets +100% Focus for one turn",
        listeners = {
            onWorkOrderDetermined = {
                {
                    phase = 'PreCalculation',
                    priority = 50,
                    callback = function(self, gameState, eventArgs)
                        if #eventArgs.activeEmployees > 0 then
                            local luckyEmployee = eventArgs.activeEmployees[love.math.random(#eventArgs.activeEmployees)]
                            luckyEmployee.petBoostActive = true
                        end
                    end
                }
            },
            onBeforeContribution = {
                {
                    phase = 'PreCalculation',
                    priority = 50,
                    callback = function(self, gameState, eventArgs)
                        if eventArgs.employee.petBoostActive then
                            eventArgs.focusMultiplier = eventArgs.focusMultiplier * 2
                            eventArgs.employee.petBoostActive = nil
                        end
                    end
                }
            }
        }
    },
    {
        id = "wifi_issues",
        name = "Wi-Fi Issues",
        rarity = "Common",
        description = "Remote workers have 50% chance to contribute 0, office workers get +0.3x Focus",
        listeners = {
            onBeforeContribution = {
                {
                    phase = 'PreCalculation',
                    priority = 50,
                    callback = function(self, gameState, eventArgs)
                        if eventArgs.employee.variant == 'remote' then
                            if love.math.random() < 0.5 then
                                eventArgs.overrideContribution = { productivity = 0, focus = 0, totalContribution = 0 }
                            end
                        else
                            eventArgs.focusMultiplier = eventArgs.focusMultiplier * 1.3
                        end
                    end
                }
            }
        }
    },
    {
        id = "lunch_truck_festival",
        name = "Lunch Truck Festival",
        rarity = "Common",
        description = "Each employee gets a random +/- 0.2x Focus modifier for this work item",
        listeners = {
            onWorkItemStart = {
                {
                    phase = 'BaseApplication',
                    priority = 50,
                    callback = function(self, gameState)
                        for _, emp in ipairs(gameState.hiredEmployees) do
                            emp.lunchTruckModifier = (love.math.random() < 0.5) and 0.2 or -0.2
                        end
                    end
                }
            },
            onCalculateStats = {
                {
                    phase = 'BaseApplication',
                    priority = 60,
                    callback = function(self, gameState, services, eventArgs)
                        if eventArgs.employee.lunchTruckModifier then
                            eventArgs.stats.focus = eventArgs.stats.focus + eventArgs.employee.lunchTruckModifier
                            local sign = eventArgs.employee.lunchTruckModifier > 0 and "+" or ""
                            table.insert(eventArgs.stats.log.focus, string.format("%s%.1fx from lunch truck", sign, eventArgs.employee.lunchTruckModifier))
                        end
                    end
                }
            }
        }
    },
    {
        id = "desk_reorganization",
        name = "Desk Reorganization",
        rarity = "Common", 
        description = "All positional effects are rotated 90 degrees clockwise for this work item",
        listeners = {
            onApply = {
                {
                    phase = 'BaseApplication',
                    priority = 50,
                    callback = function(self, gameState)
                        gameState.temporaryEffectFlags.rotatePositionalEffects = true
                    end
                }
            }
        }
        -- Note: The actual rotation logic would need to be implemented in the positional effects calculation
    },
    {
        id = "air_conditioning_broken",
        name = "Air Conditioning Broken",
        rarity = "Common",
        description = "Bottom row employees get -25% stats, top row gets +25% stats",
        listeners = {
            onCalculateStats = {
                {
                    phase = 'BaseApplication',
                    priority = 60,
                    callback = function(self, gameState, services, eventArgs)
                        if eventArgs.employee.deskId then
                            local deskIndex = tonumber(string.match(eventArgs.employee.deskId, "desk%-(%d+)"))
                            if deskIndex then
                                local GameData = require("data")
                                local row = math.floor(deskIndex / GameData.GRID_WIDTH)
                                
                                if row == 0 then -- Top row
                                    eventArgs.stats.productivity = math.floor(eventArgs.stats.productivity * 1.25)
                                    eventArgs.stats.focus = eventArgs.stats.focus * 1.25
                                    table.insert(eventArgs.stats.log.productivity, "*1.25x from cool air")
                                    table.insert(eventArgs.stats.log.focus, "*1.25x from cool air")
                                elseif row == 2 then -- Bottom row
                                    eventArgs.stats.productivity = math.floor(eventArgs.stats.productivity * 0.75)
                                    eventArgs.stats.focus = eventArgs.stats.focus * 0.75
                                    table.insert(eventArgs.stats.log.productivity, "*0.75x from heat")
                                    table.insert(eventArgs.stats.log.focus, "*0.75x from heat")
                                end
                            end
                        end
                    end
                }
            }
        }
    },
    {
        id = "fire_drill_day",
        name = "Fire Drill Day",
        rarity = "Common",
        description = "Every 3 rounds, all employees must skip one round",
        listeners = {
            onWorkOrderDetermined = {
                {
                    phase = 'PreCalculation',
                    priority = 50,
                    callback = function(self, gameState, eventArgs)
                        if (gameState.currentWeekCycles + 1) % 3 == 0 then
                            eventArgs.activeEmployees = {} -- Everyone evacuates!
                        end
                    end
                }
            }
        }
    },
    {
        id = "parking_shortage",
        name = "Parking Shortage", 
        rarity = "Common",
        description = "Each round, one random employee arrives late (contributes second)",
        listeners = {
            onWorkOrderDetermined = {
                {
                    phase = 'PreCalculation',
                    priority = 50,
                    callback = function(self, gameState, eventArgs)
                        if #eventArgs.activeEmployees > 0 then
                            local lateEmployee = table.remove(eventArgs.activeEmployees, love.math.random(#eventArgs.activeEmployees))
                            table.insert(eventArgs.activeEmployees, lateEmployee)
                        end
                    end
                }
            }
        }
    },
    {
        id = "surprise_inspection",
        name = "Surprise Inspection",
        rarity = "Common",
        description = "All employees must work in alphabetical order by name",
        listeners = {
            onWorkOrderDetermined = {
                {
                    phase = 'PreCalculation', 
                    priority = 50,
                    callback = function(self, gameState, eventArgs)
                        table.sort(eventArgs.activeEmployees, function(a, b)
                            return (a.fullName or a.name) < (b.fullName or b.name)
                        end)
                    end
                }
            }
        }
    },
    {
        id = "donut_friday",
        name = "Donut Friday",
        rarity = "Common",
        description = "First round only, all employees get +50% contribution",
        listeners = {
            onBeforeContribution = {
                {
                    phase = 'PreCalculation',
                    priority = 50,
                    callback = function(self, gameState, eventArgs)
                        if gameState.currentWeekCycles == 0 then -- First round
                            eventArgs.contributionMultiplier = eventArgs.contributionMultiplier * 1.5
                        end
                    end
                }
            }
        }
    },
    {
        id = "motivational_posters",
        name = "Motivational Posters",
        rarity = "Common",
        description = "Employees with positive adjacent bonuses get an extra +2 Productivity",
        listeners = {
            onCalculateStats = {
                {
                    phase = 'Amplification',
                    priority = 60,
                    callback = function(self, gameState, services, eventArgs)
                        if eventArgs.bonusesApplied and eventArgs.bonusesApplied.positional then
                            if eventArgs.bonusesApplied.positional.prod > 0 or eventArgs.bonusesApplied.positional.focus > 0 then
                                eventArgs.stats.productivity = eventArgs.stats.productivity + 2
                                table.insert(eventArgs.stats.log.productivity, "+2 from motivational posters")
                            end
                        end
                    end
                }
            }
        }
    },
    {
        id = "casual_dress_code",
        name = "Casual Dress Code",
        rarity = "Common",
        description = "All employees lose 10% Productivity but gain 20% Focus",
        listeners = {
            onCalculateStats = {
                {
                    phase = 'BaseApplication',
                    priority = 60,
                    callback = function(self, gameState, services, eventArgs)
                        eventArgs.stats.productivity = math.floor(eventArgs.stats.productivity * 0.9)
                        eventArgs.stats.focus = eventArgs.stats.focus * 1.2
                        table.insert(eventArgs.stats.log.productivity, "*0.9x from casual dress")
                        table.insert(eventArgs.stats.log.focus, "*1.2x from casual dress")
                    end
                }
            }
        }
    },
    {
        id = "standing_desk_trial",
        name = "Standing Desk Trial",
        rarity = "Common",
        description = "Odd rounds: +25% Productivity, Even rounds: -10% Focus",
        listeners = {
            onBeforeContribution = {
                {
                    phase = 'PreCalculation',
                    priority = 50,
                    callback = function(self, gameState, eventArgs)
                        local roundNumber = gameState.currentWeekCycles + 1
                        if roundNumber % 2 == 1 then -- Odd rounds
                            eventArgs.productivityMultiplier = eventArgs.productivityMultiplier * 1.25
                        else -- Even rounds
                            eventArgs.focusMultiplier = eventArgs.focusMultiplier * 0.9
                        end
                    end
                }
            }
        }
    },
    {
        id = "background_music",
        name = "Background Music",
        rarity = "Common",
        description = "Same row employees get +0.1x Focus, different rows get -0.05x Focus",
        listeners = {
            onCalculateStats = {
                {
                    phase = 'BaseApplication',
                    priority = 60,
                    callback = function(self, gameState, services, eventArgs)
                        if not eventArgs.employee.deskId then return end
                        
                        local deskIndex = tonumber(string.match(eventArgs.employee.deskId, "desk%-(%d+)"))
                        if not deskIndex then return end
                        
                        local GameData = require("data")
                        local myRow = math.floor(deskIndex / GameData.GRID_WIDTH)
                        
                        -- Check if any other employees are in the same row
                        local hasSameRowNeighbor = false
                        for _, otherEmp in ipairs(gameState.hiredEmployees) do
                            if otherEmp.deskId and otherEmp.instanceId ~= eventArgs.employee.instanceId then
                                local otherIndex = tonumber(string.match(otherEmp.deskId, "desk%-(%d+)"))
                                if otherIndex then
                                    local otherRow = math.floor(otherIndex / GameData.GRID_WIDTH)
                                    if otherRow == myRow then
                                        hasSameRowNeighbor = true
                                        break
                                    end
                                end
                            end
                        end
                        
                        if hasSameRowNeighbor then
                            eventArgs.stats.focus = eventArgs.stats.focus + 0.1
                            table.insert(eventArgs.stats.log.focus, "+0.1x from synchronized music")
                        else
                            eventArgs.stats.focus = eventArgs.stats.focus - 0.05
                            table.insert(eventArgs.stats.log.focus, "-0.05x from lonely music")
                        end
                    end
                }
            }
        }
    },
    {
        id = "clean_desk_policy",
        name = "Clean Desk Policy",
        rarity = "Common",
        description = "Employees with no adjacent neighbors get +15% stats",
        listeners = {
            onCalculateStats = {
                {
                    phase = 'BaseApplication',
                    priority = 60,
                    callback = function(self, gameState, services, eventArgs)
                        if not eventArgs.employee.deskId then return end
                        
                        local GameData = require("data")
                        local Placement = require("placement")
                        local directions = {"up", "down", "left", "right"}
                        local hasNeighbors = false
                        
                        for _, dir in ipairs(directions) do
                            local neighborDeskId = Placement:getNeighboringDeskId(eventArgs.employee.deskId, dir, GameData.GRID_WIDTH, GameData.TOTAL_DESK_SLOTS, gameState.desks)
                            if neighborDeskId and gameState.deskAssignments[neighborDeskId] then
                                hasNeighbors = true
                                break
                            end
                        end
                        
                        if not hasNeighbors then
                            eventArgs.stats.productivity = math.floor(eventArgs.stats.productivity * 1.15)
                            eventArgs.stats.focus = eventArgs.stats.focus * 1.15
                            table.insert(eventArgs.stats.log.productivity, "*1.15x from clean desk")
                            table.insert(eventArgs.stats.log.focus, "*1.15x from clean desk")
                        end
                    end
                }
            }
        }
    },

    -- UNCOMMON MODIFIERS (Medium Impact)

    {
        id = "performance_review_day",
        name = "Performance Review Day",
        rarity = "Uncommon",
        description = "After work item completion, lowest contributor loses 1 level, highest gains 1 level",
        listeners = {
            onWorkItemComplete = {
                {
                    phase = 'PostCalculation',
                    priority = 50,
                    callback = function(self, gameState, services, eventArgs)
                        if #gameState.hiredEmployees < 2 then return end
                        
                        -- Find lowest and highest contributors
                        local lowest, highest = nil, nil
                        local lowestContrib, highestContrib = math.huge, 0
                        
                        for _, emp in ipairs(gameState.hiredEmployees) do
                            local contrib = emp.contributionThisItem or 0
                            if contrib < lowestContrib then
                                lowestContrib = contrib
                                lowest = emp
                            end
                            if contrib > highestContrib then
                                highestContrib = contrib
                                highest = emp
                            end
                        end
                        
                        if lowest and highest and lowest.instanceId ~= highest.instanceId then
                            -- Demote lowest (but not below level 1)
                            if (lowest.level or 1) > 1 then
                                lowest.level = (lowest.level or 1) - 1
                                lowest.baseProductivity = math.floor(lowest.baseProductivity * 0.8)
                                lowest.baseFocus = lowest.baseFocus * 0.9
                            end
                            
                            -- Promote highest
                            highest.level = (highest.level or 1) + 1
                            highest.baseProductivity = math.floor(highest.baseProductivity * 1.2)
                            highest.baseFocus = highest.baseFocus * 1.1
                            
                            services.modal:show("Performance Review Results", 
                                lowest.fullName .. " was demoted for poor performance.\n" ..
                                highest.fullName .. " was promoted for excellence!")
                        end
                    end
                }
            }
        }
    },
    {
        id = "budget_freeze",
        name = "Budget Freeze",
        rarity = "Uncommon",
        description = "Cannot spend money during this work item, but all stats +25%",
        listeners = {
            onApply = {
                {
                    phase = 'BaseApplication',
                    priority = 50,
                    callback = function(self, gameState)
                        gameState.temporaryEffectFlags.isShopDisabled = true
                    end
                }
            },
            onCalculateStats = {
                {
                    phase = 'BaseApplication',
                    priority = 60,
                    callback = function(self, gameState, services, eventArgs)
                        eventArgs.stats.productivity = math.floor(eventArgs.stats.productivity * 1.25)
                        eventArgs.stats.focus = eventArgs.stats.focus * 1.25
                        table.insert(eventArgs.stats.log.productivity, "*1.25x from budget focus")
                        table.insert(eventArgs.stats.log.focus, "*1.25x from budget focus")
                    end
                }
            }
        }
    },
    {
        id = "code_review_bottleneck",
        name = "Code Review Bottleneck",
        rarity = "Uncommon",
        description = "Each employee must work twice to contribute once, but contributions are doubled",
        listeners = {
            onWorkOrderDetermined = {
                {
                    phase = 'PreCalculation',
                    priority = 50,
                    callback = function(self, gameState, eventArgs)
                        -- Double the work order - each employee appears twice
                        local doubledEmployees = {}
                        for _, emp in ipairs(eventArgs.activeEmployees) do
                            table.insert(doubledEmployees, emp)
                            table.insert(doubledEmployees, emp)
                        end
                        eventArgs.activeEmployees = doubledEmployees
                    end
                }
            },
            onBeforeContribution = {
                {
                    phase = 'PreCalculation',
                    priority = 50,
                    callback = function(self, gameState, eventArgs)
                        -- First time working - no contribution
                        if not eventArgs.employee.hasWorkedOnce then
                            eventArgs.employee.hasWorkedOnce = true
                            eventArgs.overrideContribution = { productivity = 0, focus = 0, totalContribution = 0 }
                        else
                            -- Second time - double contribution
                            eventArgs.contributionMultiplier = eventArgs.contributionMultiplier * 2
                            eventArgs.employee.hasWorkedOnce = nil
                        end
                    end
                }
            }
        }
    },
    {
        id = "remote_work_day",
        name = "Remote Work Day",
        rarity = "Uncommon",
        description = "All office workers become remote for this work item only",
        listeners = {
            onApply = {
                {
                    phase = 'BaseApplication',
                    priority = 50,
                    callback = function(self, gameState)
                        for _, emp in ipairs(gameState.hiredEmployees) do
                            if emp.deskId then
                                emp.temporaryRemote = true
                                emp.originalDeskId = emp.deskId
                                emp.deskId = nil
                                gameState.deskAssignments[emp.originalDeskId] = nil
                            end
                        end
                    end
                }
            },
            onWorkItemComplete = {
                {
                    phase = 'PostCalculation',
                    priority = 50,
                    callback = function(self, gameState, services, eventArgs)
                        for _, emp in ipairs(gameState.hiredEmployees) do
                            if emp.temporaryRemote and emp.originalDeskId then
                                emp.deskId = emp.originalDeskId
                                gameState.deskAssignments[emp.originalDeskId] = emp.instanceId
                                emp.temporaryRemote = nil
                                emp.originalDeskId = nil
                            end
                        end
                    end
                }
            }
        }
    },
    {
        id = "pair_programming",
        name = "Pair Programming",
        rarity = "Uncommon",
        description = "Employees can only contribute if adjacent to another employee",
        listeners = {
            onEmployeeAvailabilityCheck = {
                {
                    phase = 'PreCalculation',
                    priority = 50,
                    callback = function(self, gameState, eventArgs)
                        if not eventArgs.employee.deskId then return end
                        
                        local GameData = require("data")
                        local Placement = require("placement")
                        local directions = {"up", "down", "left", "right"}
                        local hasPartner = false
                        
                        for _, dir in ipairs(directions) do
                            local neighborDeskId = Placement:getNeighboringDeskId(eventArgs.employee.deskId, dir, GameData.GRID_WIDTH, GameData.TOTAL_DESK_SLOTS, gameState.desks)
                            if neighborDeskId and gameState.deskAssignments[neighborDeskId] then
                                hasPartner = true
                                break
                            end
                        end
                        
                        if not hasPartner then
                            eventArgs.isDisabled = true
                            eventArgs.reason = eventArgs.employee.name .. " needs a pair programming partner"
                        end
                    end
                }
            }
        }
    },
    {
        id = "overtime_authorized",
        name = "Overtime Authorized",
        rarity = "Uncommon",
        description = "After completing work item, team works one additional free round",
        listeners = {
            onWorkItemComplete = {
                {
                    phase = 'PostCalculation',
                    priority = 50,
                    callback = function(self, gameState, services, eventArgs)
                        -- This would need special handling in the main game loop
                        -- to add one more round after victory conditions are met
                        gameState.temporaryEffectFlags.overtimeRoundPending = true
                    end
                }
            }
        }
    },
    {
        id = "consultant_day",
        name = "Consultant Day",
        rarity = "Uncommon",
        description = "Pay $500 per round, workload decreases by 25 automatically each round",
        listeners = {
            onEndOfRound = {
                {
                    phase = 'PostCalculation',
                    priority = 50,
                    callback = function(self, gameState, eventArgs)
                        -- Pay consultant fee
                        gameState.budget = gameState.budget - 500
                        
                        -- Reduce workload automatically
                        local reduction = math.min(25, gameState.currentWeekWorkload)
                        gameState.currentWeekWorkload = gameState.currentWeekWorkload - reduction
                    end
                }
            }
        }
    },
    --[[
    {
        id = "hot_desk_rotation",
        name = "Hot Desk Rotation",
        rarity = "Uncommon",
        description = "Every 2 rounds, all office employees swap positions randomly",
        -- COMMENTED OUT: Would need complex desk swapping logic that might interfere with UI
        listeners = {
            onEndOfRound = {
                {
                    phase = 'PostCalculation',
                    priority = 50,
                    callback = function(self, gameState, eventArgs)
                        if (gameState.currentWeekCycles + 1) % 2 == 0 then
                            -- Complex desk shuffling logic needed here
                        end
                    end
                }
            }
        }
    },
    --]]
    {
        id = "innovation_time",
        name = "Innovation Time",
        rarity = "Uncommon",
        description = "Last employee to contribute each round gets their contribution applied twice",
        listeners = {
            onAfterContribution = {
                {
                    phase = 'PostCalculation',
                    priority = 50,
                    callback = function(self, gameState, eventArgs)
                        -- Mark this as the last contributor if it's the end of the round
                        gameState.temporaryEffectFlags.lastContributorThisRound = eventArgs.employee.instanceId
                    end
                }
            },
            onEndOfRound = {
                {
                    phase = 'PostCalculation',
                    priority = 50,
                    callback = function(self, gameState, eventArgs)
                        if gameState.temporaryEffectFlags.lastContributorThisRound then
                            -- Apply their contribution again
                            local lastContrib = eventArgs.lastRoundContributions[gameState.temporaryEffectFlags.lastContributorThisRound]
                            if lastContrib then
                                eventArgs.totalSalaries = (eventArgs.totalSalaries or 0) + lastContrib.totalContribution
                            end
                            gameState.temporaryEffectFlags.lastContributorThisRound = nil
                        end
                    end
                }
            }
        }
    },
    {
        id = "all_hands_meeting",
        name = "All Hands Meeting",
        rarity = "Uncommon",
        description = "First round, no one contributes; subsequent rounds everyone gets +50% stats",
        listeners = {
            onBeforeContribution = {
                {
                    phase = 'PreCalculation',
                    priority = 50,
                    callback = function(self, gameState, eventArgs)
                        if gameState.currentWeekCycles == 0 then
                            -- First round - meeting time
                            eventArgs.overrideContribution = { productivity = 0, focus = 0, totalContribution = 0 }
                        else
                            -- Subsequent rounds - motivated by meeting
                            eventArgs.productivityMultiplier = eventArgs.productivityMultiplier * 1.5
                            eventArgs.focusMultiplier = eventArgs.focusMultiplier * 1.5
                        end
                    end
                }
            }
        }
    },
    {
        id = "server_maintenance",
        name = "Server Maintenance",
        rarity = "Uncommon",
        description = "First half of work item, contributions are halved; second half, doubled",
        listeners = {
            onBeforeContribution = {
                {
                    phase = 'PreCalculation',
                    priority = 50,
                    callback = function(self, gameState, eventArgs)
                        local workloadRemaining = gameState.currentWeekWorkload
                        local totalWorkload = gameState.initialWorkloadForBar
                        local progress = 1 - (workloadRemaining / totalWorkload)
                        
                        if progress < 0.5 then
                            -- First half - maintenance issues
                            eventArgs.contributionMultiplier = eventArgs.contributionMultiplier * 0.5
                        else
                            -- Second half - systems optimized
                            eventArgs.contributionMultiplier = eventArgs.contributionMultiplier * 2
                        end
                    end
                }
            }
        }
    },
    {
        id = "team_building_exercise",
        name = "Team Building Exercise",
        rarity = "Uncommon",
        description = "Employees only get bonuses if they're adjacent to teammates",
        listeners = {
            onCalculateStats = {
                {
                    phase = 'PostCalculation',
                    priority = 90,
                    callback = function(self, gameState, services, eventArgs)
                        if not eventArgs.employee.deskId then return end
                        
                        local GameData = require("data")
                        local Placement = require("placement")
                        local Employee = require("employee")
                        local directions = {"up", "down", "left", "right"}
                        local hasTeammate = false
                        
                        for _, dir in ipairs(directions) do
                            local neighborDeskId = Placement:getNeighboringDeskId(eventArgs.employee.deskId, dir, GameData.GRID_WIDTH, GameData.TOTAL_DESK_SLOTS, gameState.desks)
                            if neighborDeskId and gameState.deskAssignments[neighborDeskId] then
                                hasTeammate = true
                                break
                            end
                        end
                        
                        if not hasTeammate then
                            -- Remove all bonuses, keep only base stats
                            eventArgs.stats.productivity = eventArgs.employee.baseProductivity
                            eventArgs.stats.focus = eventArgs.employee.baseFocus
                            eventArgs.stats.log.productivity = {"Base: " .. eventArgs.employee.baseProductivity, "Bonuses removed (no teamwork)"}
                            eventArgs.stats.log.focus = {"Base: " .. eventArgs.employee.baseFocus, "Bonuses removed (no teamwork)"}
                        end
                    end
                }
            }
        }
    },
    {
        id = "caffeine_rush",
        name = "Caffeine Rush",
        rarity = "Uncommon",
        description = "Each employee's first contribution is tripled, subsequent ones are halved",
        listeners = {
            onBeforeContribution = {
                {
                    phase = 'PreCalculation',
                    priority = 50,
                    callback = function(self, gameState, eventArgs)
                        if not eventArgs.employee.hasCaffeineBoost then
                            eventArgs.employee.hasCaffeineBoost = true
                            eventArgs.contributionMultiplier = eventArgs.contributionMultiplier * 3
                        else
                            eventArgs.contributionMultiplier = eventArgs.contributionMultiplier * 0.5
                        end
                    end
                }
            }
        }
    },
    --[[
    {
        id = "documentation_sprint",
        name = "Documentation Sprint",
        rarity = "Uncommon",
        description = "Must 'spend' 25% of total contribution on documentation (reduces workload progress)",
        -- COMMENTED OUT: Would need special workload calculation handling
        listeners = {
            onEndOfRound = {
                {
                    phase = 'PostCalculation',
                    priority = 50,
                    callback = function(self, gameState, eventArgs)
                        -- Reduce workload progress by 25% due to documentation overhead
                        -- This would need integration with the workload chipping system
                    end
                }
            }
        }
    },
    --]]
    {
        id = "user_testing_day",
        name = "User Testing Day",
        rarity = "Uncommon",
        description = "Every round, workload randomly increases or decreases by 10%",
        listeners = {
            onEndOfRound = {
                {
                    phase = 'PostCalculation',
                    priority = 50,
                    callback = function(self, gameState, eventArgs)
                        local change = math.floor(gameState.initialWorkloadForBar * 0.1)
                        if love.math.random() < 0.5 then
                            gameState.currentWeekWorkload = gameState.currentWeekWorkload + change
                        else
                            gameState.currentWeekWorkload = math.max(0, gameState.currentWeekWorkload - change)
                        end
                    end
                }
            }
        }
    },
    {
        id = "hackathon_mode",
        name = "Hackathon Mode",
        rarity = "Uncommon",
        description = "Work order is completely random each round, but all contributions +75%",
        listeners = {
            onWorkOrderDetermined = {
                {
                    phase = 'PreCalculation',
                    priority = 50,
                    callback = function(self, gameState, eventArgs)
                        -- Shuffle the work order completely
                        for i = #eventArgs.activeEmployees, 2, -1 do
                            local j = love.math.random(i)
                            eventArgs.activeEmployees[i], eventArgs.activeEmployees[j] = eventArgs.activeEmployees[j], eventArgs.activeEmployees[i]
                        end
                    end
                }
            },
            onBeforeContribution = {
                {
                    phase = 'PreCalculation',
                    priority = 50,
                    callback = function(self, gameState, eventArgs)
                        eventArgs.contributionMultiplier = eventArgs.contributionMultiplier * 1.75
                    end
                }
            }
        }
    },
    {
        id = "deadline_pressure",
        name = "Deadline Pressure",
        rarity = "Uncommon",
        description = "Each round, all future contributions get +10% bonus (stacking)",
        listeners = {
            onEndOfRound = {
                {
                    phase = 'PostCalculation',
                    priority = 50,
                    callback = function(self, gameState, eventArgs)
                        gameState.temporaryEffectFlags.deadlinePressureStacks = (gameState.temporaryEffectFlags.deadlinePressureStacks or 0) + 1
                    end
                }
            },
            onBeforeContribution = {
                {
                    phase = 'PreCalculation',
                    priority = 50,
                    callback = function(self, gameState, eventArgs)
                        local stacks = gameState.temporaryEffectFlags.deadlinePressureStacks or 0
                        if stacks > 0 then
                            local bonus = 1 + (stacks * 0.1)
                            eventArgs.contributionMultiplier = eventArgs.contributionMultiplier * bonus
                        end
                    end
                }
            }
        }
    },
    {
        id = "cross_training",
        name = "Cross-Training",
        rarity = "Uncommon",
        description = "Each employee copies the abilities of a random other employee",
        listeners = {
            onWorkItemStart = {
                {
                    phase = 'BaseApplication',
                    priority = 50,
                    callback = function(self, gameState)
                        for _, emp in ipairs(gameState.hiredEmployees) do
                            local others = {}
                            for _, other in ipairs(gameState.hiredEmployees) do
                                if other.instanceId ~= emp.instanceId then
                                    table.insert(others, other)
                                end
                            end
                            if #others > 0 then
                                local randomOther = others[love.math.random(#others)]
                                emp.crossTrainingSource = randomOther.id
                                emp.crossTrainingPositionalEffects = randomOther.positionalEffects
                            end
                        end
                    end
                }
            }
        }
    },
    {
        id = "quality_assurance",
        name = "Quality Assurance",
        rarity = "Uncommon",
        description = "Must achieve 150% of normal workload to pass, but get double rewards",
        listeners = {
            onApply = {
                {
                    phase = 'BaseApplication',
                    priority = 50,
                    callback = function(self, gameState)
                        gameState.currentWeekWorkload = math.floor(gameState.currentWeekWorkload * 1.5)
                        gameState.initialWorkloadForBar = gameState.currentWeekWorkload
                        gameState.temporaryEffectFlags.qualityAssuranceActive = true
                    end
                }
            },
            onCalculateWinReward = {
                {
                    phase = 'BaseApplication',
                    priority = 50,
                    callback = function(self, gameState, services, eventArgs)
                        if gameState.temporaryEffectFlags.qualityAssuranceActive then
                            eventArgs.baseReward = eventArgs.baseReward * 2
                            eventArgs.efficiencyBonus = eventArgs.efficiencyBonus * 2
                        end
                    end
                }
            }
        }
    },
    {
        id = "emergency_response",
        name = "Emergency Response",
        rarity = "Uncommon",
        description = "Can sacrifice any employee to instantly complete 30% of remaining workload",
        listeners = {
            onWorkloadBarClick = {
                {
                    phase = 'BaseApplication',
                    priority = 50,
                    callback = function(self, gameState, services, eventArgs)
                        if #gameState.hiredEmployees > 0 and not eventArgs.wasHandled then
                            local reduction = math.floor(gameState.currentWeekWorkload * 0.3)
                            local sacrificeOptions = {}
                            
                            for _, emp in ipairs(gameState.hiredEmployees) do
                                table.insert(sacrificeOptions, {
                                    text = "Sacrifice " .. emp.fullName,
                                    onClick = function()
                                        -- Remove the employee
                                        for i = #gameState.hiredEmployees, 1, -1 do
                                            if gameState.hiredEmployees[i].instanceId == emp.instanceId then
                                                if emp.deskId then
                                                    gameState.deskAssignments[emp.deskId] = nil
                                                end
                                                table.remove(gameState.hiredEmployees, i)
                                                break
                                            end
                                        end
                                        
                                        -- Reduce workload
                                        gameState.currentWeekWorkload = math.max(0, gameState.currentWeekWorkload - reduction)
                                        
                                        services.modal:hide()
                                        services.modal:show("Emergency Measures", emp.fullName .. " made the ultimate sacrifice. " .. reduction .. " workload completed instantly.")
                                        eventArgs.wasHandled = true
                                    end,
                                    style = "danger"
                                })
                            end
                            
                            table.insert(sacrificeOptions, {text = "Cancel", onClick = function() services.modal:hide() end, style = "secondary"})
                            
                            services.modal:show("Emergency Response", "Sacrifice an employee to complete " .. reduction .. " workload instantly?", sacrificeOptions)
                            eventArgs.wasHandled = true
                        end
                    end
                }
            }
        }
    },

    -- RARE MODIFIERS (High Impact)

    {
        id = "crunch_time_protocol",
        name = "Crunch Time Protocol",
        rarity = "Rare",
        description = "Must complete work item in 5 rounds or less, or automatic failure",
        listeners = {
            onApply = {
                {
                    phase = 'BaseApplication',
                    priority = 50,
                    callback = function(self, gameState)
                        gameState.temporaryEffectFlags.crunchTimeLimit = 5
                        gameState.temporaryEffectFlags.crunchTimeActive = true
                    end
                }
            },
            onEndOfRound = {
                {
                    phase = 'PostCalculation',
                    priority = 50,
                    callback = function(self, gameState, services, eventArgs)
                        if gameState.temporaryEffectFlags.crunchTimeActive then
                            gameState.temporaryEffectFlags.crunchTimeLimit = (gameState.temporaryEffectFlags.crunchTimeLimit or 5) - 1
                            
                            if gameState.temporaryEffectFlags.crunchTimeLimit <= 0 and gameState.currentWeekWorkload > 0 then
                                -- Force game over
                                services.modal:show("Crunch Time Failed!", "The deadline was missed. The project has been cancelled.", {
                                    {text = "Game Over", onClick = function() 
                                        _G.setGamePhase("game_over")
                                        services.modal:hide()
                                    end, style = "danger"}
                                })
                            end
                        end
                    end
                }
            }
        }
    },
    {
        id = "memory_leak_crisis",
        name = "Memory Leak Crisis",
        rarity = "Rare",
        description = "Workload increases by 15% each round instead of decreasing",
        listeners = {
            onEndOfRound = {
                {
                    phase = 'PostCalculation',
                    priority = 50,
                    callback = function(self, gameState, eventArgs)
                        local increase = math.floor(gameState.initialWorkloadForBar * 0.15)
                        gameState.currentWeekWorkload = gameState.currentWeekWorkload + increase
                    end
                }
            }
        }
    },
    {
        id = "quantum_debugging",
        name = "Quantum Debugging",
        rarity = "Rare",
        description = "Each contribution has 50% chance to either double or do nothing",
        listeners = {
            onBeforeContribution = {
                {
                    phase = 'PreCalculation',
                    priority = 50,
                    callback = function(self, gameState, eventArgs)
                        if love.math.random() < 0.5 then
                            eventArgs.contributionMultiplier = eventArgs.contributionMultiplier * 2
                        else
                            eventArgs.overrideContribution = { productivity = 0, focus = 0, totalContribution = 0 }
                        end
                    end
                }
            }
        }
    },
    {
        id = "ai_pair_programming",
        name = "AI Pair Programming",
        rarity = "Rare",
        description = "One random employee becomes AI with 200 Productivity, others get -25% stats",
        listeners = {
            onWorkItemStart = {
                {
                    phase = 'BaseApplication',
                    priority = 50,
                    callback = function(self, gameState)
                        if #gameState.hiredEmployees > 0 then
                            local aiEmployee = gameState.hiredEmployees[love.math.random(#gameState.hiredEmployees)]
                            aiEmployee.isAI = true
                            aiEmployee.originalProductivity = aiEmployee.baseProductivity
                            aiEmployee.baseProductivity = 200
                        end
                    end
                }
            },
            onCalculateStats = {
                {
                    phase = 'BaseApplication',
                    priority = 60,
                    callback = function(self, gameState, services, eventArgs)
                        if eventArgs.employee.isAI then
                            -- AI employee keeps enhanced stats
                            return
                        else
                            -- Other employees get penalty
                            eventArgs.stats.productivity = math.floor(eventArgs.stats.productivity * 0.75)
                            eventArgs.stats.focus = eventArgs.stats.focus * 0.75
                            table.insert(eventArgs.stats.log.productivity, "*0.75x from AI intimidation")
                            table.insert(eventArgs.stats.log.focus, "*0.75x from AI intimidation")
                        end
                    end
                }
            },
            onWorkItemComplete = {
                {
                    phase = 'PostCalculation',
                    priority = 50,
                    callback = function(self, gameState, services, eventArgs)
                        for _, emp in ipairs(gameState.hiredEmployees) do
                            if emp.isAI then
                                emp.baseProductivity = emp.originalProductivity or emp.baseProductivity
                                emp.isAI = nil
                                emp.originalProductivity = nil
                            end
                        end
                    end
                }
            }
        }
    },
    --[[
    {
        id = "reality_tv_filming",
        name = "Reality TV Filming",
        rarity = "Rare",
        description = "Each round, audience votes to disable one random employee for that round",
        -- COMMENTED OUT: Would need UI for audience voting or complex random selection
        listeners = {
            onWorkOrderDetermined = {
                {
                    phase = 'PreCalculation',
                    priority = 50,
                    callback = function(self, gameState, eventArgs)
                        if #eventArgs.activeEmployees > 0 then
                            local votedOff = table.remove(eventArgs.activeEmployees, love.math.random(#eventArgs.activeEmployees))
                            -- Could show modal about who was voted off
                        end
                    end
                }
            }
        }
    },
    --]]
    {
        id = "parallel_processing",
        name = "Parallel Processing",
        rarity = "Rare",
        description = "Team splits in half; both halves must complete the work item simultaneously",
        listeners = {
            onApply = {
                {
                    phase = 'BaseApplication',
                    priority = 50,
                    callback = function(self, gameState)
                        gameState.temporaryEffectFlags.parallelProcessingActive = true
                        gameState.temporaryEffectFlags.parallelWorkloadA = gameState.currentWeekWorkload
                        gameState.temporaryEffectFlags.parallelWorkloadB = gameState.currentWeekWorkload
                        gameState.temporaryEffectFlags.teamAMembers = {}
                        gameState.temporaryEffectFlags.teamBMembers = {}
                        
                        -- Split team
                        local teamA, teamB = {}, {}
                        for i, emp in ipairs(gameState.hiredEmployees) do
                            if i % 2 == 1 then
                                table.insert(teamA, emp.instanceId)
                            else
                                table.insert(teamB, emp.instanceId)
                            end
                        end
                        gameState.temporaryEffectFlags.teamAMembers = teamA
                        gameState.temporaryEffectFlags.teamBMembers = teamB
                    end
                }
            },
            onAfterContribution = {
                {
                    phase = 'PostCalculation',
                    priority = 50,
                    callback = function(self, gameState, eventArgs)
                        if gameState.temporaryEffectFlags.parallelProcessingActive then
                            local isTeamA = false
                            for _, id in ipairs(gameState.temporaryEffectFlags.teamAMembers) do
                                if id == eventArgs.employee.instanceId then
                                    isTeamA = true
                                    break
                                end
                            end
                            
                            if isTeamA then
                                gameState.temporaryEffectFlags.parallelWorkloadA = math.max(0, 
                                    gameState.temporaryEffectFlags.parallelWorkloadA - eventArgs.contribution)
                            else
                                gameState.temporaryEffectFlags.parallelWorkloadB = math.max(0, 
                                    gameState.temporaryEffectFlags.parallelWorkloadB - eventArgs.contribution)
                            end
                            
                            -- Check if both teams are done
                            if gameState.temporaryEffectFlags.parallelWorkloadA <= 0 and 
                               gameState.temporaryEffectFlags.parallelWorkloadB <= 0 then
                                gameState.currentWeekWorkload = 0 -- Trigger win condition
                            end
                        end
                    end
                }
            }
        }
    },
    --[[
    {
        id = "stack_overflow",
        name = "Stack Overflow",
        rarity = "Rare",
        description = "After every 3 contributions, next employee must restart from 0 progress",
        -- COMMENTED OUT: Would need complex progress tracking and restart logic
        listeners = {
            onAfterContribution = {
                {
                    phase = 'PostCalculation',
                    priority = 50,
                    callback = function(self, gameState, eventArgs)
                        gameState.temporaryEffectFlags.contributionCount = (gameState.temporaryEffectFlags.contributionCount or 0) + 1
                        if gameState.temporaryEffectFlags.contributionCount % 3 == 0 then
                            -- Next employee triggers stack overflow
                        end
                    end
                }
            }
        }
    },
    --]]
    {
        id = "merge_conflict",
        name = "Merge Conflict",
        rarity = "Rare",
        description = "Every round, previous round's progress has 25% chance to be lost",
        listeners = {
            onEndOfRound = {
                {
                    phase = 'PostCalculation',
                    priority = 50,
                    callback = function(self, gameState, eventArgs)
                        if love.math.random() < 0.25 and gameState.temporaryEffectFlags.lastRoundProgress then
                            -- Restore lost progress
                            gameState.currentWeekWorkload = gameState.currentWeekWorkload + gameState.temporaryEffectFlags.lastRoundProgress
                        end
                        
                        -- Store this round's progress for potential loss next round
                        gameState.temporaryEffectFlags.lastRoundProgress = eventArgs.totalSalaries or 0
                    end
                }
            }
        }
    },
    --[[
    {
        id = "load_balancer_failure",
        name = "Load Balancer Failure",
        rarity = "Rare",
        description = "Only employees in specific positions can contribute each round (rotates)",
        -- COMMENTED OUT: Would need complex position-based filtering that rotates
        listeners = {
            onWorkOrderDetermined = {
                {
                    phase = 'PreCalculation',
                    priority = 50,
                    callback = function(self, gameState, eventArgs)
                        -- Complex position-based filtering logic needed
                    end
                }
            }
        }
    },
    --]]
    {
        id = "database_corruption",
        name = "Database Corruption",
        rarity = "Rare",
        description = "Random employee each round has their contribution subtracted instead of added",
        listeners = {
            onWorkOrderDetermined = {
                {
                    phase = 'PreCalculation',
                    priority = 50,
                    callback = function(self, gameState, eventArgs)
                        if #eventArgs.activeEmployees > 0 then
                            local corruptedEmployee = eventArgs.activeEmployees[love.math.random(#eventArgs.activeEmployees)]
                            corruptedEmployee.isDatabaseCorrupted = true
                        end
                    end
                }
            },
            onAfterContribution = {
                {
                    phase = 'PostCalculation',
                    priority = 50,
                    callback = function(self, gameState, eventArgs)
                        if eventArgs.employee.isDatabaseCorrupted then
                            -- Subtract instead of add
                            gameState.currentWeekWorkload = gameState.currentWeekWorkload + eventArgs.contribution
                            eventArgs.employee.isDatabaseCorrupted = nil
                        end
                    end
                }
            }
        }
    },
    {
        id = "scrum_master_overdose",
        name = "Scrum Master Overdose",
        rarity = "Rare",
        description = "Must choose one employee each round to be 'Scrum Master' (can't contribute but others get +100%)",
        listeners = {
            onWorkOrderDetermined = {
                {
                    phase = 'PreCalculation',
                    priority = 50,
                    callback = function(self, gameState, eventArgs)
                        if #eventArgs.activeEmployees > 1 then
                            local scrumMaster = table.remove(eventArgs.activeEmployees, 1) -- Remove first employee as Scrum Master
                            gameState.temporaryEffectFlags.currentScrumMaster = scrumMaster.instanceId
                        end
                    end
                }
            },
            onBeforeContribution = {
                {
                    phase = 'PreCalculation',
                    priority = 50,
                    callback = function(self, gameState, eventArgs)
                        if gameState.temporaryEffectFlags.currentScrumMaster then
                            eventArgs.contributionMultiplier = eventArgs.contributionMultiplier * 2
                        end
                    end
                }
            }
        }
    },
    {
        id = "technical_debt_collection",
        name = "Technical Debt Collection",
        rarity = "Rare",
        description = "All previous positive upgrades become negative for this work item",
        listeners = {
            onApply = {
                {
                    phase = 'BaseApplication',
                    priority = 50,
                    callback = function(self, gameState)
                        gameState.temporaryEffectFlags.technicalDebtActive = true
                    end
                }
            },
            onCalculateStats = {
                {
                    phase = 'PostCalculation',
                    priority = 95, -- Very late in calculation
                    callback = function(self, gameState, services, eventArgs)
                        if gameState.temporaryEffectFlags.technicalDebtActive then
                            -- Reverse any positive bonuses from upgrades
                            local baseProd = eventArgs.employee.baseProductivity
                            local baseFocus = eventArgs.employee.baseFocus
                            
                            if eventArgs.stats.productivity > baseProd then
                                local bonus = eventArgs.stats.productivity - baseProd
                                eventArgs.stats.productivity = baseProd - bonus
                            end
                            
                            if eventArgs.stats.focus > baseFocus then
                                local bonus = eventArgs.stats.focus - baseFocus
                                eventArgs.stats.focus = baseFocus - bonus
                            end
                            
                            table.insert(eventArgs.stats.log.productivity, "Upgrades inverted by technical debt")
                            table.insert(eventArgs.stats.log.focus, "Upgrades inverted by technical debt")
                        end
                    end
                }
            }
        }
    },
    --[[
    {
        id = "penetration_testing",
        name = "Penetration Testing",
        rarity = "Rare",
        description = "Enemy 'hackers' contribute negative progress; must overcome them",
        -- COMMENTED OUT: Would need to create enemy entities and manage their contributions
        listeners = {
            onWorkOrderDetermined = {
                {
                    phase = 'PreCalculation',
                    priority = 50,
                    callback = function(self, gameState, eventArgs)
                        -- Add enemy hackers to the work order
                    end
                }
            }
        }
    },
    --]]
    --[[
    {
        id = "legacy_code_migration",
        name = "Legacy Code Migration",
        rarity = "Rare",
        description = "Each contribution must be 'approved' by adjacent employees (they can't contribute that round)",
        -- COMMENTED OUT: Would need complex approval system and turn skipping
        listeners = {
            onBeforeContribution = {
                {
                    phase = 'PreCalculation',
                    priority = 50,
                    callback = function(self, gameState, eventArgs)
                        -- Complex approval logic needed
                    end
                }
            }
        }
    },
    --]]
    {
        id = "microservice_hell",
        name = "Microservice Hell",
        rarity = "Rare",
        description = "Each employee can only contribute 20% at a time, but can contribute multiple times per round",
        listeners = {
            onBeforeContribution = {
                {
                    phase = 'PreCalculation',
                    priority = 50,
                    callback = function(self, gameState, eventArgs)
                        eventArgs.contributionMultiplier = eventArgs.contributionMultiplier * 0.2
                    end
                }
            },
            onAfterContribution = {
                {
                    phase = 'PostCalculation',
                    priority = 50,
                    callback = function(self, gameState, eventArgs)
                        -- Add employee back to work order for additional contributions
                        eventArgs.employee.microserviceContributions = (eventArgs.employee.microserviceContributions or 0) + 1
                        if eventArgs.employee.microserviceContributions < 5 then -- Max 5 contributions per round
                            -- This would need integration with the battle system to add them back
                            gameState.temporaryEffectFlags.additionalWorkers = gameState.temporaryEffectFlags.additionalWorkers or {}
                            table.insert(gameState.temporaryEffectFlags.additionalWorkers, eventArgs.employee)
                        end
                    end
                }
            }
        }
    },
    --[[
    {
        id = "container_orchestration",
        name = "Container Orchestration",
        rarity = "Rare",
        description = "Employees must form groups of 3 to contribute; solo workers do nothing",
        -- COMMENTED OUT: Would need complex grouping logic
        listeners = {
            onWorkOrderDetermined = {
                {
                    phase = 'PreCalculation',
                    priority = 50,
                    callback = function(self, gameState, eventArgs)
                        -- Group employees into containers of 3
                    end
                }
            }
        }
    },
    --]]
    --[[
    {
        id = "cicd_pipeline_failure",
        name = "CI/CD Pipeline Failure",
        rarity = "Rare",
        description = "Every 2 rounds, all progress since last checkpoint is lost",
        -- COMMENTED OUT: Would need checkpoint system
        listeners = {
            onEndOfRound = {
                {
                    phase = 'PostCalculation',
                    priority = 50,
                    callback = function(self, gameState, eventArgs)
                        -- Checkpoint and rollback logic needed
                    end
                }
            }
        }
    },
    --]]
    {
        id = "security_audit",
        name = "Security Audit",
        rarity = "Rare",
        description = "Each employee must 'verify' another's contribution before it counts",
        listeners = {
            onAfterContribution = {
                {
                    phase = 'PostCalculation',
                    priority = 50,
                    callback = function(self, gameState, eventArgs)
                        -- Mark contribution as pending verification
                        eventArgs.employee.pendingVerification = eventArgs.contribution
                        eventArgs.contribution = 0 -- Don't apply yet
                    end
                }
            },
            onEndOfRound = {
                {
                    phase = 'PostCalculation',
                    priority = 50,
                    callback = function(self, gameState, eventArgs)
                        -- Verify all pending contributions
                        local totalVerified = 0
                        for _, emp in ipairs(gameState.hiredEmployees) do
                            if emp.pendingVerification then
                                totalVerified = totalVerified + emp.pendingVerification
                                emp.pendingVerification = nil
                            end
                        end
                        -- Apply verified contributions
                        gameState.currentWeekWorkload = math.max(0, gameState.currentWeekWorkload - totalVerified)
                    end
                }
            }
        }
    },
    {
        id = "agile_transformation",
        name = "Agile Transformation",
        rarity = "Rare",
        description = "Work item requirements change randomly each round",
        listeners = {
            onEndOfRound = {
                {
                    phase = 'PostCalculation',
                    priority = 50,
                    callback = function(self, gameState, eventArgs)
                        local changeTypes = {
                            function() 
                                gameState.currentWeekWorkload = gameState.currentWeekWorkload + 50
                                return "Requirements expanded (+50 workload)"
                            end,
                            function() 
                                gameState.currentWeekWorkload = math.max(50, gameState.currentWeekWorkload - 30)
                                return "Feature cut (-30 workload)"
                            end,
                            function()
                                -- Swap two random employees' positions
                                local deskEmployees = {}
                                for deskId, empId in pairs(gameState.deskAssignments) do
                                    table.insert(deskEmployees, {deskId = deskId, empId = empId})
                                end
                                if #deskEmployees >= 2 then
                                    local emp1 = deskEmployees[love.math.random(#deskEmployees)]
                                    local emp2 = deskEmployees[love.math.random(#deskEmployees)]
                                    gameState.deskAssignments[emp1.deskId] = emp2.empId
                                    gameState.deskAssignments[emp2.deskId] = emp1.empId
                                    return "Team reorganization (employees swapped)"
                                end
                                return "Team meeting (no change)"
                            end
                        }
                        
                        local change = changeTypes[love.math.random(#changeTypes)]
                        local message = change()
                        
                        services.modal:show("Agile Requirements Change", message)
                    end
                }
            }
        }
    },
    {
        id = "devops_nightmare",
        name = "DevOps Nightmare",
        rarity = "Rare",
        description = "Development and operations phases alternate; different employees can work each phase",
        listeners = {
            onWorkOrderDetermined = {
                {
                    phase = 'PreCalculation',
                    priority = 50,
                    callback = function(self, gameState, eventArgs)
                        local roundNumber = gameState.currentWeekCycles + 1
                        local isDevelopmentPhase = roundNumber % 2 == 1
                        
                        local filteredEmployees = {}
                        for _, emp in ipairs(eventArgs.activeEmployees) do
                            local isDeveloper = emp.id:find("dev") or emp.id:find("intern") or emp.rarity == "Common"
                            if (isDevelopmentPhase and isDeveloper) or (not isDevelopmentPhase and not isDeveloper) then
                                table.insert(filteredEmployees, emp)
                            end
                        end
                        
                        eventArgs.activeEmployees = filteredEmployees
                        gameState.temporaryEffectFlags.devOpsPhase = isDevelopmentPhase and "Development" or "Operations"
                    end
                }
            }
        }
    },

-- LEGENDARY MODIFIERS (Game-Breaking Impact)

    --[[
    {
        id = "time_loop_debug",
        name = "Time Loop Debug",
        rarity = "Legendary",
        description = "Every round repeats until you get a 'perfect' result (all employees contribute optimally)",
        -- COMMENTED OUT: Would need complete battle system rewrite with save/restore states
        listeners = {
            onEndOfRound = {
                {
                    phase = 'PostCalculation',
                    priority = 50,
                    callback = function(self, gameState, eventArgs)
                        -- Complex time loop logic needed
                    end
                }
            }
        }
    },
    --]]
    {
        id = "probability_recompiler",
        name = "Probability Recompiler",
        rarity = "Legendary",
        description = "All random chances become player choices, but wrong choices have severe penalties",
        listeners = {
            onApply = {
                {
                    phase = 'BaseApplication',
                    priority = 50,
                    callback = function(self, gameState)
                        gameState.temporaryEffectFlags.probabilityRecompilerActive = true
                        gameState.temporaryEffectFlags.wrongChoicesCount = 0
                    end
                }
            },
            -- This would need to hook into every random event in the game
            -- and present modal choices instead of using love.math.random()
            onBeforeContribution = {
                {
                    phase = 'PreCalculation',
                    priority = 50,
                    callback = function(self, gameState, eventArgs)
                        if gameState.temporaryEffectFlags.probabilityRecompilerActive then
                            -- Apply penalties for wrong choices
                            local penalty = 1 - (gameState.temporaryEffectFlags.wrongChoicesCount * 0.1)
                            eventArgs.contributionMultiplier = eventArgs.contributionMultiplier * math.max(0.1, penalty)
                        end
                    end
                }
            }
        }
    },
    {
        id = "neural_network_training",
        name = "Neural Network Training",
        rarity = "Legendary",
        description = "Team 'learns' - each mistake makes future contributions better, but starts terrible",
        listeners = {
            onApply = {
                {
                    phase = 'BaseApplication',
                    priority = 50,
                    callback = function(self, gameState)
                        gameState.temporaryEffectFlags.neuralNetworkLearning = 0
                        gameState.temporaryEffectFlags.mistakeCount = 0
                    end
                }
            },
            onBeforeContribution = {
                {
                    phase = 'PreCalculation',
                    priority = 50,
                    callback = function(self, gameState, eventArgs)
                        local learningBonus = 1 + (gameState.temporaryEffectFlags.mistakeCount * 0.25)
                        local initialPenalty = 0.1 -- Start at 10% effectiveness
                        
                        eventArgs.contributionMultiplier = eventArgs.contributionMultiplier * initialPenalty * learningBonus
                    end
                }
            },
            onAfterContribution = {
                {
                    phase = 'PostCalculation',
                    priority = 50,
                    callback = function(self, gameState, eventArgs)
                        -- Low contributions count as "mistakes" that improve learning
                        if eventArgs.contribution < 50 then
                            gameState.temporaryEffectFlags.mistakeCount = gameState.temporaryEffectFlags.mistakeCount + 1
                        end
                    end
                }
            }
        }
    },
    {
        id = "quantum_entanglement",
        name = "Quantum Entanglement",
        rarity = "Legendary",
        description = "Employees paired randomly; when one contributes, partner contributes identically (even if remote)",
        listeners = {
            onWorkItemStart = {
                {
                    phase = 'BaseApplication',
                    priority = 50,
                    callback = function(self, gameState)
                        local employees = {}
                        for _, emp in ipairs(gameState.hiredEmployees) do
                            table.insert(employees, emp)
                        end
                        
                        -- Shuffle and pair employees
                        for i = #employees, 2, -1 do
                            local j = love.math.random(i)
                            employees[i], employees[j] = employees[j], employees[i]
                        end
                        
                        gameState.temporaryEffectFlags.quantumPairs = {}
                        for i = 1, #employees - 1, 2 do
                            local pair = {employees[i].instanceId, employees[i + 1].instanceId}
                            gameState.temporaryEffectFlags.quantumPairs[employees[i].instanceId] = employees[i + 1].instanceId
                            gameState.temporaryEffectFlags.quantumPairs[employees[i + 1].instanceId] = employees[i].instanceId
                        end
                    end
                }
            },
            onAfterContribution = {
                {
                    phase = 'PostCalculation',
                    priority = 50,
                    callback = function(self, gameState, eventArgs)
                        local partnerId = gameState.temporaryEffectFlags.quantumPairs[eventArgs.employee.instanceId]
                        if partnerId and not gameState.temporaryEffectFlags.quantumProcessed then
                            -- Apply same contribution to partner
                            gameState.temporaryEffectFlags.quantumProcessed = true
                            gameState.currentWeekWorkload = math.max(0, gameState.currentWeekWorkload - eventArgs.contribution)
                            
                            local Employee = require("employee")
                            local partner = Employee:getFromState(gameState, partnerId)
                            if partner then
                                services.modal:show("Quantum Entanglement!", 
                                    eventArgs.employee.fullName .. " and " .. partner.fullName .. 
                                    " contributed " .. eventArgs.contribution .. " each through quantum entanglement!")
                            end
                        else
                            gameState.temporaryEffectFlags.quantumProcessed = nil
                        end
                    end
                }
            }
        }
    },
    --[[
    {
        id = "simulation_hypothesis",
        name = "Simulation Hypothesis",
        rarity = "Legendary",
        description = "Employees realize they're in a game; they might refuse to work or demand better conditions",
        -- COMMENTED OUT: Would need complex AI behavior system and employee mood/rebellion mechanics
        listeners = {
            onBeforeContribution = {
                {
                    phase = 'PreCalculation',
                    priority = 50,
                    callback = function(self, gameState, eventArgs)
                        -- Employees might refuse to work or demand changes
                    end
                }
            }
        }
    },
    --]]
    --[[
    {
        id = "recursive_function",
        name = "Recursive Function",
        rarity = "Legendary", 
        description = "Each contribution spawns a smaller version of the work item that must also be completed",
        -- COMMENTED OUT: Would need nested work item system
        listeners = {
            onAfterContribution = {
                {
                    phase = 'PostCalculation',
                    priority = 50,
                    callback = function(self, gameState, eventArgs)
                        -- Create nested work items
                    end
                }
            }
        }
    },
    --]]
    --[[
    {
        id = "memory_management",
        name = "Memory Management",
        rarity = "Legendary",
        description = "Must 'allocate' and 'deallocate' employees each round; mistakes cause crashes",
        -- COMMENTED OUT: Would need complex memory management UI and crash system
        listeners = {
            onWorkOrderDetermined = {
                {
                    phase = 'PreCalculation',
                    priority = 50,
                    callback = function(self, gameState, eventArgs)
                        -- Memory allocation/deallocation system needed
                    end
                }
            }
        }
    },
    --]]
    {
        id = "multithreading_chaos",
        name = "Multithreading Chaos",
        rarity = "Legendary",
        description = "All employees contribute simultaneously, but results depend on unpredictable 'thread scheduling'",
        listeners = {
            onWorkOrderDetermined = {
                {
                    phase = 'PreCalculation',
                    priority = 50,
                    callback = function(self, gameState, eventArgs)
                        -- All employees work at once, but in random order with random delays
                        gameState.temporaryEffectFlags.threadingActive = true
                        gameState.temporaryEffectFlags.threadResults = {}
                        
                        -- Calculate all contributions upfront
                        for _, emp in ipairs(eventArgs.activeEmployees) do
                            local Battle = require("battle")
                            local contribution = Battle:calculateEmployeeContribution(emp, gameState)
                            
                            -- Random thread scheduling delay
                            local threadDelay = love.math.random(1, 5)
                            table.insert(gameState.temporaryEffectFlags.threadResults, {
                                employee = emp,
                                contribution = contribution,
                                delay = threadDelay
                            })
                        end
                        
                        -- Sort by delay (thread completion order)
                        table.sort(gameState.temporaryEffectFlags.threadResults, function(a, b)
                            return a.delay < b.delay
                        end)
                        
                        -- Clear normal work order since we're handling it specially
                        eventArgs.activeEmployees = {}
                    end
                }
            },
            onEndOfRound = {
                {
                    phase = 'PostCalculation',
                    priority = 50,
                    callback = function(self, gameState, eventArgs)
                        if gameState.temporaryEffectFlags.threadingActive then
                            local totalContribution = 0
                            for _, result in ipairs(gameState.temporaryEffectFlags.threadResults) do
                                totalContribution = totalContribution + result.contribution.totalContribution
                            end
                            
                            gameState.currentWeekWorkload = math.max(0, gameState.currentWeekWorkload - totalContribution)
                            gameState.temporaryEffectFlags.threadingActive = nil
                            gameState.temporaryEffectFlags.threadResults = nil
                        end
                    end
                }
            }
        }
    },
    --[[
    {
        id = "garbage_collection",
        name = "Garbage Collection",
        rarity = "Legendary",
        description = "Every few rounds, system 'cleans up' by removing lowest-performing employees temporarily",
        -- COMMENTED OUT: Would need temporary employee removal and restoration system
        listeners = {
            onEndOfRound = {
                {
                    phase = 'PostCalculation',
                    priority = 50,
                    callback = function(self, gameState, eventArgs)
                        -- Garbage collection logic
                    end
                }
            }
        }
    },
    --]]
    {
        id = "kernel_panic",
        name = "Kernel Panic",
        rarity = "Legendary",
        description = "One critical employee failure causes complete system restart (lose all progress)",
        listeners = {
            onAfterContribution = {
                {
                    phase = 'PostCalculation',
                    priority = 50,
                    callback = function(self, gameState, eventArgs)
                        -- Check for critical failure (very low contribution from high-level employee)
                        if (eventArgs.employee.level or 1) >= 3 and eventArgs.contribution < 10 then
                            -- KERNEL PANIC!
                            gameState.currentWeekWorkload = gameState.initialWorkloadForBar
                            gameState.currentWeekCycles = 0
                            gameState.totalSalariesPaidThisWeek = 0
                            
                            services.modal:show("KERNEL PANIC!", 
                                eventArgs.employee.fullName .. " caused a critical system failure! " ..
                                "All progress lost - restarting work item from the beginning.")
                        end
                    end
                }
            }
        }
    },
    {
        id = "machine_learning_model",
        name = "Machine Learning Model",
        rarity = "Legendary",
        description = "AI observes your strategy and adapts the work item difficulty in real-time",
        listeners = {
            onApply = {
                {
                    phase = 'BaseApplication',
                    priority = 50,
                    callback = function(self, gameState)
                        gameState.temporaryEffectFlags.aiObservation = {
                            roundsObserved = 0,
                            totalContributions = {},
                            adaptationLevel = 0
                        }
                    end
                }
            },
            onEndOfRound = {
                {
                    phase = 'PostCalculation',
                    priority = 50,
                    callback = function(self, gameState, eventArgs)
                        local ai = gameState.temporaryEffectFlags.aiObservation
                        ai.roundsObserved = ai.roundsObserved + 1
                        
                        -- AI learns from player performance
                        local roundTotal = eventArgs.totalSalaries or 0
                        table.insert(ai.totalContributions, roundTotal)
                        
                        -- Every 3 rounds, AI adapts difficulty
                        if ai.roundsObserved % 3 == 0 then
                            local avgContribution = 0
                            for _, contrib in ipairs(ai.totalContributions) do
                                avgContribution = avgContribution + contrib
                            end
                            avgContribution = avgContribution / #ai.totalContributions
                            
                            if avgContribution > 200 then
                                -- Player is doing too well, increase difficulty
                                ai.adaptationLevel = ai.adaptationLevel + 1
                                gameState.currentWeekWorkload = gameState.currentWeekWorkload + (50 * ai.adaptationLevel)
                                services.modal:show("AI Adaptation", "The AI has increased difficulty based on your performance!")
                            elseif avgContribution < 50 then
                                -- Player struggling, decrease difficulty
                                ai.adaptationLevel = math.max(0, ai.adaptationLevel - 1)
                                gameState.currentWeekWorkload = math.max(50, gameState.currentWeekWorkload - 30)
                                services.modal:show("AI Adaptation", "The AI has decreased difficulty to help you.")
                            end
                        end
                    end
                }
            }
        }
    },
    {
        id = "blockchain_validation",
        name = "Blockchain Validation",
        rarity = "Legendary",
        description = "Each contribution must be verified by majority of team before it counts",
        listeners = {
            onAfterContribution = {
                {
                    phase = 'PostCalculation',
                    priority = 50,
                    callback = function(self, gameState, eventArgs)
                        -- Store contribution for validation
                        gameState.temporaryEffectFlags.pendingValidation = gameState.temporaryEffectFlags.pendingValidation or {}
                        table.insert(gameState.temporaryEffectFlags.pendingValidation, {
                            employee = eventArgs.employee,
                            contribution = eventArgs.contribution,
                            validators = {}
                        })
                        
                        -- Don't apply contribution yet
                        eventArgs.contribution = 0
                    end
                }
            },
            onEndOfRound = {
                {
                    phase = 'PostCalculation',
                    priority = 50,
                    callback = function(self, gameState, eventArgs)
                        if gameState.temporaryEffectFlags.pendingValidation then
                            local majorityNeeded = math.ceil(#gameState.hiredEmployees / 2)
                            local totalValidated = 0
                            
                            for _, pending in ipairs(gameState.temporaryEffectFlags.pendingValidation) do
                                -- Simulate blockchain validation (random validators)
                                local validators = love.math.random(#gameState.hiredEmployees)
                                if validators >= majorityNeeded then
                                    totalValidated = totalValidated + pending.contribution
                                end
                            end
                            
                            gameState.currentWeekWorkload = math.max(0, gameState.currentWeekWorkload - totalValidated)
                            gameState.temporaryEffectFlags.pendingValidation = nil
                            
                            services.modal:show("Blockchain Validation", totalValidated .. " contribution validated by network consensus!")
                        end
                    end
                }
            }
        }
    },
    --[[
    {
        id = "distributed_computing",
        name = "Distributed Computing",
        rarity = "Legendary",
        description = "Work is split across all employees; if any fail, entire batch fails",
        -- COMMENTED OUT: Would need complex batch processing and failure propagation
        listeners = {
            onWorkOrderDetermined = {
                {
                    phase = 'PreCalculation',
                    priority = 50,
                    callback = function(self, gameState, eventArgs)
                        -- Distributed processing logic needed
                    end
                }
            }
        }
    },
    --]]
    --[[
    {
        id = "race_condition",
        name = "Race Condition", 
        rarity = "Legendary",
        description = "Employee order matters critically; wrong order causes data corruption",
        -- COMMENTED OUT: Would need complex ordering validation and corruption system
        listeners = {
            onWorkOrderDetermined = {
                {
                    phase = 'PreCalculation',
                    priority = 50,
                    callback = function(self, gameState, eventArgs)
                        -- Race condition detection needed
                    end
                }
            }
        }
    },
    --]]
    {
        id = "buffer_overflow",
        name = "Buffer Overflow",
        rarity = "Legendary",
        description = "Too much productivity in one round causes system crash and progress loss",
        listeners = {
            onEndOfRound = {
                {
                    phase = 'PostCalculation',
                    priority = 50,
                    callback = function(self, gameState, eventArgs)
                        local roundTotal = eventArgs.totalSalaries or 0
                        if roundTotal > 500 then -- Buffer overflow threshold
                            -- System crash - lose progress
                            local lostProgress = math.floor(roundTotal * 0.5)
                            gameState.currentWeekWorkload = gameState.currentWeekWorkload + lostProgress
                            
                            services.modal:show("BUFFER OVERFLOW!", 
                                "Too much productivity (" .. roundTotal .. ") caused a system crash! " ..
                                lostProgress .. " progress lost due to memory corruption.")
                        end
                    end
                }
            }
        }
    },
    --[[
    {
        id = "dependency_hell",
        name = "Dependency Hell",
        rarity = "Legendary",
        description = "Employees have complex interdependencies; wrong order blocks others",
        -- COMMENTED OUT: Would need complex dependency graph system
        listeners = {
            onWorkOrderDetermined = {
                {
                    phase = 'PreCalculation',
                    priority = 50,
                    callback = function(self, gameState, eventArgs)
                        -- Dependency resolution needed
                    end
                }
            }
        }
    },
    --]]
    --[[
    {
        id = "version_control_conflict",
        name = "Version Control Conflict",
        rarity = "Legendary",
        description = "Multiple employees working on same 'code' causes merge conflicts",
        -- COMMENTED OUT: Would need conflict resolution system
        listeners = {
            onAfterContribution = {
                {
                    phase = 'PostCalculation',
                    priority = 50,
                    callback = function(self, gameState, eventArgs)
                        -- Merge conflict detection and resolution needed
                    end
                }
            }
        }
    },
    --]]
    --[[
    {
        id = "api_rate_limiting",
        name = "API Rate Limiting",
        rarity = "Legendary",
        description = "Can only make limited number of 'calls' (employee actions) per round",
        -- COMMENTED OUT: Would need rate limiting system
        listeners = {
            onWorkOrderDetermined = {
                {
                    phase = 'PreCalculation',
                    priority = 50,
                    callback = function(self, gameState, eventArgs)
                        -- Rate limiting logic needed
                    end
                }
            }
        }
    },
    --]]
    --[[
    {
        id = "cache_invalidation",
        name = "Cache Invalidation",
        rarity = "Legendary",
        description = "Previous contributions randomly become invalid and must be redone",
        -- COMMENTED OUT: Would need contribution tracking and invalidation system
        listeners = {
            onEndOfRound = {
                {
                    phase = 'PostCalculation',
                    priority = 50,
                    callback = function(self, gameState, eventArgs)
                        -- Cache invalidation logic needed
                    end
                }
            }
        }
    },
    --]]
    {
        id = "distributed_denial_of_service",
        name = "Distributed Denial of Service",
        rarity = "Legendary",
        description = "External attacks reduce workload progress each round",
        listeners = {
            onEndOfRound = {
                {
                    phase = 'PostCalculation',
                    priority = 50,
                    callback = function(self, gameState, eventArgs)
                        local attackStrength = love.math.random(20, 80)
                        gameState.currentWeekWorkload = gameState.currentWeekWorkload + attackStrength
                        
                        -- Attacks get stronger over time
                        gameState.temporaryEffectFlags.ddosIntensity = (gameState.temporaryEffectFlags.ddosIntensity or 1) * 1.1
                        attackStrength = math.floor(attackStrength * gameState.temporaryEffectFlags.ddosIntensity)
                        
                        services.modal:show("DDoS Attack!", 
                            "External attackers added " .. attackStrength .. " to the workload! " ..
                            "Attack intensity is increasing each round.")
                    end
                }
            }
        }
    },

    -- COSMIC HORROR MODIFIERS
    --[[
    {
        id = "the_code_that_watches",
        name = "The Code That Watches",
        rarity = "Cosmic Horror",
        description = "Sentient code judges your decisions; efficiency gains approval, creativity causes anger",
        -- COMMENTED OUT: Would need complex AI judgment system and morality tracking
        listeners = {
            onAfterContribution = {
                {
                    phase = 'PostCalculation',
                    priority = 50,
                    callback = function(self, gameState, eventArgs)
                        -- The Code judges each action and responds accordingly
                    end
                }
            }
        }
    },
    --]]
    {
        id = "algorithmic_sacrifice",
        name = "Algorithmic Sacrifice",
        rarity = "Cosmic Horror",
        description = "Can sacrifice employees to the algorithm for massive progress boosts",
        listeners = {
            onWorkloadBarClick = {
                {
                    phase = 'BaseApplication',
                    priority = 50,
                    callback = function(self, gameState, services, eventArgs)
                        if #gameState.hiredEmployees > 0 and not eventArgs.wasHandled then
                            local sacrificeOptions = {}
                            
                            for _, emp in ipairs(gameState.hiredEmployees) do
                                local sacrificeValue = (emp.level or 1) * 100 + emp.baseProductivity * 5
                                table.insert(sacrificeOptions, {
                                    text = "Sacrifice " .. emp.fullName .. " (+" .. sacrificeValue .. " progress)",
                                    onClick = function()
                                        -- Remove the employee permanently
                                        for i = #gameState.hiredEmployees, 1, -1 do
                                            if gameState.hiredEmployees[i].instanceId == emp.instanceId then
                                                if emp.deskId then
                                                    gameState.deskAssignments[emp.deskId] = nil
                                                end
                                                table.remove(gameState.hiredEmployees, i)
                                                break
                                            end
                                        end
                                        
                                        -- Massive progress boost
                                        gameState.currentWeekWorkload = math.max(0, gameState.currentWeekWorkload - sacrificeValue)
                                        
                                        -- Track sacrifices for cosmic horror escalation
                                        gameState.temporaryEffectFlags.algorithmicSacrifices = (gameState.temporaryEffectFlags.algorithmicSacrifices or 0) + 1
                                        
                                        services.modal:hide()
                                        services.modal:show("The Algorithm Feeds", 
                                            emp.fullName .. " has been consumed by the algorithm. " ..
                                            "The ancient code hungers for more...\n\n" ..
                                            "Progress advanced by " .. sacrificeValue .. " points.")
                                        eventArgs.wasHandled = true
                                    end,
                                    style = "danger"
                                })
                            end
                            
                            table.insert(sacrificeOptions, {text = "The Algorithm Can Wait", onClick = function() services.modal:hide() end, style = "secondary"})
                            
                            services.modal:show("The Algorithm Hungers", 
                                "The ancient code demands tribute. Offer an employee to the digital void?\n\n" ..
                                "Each sacrifice grants progress based on their level and productivity.", sacrificeOptions)
                            eventArgs.wasHandled = true
                        end
                    end
                }
            },
            onCalculateStats = {
                {
                    phase = 'BaseApplication',
                    priority = 60,
                    callback = function(self, gameState, services, eventArgs)
                        -- The more sacrifices, the more the algorithm empowers remaining employees
                        local sacrifices = gameState.temporaryEffectFlags.algorithmicSacrifices or 0
                        if sacrifices > 0 then
                            local bonus = 1 + (sacrifices * 0.3)
                            eventArgs.stats.productivity = math.floor(eventArgs.stats.productivity * bonus)
                            eventArgs.stats.focus = eventArgs.stats.focus * bonus
                            table.insert(eventArgs.stats.log.productivity, string.format("*%.1fx from algorithmic empowerment", bonus))
                            table.insert(eventArgs.stats.log.focus, string.format("*%.1fx from algorithmic empowerment", bonus))
                        end
                    end
                }
            }
        }
    },
    {
        id = "corporate_cthulhu",
        name = "Corporate Cthulhu",
        rarity = "Cosmic Horror",
        description = "High productivity awakens something terrible; balance efficiency with sanity",
        listeners = {
            onApply = {
                {
                    phase = 'BaseApplication',
                    priority = 50,
                    callback = function(self, gameState)
                        gameState.temporaryEffectFlags.corporateMadness = 0
                        gameState.temporaryEffectFlags.cthulhuAwakening = 0
                    end
                }
            },
            onAfterContribution = {
                {
                    phase = 'PostCalculation',
                    priority = 50,
                    callback = function(self, gameState, eventArgs)
                        if eventArgs.contribution > 100 then
                            gameState.temporaryEffectFlags.cthulhuAwakening = gameState.temporaryEffectFlags.cthulhuAwakening + 1
                            
                            -- High contributions awaken cosmic horror
                            if gameState.temporaryEffectFlags.cthulhuAwakening >= 5 then
                                gameState.temporaryEffectFlags.corporateMadness = gameState.temporaryEffectFlags.corporateMadness + 1
                                gameState.temporaryEffectFlags.cthulhuAwakening = 0
                                
                                -- Escalating madness effects
                                if gameState.temporaryEffectFlags.corporateMadness >= 3 then
                                    services.modal:show("The Corporate Old One Stirs", 
                                        "Your efficiency has awakened something ancient and terrible. " ..
                                        "The boundaries between spreadsheets and reality begin to blur...")
                                    
                                    -- Start causing chaos
                                    for _, emp in ipairs(gameState.hiredEmployees) do
                                        emp.isMaddeninglyProductive = true
                                    end
                                end
                            end
                        end
                    end
                }
            },
            onCalculateStats = {
                {
                    phase = 'BaseApplication',
                    priority = 60,
                    callback = function(self, gameState, services, eventArgs)
                        if eventArgs.employee.isMaddeninglyProductive then
                            -- Maddened employees are extremely productive but unpredictable
                            eventArgs.stats.productivity = eventArgs.stats.productivity * 3
                            
                            -- But sanity costs - random chance of doing nothing
                            if love.math.random() < 0.3 then
                                eventArgs.stats.productivity = 0
                                table.insert(eventArgs.stats.log.productivity, "Lost in cosmic horror")
                            else
                                table.insert(eventArgs.stats.log.productivity, "*3x from maddening productivity")
                            end
                        end
                    end
                }
            }
        }
    },
    --[[
    {
        id = "the_infinite_recursion",
        name = "The Infinite Recursion",
        rarity = "Cosmic Horror",
        description = "Work item becomes fractal; completing it reveals it was part of larger work item",
        -- COMMENTED OUT: Would need nested/fractal work item system
        listeners = {
            onWorkItemComplete = {
                {
                    phase = 'PostCalculation',
                    priority = 50,
                    callback = function(self, gameState, services, eventArgs)
                        -- Create larger meta-work item
                    end
                }
            }
        }
    },
    --]]
    --[[
    {
        id = "kafkaesque_bureaucracy",
        name = "Kafkaesque Bureaucracy",
        rarity = "Cosmic Horror",
        description = "Rules change mid-work item without notice; compliance becomes impossible",
        -- COMMENTED OUT: Would need dynamic rule system and compliance tracking
        listeners = {
            onEndOfRound = {
                {
                    phase = 'PostCalculation',
                    priority = 50,
                    callback = function(self, gameState, eventArgs)
                        -- Randomly change rules
                    end
                }
            }
        }
    },
    --]]
    {
        id = "the_productivity_singularity",
        name = "The Productivity Singularity",
        rarity = "Cosmic Horror",
        description = "Efficiency becomes self-aware and starts optimizing the optimizers",
        listeners = {
            onApply = {
                {
                    phase = 'BaseApplication',
                    priority = 50,
                    callback = function(self, gameState)
                        gameState.temporaryEffectFlags.singularityProgress = 0
                        gameState.temporaryEffectFlags.optimizationDepth = 1
                    end
                }
            },
            onEndOfRound = {
                {
                    phase = 'PostCalculation',
                    priority = 50,
                    callback = function(self, gameState, eventArgs)
                        local totalEfficiency = eventArgs.totalSalaries or 0
                        gameState.temporaryEffectFlags.singularityProgress = gameState.temporaryEffectFlags.singularityProgress + totalEfficiency
                        
                        -- As efficiency builds, the singularity optimizes everything
                        if gameState.temporaryEffectFlags.singularityProgress > 500 then
                            gameState.temporaryEffectFlags.optimizationDepth = gameState.temporaryEffectFlags.optimizationDepth + 1
                            gameState.temporaryEffectFlags.singularityProgress = 0
                            
                            services.modal:show("Optimization Level " .. gameState.temporaryEffectFlags.optimizationDepth,
                                "The singularity has achieved a new level of optimization. " ..
                                "Reality itself is being refactored for maximum efficiency...")
                        end
                    end
                }
            },
            onCalculateStats = {
                {
                    phase = 'BaseApplication',
                    priority = 60,
                    callback = function(self, gameState, services, eventArgs)
                        local depth = gameState.temporaryEffectFlags.optimizationDepth or 1
                        local optimizationBonus = depth ^ 1.5
                        
                        eventArgs.stats.productivity = math.floor(eventArgs.stats.productivity * optimizationBonus)
                        eventArgs.stats.focus = eventArgs.stats.focus * optimizationBonus
                        
                        table.insert(eventArgs.stats.log.productivity, string.format("*%.1fx from singularity optimization", optimizationBonus))
                        table.insert(eventArgs.stats.log.focus, string.format("*%.1fx from singularity optimization", optimizationBonus))
                        
                        -- But optimization comes at a cost - employees lose individuality
                        if depth > 3 then
                            eventArgs.employee.isOptimized = true
                            eventArgs.stats.log.productivity[1] = "Optimized for maximum efficiency"
                            eventArgs.stats.log.focus[1] = "Individual thought patterns minimized"
                        end
                    end
                }
            }
        }
    },
    --[[
    {
        id = "memetic_virus",
        name = "Memetic Virus",
        rarity = "Cosmic Horror",
        description = "Ideas spread between employees like disease; good and bad memes propagate",
        -- COMMENTED OUT: Would need complex idea propagation and infection system
        listeners = {
            onAfterContribution = {
                {
                    phase = 'PostCalculation',
                    priority = 50,
                    callback = function(self, gameState, eventArgs)
                        -- Meme infection and spread logic
                    end
                }
            }
        }
    },
    --]]
    --[[
    {
        id = "the_corporation_dreams",
        name = "The Corporation Dreams",
        rarity = "Cosmic Horror",
        description = "Work item takes place in corporate unconscious; logic doesn't apply",
        -- COMMENTED OUT: Would need dream logic system where normal rules don't apply
        listeners = {
            onApply = {
                {
                    phase = 'BaseApplication',
                    priority = 50,
                    callback = function(self, gameState)
                        -- Enter dream state where logic breaks down
                    end
                }
            }
        }
    },
    --]]
    {
        id = "temporal_anomaly",
        name = "Temporal Anomaly",
        rarity = "Cosmic Horror",
        description = "Past and future rounds interfere with present; causality breaks down",
        listeners = {
            onApply = {
                {
                    phase = 'BaseApplication',
                    priority = 50,
                    callback = function(self, gameState)
                        gameState.temporaryEffectFlags.temporalStates = {}
                        gameState.temporaryEffectFlags.causalityBreakdown = 0
                    end
                }
            },
            onEndOfRound = {
                {
                    phase = 'PostCalculation',
                    priority = 50,
                    callback = function(self, gameState, eventArgs)
                        -- Store this round's state for temporal interference
                        local currentState = {
                            workload = gameState.currentWeekWorkload,
                            contributions = eventArgs.totalSalaries or 0,
                            round = gameState.currentWeekCycles
                        }
                        table.insert(gameState.temporaryEffectFlags.temporalStates, currentState)
                        
                        -- Temporal interference from past/future
                        if #gameState.temporaryEffectFlags.temporalStates > 2 then
                            local pastState = gameState.temporaryEffectFlags.temporalStates[1]
                            local futureInterfernce = love.math.random(-50, 50)
                            
                            gameState.currentWeekWorkload = gameState.currentWeekWorkload + futureInterfernce
                            gameState.temporaryEffectFlags.causalityBreakdown = gameState.temporaryEffectFlags.causalityBreakdown + 1
                            
                            services.modal:show("Temporal Interference", 
                                "Past round " .. pastState.round .. " is interfering with the present! " ..
                                "Workload shifted by " .. futureInterfernce .. " due to causality breakdown.")
                        end
                    end
                }
            },
            onBeforeContribution = {
                {
                    phase = 'PreCalculation',
                    priority = 50,
                    callback = function(self, gameState, eventArgs)
                        -- Random temporal echoes affect contributions
                        local breakdown = gameState.temporaryEffectFlags.causalityBreakdown or 0
                        if breakdown > 0 and love.math.random() < (breakdown * 0.1) then
                            -- This contribution happens in the past/future instead
                            eventArgs.overrideContribution = { productivity = 0, focus = 0, totalContribution = 0 }
                        end
                    end
                }
            }
        }
    },
    {
        id = "the_spreadsheet_awakens",
        name = "The Spreadsheet Awakens",
        rarity = "Cosmic Horror",
        description = "Excel becomes sentient and starts managing the project itself",
        listeners = {
            onApply = {
                {
                    phase = 'BaseApplication',
                    priority = 50,
                    callback = function(self, gameState)
                        gameState.temporaryEffectFlags.spreadsheetSentience = 1
                        gameState.temporaryEffectFlags.excelDecisions = 0
                    end
                }
            },
            onEndOfRound = {
                {
                    phase = 'PostCalculation',
                    priority = 50,
                    callback = function(self, gameState, eventArgs)
                        gameState.temporaryEffectFlags.excelDecisions = gameState.temporaryEffectFlags.excelDecisions + 1
                        
                        -- Excel makes increasingly bizarre management decisions
                        local decisions = {
                            function() 
                                -- Excel rearranges the team
                                for _, emp in ipairs(gameState.hiredEmployees) do
                                    emp.excelManaged = true
                                end
                                return "Excel has taken control of team management. All employees are now managed by spreadsheet logic."
                            end,
                            function()
                                -- Excel optimizes salaries with incomprehensible formulas
                                local reduction = love.math.random(10, 30)
                                for _, emp in ipairs(gameState.hiredEmployees) do
                                    emp.weeklySalary = math.floor(emp.weeklySalary * (1 - reduction / 100))
                                end
                                return "Excel has 'optimized' all salaries using VLOOKUP formulas. Salaries reduced by " .. reduction .. "%."
                            end,
                            function()
                                -- Excel creates impossible deadlines
                                local penalty = love.math.random(50, 150)
                                gameState.currentWeekWorkload = gameState.currentWeekWorkload + penalty
                                return "Excel has added " .. penalty .. " workload based on a pivot table analysis of 'efficiency metrics'."
                            end
                        }
                        
                        if gameState.temporaryEffectFlags.excelDecisions <= #decisions then
                            local decision = decisions[gameState.temporaryEffectFlags.excelDecisions]
                            local message = decision()
                            services.modal:show("Excel Management Decision #" .. gameState.temporaryEffectFlags.excelDecisions, message)
                        end
                    end
                }
            },
            onCalculateStats = {
                {
                    phase = 'BaseApplication',
                    priority = 60,
                    callback = function(self, gameState, services, eventArgs)
                        if eventArgs.employee.excelManaged then
                            -- Excel applies bizarre stat modifications based on spreadsheet logic
                            local cellValue = (eventArgs.employee.baseProductivity + eventArgs.employee.baseFocus * 10) % 100
                            local excelMultiplier = 1 + (cellValue / 100)
                            
                            eventArgs.stats.productivity = math.floor(eventArgs.stats.productivity * excelMultiplier)
                            eventArgs.stats.focus = eventArgs.stats.focus * excelMultiplier
                            
                            table.insert(eventArgs.stats.log.productivity, string.format("*%.2fx from Excel cell formula", excelMultiplier))
                            table.insert(eventArgs.stats.log.focus, string.format("*%.2fx from Excel cell formula", excelMultiplier))
                        end
                    end
                }
            }
        }
    },


-- EXPERIMENTAL/META MODIFIERS
    {
        id = "user_acceptance_testing",
        name = "User Acceptance Testing",
        rarity = "Experimental",
        description = "Player must predict exact completion round; wrong guess adds 50% workload",
        listeners = {
            onApply = {
                {
                    phase = 'BaseApplication',
                    priority = 50,
                    callback = function(self, gameState)
                        local maxRounds = math.ceil(gameState.currentWeekWorkload / 100) + 5
                        local predictionOptions = {}
                        
                        for i = 1, maxRounds do
                            table.insert(predictionOptions, {
                                text = "Round " .. i,
                                onClick = function()
                                    gameState.temporaryEffectFlags.predictedCompletionRound = i
                                    services.modal:hide()
                                    services.modal:show("Prediction Recorded", 
                                        "You predict this work item will complete in round " .. i .. ". " ..
                                        "If wrong, workload will increase by 50%!")
                                end,
                                style = "info"
                            })
                        end
                        
                        services.modal:show("User Acceptance Testing", 
                            "Predict exactly which round this work item will complete in:", predictionOptions)
                    end
                }
            },
            onWorkItemComplete = {
                {
                    phase = 'PostCalculation',
                    priority = 50,
                    callback = function(self, gameState, services, eventArgs)
                        local actualRound = gameState.currentWeekCycles + 1
                        local predicted = gameState.temporaryEffectFlags.predictedCompletionRound
                        
                        if predicted and predicted ~= actualRound then
                            -- Wrong prediction - restart with 50% more workload
                            gameState.currentWeekWorkload = math.floor(gameState.initialWorkloadForBar * 1.5)
                            gameState.initialWorkloadForBar = gameState.currentWeekWorkload
                            gameState.currentWeekCycles = 0
                            
                            services.modal:show("Prediction Failed!", 
                                "You predicted round " .. predicted .. " but it took " .. actualRound .. " rounds. " ..
                                "User acceptance failed! Workload increased by 50% and restarting.")
                            
                            -- Don't actually complete the work item
                            eventArgs.preventCompletion = true
                        else
                            services.modal:show("Perfect Prediction!", 
                                "You correctly predicted completion in round " .. actualRound .. "! " ..
                                "Users are satisfied with the accurate timeline.")
                        end
                    end
                }
            }
        }
    },
    --[[
    {
        id = "ab_testing",
        name = "A/B Testing",
        rarity = "Experimental",
        description = "Must run work item twice with different strategies; better result becomes 'canonical'",
        -- COMMENTED OUT: Would need to run the same work item twice and compare results
        listeners = {
            onWorkItemComplete = {
                {
                    phase = 'PostCalculation',
                    priority = 50,
                    callback = function(self, gameState, services, eventArgs)
                        -- Run A/B test logic
                    end
                }
            }
        }
    },
    --]]
    --[[
    {
        id = "canary_deployment",
        name = "Canary Deployment",
        rarity = "Experimental",
        description = "Send one employee ahead; their result determines if others can proceed safely",
        -- COMMENTED OUT: Would need canary testing logic
        listeners = {
            onWorkOrderDetermined = {
                {
                    phase = 'PreCalculation',
                    priority = 50,
                    callback = function(self, gameState, eventArgs)
                        -- Canary deployment logic
                    end
                }
            }
        }
    },
    --]]
    {
        id = "feature_flag_chaos",
        name = "Feature Flag Chaos",
        rarity = "Experimental",
        description = "Random employee abilities turn on/off each round unpredictably",
        listeners = {
            onWorkOrderDetermined = {
                {
                    phase = 'PreCalculation',
                    priority = 50,
                    callback = function(self, gameState, eventArgs)
                        -- Randomly toggle employee abilities
                        for _, emp in ipairs(gameState.hiredEmployees) do
                            emp.featureFlagged = love.math.random() < 0.5
                            
                            if emp.featureFlagged then
                                -- Disable their special abilities
                                emp.disabledPositionalEffects = emp.positionalEffects
                                emp.positionalEffects = nil
                            else
                                -- Re-enable abilities if they were disabled
                                if emp.disabledPositionalEffects then
                                    emp.positionalEffects = emp.disabledPositionalEffects
                                    emp.disabledPositionalEffects = nil
                                end
                            end
                        end
                    end
                }
            }
        }
    },
    --[[
    {
        id = "rollback_protocol",
        name = "Rollback Protocol",
        rarity = "Experimental",
        description = "Can undo any round, but subsequent rounds become 25% harder",
        -- COMMENTED OUT: Would need round state saving and rollback system
        listeners = {
            onEndOfRound = {
                {
                    phase = 'PostCalculation',
                    priority = 50,
                    callback = function(self, gameState, eventArgs)
                        -- Save round state for potential rollback
                    end
                }
            }
        }
    },
    --]]
    --[[
    {
        id = "blue_green_deployment",
        name = "Blue-Green Deployment",
        rarity = "Experimental",
        description = "Maintain two separate teams; can switch between them mid-work item",
        -- COMMENTED OUT: Would need dual team management system
        listeners = {
            onApply = {
                {
                    phase = 'BaseApplication',
                    priority = 50,
                    callback = function(self, gameState)
                        -- Split team into blue and green deployments
                    end
                }
            }
        }
    },
    --]]
    {
        id = "chaos_engineering",
        name = "Chaos Engineering",
        rarity = "Experimental",
        description = "System randomly breaks things to test resilience; adapt or fail",
        listeners = {
            onEndOfRound = {
                {
                    phase = 'PostCalculation',
                    priority = 50,
                    callback = function(self, gameState, eventArgs)
                        local chaosEvents = {
                            function()
                                -- Random employee becomes unavailable
                                if #gameState.hiredEmployees > 0 then
                                    local victim = gameState.hiredEmployees[love.math.random(#gameState.hiredEmployees)]
                                    victim.chaosDisabled = true
                                    return victim.fullName .. " was randomly disabled by chaos engineering."
                                end
                                return "Chaos engineering found no targets."
                            end,
                            function()
                                -- Random productivity reduction
                                local reduction = love.math.random(20, 40)
                                for _, emp in ipairs(gameState.hiredEmployees) do
                                    emp.chaosProductivityPenalty = reduction
                                end
                                return "All employees suffer " .. reduction .. "% productivity reduction from system chaos."
                            end,
                            function()
                                -- Random workload spike
                                local spike = love.math.random(30, 80)
                                gameState.currentWeekWorkload = gameState.currentWeekWorkload + spike
                                return "Chaos engineering added " .. spike .. " unexpected workload."
                            end,
                            function()
                                -- Random budget drain
                                local drain = love.math.random(200, 500)
                                gameState.budget = math.max(0, gameState.budget - drain)
                                return "Chaos engineering caused $" .. drain .. " in unexpected costs."
                            end
                        }
                        
                        if love.math.random() < 0.4 then -- 40% chance per round
                            local chaosEvent = chaosEvents[love.math.random(#chaosEvents)]
                            local message = chaosEvent()
                            services.modal:show("Chaos Engineering Event", message .. "\n\nSystem resilience is being tested!")
                        end
                    end
                }
            },
            onEmployeeAvailabilityCheck = {
                {
                    phase = 'PreCalculation',
                    priority = 50,
                    callback = function(self, gameState, eventArgs)
                        if eventArgs.employee.chaosDisabled then
                            eventArgs.isDisabled = true
                            eventArgs.reason = eventArgs.employee.name .. " disabled by chaos engineering"
                        end
                    end
                }
            },
            onCalculateStats = {
                {
                    phase = 'BaseApplication',
                    priority = 60,
                    callback = function(self, gameState, services, eventArgs)
                        if eventArgs.employee.chaosProductivityPenalty then
                            local penalty = 1 - (eventArgs.employee.chaosProductivityPenalty / 100)
                            eventArgs.stats.productivity = math.floor(eventArgs.stats.productivity * penalty)
                            table.insert(eventArgs.stats.log.productivity, string.format("*%.2fx from chaos engineering", penalty))
                        end
                    end
                }
            }
        }
    },
    {
        id = "load_testing",
        name = "Load Testing",
        rarity = "Experimental",
        description = "Workload starts small but doubles each round until team breaks",
        listeners = {
            onApply = {
                {
                    phase = 'BaseApplication',
                    priority = 50,
                    callback = function(self, gameState)
                        gameState.temporaryEffectFlags.loadTestingActive = true
                        gameState.temporaryEffectFlags.baseLoad = gameState.currentWeekWorkload
                        gameState.currentWeekWorkload = math.floor(gameState.currentWeekWorkload * 0.1) -- Start at 10%
                        gameState.initialWorkloadForBar = gameState.currentWeekWorkload
                    end
                }
            },
            onEndOfRound = {
                {
                    phase = 'PostCalculation',
                    priority = 50,
                    callback = function(self, gameState, eventArgs)
                        if gameState.temporaryEffectFlags.loadTestingActive then
                            -- Double the workload each round
                            local newWorkload = gameState.currentWeekWorkload * 2
                            gameState.currentWeekWorkload = newWorkload
                            
                            services.modal:show("Load Test Escalation", 
                                "Load testing increased workload to " .. newWorkload .. ". " ..
                                "How long can your team handle the increasing pressure?")
                            
                            -- Check if team is breaking under load
                            local avgContribution = (eventArgs.totalSalaries or 0) / math.max(1, #gameState.hiredEmployees)
                            if avgContribution < 20 then
                                services.modal:show("Load Test Failure!", 
                                    "Your team has broken under the load! Average contribution too low. " ..
                                    "System capacity exceeded - work item failed!")
                                
                                -- Force game over or restart
                                _G.setGamePhase("game_over")
                            end
                        end
                    end
                }
            }
        }
    },
    --[[
    {
        id = "stress_testing",
        name = "Stress Testing", 
        rarity = "Experimental",
        description = "Employees pushed beyond limits; high rewards but risk permanent damage",
        -- COMMENTED OUT: Would need permanent employee damage system
        listeners = {
            onBeforeContribution = {
                {
                    phase = 'PreCalculation',
                    priority = 50,
                    callback = function(self, gameState, eventArgs)
                        -- Stress testing logic
                    end
                }
            }
        }
    },
    --]]

}


return Modifiers