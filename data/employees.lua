-- Employee Definitions
-- baseFocus is now 1.0 for all. Focus modifiers are multiplicative (value is the 'plus' part, e.g., 0.5 means 1.5x)

return {

    -- RARE & LEGENDARY EMPLOYEES
    {
        id = 'corporate_lawyer1', name = 'Corporate Lawyer', icon = 'assets/portraits/prt0001.png', rarity = 'Rare',
        hiringBonus = 3300, weeklySalary = 805,
        baseProductivity = 26, baseFocus = 1.1,
        description = "If your budget would be depleted, this employee is 'sacrificed' (fired) to prevent a Game Over once.",
        special = { type = 'negates_budget_game_over_once' },
        listeners = {
            onBudgetDepleted = {
                {
                    phase = 'BaseApplication',
                    priority = 50,
                    callback = function(self, gameState, eventArgs)
                        if eventArgs.gameOverPrevented then return end

                        eventArgs.gameOverPrevented = true
                        eventArgs.message = "Objection!\nThe Corporate Lawyer, " .. self.fullName .. ", was sacrificed to settle the debt, preventing bankruptcy... this time."
                        
                        for i = #gameState.hiredEmployees, 1, -1 do
                            if gameState.hiredEmployees[i].instanceId == self.instanceId then
                                if self.deskId and gameState.deskAssignments[self.deskId] then
                                    gameState.deskAssignments[self.deskId] = nil
                                end
                                table.remove(gameState.hiredEmployees, i)
                                break
                            end
                        end
                    end
                }
            }
        }
    },
    {
        id = 'vc_nephew1', name = 'VC\'s Nephew', icon = 'assets/portraits/prt0002.png', rarity = 'Rare',
        hiringBonus = 5500, weeklySalary = 2300,
        baseProductivity = 0, baseFocus = 1.0,
        description = 'Does nothing, and has a very high salary. However, at the end of each Sprint, there\'s a 25% chance of a massive budget injection "from his dad."',
        special = { type = 'sprint_end_budget_injection', chance = 0.25, amount = 25000, does_not_work = true },
        listeners = {
            onSprintStart = {
                {
                    phase = 'BaseApplication',
                    priority = 50,
                    callback = function(self, gameState, services, eventArgs)
                        if love.math.random() < self.special.chance then
                            if not gameState.ventureCapitalActive then
                                gameState.budget = gameState.budget + self.special.amount
                            end
                            services.modal:show(
                                "A Call From Dad",
                                self.fullName.."'s father was impressed by your progress and made a 'small' donation of $"..self.special.amount.."!"
                            )
                        end
                    end
                }
            }
        }
    },
    {
        id = 'masseuse1', name = 'In-House Masseuse', icon = 'assets/portraits/prt0003.png', rarity = 'Rare',
        hiringBonus = 2420, weeklySalary = 518,
        baseProductivity = 0, baseFocus = 1.0,
        description = 'Does not contribute to workload. Instead, all adjacent employees have their Focus multiplied by 1.5x per level.',
        special = { does_not_work = true },
        positionalEffects = { all_adjacent = { focus_mult = 1.5, scales_with_level = true } },
    },
    {
        id = 'wfh_advocate1', name = 'Work from Home Advocate', icon = 'assets/portraits/prt0004.png', rarity = 'Rare',
        hiringBonus = 2860, weeklySalary = 575,
        baseProductivity = 25, baseFocus = 1.0,
        description = 'Must be placed in the office. Doubles the Productivity and Focus of all remote workers.',
        special = { type = 'boost_remote_workers', prod_mult = 2.0, focus_mult = 2.0 },
        listeners = {
            onCalculateStats = {
                {
                    phase = 'BaseApplication',
                    priority = 50,
                    callback = function(self, gameState, services, eventArgs)
                        if eventArgs.employee.variant == 'remote' and eventArgs.employee.instanceId ~= self.instanceId then
                            eventArgs.stats.productivity = eventArgs.stats.productivity * self.special.prod_mult
                            eventArgs.stats.focus = eventArgs.stats.focus * self.special.focus_mult
                            table.insert(eventArgs.stats.log.productivity, string.format("*%.1fx from WFH Advocate", self.special.prod_mult))
                            table.insert(eventArgs.stats.log.focus, string.format("*%.1fx from WFH Advocate", self.special.focus_mult))
                        end
                    end
                }
            }
        }
    },
    -- {
    --     id = 'office_dog1', name = 'Office Dog', icon = 'assets/portraits/prt0005.png', rarity = 'Rare',
    --     hiringBonus = 1500, weeklySalary = 100,
    --     baseProductivity = 0, baseFocus = 1.0,
    --     description = 'Does not work. Each turn, has a 50% chance to "motivate" a random employee, granting them +5 Productivity per level for that turn.',
    --     special = { type = 'office_dog_motivation', chance = 0.5, prod_boost = 5, does_not_work = true, scales_with_level = true },
    --     listeners = {
    --         onEmployeeContextCheck = {
    --             {
    --                 phase = 'BaseApplication',
    --                 priority = 50,
    --                 callback = function(self, gameState, eventArgs)
    --                     if eventArgs.employee.instanceId == self.instanceId then
    --                         eventArgs.context = "worker_training"
    --                     end
    --                 end
    --             }
    --         },
    --         onTurnStart = {
    --             {
    --                 phase = 'BaseApplication',
    --                 priority = 50,
    --                 callback = function(self, gameState, eventArgs)
    --                     if love.math.random() < self.special.chance then
    --                         local potentialTargets = {}
    --                         for _, emp in ipairs(gameState.hiredEmployees) do
    --                             if emp.instanceId ~= self.instanceId then table.insert(potentialTargets, emp) end
    --                         end
                            
    --                         if #potentialTargets > 0 then
    --                             local targetIndex = love.math.random(#potentialTargets)
    --                             local targetEmp = potentialTargets[targetIndex]
    --                             local boost = self.special.prod_boost
    --                             if self.special.scales_with_level then boost = boost * (self.level or 1) end
    --                             targetEmp.baseProductivity = targetEmp.baseProductivity + boost
    --                             print(self.fullName .. " motivated " .. targetEmp.fullName .. " with a productivity boost of " .. boost)
    --                         end
    --                     end
    --                 end
    --             }
    --         }
    --     }
    -- },
    {
        id = 'chess_master1', name = 'Chess Master', icon = 'assets/portraits/prt0076.png', rarity = 'Rare',
        hiringBonus = 2640, weeklySalary = 552,
        baseProductivity = 22, baseFocus = 1.2,
        description = 'All positional effects (positive and negative) of employees in the same row AND column are increased by 25% per level.',
        special = { type = 'amplify_positional_effects', multiplier = 1.25, scales_with_level = true },
        listeners = {
            onCalculateStats = {
                {
                    phase = 'Amplification',
                    priority = 50,
                    callback = function(self, gameState, services, eventArgs)
                        if not self.deskId then return end
                        local targetEmployee = eventArgs.employee
                        if not targetEmployee.deskId then return end
                        
                        local organizerDeskIndex = tonumber(string.match(self.deskId, "desk%-(%d+)"))
                        if not organizerDeskIndex then return end
                        
                        local GameData = require("data")
                        local organizerRow = math.floor(organizerDeskIndex / GameData.GRID_WIDTH)
                        local organizerCol = organizerDeskIndex % GameData.GRID_WIDTH
                        
                        local targetDeskIndex = tonumber(string.match(targetEmployee.deskId, "desk%-(%d+)"))
                        if not targetDeskIndex then return end

                        local targetRow = math.floor(targetDeskIndex / GameData.GRID_WIDTH)
                        local targetCol = targetDeskIndex % GameData.GRID_WIDTH

                        -- Only amplify if target is in the same row OR column
                        if targetRow == organizerRow or targetCol == organizerCol then
                            if eventArgs.bonusesApplied and eventArgs.bonusesApplied.positional then
                                local amplifier = 1 + ((self.special.multiplier - 1) * (self.level or 1))
                                
                                local prodAmplification = math.floor(eventArgs.bonusesApplied.positional.prod * (amplifier - 1))
                                local focusAmplification = eventArgs.bonusesApplied.positional.focus * (amplifier - 1)

                                if prodAmplification ~= 0 then
                                    eventArgs.stats.productivity = eventArgs.stats.productivity + prodAmplification
                                    table.insert(eventArgs.stats.log.productivity, string.format("%s%d from Organizer", prodAmplification > 0 and "+" or "", prodAmplification))
                                end

                                if focusAmplification ~= 0 then
                                    eventArgs.stats.focus = eventArgs.stats.focus + focusAmplification
                                    table.insert(eventArgs.stats.log.focus, string.format("%s%.2fx from Organizer", focusAmplification > 0 and "+" or "", focusAmplification))
                                end
                            end
                        end
                    end
                }
            }
        }
    },
    -- {
    --     id = 'cobol_coder1', name = 'Old-School Coder', icon = 'assets/portraits/prt0007.png', rarity = 'Rare',
    --     hiringBonus = 2800, weeklySalary = 600,
    --     baseProductivity = 10, baseFocus = 1.0,
    --     description = 'Productivity is 5x on "Database Migration" or "Refactor Legacy Code" work items, but only 0.2x on all other items.',
    --     special = { type = 'conditional_productivity_by_work_item', prod_mult = 5.0, penalty_mult = 0.2, target_work_items = { s4_item1 = true, s4_item2 = true } },
    --     listeners = {
    --         onCalculateStats = {
    --             {
    --                 phase = 'BaseApplication',
    --                 priority = 50,
    --                 callback = function(self, gameState, services, eventArgs)
    --                     if eventArgs.employee.instanceId == self.instanceId then
    --                         local currentSprint = require("data").ALL_SPRINTS[gameState.currentSprintIndex]
    --                         local currentWorkItem = currentSprint and currentSprint.workItems[gameState.currentWorkItemIndex]
                            
    --                         if currentWorkItem then
    --                             local multiplier = self.special.target_work_items[currentWorkItem.id] and self.special.prod_mult or self.special.penalty_mult
    --                             eventArgs.stats.productivity = math.floor(eventArgs.stats.productivity * multiplier)
    --                             local description = multiplier > 1 and "legacy code expertise" or "modern tech confusion"
    --                             table.insert(eventArgs.stats.log.productivity, string.format("*%.1fx from %s", multiplier, description))
    --                         end
    --                     end
    --                 end
    --             }
    --         }
    --     }
    -- },
    {
        id = 'efficiency_expert1', name = 'Efficiency Expert', icon = 'assets/portraits/prt0008.png', rarity = 'Rare',
        hiringBonus = 3300, weeklySalary = 748,
        baseProductivity = 25, baseFocus = 1.3,
        description = 'After the third work item of each Sprint, fires the Common employee who contributed the least and redistributes their productivity to other Common employees per level.',
        special = { type = 'cull_the_weak_on_work_item_3', target_rarity = 'Common', scales_with_level = true },
        listeners = {
            onWorkItemComplete = {
                {
                    phase = 'PostCalculation',
                    priority = 50,
                    callback = function(self, gameState, eventArgs)
                        if gameState.currentWorkItemIndex == 3 then
                            local commonEmployees = {}
                            for _, emp in ipairs(gameState.hiredEmployees) do
                                if emp.rarity == self.special.target_rarity and emp.instanceId ~= self.instanceId then
                                    table.insert(commonEmployees, emp)
                                end
                            end
                            
                            if #commonEmployees >= 2 then
                                -- Sort by contribution, lowest first
                                table.sort(commonEmployees, function(a,b) return (a.contributionThisItem or 0) < (b.contributionThisItem or 0) end)
                                
                                local fired = commonEmployees[1]
                                local firedProductivity = fired.baseProductivity
                                
                                -- Remove the fired employee
                                for i = #gameState.hiredEmployees, 1, -1 do
                                    if gameState.hiredEmployees[i].instanceId == fired.instanceId then
                                        table.remove(gameState.hiredEmployees, i)
                                        if fired.deskId and gameState.deskAssignments[fired.deskId] then
                                            gameState.deskAssignments[fired.deskId] = nil
                                        end
                                        break
                                    end
                                end
                                
                                -- Redistribute productivity to remaining common employees
                                local remainingCommon = {}
                                for _, emp in ipairs(gameState.hiredEmployees) do
                                    if emp.rarity == self.special.target_rarity and emp.instanceId ~= self.instanceId then
                                        table.insert(remainingCommon, emp)
                                    end
                                end
                                
                                if #remainingCommon > 0 then
                                    local baseProductivityPerEmployee = math.floor(firedProductivity / #remainingCommon)
                                    local remainder = firedProductivity % #remainingCommon
                                    local levelMultiplier = self.level or 1
                                    
                                    for i, emp in ipairs(remainingCommon) do
                                        local boost = baseProductivityPerEmployee
                                        if i <= remainder then boost = boost + 1 end
                                        boost = boost * levelMultiplier
                                        emp.baseProductivity = emp.baseProductivity + boost
                                    end
                                    
                                    services.modal:show(
                                        "Restructuring Complete",
                                        self.fullName .. " fired " .. fired.fullName .. " and redistributed their productivity among " .. #remainingCommon .. " remaining common employees (x" .. levelMultiplier .. " from level)."
                                    )
                                else
                                    services.modal:show(
                                        "Restructuring",
                                        self.fullName .. " fired " .. fired.fullName .. " but there were no other common employees to boost."
                                    )
                                end
                            end
                        end
                    end
                }
            }
        }
    },
    {
        id = 'scrum_master', name = 'Scrum Master', icon = 'assets/portraits/prt0009.png', rarity = 'Rare',
        hiringBonus = 2750, weeklySalary = 633,
        baseProductivity = 25, baseFocus = 1.1,
        description = 'Employees work in a random order each cycle. The first employee to work gets a 2x productivity boost per level.',
        special = { type = 'randomize_work_order', first_worker_mult = 2.0, scales_with_level = true },
        listeners = {
            onWorkOrderDetermined = {
                {
                    phase = 'PreCalculation',
                    priority = 50,
                    callback = function(self, gameState, eventArgs)
                        if #eventArgs.activeEmployees > 0 then
                            for i = #eventArgs.activeEmployees, 2, -1 do 
                                local j = love.math.random(i)
                                eventArgs.activeEmployees[i], eventArgs.activeEmployees[j] = eventArgs.activeEmployees[j], eventArgs.activeEmployees[i]
                            end
                            if eventArgs.activeEmployees[1] then 
                                eventArgs.activeEmployees[1].agileFirstTurnBoost = self.special.first_worker_mult
                                print("Agile Coach randomized work order. First worker is " .. eventArgs.activeEmployees[1].name)
                            end
                        end
                    end
                }
            },
            onBeforeContribution = {
                {
                    phase = 'PreCalculation',
                    priority = 50,
                    callback = function(self, gameState, eventArgs)
                        if eventArgs.employee.agileFirstTurnBoost then
                            local boost = eventArgs.employee.agileFirstTurnBoost
                            if self.special.scales_with_level then 
                                boost = 1 + ((boost - 1) * (self.level or 1)) 
                            end
                            eventArgs.contributionMultiplier = eventArgs.contributionMultiplier * boost
                            eventArgs.employee.agileFirstTurnBoost = nil
                        end
                    end
                }
            }
        }
    },
    -- { 
    --     id = 'office_plant', name = 'Office Plant', rarity = 'Rare', cost = 800, icon = '🌱',
    --     description = 'A plant in the office boosts Focus by +0.5x for all employees.',
    --     effect = { type = 'special_office_plant' },
    --     listeners = {
    --         onCalculateStats = {
    --             {
    --                 phase = 'BaseApplication',
    --                 priority = 60, -- A bit later than employee-specific
    --                 callback = function(self, gameState, services, eventArgs)
    --                     -- Check if a watering can is owned and not disabled
    --                     local hasWateringCan = false
    --                     for _, upgId in ipairs(gameState.purchasedPermanentUpgrades) do
    --                         if upgId == 'watering_can' and not (gameState.temporaryEffectFlags.disabledUpgrades and gameState.temporaryEffectFlags.disabledUpgrades['watering_can']) then
    --                             hasWateringCan = true
    --                             break
    --                         end
    --                     end

    --                     local focus_boost = hasWateringCan and 1.0 or 0.5
    --                     eventArgs.stats.focus = eventArgs.stats.focus + focus_boost
    --                     table.insert(eventArgs.stats.log.focus, string.format("+%.2fx from Office Plant %s", focus_boost, hasWateringCan and "(Watered)" or ""))
    --                 end
    --             }
    --         }
    --     }
    -- },
    {
        id = 'legacy_mentor1', name = 'Legacy Mentor', icon = 'assets/portraits/prt0011.png', rarity = 'Rare',
        hiringBonus = 2200, weeklySalary = 0,
        baseProductivity = 0, baseFocus = 0,
        description = 'Drag onto an office worker to "haunt" them, permanently granting them +18 Prod and +1.0x Focus. Consumed on use. This effect stacks.',
        special = { type = 'haunt_target_on_hire', prod_boost = 18, focus_add = 1.0 },
        listeners = {
            onPlacement = {
                {
                    phase = 'BaseApplication',
                    priority = 50,
                    callback = function(self, gameState, services, eventArgs)
                        if eventArgs.employee.instanceId == self.instanceId and eventArgs.fromShop then
                            local occupantId = gameState.deskAssignments[eventArgs.targetDeskId]
                            if occupantId then
                                local targetEmployee = require("employee"):getFromState(gameState, occupantId)
                                if targetEmployee then
                                    targetEmployee.baseProductivity = targetEmployee.baseProductivity + (self.special.prod_boost or 10)
                                    targetEmployee.baseFocus = targetEmployee.baseFocus + (self.special.focus_add or 0.5)
                                    targetEmployee.haunt_stacks = (targetEmployee.haunt_stacks or 0) + 1
                                    print(targetEmployee.name .. " is now haunted by " .. self.name)
                                    eventArgs.wasHandled = true
                                    eventArgs.success = true
                                    return
                                end
                            end
                            eventArgs.wasHandled = true
                            eventArgs.success = false
                            eventArgs.message = "This must be dropped onto an existing office worker's desk."
                        end
                    end
                }
            }
        }
    },
    {
        id = 'tintern1', name = 'Tintern', icon = 'assets/portraits/prt0012.png', rarity = 'Rare',
        hiringBonus = 2530, weeklySalary = 460,
        baseProductivity = 18, baseFocus = 1.8,
        description = 'High focus, but ignores bonuses from managers. Has a 5% chance each turn to "expose a conspiracy," disabling a random positive upgrade for the rest of the sprint.',
        special = { type = 'expose_conspiracy', chance = 0.05, ignores_manager_bonus = true },
        listeners = {
            onFinalizeStats = {
                {
                    phase = 'PostCalculation',
                    priority = 50,
                    callback = function(self, gameState, eventArgs)
                        if eventArgs.employee.instanceId == self.instanceId and self.special.ignores_manager_bonus then
                            local filteredLog = {}
                            for _, logEntry in ipairs(eventArgs.stats.log.focus) do
                                if not logEntry:find("Project Manager") then
                                    table.insert(filteredLog, logEntry)
                                end
                            end
                            eventArgs.stats.log.focus = filteredLog
                            eventArgs.stats.focus = eventArgs.employee.baseFocus
                        end
                    end
                }
            },
            onTurnStart = {
                {
                    phase = 'BaseApplication',
                    priority = 50,
                    callback = function(self, gameState, eventArgs)
                        if love.math.random() < self.special.chance then
                            local potentialUpgrades = {}
                            local positiveUpgradeTypes = { 
                                focus_boost_all_flat_permanent = true, productivityMultiplierAll = true, focusMultiplierAllFlat = true, 
                                special_office_dog = true, productivity_boost_all_flat_permanent = true, budget_generation_per_win = true, 
                                ignore_negative_focus_positional = true, reduce_all_salaries_flat = true, productivity_boost_remote_flat = true, 
                                increase_positive_positional_focus_percent = true, reduce_all_salaries_percent = true, team_score_multiplier_first_round = true, 
                                chance_avoid_bailout_cost = true, special_plant_boost = true 
                            }
                            
                            for _, upgId in ipairs(gameState.purchasedPermanentUpgrades) do
                                if not (gameState.temporaryEffectFlags.disabledUpgrades and gameState.temporaryEffectFlags.disabledUpgrades[upgId]) then
                                    for _, upgData in ipairs(require("data").ALL_UPGRADES) do
                                        if upgData.id == upgId and upgData.effect and positiveUpgradeTypes[upgData.effect.type] then
                                            table.insert(potentialUpgrades, upgData)
                                        end
                                    end
                                end
                            end
                            
                            if #potentialUpgrades > 0 then
                                local upgradeToDisable = potentialUpgrades[love.math.random(#potentialUpgrades)]
                                gameState.temporaryEffectFlags.disabledUpgrades[upgradeToDisable.id] = true
                                services.modal:show(
                                "A Conspiracy!",
                                self.fullName .. " has convinced the team that '"..upgradeToDisable.name.."' is a corporate plot and they will no longer use it this sprint!"
                                )
                            end
                        end
                    end
                }
            }
        }
    },

    -- {
    --     id = 'time_traveling_intern1', name = 'Time-Traveling Intern', icon = 'assets/portraits/prt0013.png', rarity = 'Rare',
    --     hiringBonus = 1800, weeklySalary = 350,
    --     baseProductivity = 8, baseFocus = 1.0,
    --     description = 'Arrives with knowledge of the future. The modifier for the final work item of the current sprint is revealed.',
    --     special = { type = 'reveals_modifier' },
    --     listeners = {
    --         onDrawIntelPanel = {
    --             {
    --                 phase = "BaseApplication",
    --                 priority = 50,
    --                 callback = function(self, gameState, services, eventArgs)
    --                     local sprint = require("data").ALL_SPRINTS[gameState.currentSprintIndex]
    --                     local bossWorkItem = sprint and sprint.workItems[3]
    --                     if bossWorkItem and bossWorkItem.modifier then
    --                         love.graphics.setColor(0.2, 0.6, 0.8, 1)
    --                         eventArgs.y = eventArgs.y + Drawing.drawTextWrapped("Future Insight:", eventArgs.x, eventArgs.y, eventArgs.width, services.fontSmall)
    --                         love.graphics.setColor(services.colors.text)
    --                         eventArgs.y = eventArgs.y + Drawing.drawTextWrapped("This Sprint's Boss: "..bossWorkItem.modifier.description, eventArgs.x, eventArgs.y, eventArgs.width, services.fontSmall) + 5
    --                     end
    --                 end
    --             }
    --         }
    --     }
    -- },
    -- {
    --     id = 'dog_walker1', name = 'Office Dog Walker', icon = 'assets/portraits/prt0014.png', rarity = 'Rare',
    --     hiringBonus = 1600, weeklySalary = 300,
    --     baseProductivity = 0, baseFocus = 1.0,
    --     description = 'Has 0 productivity, but ensures the "Office Dog" has a 100% chance to motivate an employee each turn.',
    --     special = { type = 'enhances_office_dog', does_not_work = true }
    -- },
    {
        id = 'barista1', name = 'Barista', icon = 'assets/portraits/prt0015.png', rarity = 'Rare',
        hiringBonus = 2200, weeklySalary = 460,
        baseProductivity = 0, baseFocus = 1.0,
        description = 'Does not work. If you own an Espresso Machine, serves coffee to 3 random employees at the start of each Sprint, giving them a permanent +8 Productivity per level.',
        special = { type = 'sprint_start_prod_boost', target_count = 3, prod_boost = 8, required_upgrade = 'coffee1', does_not_work = true, scales_with_level = true },
            listeners = {
                onSprintStart = {
                    {
                        phase = 'BaseApplication',
                        priority = 50,
                        callback = function(self, gameState, eventArgs)
                            -- The upgrade check is now self-contained
                            if require("shop"):isUpgradePurchased(gameState.purchasedPermanentUpgrades, self.special.required_upgrade) then
                                local boostedNames = {}
                                local potentialTargets = {}
                                for _, emp in ipairs(gameState.hiredEmployees) do
                                    if emp.instanceId ~= self.instanceId then table.insert(potentialTargets, emp) end
                                end
                                
                                for i = 1, self.special.target_count do
                                    if #potentialTargets > 0 then
                                        local targetIndex = love.math.random(#potentialTargets)
                                        local target = potentialTargets[targetIndex]
                                        local boost = self.special.prod_boost
                                        if self.special.scales_with_level then boost = boost * (self.level or 1) end
                                        target.baseProductivity = target.baseProductivity + boost
                                        table.insert(boostedNames, target.fullName)
                                        table.remove(potentialTargets, targetIndex)
                                    end
                                end
                                
                                if #boostedNames > 0 then
                                    services.modal:show(
                                    "Coffee Break!",
                                    self.fullName .. " served coffee, boosting the productivity of: " .. table.concat(boostedNames, ", ")
                                    )
                                end
                            end
                        end
                    }
                }
            }
    },
    {
        id = 'beet_farmer1', name = 'Beet Farmer', icon = 'assets/portraits/prt0016.png', rarity = 'Rare',
        hiringBonus = 2860, weeklySalary = 575,
        baseProductivity = 25, baseFocus = 1.2,
        description = 'Gains +1.5x Focus per level when adjacent to a Project Manager. After each completed work item, has a 25% chance to "train" a random employee, disabling them for the next item but giving them a permanent +10 Productivity per level.',
        special = { type = 'dwight_behavior', manager_id = 'project_manager', focus_mult = 1.5, train_chance = 0.25, train_prod_boost = 10, scales_with_level = true },
        listeners = {
            onCalculateStats = {
                {
                    phase = 'BaseApplication',
                    priority = 50,
                    callback = function(self, gameState, services, eventArgs)
                        if eventArgs.employee.instanceId == self.instanceId and eventArgs.employee.deskId then
                            local hasAdjacentManager = false
                            local directions = {"up", "down", "left", "right"}
                            for _, dir in ipairs(directions) do
                                local neighborDeskId = require("placement"):getNeighboringDeskId(eventArgs.employee.deskId, dir, require("data").GRID_WIDTH, require("data").TOTAL_DESK_SLOTS, gameState.desks)
                                if neighborDeskId and gameState.deskAssignments[neighborDeskId] then
                                    local neighbor = require("employee"):getFromState(gameState, gameState.deskAssignments[neighborDeskId])
                                    if neighbor and neighbor.id == self.special.manager_id then
                                        hasAdjacentManager = true
                                        break
                                    end
                                end
                            end
                            
                            if hasAdjacentManager then
                                local focusBonus = self.special.focus_mult
                                if self.special.scales_with_level then
                                    focusBonus = 1 + ((focusBonus - 1) * (self.level or 1))
                                end
                                eventArgs.stats.focus = eventArgs.stats.focus * focusBonus
                                table.insert(eventArgs.stats.log.focus, string.format("*%.1fx from adjacent manager", focusBonus))
                            end
                        end
                    end
                }
            },
            onWorkItemComplete = {
                {
                    phase = 'PostCalculation',
                    priority = 50,
                    callback = function(self, gameState, eventArgs)
                        if eventArgs.isBossItem and love.math.random() < self.special.train_chance then
                            local potentialTargets = {}
                            for _, targetEmp in ipairs(gameState.hiredEmployees) do
                                if targetEmp.instanceId ~= self.instanceId then table.insert(potentialTargets, targetEmp) end
                            end
                            if #potentialTargets > 0 then
                                local trainee = potentialTargets[love.math.random(#potentialTargets)]
                                local boost = self.special.train_prod_boost
                                if self.special.scales_with_level then boost = boost * (self.level or 1) end
                                trainee.isTraining = true
                                trainee.baseProductivity = trainee.baseProductivity + boost
                                print(self.fullName .. " has put " .. trainee.fullName .. " into safety training.")
                            end
                        end
                    end
                }
            }
        }
    },
    {
        id = 'red_shirt_intern1', name = 'Red-Shirt Intern', icon = 'assets/portraits/prt0017.png', rarity = 'Rare',
        hiringBonus = 1100, weeklySalary = 230,
        baseProductivity = 27, baseFocus = 1.1,
        description = 'If you would get a Game Over from budget depletion, this employee is automatically fired to absorb the penalty, preventing the loss.',
        special = { type = 'sacrificial_intern' },
        listeners = {
            onBudgetDepleted = {
                {
                    phase = 'BaseApplication',
                    priority = 50,
                    callback = function(self, gameState, eventArgs)
                        if eventArgs.gameOverPrevented then return end

                        if gameState.bailOutsRemaining <= 0 then
                            eventArgs.gameOverPrevented = true
                            eventArgs.message = "A Noble Sacrifice!\nRed-Shirt Intern " .. self.fullName .. " was fired to cover the budget shortfall, preventing a Game Over!"
                            
                            for i = #gameState.hiredEmployees, 1, -1 do
                                if gameState.hiredEmployees[i].instanceId == self.instanceId then
                                    if self.deskId and gameState.deskAssignments[self.deskId] then
                                        gameState.deskAssignments[self.deskId] = nil
                                    end
                                    table.remove(gameState.hiredEmployees, i)
                                    break
                                end
                            end
                        end
                    end
                }
            }
        }
    },
    {
        id = 'time_traveling_intern1', name = 'Time-Traveling Intern', icon = 'assets/portraits/prt0018.png', rarity = 'Rare',
        hiringBonus = 2420, weeklySalary = 518,
        baseProductivity = 22, baseFocus = 1.2,
        description = 'Allows you to see the "Boss Modifier" of the NEXT sprint\'s boss.',
        special = { type = 'reveals_next_sprint_modifier' },
        listeners = {
            onDrawIntelPanel = {
                {
                    phase = "BaseApplication",
                    priority = 50,
                    callback = function(self, gameState, services, eventArgs)
                        if gameState.currentSprintIndex < #require("data").ALL_SPRINTS then
                            local nextSprint = require("data").ALL_SPRINTS[gameState.currentSprintIndex + 1]
                            local nextBoss = nextSprint and nextSprint.workItems[3]
                            if nextBoss and nextBoss.modifier then
                                love.graphics.setColor(0.8, 0.2, 0.6, 1)
                                eventArgs.y = eventArgs.y + Drawing.drawTextWrapped("Admiral's Intel:", eventArgs.x, eventArgs.y, eventArgs.width, services.fontSmall)
                                love.graphics.setColor(services.colors.text)
                                eventArgs.y = eventArgs.y + Drawing.drawTextWrapped("Next Sprint's Boss: "..nextBoss.modifier.description, eventArgs.x, eventArgs.y, eventArgs.width, services.fontSmall) + 5
                            end
                        end
                    end
                }
            }
        }
    },
    {
        id = 'q1', name = 'Q', icon = 'assets/portraits/prt0019.png', rarity = 'Rare',
        hiringBonus = 3080, weeklySalary = 633,
        baseProductivity = 27, baseFocus = 1.0,
        description = 'Provides one random "gadget" (a temporary, single-sprint bonus) at the start of each Sprint.',
        special = { type = 'provides_gadget' },
        listeners = {
            onSprintStart = {
                {
                    phase = 'BaseApplication',
                    priority = 50,
                    callback = function(self, gameState, eventArgs)
                        if #require("data").ALL_GADGETS > 0 then
                            local gadget = require("data").ALL_GADGETS[love.math.random(#require("data").ALL_GADGETS)]
                            
                            if gadget and gadget.listeners and gadget.listeners.onUse then
                                require("effects_dispatcher").dispatchEvent("onUse", gameState, services, { gadget = gadget })
                            else
                                print("Warning: Gadget '" .. (gadget.name or "unknown") .. "' has no onUse listener.")
                            end
                        end
                    end
                }
            }
        }
    },
    {
    id = 'camera_man1', name = 'Camera Man', icon = 'assets/portraits/prt0020.png', rarity = 'Rare',
    hiringBonus = 3850, weeklySalary = 115,
    baseProductivity = 25, baseFocus = 1.3,
    description = 'Buffs a random employee with +15 Prod per level each Sprint, but also secretly adds 5% to ALL salaries.',
    special = { type = 'secret_effects', salary_increase = 1.05, prod_boost = 15, scales_with_level = true },
    listeners = {
        onSprintStart = {
            {
                phase = 'BaseApplication',
                priority = 50,
                callback = function(self, gameState, eventArgs)
                    local potentialTargets = {}
                    for _, emp in ipairs(gameState.hiredEmployees) do
                        if emp.instanceId ~= self.instanceId then
                            table.insert(potentialTargets, emp)
                        end
                    end
                    if #potentialTargets > 0 then
                        local target = potentialTargets[love.math.random(#potentialTargets)]
                        target.isSecretlyBuffed = true
                        local boost = self.special.prod_boost
                        if self.special.scales_with_level then boost = boost * (self.level or 1) end
                        target.baseProductivity = target.baseProductivity + boost
                        print("CSM secretly buffed " .. target.fullName)
                    end
                end
            }
        },
        onCalculateSalaries = {
            {
                phase = 'BaseApplication',
                priority = 50,
                callback = function(self, gameState, eventArgs)
                    local multiplier = self.special.salary_increase or 1.05
                    eventArgs.cumulativePercentReduction = eventArgs.cumulativePercentReduction * multiplier
                    print("Salaries secretly increased by CSM...")
                end
            }
        }
    }
    },
    {
        id = 'pen_tester1', name = 'Penetration Tester', icon = 'assets/portraits/prt0021.png', rarity = 'Rare',
        hiringBonus = 2750, weeklySalary = 633,
        baseProductivity = 26, baseFocus = 1.2,
        description = 'Once per sprint, upon completing a work item, they test the firewalls. 50% chance to gain $2000, 50% chance to lose $1000 and disable the shop for the next item.',
        special = { type = 'firewall_test_on_win', success_chance = 0.5, success_gain = 2000, failure_loss = 1000 },
        listeners = {
            onWorkItemComplete = {
                {
                    phase = 'PostCalculation',
                    priority = 50,
                    callback = function(self, gameState, eventArgs)
                        if gameState.temporaryEffectFlags.penTesterUsedInSprint ~= gameState.currentSprintIndex then
                            if love.math.random() < self.special.success_chance then
                                if not gameState.ventureCapitalActive then
                                    gameState.budget = gameState.budget + self.special.success_gain
                                end
                                services.modal:show(
                                "Coffee Break!",
                                self.fullName .. " served coffee, boosting the productivity of: " .. table.concat(boostedNames, ", ")
                                )
                            else
                                gameState.budget = gameState.budget - self.special.failure_loss
                                gameState.temporaryEffectFlags.shopDisabledNextWorkItem = true
                                services.modal:show(
                                "Firewall Alert!",
                                self.fullName .. " tripped an alarm, losing $" .. self.special.failure_loss .. "! The shop is locked down for the next work item."
                                )
                            end
                            gameState.temporaryEffectFlags.penTesterUsedInSprint = gameState.currentSprintIndex
                        end
                    end
                }
            }
        }
    },
    {
        id = "time_traveler",
        name = "Time Traveler",
        description = "Reveals upcoming work item modifiers and boss fight details. Can see the challenges that lie ahead.",
        icon = "assets/portraits/time_traveler.png",
        rarity = "Legendary",
        baseProductivity = 30,
        baseFocus = 1.7,
        hiringBonus = 2500,
        weeklySalary = 400,
        special = {
            type = 'reveals_modifier',
            description = "Shows upcoming modifiers for this sprint and next sprint's boss"
        },
        listeners = {
            onDrawIntelPanel = {
                {
                    phase = 'BaseApplication',
                    priority = 50,
                    callback = function(self, gameState, services, eventArgs)
                        local ModifierManager = require("modifier_manager")
                        local currentY = eventArgs.currentY
                        
                        -- Show current sprint's remaining modifiers
                        love.graphics.setColor(0.2, 0.6, 0.8, 1)
                        love.graphics.setFont(services.fontSmall)
                        love.graphics.print("Time Traveler Intel:", eventArgs.x, currentY)
                        currentY = currentY + services.fontSmall:getHeight() + 5
                        
                        love.graphics.setColor(services.colors.text)
                        
                        -- Show remaining work items in current sprint
                        local sprint = GameData.ALL_SPRINTS[gameState.currentSprintIndex]
                        if sprint then
                            for i = gameState.currentWorkItemIndex + 1, #sprint.workItems do
                                local workItem = ModifierManager:getWorkItemWithModifier(gameState, gameState.currentSprintIndex, i)
                                if workItem then
                                    local itemText = "Item " .. i .. ": " .. workItem.name
                                    if workItem.modifier then
                                        itemText = itemText .. " [" .. workItem.modifier.name .. "]"
                                        love.graphics.setColor(0.9, 0.4, 0.4, 1)
                                    else
                                        itemText = itemText .. " [No Modifier]"
                                        love.graphics.setColor(0.4, 0.8, 0.4, 1)
                                    end
                                    
                                    currentY = currentY + Drawing.drawTextWrapped(itemText, eventArgs.x, currentY, eventArgs.width, services.fontSmall, "left") + 2
                                    love.graphics.setColor(services.colors.text)
                                end
                            end
                        end
                        
                        -- Show next sprint's boss if available
                        if gameState.currentSprintIndex < #GameData.ALL_SPRINTS then
                            local nextSprint = GameData.ALL_SPRINTS[gameState.currentSprintIndex + 1]
                            if nextSprint and nextSprint.workItems[3] then
                                currentY = currentY + 5
                                love.graphics.setColor(0.8, 0.2, 0.6, 1)
                                love.graphics.print("Next Sprint Boss:", eventArgs.x, currentY)
                                currentY = currentY + services.fontSmall:getHeight() + 2
                                
                                local bossItem = ModifierManager:getWorkItemWithModifier(gameState, gameState.currentSprintIndex + 1, 3)
                                if bossItem then
                                    local bossText = bossItem.name
                                    if bossItem.modifier then
                                        bossText = bossText .. " [" .. bossItem.modifier.name .. "]"
                                    end
                                    love.graphics.setColor(services.colors.text)
                                    currentY = currentY + Drawing.drawTextWrapped(bossText, eventArgs.x, currentY, eventArgs.width, services.fontSmall, "left")
                                end
                            end
                        end
                        
                        eventArgs.currentY = currentY
                    end
                }
            }
        }
    },
    {
        id = 'shadow_worker', name = 'Shadow Worker', icon = 'assets/portraits/prt0022.png', rarity = 'Legendary',
        hiringBonus = 5000, weeklySalary = 0,
        baseProductivity = 50, baseFocus = 2.5,
        description = "Insane stats. Instead of a salary, lose 10% of your current budget after each work item. Cannot be placed in the top row.",
        special = { type = 'vampire_budget_drain', drain_percent = 0.1, placement_restriction = 'not_top_row' },
        listeners = {
            onCalculateSalaries = {
                {
                    phase = 'BaseApplication',
                    priority = 50,
                    callback = function(self, gameState, services, eventArgs)
                        eventArgs.excludeEmployee = eventArgs.excludeEmployee or {}
                        eventArgs.excludeEmployee[self.instanceId] = true
                    end
                }
            },
            onWorkItemComplete = {
                {
                    phase = 'PostCalculation',
                    priority = 50,
                    callback = function(self, gameState, services, eventArgs)
                        if self.special and self.special.type == 'vampire_budget_drain' then
                            local drain = math.floor(gameState.budget * self.special.drain_percent)
                            eventArgs.vampireDrain = (eventArgs.vampireDrain or 0) + drain
                        end
                    end
                }
            },
            onValidatePlacement = {
                {
                    phase = 'BaseApplication',
                    priority = 50,
                    callback = function(self, gameState, services, eventArgs)
                        if eventArgs.employee.id == self.id then
                            local deskIndex = tonumber(string.match(eventArgs.targetDeskId, "desk%-(%d+)"))
                            if deskIndex and math.floor(deskIndex / require("data").GRID_WIDTH) == 0 then
                                eventArgs.isValid = false
                                eventArgs.message = self.name .. " is sensitive to sunlight and cannot be placed in the top row."
                            end
                        end
                    end
                }
            }
        }
    },
    -- {
    --     id = 'milton1', name = 'Milton, Stapler Guy', icon = 'assets/portraits/prt0023.png', rarity = 'Legendary',
    --     hiringBonus = 1000, weeklySalary = 150,
    --     baseProductivity = 15, baseFocus = 1.0,
    --     description = "If placed in a bottom-row corner, focus becomes 5.0x. If you try to move him, there's a 50% chance he burns the office down (Game Over).",
    --     special = { type = 'stapler_guy_placement', corner_focus_multiplier = 5.0, move_risk_chance = 0.5 },
    --     listeners = {
    --         onCalculateStats = {
    --             {
    --                 phase = 'BaseApplication',
    --                 priority = 50,
    --                 callback = function(self, gameState, services, eventArgs)
    --                     if eventArgs.employee.instanceId == self.instanceId and eventArgs.employee.deskId then
    --                         local deskIndex = tonumber(string.match(eventArgs.employee.deskId, "desk%-(%d+)"))
    --                         if deskIndex and (deskIndex == 6 or deskIndex == 8) then
    --                             eventArgs.stats.focus = self.special.corner_focus_multiplier
    --                             eventArgs.stats.log.focus = {string.format("Fixed to %.1fx in corner", self.special.corner_focus_multiplier)}
    --                         end
    --                     end
    --                 end
    --             }
    --         }
    --     }
    -- },
    {
        id = 'shape_shifter1', name = 'Shape Shifter', icon = 'assets/portraits/prt0024.png', rarity = 'Legendary',
        hiringBonus = 4000, weeklySalary = 200,
        baseProductivity = 1, baseFocus = 1.0,
        description = 'Appears as a water cooler. At the start of each Sprint, copies the name, icon, stats, and abilities of a random adjacent employee for that Sprint.',
        special = { type = 'mimic' },
        listeners = {
            onSprintStart = {
                {
                    phase = 'BaseApplication',
                    priority = 50,
                    callback = function(self, gameState, eventArgs)
                        -- Reset copied state at start of each sprint
                        self.copiedState = nil

                        local adjacentEmployees = {}
                        local directions = {"up", "down", "left", "right"}
                        for _, dir in ipairs(directions) do
                            local neighborDeskId = require("employee"):getNeighboringDeskId(self.deskId, dir, require("data").GRID_WIDTH, require("data").TOTAL_DESK_SLOTS, gameState.desks)
                            if neighborDeskId and gameState.deskAssignments[neighborDeskId] then
                                local neighbor = require("employee"):getFromState(gameState, gameState.deskAssignments[neighborDeskId])
                                if neighbor then table.insert(adjacentEmployees, neighbor) end
                            end
                        end
                        
                        if #adjacentEmployees > 0 then
                            local target = adjacentEmployees[love.math.random(#adjacentEmployees)]
                            self.copiedState = {
                                name = target.name,
                                icon = target.icon,
                                description = target.description,
                                baseProductivity = target.baseProductivity,
                                baseFocus = target.baseFocus,
                                positionalEffects = target.positionalEffects,
                                special = target.special
                            }
                            print("The Mimic has copied " .. target.name .. " for this sprint")
                        else
                            print("The Mimic was placed with no adjacent employees to copy.")
                        end
                    end
                }
            },
            onGetEffectiveCardData = {
                {
                    phase = 'BaseApplication',
                    priority = 50,
                    callback = function(self, gameState, eventArgs)
                        if eventArgs.employee.instanceId == self.instanceId and self.copiedState then
                            local effectiveData = {}
                            for k, v in pairs(eventArgs.employee) do effectiveData[k] = v end
                            for k, v in pairs(self.copiedState) do effectiveData[k] = v end
                            eventArgs.effectiveData = effectiveData
                        end
                    end
                }
            },
            onGetEffectiveEmployee = {
                {
                    phase = 'BaseApplication',
                    priority = 50,
                    callback = function(self, gameState, services, eventArgs)
                        if eventArgs.employee.instanceId == self.instanceId and self.copiedState then
                            local effectiveInstance = {}
                            for k, v in pairs(self) do effectiveInstance[k] = v end
                            for k, v in pairs(self.copiedState) do effectiveInstance[k] = v end
                            eventArgs.employee = effectiveInstance
                        end
                    end
                }
            }
        }
    },
    -- {
    --     id = 'office_cat1', name = 'Office Cat', icon = 'assets/portraits/prt0025.png', rarity = 'Legendary',
    --     hiringBonus = 3000, weeklySalary = 100,
    --     baseProductivity = 0, baseFocus = 1.0,
    --     description = 'Does not work. Each turn, has a 50% chance to "pounce" on a random employee, granting them +10 Productivity per level for that turn.',
    --     special = { type = 'office_cat_pounce', chance = 0.5, prod_boost = 10, does_not_work = true, scales_with_level = true },
    --     listeners = {
    --         onEmployeeContextCheck = {
    --             {
    --                 phase = 'BaseApplication',
    --                 priority = 50,
    --                 callback = function(self, gameState, eventArgs)
    --                     if eventArgs.employee.instanceId == self.instanceId then
    --                         eventArgs.context = "worker_training"
    --                     end
    --                 end
    --             }
    --         },
    --         onTurnStart = {
    --             {
    --                 phase = 'BaseApplication',
    --                 priority = 50,
    --                 callback = function(self, gameState, eventArgs)
    --                     if love.math.random() < self.special.chance then
    --                         local potentialTargets = {}
    --                         for _, emp in ipairs(gameState.hiredEmployees) do
    --                             if emp.instanceId ~= self.instanceId then table.insert(potentialTargets, emp) end
    --                         end
                            
    --                         if #potentialTargets > 0 then
    --                             local targetIndex = love.math.random(#potentialTargets)
    --                             local targetEmp = potentialTargets[targetIndex]
    --                             local boost = self.special.prod_boost
    --                             if self.special.scales_with_level then boost = boost * (self.level or 1) end
    --                             targetEmp.baseProductivity = targetEmp.baseProductivity + boost
    --                             print(self.fullName .. " pounced on " .. targetEmp.fullName .. ", boosting their productivity by " .. boost)
    --                         end
    --                     end
    --                 end
    --             }
    --         }
    --     }
    -- },
    {
        id = 'golem1', name = 'Paperwork Golem', icon = 'assets/portraits/prt0026.png', rarity = 'Legendary',
        hiringBonus = 1000, weeklySalary = 0,
        baseProductivity = 100, baseFocus = 0.5,
        description = 'Insane base productivity, but very unfocused. Has no salary, but permanently loses 10 base productivity after each work item it contributes to.',
        special = { type = 'degrading_productivity', degradation_amount = 10 },
        listeners = {
            onCalculateSalaries = {
                {
                    phase = 'BaseApplication',
                    priority = 50,
                    callback = function(self, gameState, eventArgs)
                        eventArgs.excludeEmployee = eventArgs.excludeEmployee or {}
                        eventArgs.excludeEmployee[self.instanceId] = true
                    end
                }
            },
            onWorkItemComplete = {
                {
                    phase = 'PostCalculation',
                    priority = 50,
                    callback = function(self, gameState, eventArgs)
                        if self.contributionThisItem and self.contributionThisItem > 0 then
                            local oldProd = self.baseProductivity
                            self.baseProductivity = math.max(0, self.baseProductivity - (self.special.degradation_amount or 10))
                            print(self.fullName .. " has degraded from " .. oldProd .. " to " .. self.baseProductivity)
                        end
                    end
                }
            }
        }
    },
    {
        id = 'ai_overlord1', name = 'The AI Overlord', icon = 'assets/portraits/prt0027.png', rarity = 'Legendary',
        hiringBonus = 6000, weeklySalary = 1000,
        baseProductivity = 35, baseFocus = 1.3,
        description = 'Must be a Remote worker. Doubles the Productivity and Focus of all other remote workers. All upgrades cost 10% more per level.',
        special = { type = 'boost_other_remotes', prod_mult = 2.0, focus_mult = 2.0, upgrade_cost_increase = 1.1, scales_with_level = true },
        forceVariant = 'remote',
        listeners = {
            onCalculateStats = {
                {
                    phase = 'BaseApplication',
                    priority = 50,
                    callback = function(self, gameState, services, eventArgs)
                        if eventArgs.employee.variant == 'remote' and eventArgs.employee.instanceId ~= self.instanceId then
                            eventArgs.stats.productivity = eventArgs.stats.productivity * self.special.prod_mult
                            eventArgs.stats.focus = eventArgs.stats.focus * self.special.focus_mult
                            table.insert(eventArgs.stats.log.productivity, string.format("*%.1fx from AI Overlord", self.special.prod_mult))
                            table.insert(eventArgs.stats.log.focus, string.format("*%.1fx from AI Overlord", self.special.focus_mult))
                        end
                    end
                }
            },
            onCalculateUpgradeCost = {
                {
                    phase = 'BaseApplication',
                    priority = 50,
                    callback = function(self, gameState, eventArgs)
                        local costMultiplier = self.special.upgrade_cost_increase
                        if self.special.scales_with_level then
                            costMultiplier = 1 + ((costMultiplier - 1) * (self.level or 1))
                        end
                        eventArgs.cost = eventArgs.cost * costMultiplier
                    end
                }
            }
        }
    },
    {
        id = 'office_aesthetic1', name = 'Office Aesthetic', icon = 'assets/portraits/prt0028.png', rarity = 'Legendary',
        hiringBonus = 4500, weeklySalary = 500,
        baseProductivity = 22, baseFocus = 1.4,
        description = 'Each turn, has a 75% chance to inspire a random employee, granting them 3x their normal stats per level for that turn.',
        special = { type = 'inspire_teammate', multiplier = 3, chance = 0.75, scales_with_level = true },
        listeners = {
            onTurnStart = {
                {
                    phase = 'PreCalculation',
                    priority = 50,
                    callback = function(self, gameState, eventArgs)
                        if love.math.random() < self.special.chance then
                            local potentialTargets = {}
                            for _, emp in ipairs(gameState.hiredEmployees) do 
                                if emp.instanceId ~= self.instanceId then 
                                    table.insert(potentialTargets, emp) 
                                end 
                            end
                            if #potentialTargets > 0 then
                                local target = potentialTargets[love.math.random(#potentialTargets)]
                                target.isInspired = true
                                print(self.name .. " has inspired " .. target.name .. "!")
                            end
                        end
                    end
                }
            },
            onBeforeContribution = {
                {
                    phase = 'PreCalculation',
                    priority = 50,
                    callback = function(self, gameState, eventArgs)
                        if eventArgs.employee.isInspired then
                            local museMultiplier = self.special.multiplier or 3
                            if self.special.scales_with_level then 
                                museMultiplier = 1 + ((museMultiplier - 1) * (self.level or 1)) 
                            end
                            eventArgs.contributionMultiplier = eventArgs.contributionMultiplier * museMultiplier
                            eventArgs.employee.isInspired = nil
                            print(eventArgs.employee.name .. " feels inspired! Contribution multiplied by " .. museMultiplier)
                        end
                    end
                }
            }
        }
    },
    {
        id = 'code_anomaly1', name = 'Code Anomaly', icon = 'assets/portraits/prt0029.png', rarity = 'Legendary',
        hiringBonus = 7500, weeklySalary = 600,
        baseProductivity = 32, baseFocus = 1.3,
        description = 'Has a 3% chance each turn to instantly complete the current Work Item.',
        special = { type = 'glitch_in_the_matrix', chance = 0.03 },
        listeners = {
            onBeforeContribution = {
                {
                    phase = 'PreCalculation',
                    priority = 50,
                    callback = function(self, gameState, eventArgs)
                        if love.math.random() < self.special.chance then
                            print("A GLITCH IN THE MATRIX! Work item instantly completed!")
                            eventArgs.wasInstaWin = true
                        end
                    end
                }
            }
        }
    },
    {
        id = 'game_dev1', name = 'Game Developer', icon = 'assets/portraits/prt0030.png', rarity = 'Legendary',
        hiringBonus = 5000, weeklySalary = 800,
        baseProductivity = 60, baseFocus = 1.0,
        description = 'Productivity equal to the game\'s current frames-per-second.',
        special = { type = 'developer_fps_prod' },
        listeners = {
            onCalculateStats = {
                {
                    phase = 'BaseApplication',
                    priority = 10, -- High priority to run early
                    callback = function(self, gameState, services, eventArgs)
                        if eventArgs.employee.instanceId == self.instanceId then
                            eventArgs.stats.productivity = love.timer.getFPS()
                            eventArgs.stats.log.productivity = {"Base: " .. eventArgs.stats.productivity .. " (from FPS)"}
                        end
                    end
                }
            }
        }
    },
    {
        id = 'merger1', name = 'Merger', icon = 'assets/portraits/prt0031.png', rarity = 'Legendary',
        hiringBonus = 6000, weeklySalary = 250,
        baseProductivity = 5, baseFocus = 1.0,
        description = 'Drag from the shop onto another employee to merge. The Merger is consumed, but the target\'s base stats are doubled and they become Legendary. This effect stacks.',
        special = { type = 'slime_merge' },
        listeners = {
            onPlacement = {
                {
                    phase = 'BaseApplication',
                    priority = 50,
                    callback = function(self, gameState, services, eventArgs)
                        if eventArgs.employee.instanceId == self.instanceId and eventArgs.fromShop then
                            local occupantId = gameState.deskAssignments[eventArgs.targetDeskId]
                            if occupantId then
                                local targetEmployee = require("employee"):getFromState(gameState, occupantId)
                                if targetEmployee then
                                    targetEmployee.baseProductivity = targetEmployee.baseProductivity * 2
                                    targetEmployee.baseFocus = targetEmployee.baseFocus * 2
                                    targetEmployee.rarity = "Legendary"
                                    targetEmployee.slime_stacks = (targetEmployee.slime_stacks or 0) + 1
                                    print(targetEmployee.name .. " has merged with the slime!")
                                    eventArgs.wasHandled = true
                                    eventArgs.success = true
                                    return
                                end
                            end
                            eventArgs.wasHandled = true
                            eventArgs.success = false
                            eventArgs.message = "This must be dropped onto an existing office worker's desk."
                        end
                    end
                }
            }
        }
    },
    {
        id = 'Story Teller', name = 'Story Teller', icon = 'assets/portraits/prt0032.png', rarity = 'Legendary',
        hiringBonus = 3000, weeklySalary = 400,
        baseProductivity = 33, baseFocus = 1.0,
        description = 'During each work item, gives escalating Focus boosts: +0.1x per level to 1st employee, +0.2x per level to 2nd, etc. Resets after each work item.',
        special = { type = 'narrator_escalating_boost', focus_base = 0.1, scales_with_level = true },
        listeners = {
            onWorkItemStart = {
                {
                    phase = 'PreCalculation',
                    priority = 50,
                    callback = function(self, gameState, eventArgs)
                        gameState.narratorTurnCounter = 0
                    end
                }
            },
            onTurnStart = {
                {
                    phase = 'PreCalculation',
                    priority = 50,
                    callback = function(self, gameState, eventArgs)
                        if eventArgs.currentEmployee then
                            gameState.narratorTurnCounter = (gameState.narratorTurnCounter or 0) + 1
                            eventArgs.currentEmployee.narratorBoostActive = true
                            eventArgs.currentEmployee.narratorTurnNumber = gameState.narratorTurnCounter
                            print("The Narrator encourages " .. eventArgs.currentEmployee.fullName .. " (turn #" .. gameState.narratorTurnCounter .. ")...")
                        end
                    end
                }
            },
            onBeforeContribution = {
                {
                    phase = 'PreCalculation',
                    priority = 50,
                    callback = function(self, gameState, eventArgs)
                        if eventArgs.employee.narratorBoostActive then
                            local baseFocusBonus = self.special.focus_base or 0.1
                            local turnMultiplier = eventArgs.employee.narratorTurnNumber or 1
                            local levelMultiplier = self.special.scales_with_level and (self.level or 1) or 1
                            local focusBonus = baseFocusBonus * turnMultiplier * levelMultiplier
                            
                            eventArgs.focusMultiplier = eventArgs.focusMultiplier * (1 + focusBonus)
                            eventArgs.employee.narratorBoostActive = nil
                            eventArgs.employee.narratorTurnNumber = nil
                        end
                    end
                }
            }
        }
    },
    {
        id = 'tps1', name = 'TPS', icon = 'assets/portraits/prt0033.png', rarity = 'Legendary',
        hiringBonus = 4000, weeklySalary = 750,
        baseProductivity = 36, baseFocus = 1.0,
        description = 'Adjacent employees get -0.5x Focus per level. Forces each to work 1 extra time per round for each of his levels. Yeah... that\'d be great.',
        remoteDescription = 'Forces two random remote employees to work 1 extra time per round for each of his levels. Yeah... that\'d be great.',
        positionalEffects = { all_adjacent = { focus_mult = 0.5, scales_with_level = true } },
        special = { type = 'forces_double_work' },
        listeners = {
            onBattleStart = {
                {
                    phase = 'PreCalculation',
                    priority = 50,
                    callback = function(self, gameState, services, eventArgs)
                        local victims = {}
                        if self.deskId then
                            local directions = {"up", "down", "left", "right"}
                            for _, dir in ipairs(directions) do 
                                local neighborDeskId = require("placement"):getNeighboringDeskId(self.deskId, dir, require("data").GRID_WIDTH, require("data").TOTAL_DESK_SLOTS, gameState.desks)
                                if neighborDeskId and gameState.deskAssignments[neighborDeskId] then 
                                    local neighbor = require("employee"):getFromState(gameState, gameState.deskAssignments[neighborDeskId])
                                    if neighbor then 
                                        table.insert(victims, neighbor) 
                                    end 
                                end 
                            end
                            for _, victim in ipairs(victims) do 
                                for i = 1, (self.level or 1) do 
                                    table.insert(eventArgs.activeEmployees, victim) 
                                end 
                            end
                        elseif self.variant == 'remote' then
                            local potentialVictims = {}
                            for _, e in ipairs(eventArgs.remoteWorkers) do 
                                if e.instanceId ~= self.instanceId then 
                                    table.insert(potentialVictims, e) 
                                end 
                            end
                            for i = 1, 2 do 
                                if #potentialVictims > 0 then 
                                    local victim = table.remove(potentialVictims, love.math.random(#potentialVictims))
                                    for j = 1, (self.level or 1) do 
                                        table.insert(eventArgs.activeEmployees, victim) 
                                    end 
                                end 
                            end
                        end
                    end
                }
            }
        }
    },
    {
        id = 'libertarian1', name = 'Libertarian', icon = 'assets/portraits/prt0034.png', rarity = 'Legendary',
        hiringBonus = 3500, weeklySalary = 500,
        baseProductivity = 31, baseFocus = 1.0,
        description = 'Refuses to work if budget is over $50k. If budget is under $5k, his productivity is x10. Ignores all positional bonuses.',
        special = { type = 'ron_swanson_behavior', upper_budget_threshold = 50000, lower_budget_threshold = 5000, prod_mult = 10, ignores_positional_bonuses = true },
        listeners = {
            onEmployeeAvailabilityCheck = {
                {
                    phase = 'PreCalculation',
                    priority = 50,
                    callback = function(self, gameState, eventArgs)
                        if eventArgs.employee.instanceId == self.instanceId then
                            if gameState.budget > self.special.upper_budget_threshold then
                                eventArgs.isDisabled = true
                                eventArgs.reason = self.name .. " refuses to work; the government has too much money."
                            end
                        end
                    end
                }
            },
            onCalculateStats = {
                {
                    phase = 'BaseApplication',
                    priority = 50,
                    callback = function(self, gameState, services, eventArgs)
                        if eventArgs.employee.instanceId == self.instanceId then
                            if gameState.budget < self.special.lower_budget_threshold then
                                eventArgs.stats.productivity = eventArgs.stats.productivity * self.special.prod_mult
                                table.insert(eventArgs.stats.log.productivity, string.format("*%dx from low government budget", self.special.prod_mult))
                            end
                        end
                    end
                }
            }
        }
    },
    {
        id = 'copypasta', name = 'Copypasta', icon = 'assets/portraits/prt0035.png', rarity = 'Legendary',
        hiringBonus = 6000, weeklySalary = 300,
        baseProductivity = 35, baseFocus = 1.2,
        description = 'Grants +5 Productivity per level to adjacent employees. When hired, turns two other random employees into copies for the rest of the Sprint.',
        special = { type = 'virus_on_hire' },
        positionalEffects = { all_adjacent = { productivity_add = 5, scales_with_level = true } },
        listeners = {
            onHire = {
                {
                    phase = 'BaseApplication',
                    priority = 50,
                    callback = function(self, gameState, services, eventArgs)
                        if eventArgs.employee.instanceId == self.instanceId then
                            local potentialTargets = {}
                            for _, emp in ipairs(gameState.hiredEmployees) do 
                                if emp.instanceId ~= self.instanceId and emp.rarity ~= 'Legendary' and not emp.isCopyPastaCopy then 
                                    table.insert(potentialTargets, emp) 
                                end 
                            end
                            
                            local copypastaData = nil
                            for _, card in ipairs(require("data").BASE_EMPLOYEE_CARDS) do 
                                if card.id == 'copypasta' then 
                                    copypastaData = card
                                    break 
                                end 
                            end

                            for i=1, 2 do
                                if #potentialTargets > 0 and copypastaData then
                                    local targetIndex = love.math.random(#potentialTargets)
                                    local victim = potentialTargets[targetIndex]
                                    victim.isCopyPastaCopy = true
                                    victim.copypastaOriginalData = {
                                        name = victim.name,
                                        description = victim.description,
                                        baseProductivity = victim.baseProductivity,
                                        baseFocus = victim.baseFocus,
                                        positionalEffects = victim.positionalEffects
                                    }
                                    victim.weeklySalary = copypastaData.weeklySalary
                                    print(victim.name .. " has been assimilated by Copypasta.")
                                    table.remove(potentialTargets, targetIndex)
                                end
                            end
                        end
                    end
                }
            },
            onGetEffectiveCardData = {
                {
                    phase = 'BaseApplication',
                    priority = 50,
                    callback = function(self, gameState, services, eventArgs)
                        if eventArgs.employee and eventArgs.employee.isCopyPastaCopy then
                            local copypastaData = nil
                            for _, card in ipairs(require("data").BASE_EMPLOYEE_CARDS) do 
                                if card.id == 'copypasta' then 
                                    copypastaData = card
                                    break 
                                end 
                            end
                            
                            if copypastaData then
                                local effectiveData = {}
                                for k, v in pairs(eventArgs.employee) do effectiveData[k] = v end
                                for k, v in pairs(copypastaData) do
                                    if k ~= 'id' and k ~= 'instanceId' and k ~= 'fullName' and k ~= 'level' then
                                        effectiveData[k] = v
                                    end
                                end
                                effectiveData.weeklySalary = copypastaData.weeklySalary
                                eventArgs.effectiveData = effectiveData
                            end
                        end
                    end
                }
            },
            onGetEffectiveEmployee = {
                {
                    phase = 'BaseApplication',
                    priority = 50,
                    callback = function(self, gameState, services, eventArgs)
                        if eventArgs.employee and eventArgs.employee.isCopyPastaCopy then
                            local copypastaData = nil
                            for _, card in ipairs(require("data").BASE_EMPLOYEE_CARDS) do 
                                if card.id == 'copypasta' then 
                                    copypastaData = card
                                    break 
                                end 
                            end
                            
                            if copypastaData then
                                local effectiveInstance = {}
                                for k, v in pairs(eventArgs.employee) do effectiveInstance[k] = v end
                                for k, v in pairs(copypastaData) do
                                    if k ~= 'id' and k ~= 'instanceId' and k ~= 'fullName' then
                                        effectiveInstance[k] = v
                                    end
                                end
                                eventArgs.employee = effectiveInstance
                            end
                        end
                    end
                }
            }
        }
    },
    {
        id = 'glados1', name = 'GLaDOS', icon = 'assets/portraits/prt0036.png', rarity = 'Legendary',
        hiringBonus = 5000, weeklySalary = 0,
        baseProductivity = 0, baseFocus = 1.0,
        description = 'Provides a +50% productivity boost to ALL employees. At the end of each work item, she will "test" you by forcing you to choose one of two negative modifiers for the next item.',
        special = { type = 'ai_test_on_win', prod_boost_all = 1.5, does_not_work = true },
        listeners = {
            onCalculateStats = {
                {
                    phase = 'BaseApplication',
                    priority = 60, -- A bit later than employee-specific
                    callback = function(self, gameState, services, eventArgs)
                        eventArgs.stats.productivity = eventArgs.stats.productivity * self.special.prod_boost_all
                        table.insert(eventArgs.stats.log.productivity, string.format("*%.1fx from GLaDOS", self.special.prod_boost_all))
                    end
                }
            },
            onWorkItemComplete = {
                {
                    phase = 'PostCalculation',
                    priority = 50,
                    callback = function(self, gameState, services, eventArgs)
                        local modifiers = require("data").GLADOS_NEGATIVE_MODIFIERS
                        if #modifiers >= 2 then
                            local mod1 = modifiers[love.math.random(#modifiers)]
                            local mod2 = modifiers[love.math.random(#modifiers)]
                            while mod2 == mod1 do
                                mod2 = modifiers[love.math.random(#modifiers)]
                            end
                            
                            -- Default to mod1, let user change it
                            gameState.temporaryEffectFlags.gladosModifierForNextItem = mod1
                            
                            services.modal:show(
                            "GLaDOS Test Chamber",
                            "GLaDOS has prepared a test for you. Choose your 'reward':\n\nOption A: " .. mod1.description .. "\n\nOption B: " .. mod2.description,
                            {
                                {text = "Option A", onClick = function()
                                    gameState.temporaryEffectFlags.gladosModifierForNextItem = mod1
                                    services.modal:hide()
                                end},
                                {text = "Option B", onClick = function()
                                    gameState.temporaryEffectFlags.gladosModifierForNextItem = mod2
                                    services.modal:hide()
                                end}
                            }
                            )
                        end
                    end
                }
            }
        }
    },
    {
        id = 'borg_drone', name = 'Borg Drone', icon = 'assets/portraits/prt0037.png', rarity = 'Legendary',
        hiringBonus = 0, weeklySalary = 0,
        baseProductivity = 0, baseFocus = 0,
        description = 'We are the Borg. Resistance is futile. Your technological and biological distinctiveness will be added to our own.',
        special = { type = 'borg_drone_special' },
        isNotPurchasable = true
    },
    {
        id = 'company_man1', name = 'Company Man', icon = 'assets/portraits/prt0038.png', rarity = 'Legendary',
        hiringBonus = 0, weeklySalary = 0,
        baseProductivity = 0, baseFocus = 1.0,
        description = 'The company itself, manifest. Its power grows with your assets. Provides massive bonuses to all adjacent employees.',
        positionalEffects = { all_adjacent = { productivity_add = 50, focus_add = 1.0 } },
        special = { type = 'corporate_personhood_special' },
        isNotPurchasable = true
    },
    -- UNCOMMON EMPLOYEES
    {
        id = 'it_intern1', name = 'IT Intern', icon = 'assets/portraits/prt0039.png', rarity = 'Uncommon',
        hiringBonus = 2040, weeklySalary = 342,
        baseProductivity = 17, baseFocus = 1.0,
        description = 'Once per work item, has a 50% chance at the end of a round to "reboot" a random coworker, tripling their contribution on their next turn.',
        special = { type = 'chance_reboot_teammate', chance = 0.5, multiplier = 3 },
        listeners = {
            onEndOfRound = {
                {
                    phase = 'PostCalculation',
                    priority = 50,
                    callback = function(self, gameState, eventArgs)
                        if not gameState.temporaryEffectFlags.itGuyUsedThisItem and love.math.random() < self.special.chance then
                            local potentialTargets = {}
                            for _, emp in ipairs(gameState.hiredEmployees) do
                                if emp.instanceId ~= self.instanceId and not emp.isRebooted and not emp.isTraining then
                                    table.insert(potentialTargets, emp)
                                end
                            end
                            if #potentialTargets > 0 then
                                local target = potentialTargets[love.math.random(#potentialTargets)]
                                target.isRebooted = true
                                gameState.temporaryEffectFlags.itGuyUsedThisItem = true
                                print(self.fullName .. " has rebooted " .. target.fullName)
                            end
                        end
                    end
                }
            },
            onBeforeContribution = {
                {
                    phase = 'PreCalculation',
                    priority = 50,
                    callback = function(self, gameState, eventArgs)
                        if eventArgs.employee.isRebooted then
                            eventArgs.contributionMultiplier = eventArgs.contributionMultiplier * 3
                            eventArgs.employee.isRebooted = nil
                        end
                    end
                }
            }
        }
    },
    {
        id = 'rounding_expert1', name = 'Rounding Expert', icon = 'assets/portraits/prt0040.png', rarity = 'Uncommon',
        hiringBonus = 1920, weeklySalary = 315,
        baseProductivity = 16, baseFocus = 1.0,
        description = 'Reduces all salaries by 5%. Total salaries paid this item are rounded to the nearest $100.',
        special = { type = 'salary_reduction_percent_team', value = 0.05, rounds_salaries = true },
        listeners = {
            onCalculateSalaries = {
                {
                    phase = 'BaseApplication',
                    priority = 50,
                    callback = function(self, gameState, eventArgs)
                        local reduction = self.special.value or 0.03
                        if self.special.scales_with_level then 
                            reduction = 1 - ((1 - reduction) ^ (self.level or 1)) 
                        end
                        eventArgs.cumulativePercentReduction = eventArgs.cumulativePercentReduction * (1 - reduction)
                    end
                }
            },
            onEndOfRound = {
                {
                    phase = 'PostCalculation',
                    priority = 50,
                    callback = function(self, gameState, eventArgs)
                        if self.special.rounds_salaries and eventArgs.totalSalaries then
                            eventArgs.totalSalaries = math.floor(eventArgs.totalSalaries / 100 + 0.5) * 100
                            print("Accountant rounded total salaries to: $" .. eventArgs.totalSalaries)
                        end
                    end
                }
            }
        }
    },
    -- {
    --     id = 'salesperson1', name = 'Salesperson', icon = 'assets/portraits/prt0041.png', rarity = 'Uncommon',
    --     hiringBonus = 1800, weeklySalary = 400,
    --     baseProductivity = 10, baseFocus = 1.0,
    --     description = 'Generates no workload progress. Instead, generates budget equal to 1.5x their Productivity score per level each cycle.',
    --     special = { type = 'budget_gen_no_workload', multiplier = 1.5, scales_with_level = true },
    --     listeners = {
    --         onBeforeContribution = {
    --             {
    --                 phase = 'PreCalculation',
    --                 priority = 50,
    --                 callback = function(self, gameState, eventArgs)
    --                     if eventArgs.employee.instanceId ~= self.instanceId then return end

    --                     local stats = require("employee"):calculateStatsWithPosition(self, gameState.hiredEmployees, gameState.deskAssignments, gameState.purchasedPermanentUpgrades, gameState.desks, gameState)
    --                     local multiplier = self.special.multiplier or 1
    --                     if self.special.scales_with_level then multiplier = multiplier * (self.level or 1) end
    --                     local budgetGain = math.floor(stats.currentProductivity * multiplier)
                        
    --                     if not gameState.ventureCapitalActive then
    --                         gameState.budget = gameState.budget + budgetGain
    --                     end
                        
    --                     print(self.fullName .. " generated $" .. budgetGain .. " instead of working on the item!")
    --                     eventArgs.shouldSkipWorkload = true
    --                     eventArgs.productivity = stats.currentProductivity
    --                     eventArgs.focus = stats.currentFocus
    --                 end
    --             }
    --         }
    --     }
    -- },
    { 
        id = 'union_rep1', name = 'Union Rep', icon = 'assets/portraits/prt0042.png', rarity = 'Uncommon',
        hiringBonus = 2400, weeklySalary = 405,
        baseProductivity = 17, baseFocus = 1.0,
        description = 'All employees gain +2 base Productivity per level. Employee salaries cannot be reduced by any means.',
        special = { type = 'global_prod_boost_flat', value = 2, prevents_salary_reduction = true, scales_with_level = true },
        listeners = {
            onCalculateStats = {
                {
                    phase = 'BaseApplication',
                    priority = 60,
                    callback = function(self, gameState, services, eventArgs)
                        local bonus = self.special.value
                        if self.special.scales_with_level then
                            bonus = bonus * (self.level or 1)
                        end
                        eventArgs.stats.productivity = eventArgs.stats.productivity + bonus
                        table.insert(eventArgs.stats.log.productivity, string.format("+%d from %s", bonus, self.name))
                    end
                }
            },
            onCalculateSalaries = {
                {
                    phase = 'BaseApplication',
                    priority = 50,
                    callback = function(self, gameState, eventArgs)
                        if self.special.prevents_salary_reduction then
                            eventArgs.cumulativePercentReduction = 1.0
                            eventArgs.totalFlatReduction = 0
                        end
                    end
                }
            }
        }
    },
    {
        id = 'marketer1', name = 'Marketing Whiz', icon = 'assets/portraits/prt0043.png', rarity = 'Uncommon',
        hiringBonus = 2400, weeklySalary = 315,
        baseProductivity = 18, baseFocus = 1.0,
        description = 'Generates +$750 Budget/win per level.',
        special = { type = 'budget_per_win', value = 750, scales_with_level = true },
        listeners = {
            onWorkItemComplete = {
                {
                    phase = 'PostCalculation',
                    priority = 50,
                    callback = function(self, gameState, services, eventArgs)
                        if not (eventArgs and eventArgs.budgetBonus) then eventArgs.budgetBonus = 0 end

                        local bonus = self.special.value or 0
                        if self.special.scales_with_level then bonus = bonus * (self.level or 1) end
                        
                        eventArgs.budgetBonus = eventArgs.budgetBonus + bonus
                    end
                }
            }
        }
    },
    {
        id = 'hr1', name = 'HR Coordinator', icon = 'assets/portraits/prt0044.png', rarity = 'Uncommon',
        hiringBonus = 2160, weeklySalary = 288,
        baseProductivity = 14, baseFocus = 1.0,
        description = 'Reduces ALL salaries by 10% per level.',
        special = { type = 'salary_reduction_percent_team', value = 0.10, scales_with_level = true },
        listeners = {
            onCalculateSalaries = {
                {
                    phase = 'BaseApplication',
                    priority = 50,
                    callback = function(self, gameState, eventArgs)
                        local reduction = self.special.value or 0.10
                        if self.special.scales_with_level then 
                            reduction = reduction * (self.level or 1)
                            reduction = math.min(reduction, 0.95)
                        end
                        eventArgs.cumulativePercentReduction = eventArgs.cumulativePercentReduction * (1 - reduction)
                    end
                }
            }
        }
    },
    {
        id = 'stack_overflow1', name = 'Stack Overflow', icon = 'assets/portraits/prt0045.png', rarity = 'Uncommon',
        hiringBonus = 3600, weeklySalary = 540,
        baseProductivity = 30, baseFocus = 1.0,
        description = 'Productive, high salary. Up: -3 Prod, -0.15x Focus.',
        positionalEffects = { up = { productivity_add = -3, focus_add = -0.15 } }
    },
    {
        id = 'project_manager', name = 'Project Manager', icon = 'assets/portraits/prt0046.png', rarity = 'Uncommon',
        hiringBonus = 3000, weeklySalary = 450,
        baseProductivity = 15, baseFocus = 1.0,
        description = '+0.3x focus per level to ALL PLACED staff.',
        special = { type = 'focus_boost_all_placed_flat', value = 0.3, scales_with_level = true },
        listeners = {
            onCalculateStats = {
                {
                    phase = 'BaseApplication',
                    priority = 50,
                    callback = function(self, gameState, services, eventArgs)
                        if eventArgs.employee.deskId and eventArgs.employee.instanceId ~= self.instanceId then
                            local bonus = self.special.value
                            if self.special.scales_with_level then
                                bonus = bonus * (self.level or 1)
                            end
                            eventArgs.stats.focus = eventArgs.stats.focus + bonus
                            table.insert(eventArgs.stats.log.focus, string.format("+%.2fx from Project Manager", bonus))
                        end
                    end
                }
            }
        }
    },
    {
        id = 'office_introver1', name = 'Office Introvert', icon = 'assets/portraits/prt0047.png', rarity = 'Uncommon',
        hiringBonus = 2640, weeklySalary = 405,
        baseProductivity = 20, baseFocus = 1.0,
        description = 'Highly focused when alone. +0.5x Focus per level for each empty adjacent desk.',
        special = { type = 'focus_per_empty_adjacent_desk', value_per_desk = 0.5, scales_with_level = true },
        listeners = {
            onCalculateStats = {
                {
                    phase = 'BaseApplication',
                    priority = 50,
                    callback = function(self, gameState, services, eventArgs)
                        if eventArgs.employee.instanceId == self.instanceId and eventArgs.employee.deskId then
                            local emptyAdjacentCount = 0
                            local directions = {"up", "down", "left", "right"}
                            for _, dir in ipairs(directions) do
                                local neighborDeskId = require("placement"):getNeighboringDeskId(eventArgs.employee.deskId, dir, require("data").GRID_WIDTH, require("data").TOTAL_DESK_SLOTS, gameState.desks)
                                if not neighborDeskId or not gameState.deskAssignments[neighborDeskId] then
                                    emptyAdjacentCount = emptyAdjacentCount + 1
                                end
                            end
                            
                            if emptyAdjacentCount > 0 then
                                local bonusPerDesk = self.special.value_per_desk
                                if self.special.scales_with_level then
                                    bonusPerDesk = bonusPerDesk * (self.level or 1)
                                end
                                local totalBonus = emptyAdjacentCount * bonusPerDesk
                                eventArgs.stats.focus = eventArgs.stats.focus + totalBonus
                                table.insert(eventArgs.stats.log.focus, string.format("+%.2fx from %d empty spaces", totalBonus, emptyAdjacentCount))
                            end
                        end
                    end
                }
            }
        }
    },
    {
        id = 'synergist', name = 'Synergist', icon = 'assets/portraits/prt0048.png', rarity = 'Uncommon',
        hiringBonus = 2160, weeklySalary = 360,
        baseProductivity = 18, baseFocus = 1.0,
        description = 'Boosts adjacent non-Synergists (+4P, +0.4x F per level).',
        positionalEffects = { all_adjacent = { focus_add = 0.4, productivity_add = 4, condition_not_id = 'synergist', scales_with_level = true } }
    },
    {
        id = 'data_analyst', name = 'Data Analyst', icon = 'assets/portraits/prt0049.png', rarity = 'Uncommon',
        hiringBonus = 2400, weeklySalary = 378,
        baseProductivity = 15, baseFocus = 1.0,
        description = 'Productivity scales with Budget (+1P per level per $1k).',
        special = { type = 'prod_scales_with_budget', per_1k_budget = 1, scales_with_level = true },
        listeners = {
            onCalculateStats = {
                {
                    phase = 'BaseApplication',
                    priority = 50,
                    callback = function(self, gameState, services, eventArgs)
                        if eventArgs.employee.instanceId == self.instanceId then
                            local budgetInThousands = math.floor(gameState.budget / 1000)
                            local multiplier = self.special.per_1k_budget or 1
                            if self.special.scales_with_level then
                                multiplier = multiplier * (self.level or 1)
                            end
                            local bonus = budgetInThousands * multiplier
                            eventArgs.stats.productivity = eventArgs.stats.productivity + bonus
                            table.insert(eventArgs.stats.log.productivity, string.format("+%d from budget scaling", bonus))
                        end
                    end
                }
            }
        }
    },
    {
        id = 'mentor', name = 'Mentor', icon = 'assets/portraits/prt0050.png', rarity = 'Uncommon',
        hiringBonus = 3120, weeklySalary = 495,
        baseProductivity = 18, baseFocus = 1.0,
        description = 'Boosts Productivity of employee directly below by +10 per level.',
        positionalEffects = { down = { productivity_add = 10, scales_with_level = true } }
    },
    {
        id = 'creative_genius', name = 'Creative Genius', icon = 'assets/portraits/prt0051.png', rarity = 'Uncommon',
        hiringBonus = 3360, weeklySalary = 522,
        baseProductivity = 16, baseFocus = 1.0, 
        description = 'Starts with 1.5x Focus. Salary increases $50 each week.',
        special = { type = 'salary_increase_weekly', amount = 50, initial_focus_multiplier = 1.5 },
        listeners = {
            onWorkItemComplete = {
                {
                    phase = 'PostCalculation',
                    priority = 50,
                    callback = function(self, gameState, eventArgs)
                        self.weeklySalary = self.weeklySalary + (self.special.amount or 50)
                    end
                }
            },
            onCalculateStats = {
                {
                    phase = 'BaseApplication',
                    priority = 20,
                    callback = function(self, gameState, services, eventArgs)
                        if eventArgs.employee.instanceId == self.instanceId then
                            eventArgs.stats.focus = eventArgs.stats.focus * self.special.initial_focus_multiplier
                            table.insert(eventArgs.stats.log.focus, string.format("*%.1fx from innate genius", self.special.initial_focus_multiplier))
                        end
                    end
                }
            }
        }
    },
    {
        id = 'workaholic', name = 'Workaholic', icon = 'assets/portraits/prt0052.png', rarity = 'Uncommon',
        hiringBonus = 2280, weeklySalary = 342,
        baseProductivity = 25, baseFocus = 1.0, 
        description = 'High Prod, but Focus is fixed at 0.8x.',
        special = { type = 'fixed_focus_multiplier', value = 0.8 },
        listeners = {
            onCalculateStats = {
                {
                    phase = 'BaseApplication',
                    priority = 10, -- High priority to run early
                    callback = function(self, gameState, services, eventArgs)
                        if eventArgs.employee.instanceId == self.instanceId then
                            eventArgs.stats.focus = self.special.value
                            eventArgs.stats.log.focus = {string.format("Fixed to %.2fx by ability", self.special.value)}
                        end
                    end
                }
            }
        }
    },
    {
        id = 'night_owl', name = 'Night Owl', icon = 'assets/portraits/prt0053.png', rarity = 'Uncommon',
        hiringBonus = 2880, weeklySalary = 432,
        baseProductivity = 18, baseFocus = 1.0,
        description = 'Higher Focus if placed in bottom row.',
        special = { type = 'focus_if_in_row', rowIndex = 2, focus_multiplier = 1.5 },
        listeners = {
            onCalculateStats = {
                {
                    phase = 'BaseApplication',
                    priority = 50,
                    callback = function(self, gameState, services, eventArgs)
                        if eventArgs.employee.instanceId == self.instanceId and eventArgs.employee.deskId then
                            local deskIndex = tonumber(string.match(eventArgs.employee.deskId, "desk%-(%d+)"))
                            if deskIndex then
                                local row = math.floor(deskIndex / require("data").GRID_WIDTH)
                                if row == self.special.rowIndex then
                                    eventArgs.stats.focus = eventArgs.stats.focus * self.special.focus_multiplier
                                    table.insert(eventArgs.stats.log.focus, string.format("*%.1fx from night owl bonus", self.special.focus_multiplier))
                                end
                            end
                        end
                    end
                }
            }
        }
    },
    {
        id = 'corner_office_exec', name = 'Corner Office Exec', icon = 'assets/portraits/prt0054.png', rarity = 'Uncommon',
        hiringBonus = 4800, weeklySalary = 720,
        baseProductivity = 18, baseFocus = 1.0,
        description = '+1 Prod per level to all employees for each owned corner desk.',
        special = { type = 'prod_boost_per_corner_desk_owned', value_per_corner = 1, scales_with_level = true },
        listeners = {
            onCalculateStats = {
                {
                    phase = 'BaseApplication',
                    priority = 60,
                    callback = function(self, gameState, services, eventArgs)
                        local cornerDeskIds = {"desk-0", "desk-2", "desk-6", "desk-8"}
                        local ownedCorners = 0
                        for _, deskId in ipairs(cornerDeskIds) do
                            for _, desk in ipairs(gameState.desks) do
                                if desk.id == deskId and desk.status == "owned" then
                                    ownedCorners = ownedCorners + 1
                                    break
                                end
                            end
                        end
                        
                        if ownedCorners > 0 then
                            local bonusPerCorner = self.special.value_per_corner
                            if self.special.scales_with_level then
                                bonusPerCorner = bonusPerCorner * (self.level or 1)
                            end
                            local totalBonus = ownedCorners * bonusPerCorner
                            eventArgs.stats.productivity = eventArgs.stats.productivity + totalBonus
                            table.insert(eventArgs.stats.log.productivity, string.format("+%d from %d corner offices", totalBonus, ownedCorners))
                        end
                    end
                }
            }
        }
    },
    -- {
    --     id = 'hr_rep_by_the_book1', name = 'HR Rep (by the book)', icon = 'assets/portraits/prt0055.png', rarity = 'Uncommon',
    --     hiringBonus = 1700, weeklySalary = 360,
    --     baseProductivity = 5, baseFocus = 1.0,
    --     description = 'Normalizes the workplace. All other employees cannot receive any positive or negative Focus modifiers from positional effects.',
    --     special = { type = 'neutralize_positional_focus_mods' },
    --     listeners = {
    --         onCalculateStats = {
    --             {
    --                 phase = 'PreCalculation',
    --                 priority = 10,
    --                 callback = function(self, gameState, services, eventArgs)
    --                     if eventArgs.employee.instanceId ~= self.instanceId then
    --                         eventArgs.neutralizePositionalFocus = true
    --                     end
    --                 end
    --             }
    --         }
    --     }
    -- },
    {
        id = 'office_dj1', name = 'Office DJ', icon = 'assets/portraits/prt0056.png', rarity = 'Uncommon',
        hiringBonus = 1920, weeklySalary = 306,
        baseProductivity = 13, baseFocus = 1.0,
        description = 'Employees in the same row gain +0.8x Focus. All other employees get -0.3x Focus. Effect strength scales per level. Has no effect if remote.',
        special = { type = 'row_based_focus_mod', same_row_bonus = 0.8, other_row_penalty = -0.3, scales_with_level = true },
        listeners = {
            onCalculateStats = {
                {
                    phase = 'BaseApplication',
                    priority = 50,
                    callback = function(self, gameState, services, eventArgs)
                        if self.variant == 'remote' or not self.deskId then return end
                        if eventArgs.employee.instanceId == self.instanceId then return end
                        
                        local djRow = math.floor((tonumber(string.match(self.deskId, "desk%-(%d+)")) or -1) / require("data").GRID_WIDTH)
                        local targetRow = -2
                        
                        if eventArgs.employee.deskId then
                            targetRow = math.floor((tonumber(string.match(eventArgs.employee.deskId, "desk%-(%d+)")) or -1) / require("data").GRID_WIDTH)
                        end
                        
                        if djRow >= 0 and targetRow >= 0 then
                            local modifier = (targetRow == djRow) and self.special.same_row_bonus or self.special.other_row_penalty
                            if self.special.scales_with_level then
                                modifier = modifier * (self.level or 1)
                            end
                            
                            eventArgs.stats.focus = eventArgs.stats.focus + modifier
                            local description = (targetRow == djRow) and "good music" or "annoying music"
                            table.insert(eventArgs.stats.log.focus, string.format("%s%.2fx from %s", modifier > 0 and "+" or "", modifier, description))
                        end
                    end
                }
            }
        }
    },
    {
        id = 'micromanagement', name = 'Micro Management', icon = 'assets/portraits/prt0057.png', rarity = 'Uncommon',
        hiringBonus = 2280, weeklySalary = 378,
        baseProductivity = 16, baseFocus = 1.0,
        description = 'Adjacent employees have their productivity doubled and their focus is halved. Effect strength scales per level.',
        positionalEffects = { all_adjacent = { productivity_mult = 2.0, focus_mult = 0.5, scales_with_level = true } }
    },
    {
        id = 'keyworder', name = 'Keyworder', icon = 'assets/portraits/prt0058.png', rarity = 'Uncommon',
        hiringBonus = 2160, weeklySalary = 342,
        baseProductivity = 18, baseFocus = 1.0,
        description = 'Every 3rd time they contribute in a work item, their contribution is converted directly into budget instead of clearing workload.',
        special = { type = 'contribute_to_budget_every_n_cycles', n = 3 },
        listeners = {
            onBeforeContribution = {
                {
                    phase = 'PreCalculation',
                    priority = 50,
                    callback = function(self, gameState, eventArgs)
                        if eventArgs.employee.instanceId ~= self.instanceId then return end

                        if self.workCyclesThisItem % self.special.n == 0 then
                            local stats = require("employee"):calculateStatsWithPosition(self, gameState.hiredEmployees, gameState.deskAssignments, gameState.purchasedPermanentUpgrades, gameState.desks, gameState)
                            local budgetGain = math.floor(stats.currentProductivity * stats.currentFocus)
                            
                            if not gameState.ventureCapitalActive then
                                gameState.budget = gameState.budget + budgetGain
                            end
                            
                            print("SEO Magic!", self.fullName .. " found a keyword goldmine, generating $" .. budgetGain .. " for the budget!")
                            eventArgs.shouldSkipWorkload = true
                            eventArgs.productivity = stats.currentProductivity
                            eventArgs.focus = stats.currentFocus
                        end
                    end
                }
            }
        }
    },
    {
        id = 'snack_provider1', name = 'Snack Provider', icon = 'assets/portraits/prt0059.png', rarity = 'Uncommon',
        hiringBonus = 1200, weeklySalary = 180,
        baseProductivity = 15, baseFocus = 1.0,
        description = 'After every 3 contributions in a work item, they give a "Snack" to a random employee, boosting their Focus by 1.5x per level for their next turn.',
        special = { type = 'generates_snack_every_n_cycles', n = 3, focus_mult = 1.5, scales_with_level = true },
        listeners = {
            onAfterContribution = {
                {
                    phase = 'PostCalculation',
                    priority = 50,
                    callback = function(self, gameState, eventArgs)
                        if self.workCyclesThisItem % self.special.n == 0 and #gameState.hiredEmployees > 1 then
                            local potentialTargets = {}
                            for _, emp in ipairs(gameState.hiredEmployees) do
                                if emp.instanceId ~= self.instanceId then
                                    table.insert(potentialTargets, emp)
                                end
                            end
                            if #potentialTargets > 0 then
                                local target = potentialTargets[love.math.random(#potentialTargets)]
                                target.snackBoostActive = true
                                target.snackBoostMultiplier = self.special.focus_mult
                                target.snackBoostLevel = self.level or 1
                                print(self.fullName .. " shared a snack with " .. target.name)
                            end
                        end
                    end
                }
            },
            onBeforeContribution = {
                {
                    phase = 'PreCalculation',
                    priority = 50,
                    callback = function(self, gameState, eventArgs)
                        if eventArgs.employee.snackBoostActive then
                            local focusMultiplier = eventArgs.employee.snackBoostMultiplier or 1.5
                            local level = eventArgs.employee.snackBoostLevel or 1
                            if self.special.scales_with_level then 
                                focusMultiplier = 1 + ((focusMultiplier - 1) * level)
                            end
                            eventArgs.focusMultiplier = eventArgs.focusMultiplier * focusMultiplier
                            eventArgs.employee.snackBoostActive = nil
                            eventArgs.employee.snackBoostMultiplier = nil
                            eventArgs.employee.snackBoostLevel = nil
                        end
                    end
                }
            }
        }
    },
    {
        id = 'company_historian1', name = 'Company Historian', icon = 'assets/portraits/prt0060.png', rarity = 'Uncommon',
        hiringBonus = 1800, weeklySalary = 270,
        baseProductivity = 16, baseFocus = 1.0,
        description = 'Gains +1 base Productivity per level for every Sprint completed so far in this run. (Bonus begins in Sprint 2).',
        special = { type = 'prod_per_sprint_completed', value = 1, scales_with_level = true },
        listeners = {
            onCalculateStats = {
                {
                    phase = 'BaseApplication',
                    priority = 50,
                    callback = function(self, gameState, services, eventArgs)
                        if eventArgs.employee.instanceId == self.instanceId then
                            local sprintBonus = (gameState.currentSprintIndex - 1) * (self.special.value or 1)
                            if self.special.scales_with_level then
                                sprintBonus = sprintBonus * (self.level or 1)
                            end

                            if sprintBonus > 0 then
                                eventArgs.stats.productivity = eventArgs.stats.productivity + sprintBonus
                                table.insert(eventArgs.stats.log.productivity, string.format("+%d from historical knowledge", sprintBonus))
                            end
                        end
                    end
                }
            }
        }
    },
    -- COMMON EMPLOYEES
    {
        id = 'admin1', name = 'Dependable Admin', icon = 'assets/portraits/prt0061.png', rarity = 'Common',
        hiringBonus = 1650, weeklySalary = 308,
        baseProductivity = 10, baseFocus = 1.0,
        description = '+1 Productivity per level to all adjacent employees.',
        positionalEffects = { all_adjacent = { productivity_add = 1, scales_with_level = true } }
    },
    {
        id = 'data_clerk1', name = 'Data Entry Clerk', icon = 'assets/portraits/prt0062.png', rarity = 'Common',
        hiringBonus = 1350, weeklySalary = 252,
        baseProductivity = 9, baseFocus = 1.0,
        description = 'Generates +$50 budget per level per cycle they work.',
        special = { type = 'budget_per_cycle', value = 50, scales_with_level = true },
        listeners = {
            onAfterContribution = {
                {
                    phase = 'PostCalculation',
                    priority = 50,
                    callback = function(self, gameState, eventArgs)
                        if eventArgs.employee.instanceId ~= self.instanceId then return end
                        
                        local budgetGain = self.special.value
                        if self.special.scales_with_level then budgetGain = budgetGain * (self.level or 1) end
                        if not gameState.ventureCapitalActive then
                            gameState.budget = gameState.budget + budgetGain
                        end
                        print(self.fullName .. " generated $" .. budgetGain .. " this cycle.")
                    end
                }
            }
        }
    },
    {
        id = 'caffeinated_intern1', name = 'Over-Caffeinated Intern', icon = 'assets/portraits/prt0063.png', rarity = 'Common',
        hiringBonus = 450, weeklySalary = 112,
        baseProductivity = 16, baseFocus = 1.0,
        description = 'Fast, but has a 10% chance each cycle to have 0 productivity.',
        special = { type = 'chance_zero_prod', chance = 0.10 },
        listeners = {
            onBeforeContribution = {
                {
                    phase = 'PreCalculation',
                    priority = 50,
                    callback = function(self, gameState, eventArgs)
                        if eventArgs.employee.instanceId ~= self.instanceId then return end
                        
                        if love.math.random() < self.special.chance then
                            print(self.fullName .. " got distracted! Zero productivity this cycle.")
                            eventArgs.overrideContribution = { productivity = 0, focus = 0, totalContribution = 0 }
                        end
                    end
                }
            }
        }
    },
    {
        id = 'intern1', name = 'Eager Intern', icon = 'assets/portraits/prt0064.png', rarity = 'Common',
        hiringBonus = 750, weeklySalary = 140,
        baseProductivity = 8, baseFocus = 1.0,
        description = 'Cheap, enthusiastic. Right: +0.5x Focus per level.',
        positionalEffects = { right = { focus_add = 0.5, scales_with_level = true } }
    },
    {
        id = 'dev1', name = 'Junior Developer', icon = 'assets/portraits/prt0065.png', rarity = 'Common',
        hiringBonus = 2250, weeklySalary = 420,
        baseProductivity = 10, baseFocus = 1.0,
        description = 'Solid coder. Down: +5 Prod per level.',
        positionalEffects = { down = { productivity_add = 5, scales_with_level = true } }
    },
    {
        id = 'middle_man1', name = 'Middle Man', icon = 'assets/portraits/prt0066.png', rarity = 'Common',
        hiringBonus = 1800, weeklySalary = 350,
        baseProductivity = 8, baseFocus = 1.0,
        description = 'Great eye for detail. Sides: +0.5x Focus per level.',
        positionalEffects = { left = { focus_add = 0.5, scales_with_level = true }, right = { focus_add = 0.6, scales_with_level = true } }
    },
    {
        id = 'intern_assistant1', name = 'Intern Assistant', icon = 'assets/portraits/prt0067.png', rarity = 'Common',
        hiringBonus = 1500, weeklySalary = 280,
        baseProductivity = 10, baseFocus = 1.0,
        description = 'Handles small stuff.'
    },
    -- {
    --     id = 'support_agent', name = 'Support Agent', icon = 'assets/portraits/prt0068.png', rarity = 'Common',
    --     hiringBonus = 1400, weeklySalary = 280,
    --     baseProductivity = 10, baseFocus = 1.0,
    --     description = 'Keeps clients happy.'
    -- },
    {
        id = 'office_clown', name = 'Office Clown', icon = 'assets/portraits/prt0069.png', rarity = 'Common',
        hiringBonus = 750, weeklySalary = 140,
        baseProductivity = 12, baseFocus = 1.0,
        description = 'Up: +0.4x F per level, Down: -0.2x F per level.',
        positionalEffects = { up = { focus_add = 0.4, scales_with_level = true }, down = { focus_add = -0.2, scales_with_level = true } }
    },
    {
        id = 'the_minimalist', name = 'The Minimalist', icon = 'assets/portraits/prt0070.png', rarity = 'Common',
        hiringBonus = 900, weeklySalary = 168,
        baseProductivity = 10, baseFocus = 1.0,
        description = '+10 Prod per level if no adjacent employees.',
        special = { type = 'prod_if_no_adjacent', prod_bonus = 10, scales_with_level = true },
        listeners = {
            onCalculateStats = {
                {
                    phase = 'BaseApplication',
                    priority = 50,
                    callback = function(self, gameState, services, eventArgs)
                        if eventArgs.employee.instanceId == self.instanceId and eventArgs.employee.deskId then
                            local hasAdjacentEmployees = false
                            local directions = {"up", "down", "left", "right"}
                            for _, dir in ipairs(directions) do
                                local neighborDeskId = require("placement"):getNeighboringDeskId(eventArgs.employee.deskId, dir, require("data").GRID_WIDTH, require("data").TOTAL_DESK_SLOTS, gameState.desks)
                                if neighborDeskId and gameState.deskAssignments[neighborDeskId] then
                                    hasAdjacentEmployees = true
                                    break
                                end
                            end
                            
                            if not hasAdjacentEmployees then
                                local bonus = self.special.prod_bonus
                                if self.special.scales_with_level then
                                    bonus = bonus * (self.level or 1)
                                end
                                eventArgs.stats.productivity = eventArgs.stats.productivity + bonus
                                table.insert(eventArgs.stats.log.productivity, string.format("+%d from minimalist bonus", bonus))
                            end
                        end
                    end
                }
            }
        }
    },
    {
        id = 'team_player', name = 'Team Player', icon = 'assets/portraits/prt0071.png', rarity = 'Common',
        hiringBonus = 2550, weeklySalary = 462,
        baseProductivity = 9, baseFocus = 1.0,
        description = '+0.3x Focus per level for each adjacent employee.',
        special = { type = 'focus_per_adjacent_employee_mult', value_per_emp = 0.3, scales_with_level = true },
        listeners = {
            onCalculateStats = {
                {
                    phase = 'BaseApplication',
                    priority = 50,
                    callback = function(self, gameState, services, eventArgs)
                        if eventArgs.employee.instanceId == self.instanceId and eventArgs.employee.deskId then
                            local adjacentCount = 0
                            local directions = {"up", "down", "left", "right"}
                            for _, dir in ipairs(directions) do
                                local neighborDeskId = require("placement"):getNeighboringDeskId(eventArgs.employee.deskId, dir, require("data").GRID_WIDTH, require("data").TOTAL_DESK_SLOTS, gameState.desks)
                                if neighborDeskId and gameState.deskAssignments[neighborDeskId] then
                                    adjacentCount = adjacentCount + 1
                                end
                            end
                            
                            if adjacentCount > 0 then
                                local bonusPerEmp = self.special.value_per_emp
                                if self.special.scales_with_level then
                                    bonusPerEmp = bonusPerEmp * (self.level or 1)
                                end
                                local totalBonus = adjacentCount * bonusPerEmp
                                eventArgs.stats.focus = eventArgs.stats.focus + totalBonus
                                table.insert(eventArgs.stats.log.focus, string.format("+%.2fx from %d teammates", totalBonus, adjacentCount))
                            end
                        end
                    end
                }
            }
        }
    },
    {
        id = '_office_mediator', name = 'Office Mediator', icon = 'assets/portraits/prt0072.png', rarity = 'Common',
        hiringBonus = 1950, weeklySalary = 392,
        baseProductivity = 9, baseFocus = 1.0,
        description = '+0.5x Focus per level to employees Up and Down.',
        positionalEffects = { up = { focus_add = 0.5, scales_with_level = true }, down = { focus_add = 0.5, scales_with_level = true } }
    },
    {
        id = 'steady_intern', name = 'Steady Intern', icon = 'assets/portraits/prt0073.png', rarity = 'Common',
        hiringBonus = 300, weeklySalary = 70,
        baseProductivity = 7, baseFocus = 1.0,
        description = 'Gains +1 Prod each work item.',
        special = { type = 'prod_increase_weekly', amount = 1 },
        listeners = {
            onWorkItemComplete = {
                {
                    phase = 'PostCalculation',
                    priority = 50,
                    callback = function(self, gameState, eventArgs)
                        self.baseProductivity = self.baseProductivity + (self.special.amount or 1)
                    end
                }
            }
        }
    },
    {
        id = 'pen_collector1', name = 'Pen Collector', icon = 'assets/portraits/prt0074.png', rarity = 'Common',
        hiringBonus = 1200, weeklySalary = 224,
        baseProductivity = 10, baseFocus = 1.0,
        description = 'Gains +0.1x Focus for each unique type of employee on the floor (including themselves).',
        special = { type = 'focus_per_unique_employee_type', value_per_type = 0.1 },
        listeners = {
            onCalculateStats = {
                {
                    phase = 'BaseApplication',
                    priority = 50,
                    callback = function(self, gameState, services, eventArgs)
                        if eventArgs.employee.instanceId == self.instanceId then
                            local uniqueTypes = {}
                            for _, emp in ipairs(gameState.hiredEmployees) do
                                if emp.deskId or emp.variant == 'remote' then
                                    uniqueTypes[emp.id] = true
                                end
                            end
                            
                            local typeCount = 0
                            for _ in pairs(uniqueTypes) do
                                typeCount = typeCount + 1
                            end
                            
                            local bonus = typeCount * self.special.value_per_type
                            eventArgs.stats.focus = eventArgs.stats.focus + bonus
                            table.insert(eventArgs.stats.log.focus, string.format("+%.2fx from %d unique types", bonus, typeCount))
                        end
                    end
                }
            }
        }
    },
    {
        id = 'self_doubter1', name = 'Self-Doubter', icon = 'assets/portraits/prt0075.png', rarity = 'Common',
        hiringBonus = 1050, weeklySalary = 210,
        baseProductivity = 9, baseFocus = 1.0,
        description = 'Reduces their own Focus by 0.1x, but increases the Focus of all adjacent employees by +0.2x per level.',
        special = { type = 'self_focus_reduction', value = 0.1 },
        positionalEffects = { all_adjacent = { focus_add = 0.2, scales_with_level = true } },
        listeners = {
            onCalculateStats = {
                {
                    phase = 'BaseApplication',
                    priority = 50,
                    callback = function(self, gameState, services, eventArgs)
                        -- The adjacency check logic is removed.
                        -- Only the unique, self-affecting logic remains.
                        if eventArgs.employee.instanceId == self.instanceId then
                            local reduction = self.special.value or 0.1
                            eventArgs.stats.focus = eventArgs.stats.focus * (1 - reduction)
                            table.insert(eventArgs.stats.log.focus, string.format("-%.0f%% from self-doubt", reduction * 100))
                        end
                    end
                }
            }
        }
    },
    {
        id = 'procedural_thinker1', name = 'Procedural Thinker', icon = 'assets/portraits/prt0077.png', rarity = 'Common',
        hiringBonus = 2100, weeklySalary = 392,
        baseProductivity = 10, baseFocus = 1.0,
        description = 'Gains +5 Productivity per level if placed directly between two other employees (horizontally or vertically).',
        special = { type = 'between_bonus', prod_bonus = 5, scales_with_level = true },
        listeners = {
            onCalculateStats = {
                {
                    phase = 'BaseApplication',
                    priority = 50,
                    callback = function(self, gameState, services, eventArgs)
                        if eventArgs.employee.instanceId == self.instanceId and eventArgs.employee.deskId then
                            local isBetweenHorizontally = false
                            local isBetweenVertically = false
                            
                            local leftId = require("placement"):getNeighboringDeskId(eventArgs.employee.deskId, "left", require("data").GRID_WIDTH, require("data").TOTAL_DESK_SLOTS, gameState.desks)
                            local rightId = require("placement"):getNeighboringDeskId(eventArgs.employee.deskId, "right", require("data").GRID_WIDTH, require("data").TOTAL_DESK_SLOTS, gameState.desks)
                            local upId = require("placement"):getNeighboringDeskId(eventArgs.employee.deskId, "up", require("data").GRID_WIDTH, require("data").TOTAL_DESK_SLOTS, gameState.desks)
                            local downId = require("placement"):getNeighboringDeskId(eventArgs.employee.deskId, "down", require("data").GRID_WIDTH, require("data").TOTAL_DESK_SLOTS, gameState.desks)
                            
                            if leftId and rightId and gameState.deskAssignments[leftId] and gameState.deskAssignments[rightId] then
                                isBetweenHorizontally = true
                            end
                            if upId and downId and gameState.deskAssignments[upId] and gameState.deskAssignments[downId] then
                                isBetweenVertically = true
                            end
                            
                            if isBetweenHorizontally or isBetweenVertically then
                                local bonus = self.special.prod_bonus
                                if self.special.scales_with_level then
                                    bonus = bonus * (self.level or 1)
                                end
                                eventArgs.stats.productivity = eventArgs.stats.productivity + bonus
                                table.insert(eventArgs.stats.log.productivity, string.format("+%d from being between employees", bonus))
                            end
                        end
                    end
                }
            }
        }
    },
    {
        id = 'cartoonist1', name = 'Syndicated Cartoonist', icon = 'assets/portraits/prt0078.png', rarity = 'Common',
        hiringBonus = 1425, weeklySalary = 266,
        baseProductivity = 5, baseFocus = 1.0,
        description = 'At the end of each work item, permanently boosts a random employee\'s base Focus by +0.2 per level.',
        special = { type = 'permanent_work_item_end_focus_boost', focus_add = 0.2, scales_with_level = true },
        listeners = {
            onWorkItemComplete = {
                {
                    phase = 'PostCalculation',
                    priority = 50,
                    callback = function(self, gameState, eventArgs)
                        if #gameState.hiredEmployees > 0 then
                            local target = gameState.hiredEmployees[love.math.random(#gameState.hiredEmployees)]
                            local boost = self.special.focus_add
                            if self.special.scales_with_level then boost = boost * (self.level or 1) end
                            target.baseFocus = target.baseFocus + boost
                            print("Cartoonist " .. self.fullName .. " boosted " .. target.fullName .. "'s focus by " .. boost)
                        end
                    end
                }
            }
        }
    },
    {
        id = 'luddite1', name = 'Office Luddite', icon = 'assets/portraits/prt0079.png', rarity = 'Common',
        hiringBonus = 2700, weeklySalary = 448,
        baseProductivity = 20, baseFocus = 1.0,
        description = 'Has high base productivity but all positive stat modifiers are only 50% effective. Cannot benefit from tech-based upgrades.',
        special = { type = 'tech_upgrade_immunity_and_modifier_reduction', modifier_effectiveness = 0.5 },
        listeners = {
            onApplyUpgrades = {
                {
                    phase = 'BaseApplication',
                    priority = 50,
                    callback = function(self, gameState, eventArgs)
                        if eventArgs.employee.instanceId ~= self.instanceId then return end
                        
                        eventArgs.blockedUpgrades['automation_scripts'] = true
                        eventArgs.blockedUpgrades['advanced_crm'] = true
                        eventArgs.blockedUpgrades['fast_internet'] = true
                    end
                }
            },
            onCalculateStats = {
                {
                    phase = 'PostCalculation',
                    priority = 90,
                    callback = function(self, gameState, services, eventArgs)
                        if eventArgs.employee.instanceId ~= self.instanceId then return end
                        
                        -- Reduce all positive modifiers by 50%
                        local baseProductivity = self.baseProductivity
                        local baseFocus = self.baseFocus
                        local productivityBonus = eventArgs.stats.productivity - baseProductivity
                        local focusBonus = eventArgs.stats.focus - baseFocus
                        
                        if productivityBonus > 0 then
                            eventArgs.stats.productivity = baseProductivity + (productivityBonus * self.special.modifier_effectiveness)
                            table.insert(eventArgs.stats.log.productivity, string.format("Positive modifiers reduced by %.0f%%", (1 - self.special.modifier_effectiveness) * 100))
                        end
                        
                        if focusBonus > 0 then
                            eventArgs.stats.focus = baseFocus + (focusBonus * self.special.modifier_effectiveness)
                            table.insert(eventArgs.stats.log.focus, string.format("Positive modifiers reduced by %.0f%%", (1 - self.special.modifier_effectiveness) * 100))
                        end
                    end
                }
            }
        }
    },
    -- {
    --     id = 'the_hoarder1', name = 'The Hoarder', icon = 'assets/portraits/prt0080.png', rarity = 'Common',
    --     hiringBonus = 1300, weeklySalary = 250,
    --     baseProductivity = 7, baseFocus = 1.0,
    --     description = 'Gains +$100 budget per level at the end of each Sprint.',
    --     special = { type = 'budget_per_sprint', value = 100, scales_with_level = true },
    --     listeners = {
    --         onSprintStart = {
    --             {
    --                 phase = 'BaseApplication',
    --                 priority = 50,
    --                 callback = function(self, gameState, eventArgs)
    --                     local budgetGain = self.special.value
    --                     if self.special.scales_with_level then budgetGain = budgetGain * (self.level or 1) end
    --                     if not gameState.ventureCapitalActive then
    --                         gameState.budget = gameState.budget + budgetGain
    --                     end
    --                     print(self.fullName .. " hoarded $" .. budgetGain .. " this Sprint.")
    --                 end
    --             }
    --         }
    --     }
    -- },
    {
        id = 'positive_intern1', name = 'Positive Intern', icon = 'assets/portraits/prt0081.png', rarity = 'Common',
        hiringBonus = 2250, weeklySalary = 420,
        baseProductivity = 12, baseFocus = 1.0,
        description = 'Ignores the first negative positional effect applied to them each time stats are calculated.',
        special = { type = 'ignore_first_negative_positional' },
        listeners = {
            onCalculateStats = {
                {
                    phase = 'PostCalculation',
                    priority = 90,
                    callback = function(self, gameState, services, eventArgs)
                        if eventArgs.employee.instanceId ~= self.instanceId then return end
                        
                        local firstNegativeFound = false
                        local negativeProductivity = 0
                        local negativeFocus = 0
                        
                        for i, logEntry in ipairs(eventArgs.stats.log.productivity or {}) do
                            local negValue = string.match(logEntry, "^%-([%d%.]+)")
                            if negValue and not firstNegativeFound then
                                negativeProductivity = tonumber(negValue)
                                table.remove(eventArgs.stats.log.productivity, i)
                                firstNegativeFound = true
                                break
                            end
                        end
                        
                        if not firstNegativeFound then
                            for i, logEntry in ipairs(eventArgs.stats.log.focus or {}) do
                                local negValue = string.match(logEntry, "^%-([%d%.]+)")
                                if negValue and not firstNegativeFound then
                                    negativeFocus = tonumber(negValue)
                                    table.remove(eventArgs.stats.log.focus, i)
                                    firstNegativeFound = true
                                    break
                                end
                            end
                        end
                        
                        if firstNegativeFound then
                            if negativeProductivity > 0 then
                                eventArgs.stats.productivity = eventArgs.stats.productivity + negativeProductivity
                                table.insert(eventArgs.stats.log.productivity, string.format("+%d from ignoring negative effect", negativeProductivity))
                            end
                            if negativeFocus > 0 then
                                eventArgs.stats.focus = eventArgs.stats.focus + negativeFocus
                                table.insert(eventArgs.stats.log.focus, string.format("+%.2fx from ignoring negative effect", negativeFocus))
                            end
                        end
                    end
                }
            }
        }
    },
}