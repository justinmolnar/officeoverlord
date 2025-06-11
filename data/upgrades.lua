return {
    -- COMMON UPGRADES --
    { 
        id = 'scrum_board', name = 'The "Scrum" Board', rarity = 'Common', cost = 500, icon = '📌',
        description = 'Each turn, add a "story point". After 5 points, the next employee to contribute has their contribution tripled.',
        effect = { type = 'scrum_board' }
    },
    { 
        id = 'gig_economy', name = 'Gig Economy Contract', rarity = 'Common', cost = 400, icon = '📝',
        description = 'All salaries are 50% lower, but employees have a 25% chance of leaving after each Sprint.',
        effect = { type = 'gig_economy' },
        listeners = {
            onSprintStart = function(self, gameState, eventArgs)
                local contractorsLeft = {}
                for i = #gameState.hiredEmployees, 1, -1 do
                    if love.math.random() < 0.25 then
                        local firedContractor = table.remove(gameState.hiredEmployees, i)
                        if firedContractor.deskId and gameState.deskAssignments[firedContractor.deskId] then
                        gameState.deskAssignments[firedContractor.deskId] = nil
                        end
                        table.insert(contractorsLeft, firedContractor.fullName)
                    end
                end
                if #contractorsLeft > 0 then
                    eventArgs.showModal = {
                        title = "Contracts Ended",
                        message = "The following contractors have left the company:\n" .. table.concat(contractorsLeft, ", ")
                    }
                end
            end
        }
    },
    { 
        id = 'move_fast_break_things', name = '"Move Fast, Break Things" Memo', rarity = 'Common', cost = 600, icon = '🚀',
        description = 'All employees gain +1.0x Focus, but have a 5% chance each turn to "break the build," contributing 0 and costing $100.',
        effect = { type = 'move_fast_break_things' },
        listeners = {
            onApplyUpgradeModifiers = function(self, gameState, eventArgs)
                eventArgs.focus = eventArgs.focus + 1.0
                table.insert(eventArgs.log.focus, "+1.0x from Move Fast Memo")
            end,
            onBeforeContribution = function(self, gameState, eventArgs)
                if love.math.random() < 0.05 then
                    print(eventArgs.employee.fullName .. " broke the build! Costing $100.")
                    gameState.budget = gameState.budget - 100
                    eventArgs.overrideContribution = { productivity = 0, focus = 0, totalContribution = 0 }
                end
            end
        }
    },
    { 
        id = 'automation_v1', name = 'Automation Script (V.1)', rarity = 'Common', cost = 750, icon = '🤖',
        description = 'The employee with the lowest base Productivity on the team has their contribution doubled.',
        effect = { type = 'automation_v1' },
        listeners = {
            onWorkItemStart = function(self, gameState, eventArgs)
                local lowestProdEmp = nil
                local activeBattleEmployees = {}
                for _, emp in ipairs(gameState.hiredEmployees) do
                    local isDisabled = false
                    if emp.isTraining or (emp.special and emp.special.does_not_work) then isDisabled = true end
                    if gameState.temporaryEffectFlags.isRemoteWorkDisabled and emp.variant == 'remote' then isDisabled = true end
                    if gameState.temporaryEffectFlags.isTopRowDisabled and emp.deskId and (emp.deskId == 'desk-0' or emp.deskId == 'desk-1' or emp.deskId == 'desk-2') then isDisabled = true end
                    if not isDisabled then table.insert(activeBattleEmployees, emp) end
                end

                for _, emp in ipairs(activeBattleEmployees) do
                    if not lowestProdEmp or emp.baseProductivity < lowestProdEmp.baseProductivity then
                        lowestProdEmp = emp
                    end
                end

                if lowestProdEmp then
                    gameState.temporaryEffectFlags.automatedEmployeeId = lowestProdEmp.instanceId
                    print("Automation v1 targeting: " .. lowestProdEmp.fullName)
                end
            end,
            onBeforeContribution = function(self, gameState, eventArgs)
                if eventArgs.employee.isAutomated then
                    eventArgs.contributionMultiplier = eventArgs.contributionMultiplier * 2
                end
            end
        }
    },
    { 
        id = 'growth_mindset', name = '"Growth Mindset" Seminar', rarity = 'Common', cost = 1000, icon = '🧠',
        description = 'Employees can now be leveled up to Level 4.',
        effect = { type = 'growth_mindset' },
        listeners = {
            onGetMaxLevel = function(self, gameState, eventArgs)
                eventArgs.maxLevel = 4
            end
        }
    },
    {
        id = 'motivational_speaker', name = 'Motivational Speaker', rarity = 'Common', cost = 1000, icon = '📢',
        description = 'Once per sprint, pay $1000 to give all employees +100% Focus for the next work item.',
        effect = { type = 'motivational_speaker' },
        listeners = {
            onActivate = function(self, gameState, eventArgs)
                if gameState.gamePhase == 'hiring_and_upgrades' and not gameState.temporaryEffectFlags.motivationalSpeakerUsedThisSprint and gameState.budget >= 1000 then
                    gameState.budget = gameState.budget - 1000
                    gameState.temporaryEffectFlags.motivationalBoostNextItem = true
                    gameState.temporaryEffectFlags.motivationalSpeakerUsedThisSprint = true
                    eventArgs.showModal = {
                        title = "Motivation Delivered!",
                        message = "All employees will have doubled Focus for the next work item!"
                    }
                    return true
                end
                return false
            end,
            onWorkItemStart = function(self, gameState, eventArgs)
                if gameState.temporaryEffectFlags.motivationalBoostNextItem then
                    gameState.temporaryEffectFlags.globalFocusMultiplier = 2.0
                    gameState.temporaryEffectFlags.motivationalBoostNextItem = nil
                end
            end
        }
        },
    { 
        id = 'headhunter', name = 'Corporate Headhunter', rarity = 'Common', cost = 500, icon = '🕵️',
        description = 'The shop is now guaranteed to have at least one \'Rare\' or \'Legendary\' employee. Restock cost is doubled.',
        effect = { type = 'corporate_headhunter' },
        listeners = {
            onPopulateShop = function(self, gameState, eventArgs)
                eventArgs.guaranteeRareOrLegendary = true
            end,
            onCalculateRestockCost = function(self, gameState, eventArgs)
                eventArgs.finalCost = eventArgs.finalCost * 2
            end
        }
    },
    { 
        id = 'first_mover', name = 'First-Mover Advantage', rarity = 'Common', cost = 800, icon = '🥇',
        description = 'The first employee to act in every work cycle has their Productivity and Focus doubled.',
        effect = { type = 'first_mover' },
        listeners = {
            onBeforeContribution = function(self, gameState, eventArgs)
                if eventArgs.employee.isFirstMover then
                    eventArgs.productivityMultiplier = eventArgs.productivityMultiplier * 2
                    eventArgs.focusMultiplier = eventArgs.focusMultiplier * 2
                end
            end
        }
    },
    { 
        id = 'watering_can', name = 'Watering Can', rarity = 'Common', cost = 400, icon = '🪣',
        description = 'Doubles the effectiveness of the Office Plant.',
        effect = { type = 'special_plant_boost' }
    },
    {
        id = 'ballpoint_pens', name = 'Bulk-Order Ballpoint Pens', rarity = 'Common', cost = 300, icon = '✒️',
        description = 'Hiring cost of all \'Common\' employees is reduced by 25%.',
        effect = { type = 'ballpoint_pens' },
        listeners = {
            onCalculateHiringCost = function(self, gameState, eventArgs)
                if eventArgs.employeeRarity == 'Common' then
                    eventArgs.finalCost = math.floor(eventArgs.finalCost * 0.75)
                end
            end
        }
    },


    -- UNCOMMON UPGRADES --
    { 
        id = 'advanced_crm', name = 'Advanced CRM System', rarity = 'Uncommon', cost = 1400, icon = '📊',
        description = 'Marketing employees gain an additional $250 per win.',
        effect = { type = 'advanced_crm', budget_per_win_bonus = 250 }
    },
    { 
        id = 'team_building_event', name = 'Team Building Event', rarity = 'Uncommon', cost = 800, icon = '🏕️',
        description = 'Once per sprint, boosts team focus for the next work item.',
        effect = { type = 'one_time_team_focus_boost_multiplier', value = 1.3 },
        listeners = {
            onActivate = function(self, gameState, eventArgs)
                if gameState.gamePhase == 'hiring_and_upgrades' and not gameState.temporaryEffectFlags.teamBuildingUsedThisSprint then
                    gameState.temporaryEffectFlags.teamBuildingFocusBoostNextWeek = true
                    gameState.temporaryEffectFlags.teamBuildingUsedThisSprint = true
                    eventArgs.showModal = {
                        title = "Team Building Success!",
                        message = "All employees will have boosted focus for the next work item!"
                    }
                    return true
                end
                return false
            end,
            onWorkItemStart = function(self, gameState, eventArgs)
                if gameState.temporaryEffectFlags.teamBuildingFocusBoostNextWeek then
                    gameState.temporaryEffectFlags.teamBuildingActiveThisWeek = true
                    gameState.temporaryEffectFlags.teamBuildingFocusBoostNextWeek = nil
                    print("Team Spirit High! Focus boosted this week.")
                end
            end,
            onApplyGlobalFocusModifiers = function(self, gameState, eventArgs)
                if gameState.temporaryEffectFlags.teamBuildingActiveThisWeek then
                    eventArgs.focusMultiplier = eventArgs.focusMultiplier * self.effect.value
                end
            end
        }
    },
    { 
        id = 'stock_options', name = 'Stock Options', rarity = 'Uncommon', cost = 1400, icon = '💹',
        description = 'When budget is below $10,000, employees have a 10% chance to gain double productivity for a turn, motivated by their stock options.',
        effect = { type = 'stock_options', threshold = 10000, chance = 0.1 },
        listeners = {
            onBeforeContribution = function(self, gameState, eventArgs)
                if gameState.budget < self.effect.threshold and love.math.random() < self.effect.chance then
                    eventArgs.productivityMultiplier = (eventArgs.productivityMultiplier or 1) * 2
                    print(eventArgs.employee.fullName .. " gets a stock options productivity surge!")
                end
            end
        }
    },
    { 
        id = 'salary_cap', name = 'Salary Cap', rarity = 'Uncommon', cost = 1200, icon = '🧢',
        description = 'No single employee\'s salary can exceed $750. All hiring costs are increased by 25%.',
        effect = { type = 'salary_cap' },
        listeners = {
            onCalculateSalaries = function(self, gameState, eventArgs)
                eventArgs.salaryCap = 750
            end,
            onCalculateHiringCost = function(self, gameState, eventArgs)
                eventArgs.finalCost = math.floor(eventArgs.finalCost * 1.25)
            end
        }
    },
    { 
        id = 'assembly_line', name = 'The Assembly Line', rarity = 'Uncommon', cost = 900, icon = '→',
        description = 'Employees work in a fixed top-to-bottom order. Each employee gains +0.1x Focus for each employee that acted before them.',
        effect = { type = 'assembly_line' },
        listeners = {
            onWorkOrderDetermined = function(self, gameState, eventArgs)
                table.sort(eventArgs.activeEmployees, function(a, b)
                    local aIndex = tonumber(string.match(a.deskId or "desk-999", "desk%-(%d+)")) or 999
                    local bIndex = tonumber(string.match(b.deskId or "desk-999", "desk%-(%d+)")) or 999
                    return aIndex < bIndex
                end)
                
                for i, emp in ipairs(eventArgs.activeEmployees) do
                    emp.assemblyLinePosition = i
                end
            end,
            onBeforeContribution = function(self, gameState, eventArgs)
                if eventArgs.employee.assemblyLinePosition then
                    local focusBonus = (eventArgs.employee.assemblyLinePosition - 1) * 0.1
                    eventArgs.focusMultiplier = eventArgs.focusMultiplier * (1 + focusBonus)
                end
            end
        }
    },
    { 
        id = 'code_debt', name = 'Code Debt', rarity = 'Uncommon', cost = 100, icon = '💻',
        description = 'Gain $10,000 immediately. For the rest of the run, all work items have 20% more workload.',
        effect = { type = 'code_debt', value = 10000 },
        listeners = {
            onWorkItemStart = function(self, gameState, eventArgs)
                gameState.currentWeekWorkload = math.floor(gameState.currentWeekWorkload * 1.20)
                print("Workload increased by 20% due to Code Debt listener.")
            end,
            onPurchase = function(self, gameState)
                if not gameState.ventureCapitalActive then
                    gameState.budget = gameState.budget + self.effect.value
                end
            end
        }
    },
    { 
        id = 'specialist_niche', name = 'The Specialist\'s Niche', rarity = 'Uncommon', cost = 1500, icon = '🎯',
        description = 'The employee with the highest level has their stats and ability effects doubled. All other employees have their stats halved.',
        effect = { type = 'specialist_niche' },
        listeners = {
            onWorkItemStart = function(self, gameState, eventArgs)
                local specialist = nil
                for _, emp in ipairs(gameState.hiredEmployees) do
                    if not specialist or (emp.level or 1) > (specialist.level or 1) then
                        specialist = emp
                    end
                end
                if specialist then
                    gameState.temporaryEffectFlags.specialistId = specialist.instanceId
                    print("Specialist for this round: " .. specialist.name)
                end
            end,
            onFinalizeStats = function(self, gameState, eventArgs)
                local specialistId = gameState.temporaryEffectFlags.specialistId
                local isSpecialist = specialistId == eventArgs.employee.instanceId
                
                local multiplier = isSpecialist and 2 or 0.5
                eventArgs.stats.productivity = math.floor(eventArgs.stats.productivity * multiplier)
                eventArgs.stats.focus = eventArgs.stats.focus * multiplier
                local logText = string.format("%s from Specialist's Niche", isSpecialist and "*2" or "/2")
                table.insert(eventArgs.stats.log.productivity, logText)
                table.insert(eventArgs.stats.log.focus, logText)

                if isSpecialist and eventArgs.employee.positionalEffects then
                    for _, otherEmp in ipairs(gameState.hiredEmployees) do
                        if otherEmp.instanceId ~= eventArgs.employee.instanceId and otherEmp.deskId then
                            for _, effect in pairs(eventArgs.employee.positionalEffects) do
                                if effect.productivity_add then otherEmp.baseProductivity = otherEmp.baseProductivity + effect.productivity_add end
                                if effect.focus_add then otherEmp.baseFocus = otherEmp.baseFocus + effect.focus_add end
                            end
                        end
                    end
                end
            end
        }
    },
    { 
        id = 'consultant_visit', name = 'Consultant Visit', rarity = 'Uncommon', cost = 1200, icon = '👔',
        description = 'Once per work item, reduces workload by 15% at the start.',
        effect = { type = 'one_time_workload_reduction_percent', value = 0.15 },
        listeners = {
            onWorkItemStart = function(self, gameState, eventArgs)
                if gameState.temporaryEffectFlags.consultantVisitUsedThisWeek ~= true then
                    local reduction = math.floor(gameState.currentWeekWorkload * self.effect.value)
                    gameState.currentWeekWorkload = gameState.currentWeekWorkload - reduction
                    gameState.temporaryEffectFlags.consultantVisitUsedThisWeek = true
                    print("Consultant Visit! Workload reduced by " .. reduction)
                end
            end
        }
    },
    { 
        id = 'positional_inverter', name = 'Positional Inverter', rarity = 'Uncommon', cost = 1000, icon = '🔄',
        description = 'All positive positional effects are now negative, and all negative effects are now positive.',
        effect = { type = 'positional_inverter' }
    },
    { 
        id = 'focus_funnel', name = 'Focus Funnel', rarity = 'Uncommon', cost = 1300, icon = '✨',
        description = 'All Focus bonuses from all sources are collected and granted to a single random employee each work item.',
        effect = { type = 'focus_funnel' },
        listeners = {
            onBattleStart = function(self, gameState, eventArgs)
                if #eventArgs.activeEmployees > 0 then
                    local target = eventArgs.activeEmployees[love.math.random(#eventArgs.activeEmployees)]
                    gameState.temporaryEffectFlags.focusFunnelTargetId = target.instanceId
                    print(target.name .. " is the Focus Funnel target for this item.")
                end
            end,
            onWorkItemStart = function(self, gameState, eventArgs)
                local totalBonus = 1.0
                for _, sourceEmp in ipairs(gameState.hiredEmployees) do
                    if sourceEmp.deskId and sourceEmp.positionalEffects then
                        for _, effect in pairs(sourceEmp.positionalEffects) do
                            local multValue = effect.scales_with_level and (sourceEmp.level or 1) or 1
                            if effect.focus_add then
                                local bonus = effect.focus_add * multValue
                                totalBonus = totalBonus * (1 + bonus)
                            end
                            if effect.focus_mult then
                                local bonus = 1 + ((effect.focus_mult - 1) * multValue)
                                totalBonus = totalBonus * bonus
                            end
                        end
                    end
                end
                gameState.temporaryEffectFlags.focusFunnelTotalBonus = totalBonus
                print("Focus Funnel collected a total bonus multiplier of: " .. totalBonus)
            end
        }
    },
    { 
        id = 'payroll_glitch', name = 'Glitch in the Payroll', rarity = 'Uncommon', cost = 700, icon = '💸',
        description = 'Employee salaries are now randomized each pay cycle, ranging from $1 to double their normal amount.',
        effect = { type = 'payroll_glitch' },
        listeners = {
            onCalculateSalaries = function(self, gameState, eventArgs)
                local originalCalculation = eventArgs.cumulativePercentReduction
                eventArgs.cumulativePercentReduction = function(emp)
                    local randomMultiplier = love.math.random() * 2
                    return math.max(1, math.floor(emp.weeklySalary * randomMultiplier))
                end
            end
        }
    },
    { 
        id = 'synergy_generator', name = '"Synergy" Buzzword Generator', rarity = 'Uncommon', cost = 1100, icon = '⚡',
        description = 'Every unique type of positional bonus active on the board grants a stacking +0.1x Focus to ALL employees.',
        effect = { type = 'synergy_generator' },
        listeners = {
            onFinalizeStats = function(self, gameState, eventArgs)
                local uniqueBonusTypes = {}
                for _, emp in ipairs(gameState.hiredEmployees) do
                    if emp.deskId and emp.positionalEffects then
                        for direction, effect in pairs(emp.positionalEffects) do
                            for effectType, _ in pairs(effect) do
                                if effectType == 'productivity_add' or effectType == 'focus_add' or effectType == 'focus_mult' then
                                    uniqueBonusTypes[effectType] = true
                                end
                            end
                        end
                    end
                end
                
                local bonusCount = 0
                for _ in pairs(uniqueBonusTypes) do
                    bonusCount = bonusCount + 1
                end
                
                if bonusCount > 0 then
                    local synergyBonus = bonusCount * 0.1
                    eventArgs.stats.focus = eventArgs.stats.focus * (1 + synergyBonus)
                    table.insert(eventArgs.stats.log.focus, string.format("+%.1f%% from synergy (%d types)", synergyBonus * 100, bonusCount))
                end
            end
        }
    },
    {
        id = 'four_day_week', name = 'Four-Day Work Week', rarity = 'Uncommon', cost = 2000, icon = '🗓️',
        description = 'Salaries are only paid on 4 out of every 5 work cycles. All work item workloads are increased by 15%.',
        effect = { type = 'four_day_week' },
        listeners = {
            onWorkItemStart = function(self, gameState, eventArgs)
                gameState.currentWeekWorkload = math.floor(gameState.currentWeekWorkload * 1.15)
                print("Workload increased by 15% due to Four-Day Work Week listener.")
            end,
            onCalculateSalaries = function(self, gameState, eventArgs)
                if gameState.currentWeekCycles > 0 and (gameState.currentWeekCycles + 1) % 5 == 0 then
                    eventArgs.skipPayday = true
                end
            end
        }
    },
    { 
        id = 'delorean_espresso', name = 'Espresso Machine (DeLorean-Powered)', rarity = 'Uncommon', cost = 1800, icon = '🚀',
        description = 'The first employee to act each round gets two turns.',
        effect = { type = 'delorean_espresso' },
        listeners = {
            onWorkOrderDetermined = function(self, gameState, eventArgs)
                if #eventArgs.activeEmployees > 0 then
                    local firstEmployee = eventArgs.activeEmployees[1]
                    table.insert(eventArgs.activeEmployees, 2, firstEmployee)
                end
            end
        }
    },
    {
        id = 'subsidized_housing', name = 'Subsidized Housing', rarity = 'Uncommon', cost = 1500, icon = '🏠',
        description = 'All salaries are reduced by 25%, but you can no longer hire Remote workers.',
        effect = { type = 'subsidized_housing' },
        listeners = {
            onCalculateSalaries = function(self, gameState, eventArgs)
                eventArgs.cumulativePercentReduction = eventArgs.cumulativePercentReduction * 0.75
            end
        }
    },


    -- RARE UPGRADES --
    { 
        id = 'legal_retainer', name = 'Legal Retainer', rarity = 'Rare', cost = 2200, icon = '⚖️',
        description = '25% chance bailouts are free due to legal loopholes.',
        effect = { type = 'chance_avoid_bailout_cost', chance = 0.25 }
    },  
    { 
        id = 'office_plant', name = 'Office Plant', rarity = 'Rare', cost = 800, icon = '🌱',
        description = 'A plant in the office boosts Focus by +0.5x for all employees.',
        effect = { type = 'special_office_plant' },
        listeners = {
            onApplyGlobalFocusModifiers = function(self, gameState, eventArgs)
                eventArgs.focusMultiplier = eventArgs.focusMultiplier * 1.5
            end
        }
    },
    { 
        id = 'automation_scripts', name = 'Automation Scripts', rarity = 'Rare', cost = 2000, icon = '📜🤖',
        description = 'On the first work cycle of any item, all employees have their total contribution multiplied by 1.5x.',
        effect = { type = 'automation_scripts', value = 1.5 },
        listeners = {
            onBeforeContribution = function(self, gameState, eventArgs)
                if gameState.currentWeekCycles == 0 then
                    eventArgs.contributionMultiplier = (eventArgs.contributionMultiplier or 1) * self.effect.value
                end
            end
        }
    },
    { 
        id = 'positional_singularity', name = 'Positional Singularity', rarity = 'Rare', cost = 2500, icon = '⚫',
        description = 'All positional bonuses are gathered and applied only to the employee in the center desk.',
        effect = { type = 'positional_singularity' },
        listeners = {
            onCalculatePositionalBonuses = function(self, gameState, eventArgs)
                local targetEmployee = eventArgs.employee
                if targetEmployee.deskId ~= "desk-4" then
                    eventArgs.override = true
                    return
                end

                if not eventArgs.log.productivity then eventArgs.log.productivity = {} end
                table.insert(eventArgs.log.productivity, "Singularity: Receiving all bonuses")

                for _, sourceEmployee in ipairs(gameState.hiredEmployees) do
                    if sourceEmployee.instanceId ~= targetEmployee.instanceId and sourceEmployee.deskId and sourceEmployee.positionalEffects then
                        for _, effectDetails in pairs(sourceEmployee.positionalEffects) do
                            if not (effectDetails.condition_not_id and targetEmployee.id == effectDetails.condition_not_id) then
                                eventArgs.applyEffect(effectDetails, sourceEmployee)
                            end
                        end
                    end
                end
                eventArgs.override = true
            end
        }
    },
    { 
        id = 'pyramid_scheme', name = 'Pyramid Scheme License', rarity = 'Rare', cost = 2200, icon = '🔺',
        description = 'Middle row employees give 10% of their contribution to the top-center "Apex." Bottom row gives 10% to the middle row.',
        effect = { type = 'pyramid_scheme' },
        listeners = {
            onEndOfRound = function(self, gameState, eventArgs)
                eventArgs.pyramidSchemeActive = true
            end
        }
    },
    { 
        id = 'vc_funding', name = 'Venture Capital Funding', rarity = 'Rare', cost = 500, icon = '🤑',
        description = 'Instantly gain $100,000. You can no longer gain budget from any other source for the rest of the run.',
        effect = { type = 'vc_funding' },
        listeners = {
            onPurchase = function(self, gameState)
                gameState.budget = gameState.budget + 100000
                gameState.ventureCapitalActive = true
            end
        }
    },
    {
        id = 'nepotism_hire', name = 'Nepotism Hire', rarity = 'Rare', cost = 1000, icon = '🤦',
        description = 'The next \'Rare\' or \'Legendary\' employee to appear in the shop costs $0, but their salary is tripled.',
        effect = { type = 'nepotism_hire' },
        listeners = {
            onPurchase = function(self, gameState)
                gameState.temporaryEffectFlags.nepotismHireActive = true
            end,
            onPopulateShop = function(self, gameState, eventArgs)
                if gameState.temporaryEffectFlags.nepotismHireActive then
                    for _, offer in ipairs(eventArgs.offers) do
                        if offer.rarity == 'Rare' or offer.rarity == 'Legendary' then
                            offer.hiringBonus = 0
                            offer.weeklySalary = offer.weeklySalary * 3
                            offer.isNepotismBaby = true
                            offer.displayCost = 0
                            gameState.temporaryEffectFlags.nepotismHireActive = false
                            print("NEPOTISM! " .. offer.fullName .. " is the Nepo hire.")
                            break
                        end
                    end
                end
            end
        }
    },
    { 
        id = 'office_dog', name = 'Office Dog', rarity = 'Rare', cost = 1500, icon = '🐕',
        description = 'A good dog wanders the office. Has a 10% chance to motivate the active employee, doubling their Focus for one turn.',
        effect = { type = 'special_office_dog' },
        listeners = {
            onTurnStart = function(self, gameState, eventArgs)
                local currentEmployee = eventArgs.currentEmployee
                if not currentEmployee then return end

                local dogWalkerIsPresent = false
                for _, emp in ipairs(gameState.hiredEmployees) do
                    if emp.special and emp.special.type == 'enhances_office_dog' then
                        dogWalkerIsPresent = true
                        break
                    end
                end

                local dogChance = require("data").OFFICE_DOG_CHANCE
                if dogWalkerIsPresent or love.math.random() < dogChance then
                    gameState.temporaryEffectFlags.officeDogActiveThisTurn = true
                    gameState.temporaryEffectFlags.officeDogTarget = currentEmployee.instanceId
                    print("Office Dog is motivating " .. currentEmployee.fullName)
                end
            end
        }
    },
    {
        id = 'open_concept', name = 'Open-Concept Office Plan', rarity = 'Rare', cost = 3000, icon = '😮',
        description = 'All desks are now considered adjacent to all other desks for positional effects.',
        effect = { type = 'open_concept' },
        listeners = {
            onCalculatePositionalBonuses = function(self, gameState, eventArgs)
                local targetEmployee = eventArgs.employee
                
                if not eventArgs.log.productivity then eventArgs.log.productivity = {} end
                table.insert(eventArgs.log.productivity, "Open Concept: All desks are adjacent")

                for _, sourceEmployee in ipairs(gameState.hiredEmployees) do
                    if sourceEmployee.instanceId ~= targetEmployee.instanceId and sourceEmployee.deskId and sourceEmployee.positionalEffects then
                        if not (sourceEmployee.isSmithCopy and targetEmployee.isSmithCopy) then
                            for _, effectDetails in pairs(sourceEmployee.positionalEffects) do
                                if not (effectDetails.condition_not_id and targetEmployee.id == effectDetails.condition_not_id) then
                                    eventArgs.applyEffect(effectDetails, sourceEmployee)
                                end
                            end
                        end
                    end
                end
                eventArgs.override = true
            end
        }
    },
    {
        id = 'onsite_daycare', name = 'On-Site Daycare', rarity = 'Rare', cost = 2000, icon = '🧸',
        description = 'All "Parent" employees have their stats doubled. (Requires Parent trait).',
        effect = { type = 'onsite_daycare' }
    },
    {
        id = 'hr_drone', name = 'HR Drone Program', rarity = 'Rare', cost = 1800, icon = '👁️',
        description = 'You can now see the hidden traits of employees in the shop before hiring them.',
        effect = { type = 'hr_drone' }
    },
    {
        id = 'the_reorg', name = 'The Re-Org', rarity = 'Rare', cost = 1200, icon = '🔄',
        description = 'Once per sprint, you can swap a remote worker with an office worker.',
        effect = { type = 'the_reorg' },
        listeners = {
            onActivate = function(self, gameState, eventArgs)
                if gameState.gamePhase == 'hiring_and_upgrades' and not gameState.temporaryEffectFlags.reOrgUsedThisSprint then
                    gameState.temporaryEffectFlags.reOrgSwapModeActive = true
                    eventArgs.showModal = {
                        title = "Re-Org Started",
                        message = "Select a remote worker and an office worker to swap their positions."
                    }
                    return true -- Indicate success
                end
                return false -- Indicate failure or non-activation
            end
        }
    },
    {
        id = 'unbreakable_ndas', name = 'Unbreakable NDAs', rarity = 'Rare', cost = 1600, icon = '📜',
        description = 'Employees cannot be "poached." The "Gossip" trait has no effect.',
        effect = { type = 'unbreakable_ndas' }
    },
    {
        id = 'sentient_photocopier', name = 'Sentient Photocopier', rarity = 'Rare', cost = 2800, icon = '📠',
        description = 'Once per Sprint, copy a non-Legendary employee. An identical, temporary clone appears for the next work item.',
        effect = { type = 'sentient_photocopier' },
        listeners = {
            onActivate = function(self, gameState, eventArgs)
                if gameState.gamePhase == 'hiring_and_upgrades' and not gameState.temporaryEffectFlags.photocopierUsedThisSprint then
                    gameState.temporaryEffectFlags.photocopierCopyModeActive = true
                    eventArgs.showModal = {
                        title = "Photocopier Warmed Up",
                        message = "Select a non-Legendary office worker to duplicate for the next work item."
                    }
                    return true
                end
                return false
            end,
            onWorkItemStart = function(self, gameState, eventArgs)
                if gameState.temporaryEffectFlags.photocopierTargetForNextItem then
                    local target = require("employee"):getFromState(gameState, gameState.temporaryEffectFlags.photocopierTargetForNextItem)
                    local emptyDeskId = nil
                    for _, desk in ipairs(gameState.desks) do
                        if desk.status == 'owned' and not gameState.deskAssignments[desk.id] then
                            emptyDeskId = desk.id
                            break
                        end
                    end

                    if target and emptyDeskId then
                        local Employee = require("employee")
                        local Placement = require("placement")
                        local clone = Employee:new(target.id, target.variant, "Clone of " .. target.fullName)
                        clone.isTemporaryClone = true
                        clone.weeklySalary = 0
                        clone.level = target.level
                        clone.baseProductivity = target.baseProductivity
                        clone.baseFocus = target.baseFocus
                        table.insert(gameState.hiredEmployees, clone)
                        Placement:handleEmployeeDropOnDesk(gameState, clone, emptyDeskId, nil)
                        eventArgs.showModal = {
                            title = "Photocopied!",
                            message = "A temporary clone of " .. target.name .. " has appeared for this work item!"
                        }
                    else
                        eventArgs.showModal = {
                            title = "Photocopy Failed",
                            message = "Could not create a clone. Ensure there is an empty desk available."
                        }
                    end
                    gameState.temporaryEffectFlags.photocopierTargetForNextItem = nil
                end
            end
        }
    },
    {
        id = 'lead_lined_walls', name = 'Lead-Lined Walls', rarity = 'Rare', cost = 2500, icon = '🧱',
        description = 'Your office is immune to all external random events (positive and negative).',
        effect = { type = 'lead_lined_walls' }
    },
    {
        id = 'water_cooler_mimic', name = 'The Water Cooler is now a Mimic', rarity = 'Rare', cost = 2200, icon = '💧',
        description = 'The office Water Cooler is replaced by a friendly Mimic. It copies the special ability of a random employee each work cycle.',
        effect = { type = 'water_cooler_mimic' }
    },


    -- LEGENDARY UPGRADES --
    { 
        id = 'borg_hivemind', name = 'Office Hivemind (The Borg)', rarity = 'Legendary', cost = 5000, icon = '🤖',
        description = 'All employees are removed. A single "Borg Drone" appears with their combined stats. Hire new employees to "assimilate" their stats.',
        effect = { type = 'borg_hivemind' },
        listeners = {
            onPurchase = function(self, gameState)
                if #gameState.hiredEmployees == 0 then
                    require("drawing").showModal("Assimilation Failed", "There is no one to assimilate.")
                    return
                end

                local totalProd, totalFocus = 0, 0
                for _, emp in ipairs(gameState.hiredEmployees) do
                    totalProd = totalProd + emp.baseProductivity
                    totalFocus = totalFocus + emp.baseFocus
                end

                gameState.hiredEmployees = {}
                gameState.deskAssignments = {}

                local Employee = require("employee")
                local borgDrone = Employee:new('borg_drone', 'standard', "Borg Drone")
                borgDrone.baseProductivity = totalProd
                borgDrone.baseFocus = totalFocus
                
                table.insert(gameState.hiredEmployees, borgDrone)
                require("placement"):handleEmployeeDropOnDesk(gameState, borgDrone, "desk-4", nil)

                require("drawing").showModal("Resistance is Futile", "Your team has been assimilated into a single Borg Drone. You are now the Hivemind.")
            end
        }
    },
    { 
        id = 'sentient_hr', name = 'Sentient Resources Department', rarity = 'Legendary', cost = 4000, icon = '🧑‍💼',
        description = 'At the start of each Sprint, fires the employee with the lowest contribution and replaces them with a new random one of the same rarity for free.',
        effect = { type = 'sentient_hr' },
        listeners = {
            onSprintStart = function(self, gameState, eventArgs)
                if #gameState.hiredEmployees > 0 then
                    local lowestContributor = nil
                    for _, emp in ipairs(gameState.hiredEmployees) do
                        if not lowestContributor or (emp.contributionThisSprint or 0) < (lowestContributor.contributionThisSprint or 0) then
                            lowestContributor = emp
                        end
                    end

                    if lowestContributor then
                        local firedName = lowestContributor.fullName
                        local firedRarity = lowestContributor.rarity
                        for i, emp in ipairs(gameState.hiredEmployees) do
                            if emp.instanceId == lowestContributor.instanceId then
                                table.remove(gameState.hiredEmployees, i)
                                if lowestContributor.deskId then gameState.deskAssignments[lowestContributor.deskId] = nil end
                                break
                            end
                        end
                        
                        local newHireOffer = require("shop"):_generateRandomEmployeeOfRarity(gameState, firedRarity)
                        local newHire = require("employee"):new(newHireOffer.id, newHireOffer.variant, newHireOffer.fullName)
                        table.insert(gameState.hiredEmployees, newHire)
                        
                        eventArgs.showModal = {
                            title = "Performance Review",
                            message = "Sentient Resources has optimized the team.\n" .. firedName .. " was let go. Please welcome " .. newHire.fullName .. ", the " .. newHire.name .. "!"
                        }
                    end
                end
            end
        }
    },
    { 
        id = 'fourth_wall', name = 'The 4th Wall', rarity = 'Legendary', cost = 6000, icon = '📺',
        description = 'The UI becomes a tool. Once per Sprint, you can physically drag the Workload bar down by 25%.',
        effect = { type = 'fourth_wall' },
        listeners = {
            onWorkloadBarClick = function(self, gameState, eventArgs)
                if gameState.gamePhase ~= 'hiring_and_upgrades' then return end
                
                if gameState.temporaryEffectFlags.fourthWallUsedThisSprint then
                    require("drawing").showModal("Already Used", "The 4th Wall can only be broken once per sprint.")
                    eventArgs.wasHandled = true
                    return
                end

                local sprintData = require("data").ALL_SPRINTS[gameState.currentSprintIndex]
                local workItemData = sprintData and sprintData.workItems[gameState.currentWorkItemIndex]
                if workItemData then
                    local reduction = math.floor(workItemData.workload * 0.25)
                    workItemData.workload = workItemData.workload - reduction
                    gameState.temporaryEffectFlags.fourthWallUsedThisSprint = true
                    require("drawing").showModal("CRACK!", "You reached through the screen and pulled the workload bar down, reducing the upcoming workload by 25%!")
                    eventArgs.wasHandled = true
                end
            end
        }
    },
    { 
        id = 'corporate_personhood', name = 'Corporate Personhood', rarity = 'Legendary', cost = 7500, icon = '🏛️',
        description = 'The Office itself becomes a Legendary employee in the center desk. Its stats scale with desks owned and upgrades purchased.',
        effect = { type = 'corporate_personhood' },
        listeners = {
            onPurchase = function(self, gameState)
                local Employee = require("employee")
                local Placement = require("placement")
                local Drawing = require("drawing")
                
                if gameState.deskAssignments['desk-4'] then
                    local evictedEmployee = Employee:getFromState(gameState, gameState.deskAssignments['desk-4'])
                    if evictedEmployee then
                        evictedEmployee.variant = 'remote'
                        evictedEmployee.deskId = nil
                        Drawing.showModal("Eviction Notice", evictedEmployee.name .. " was moved to remote work to make way for The Corporation.")
                    end
                    gameState.deskAssignments['desk-4'] = nil
                end

                local corporation = Employee:new('corporate_personhood_employee', 'standard', "The Corporation")
                if corporation then
                    local ownedDesks = Placement:getOwnedDeskCount(gameState)
                    corporation.baseProductivity = (ownedDesks * 20) + (#gameState.purchasedPermanentUpgrades * 10)
                    corporation.baseFocus = 1.0 + (ownedDesks * 0.1)

                    table.insert(gameState.hiredEmployees, corporation)
                    Placement:handleEmployeeDropOnDesk(gameState, corporation, "desk-4", nil)
                    Drawing.showModal("Manifestation!", "The Office itself has become a sentient entity, taking its rightful place at the center of power.")
                else
                    print("ERROR: Corporate Personhood is owned, but could not create 'corporate_personhood_employee'. Check its definition in data.lua.")
                end
            end
        }
    },
    { 
        id = 'multiverse_merger', name = 'Multiverse Merger', rarity = 'Legendary', cost = 3000, icon = '🌌',
        description = 'Once per run, swap your entire team with a randomly generated team from an alternate reality. High risk, high reward.',
        effect = { type = 'multiverse_merger' },
        listeners = {
            onPurchase = function(self, gameState)
                gameState.temporaryEffectFlags.multiverseMergerAvailable = true
                local Drawing = require("drawing")
                Drawing.showModal("Multiverse Merger", "An unstable portal is ready. Activate it from the Acquired Upgrades panel at any time... if you dare.")
            end,
            onActivate = function(self, gameState)
                if gameState.temporaryEffectFlags.multiverseMergerAvailable then
                    local Drawing = require("drawing")
                    local Shop = require("shop")
                    local Placement = require("placement")
                    
                    local confirmSwap = function()
                        local numEmployees = #gameState.hiredEmployees
                        if numEmployees == 0 then
                            Drawing.showModal("Merger Failed", "There is no team to merge with the multiverse.")
                            return
                        end
                        
                        gameState.hiredEmployees = {}
                        gameState.deskAssignments = {}
                        
                        local newTeam = {}
                        for i = 1, numEmployees do
                            table.insert(newTeam, Shop:_generateRandomEmployeeOffer(gameState))
                        end
                        
                        gameState.hiredEmployees = newTeam

                        local officeWorkers = {}
                        for _, emp in ipairs(gameState.hiredEmployees) do
                            if emp.variant ~= 'remote' then
                                table.insert(officeWorkers, emp)
                            end
                        end

                        for _, desk in ipairs(gameState.desks) do
                            if #officeWorkers == 0 then break end
                            if desk.status == 'owned' then
                                local worker = table.remove(officeWorkers, 1)
                                Placement:handleEmployeeDropOnDesk(gameState, worker, desk.id, nil)
                            end
                        end

                        gameState.temporaryEffectFlags.multiverseMergerAvailable = false
                        Drawing.showModal("Worlds Collide!", "Your team has been swapped with one from an alternate reality!")
                    end

                    Drawing.showModal("Confirm Merger", "Are you sure you want to swap your entire team with a random one from another dimension? This cannot be undone.", {
                        {text = "Yes, Do It!", onClick = confirmSwap, style="danger"},
                        {text = "No, Too Risky", onClick = function() Drawing.hideModal() end, style="primary"}
                    })
                    return true
                end
                return false
            end
        }
    },
    {
        id = 'brain_interface', name = 'Company-Mandated Brain-Computer Interface', rarity = 'Legendary', cost = 4500, icon = '🧠',
        description = 'All employees share a "hive mind." Their base stats are averaged out across the team, ignoring individual stats and positional bonuses.',
        effect = { type = 'brain_interface' },
        listeners = {
            onWorkItemStart = function(self, gameState, eventArgs)
                local totalProd, totalFocus, numEmployees = 0, 0, #gameState.hiredEmployees
                if numEmployees > 0 then
                    for _, emp in ipairs(gameState.hiredEmployees) do
                        totalProd = totalProd + emp.baseProductivity
                        totalFocus = totalFocus + emp.baseFocus
                    end
                    gameState.temporaryEffectFlags.hiveMindStats = {
                        productivity = math.floor(totalProd / numEmployees),
                        focus = totalFocus / numEmployees
                    }
                    print("Hive Mind Active. Avg Prod: " .. gameState.temporaryEffectFlags.hiveMindStats.productivity .. ", Avg Focus: " .. gameState.temporaryEffectFlags.hiveMindStats.focus)
                end
            end,
            onCalculateStats = function(self, gameState, eventArgs)
                if gameState.temporaryEffectFlags.hiveMindStats then
                    local hiveMindStats = gameState.temporaryEffectFlags.hiveMindStats
                    eventArgs.employee = {
                        instanceId = eventArgs.employee.instanceId,
                        baseProductivity = hiveMindStats.productivity,
                        baseFocus = hiveMindStats.focus,
                        level = eventArgs.employee.level,
                        variant = eventArgs.employee.variant,
                        deskId = eventArgs.employee.deskId
                    }
                end
            end
        }
        },
}