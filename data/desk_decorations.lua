-- data/desk_decorations.lua
-- Desk decorations that can be placed on individual desks to provide bonuses

return {
    -- COMMON DECORATIONS --
    {
        id = 'gamer_mouse', 
        name = 'Gaming Mouse', 
        icon = '🖱️', 
        rarity = 'Common', 
        cost = 300, 
        description = 'A high-precision gaming mouse. +5 Productivity to the employee at this desk.',
        effect = { 
            type = 'desk_productivity_add', 
            value = 5 
        },
        listeners = {
            onCalculateStats = {
                {
                    phase = 'BaseApplication',
                    priority = 50,
                    callback = function(self, gameState, services, eventArgs, deskId)
                        if eventArgs.employee.deskId == deskId then
                            eventArgs.stats.productivity = eventArgs.stats.productivity + (self.effect.value or 5)
                            table.insert(eventArgs.stats.log.productivity, string.format("+%d from %s", self.effect.value or 5, self.name))
                        end
                    end
                }
            }
        }
    },
    {
        id = 'stress_ball', 
        name = 'Stress Ball', 
        icon = '⚽', 
        rarity = 'Common', 
        cost = 150, 
        description = 'A squishy stress relief ball. +0.2x Focus to the employee at this desk.',
        effect = { 
            type = 'desk_focus_add', 
            value = 0.2 
        },
        listeners = {
            onCalculateStats = {
                {
                    phase = 'BaseApplication',
                    priority = 50,
                    callback = function(self, gameState, services, eventArgs, deskId)
                        if eventArgs.employee.deskId == deskId then
                            eventArgs.stats.focus = eventArgs.stats.focus + (self.effect.value or 0.2)
                            table.insert(eventArgs.stats.log.focus, string.format("+%.2fx from %s", self.effect.value or 0.2, self.name))
                        end
                    end
                }
            }
        }
    },
    {
        id = 'desk_plant', 
        name = 'Small Desk Plant', 
        icon = '🌿', 
        rarity = 'Common', 
        cost = 200, 
        description = 'A small potted plant that brightens the workspace. +3 Productivity and +0.1x Focus.',
        effect = { 
            type = 'desk_mixed_bonus', 
            productivity_add = 3, 
            focus_add = 0.1 
        },
        listeners = {
            onCalculateStats = {
                {
                    phase = 'BaseApplication',
                    priority = 50,
                    callback = function(self, gameState, services, eventArgs, deskId)
                        if eventArgs.employee.deskId == deskId then
                            eventArgs.stats.productivity = eventArgs.stats.productivity + (self.effect.productivity_add or 3)
                            eventArgs.stats.focus = eventArgs.stats.focus + (self.effect.focus_add or 0.1)
                            table.insert(eventArgs.stats.log.productivity, string.format("+%d from %s", self.effect.productivity_add or 3, self.name))
                            table.insert(eventArgs.stats.log.focus, string.format("+%.2fx from %s", self.effect.focus_add or 0.1, self.name))
                        end
                    end
                }
            }
        }
    },
    {
        id = 'motivational_poster', 
        name = 'Motivational Poster', 
        icon = '🖼️', 
        rarity = 'Common', 
        cost = 100, 
        description = '"Hang in there!" A classic motivational poster. +0.3x Focus to this desk.',
        effect = { 
            type = 'desk_focus_add', 
            value = 0.3 
        },
        listeners = {
            onCalculateStats = {
                {
                    phase = 'BaseApplication',
                    priority = 50,
                    callback = function(self, gameState, services, eventArgs, deskId)
                        if eventArgs.employee.deskId == deskId then
                            eventArgs.stats.focus = eventArgs.stats.focus + (self.effect.value or 0.3)
                            table.insert(eventArgs.stats.log.focus, string.format("+%.2fx from %s", self.effect.value or 0.3, self.name))
                        end
                    end
                }
            }
        }
    },

    -- UNCOMMON DECORATIONS --
    {
        id = 'ergonomic_chair', 
        name = 'Ergonomic Chair', 
        icon = '🪑', 
        rarity = 'Uncommon', 
        cost = 800, 
        description = 'A premium ergonomic office chair. +8 Productivity and +0.15x Focus.',
        effect = { 
            type = 'desk_mixed_bonus', 
            productivity_add = 8, 
            focus_add = 0.15 
        },
        listeners = {
            onCalculateStats = {
                {
                    phase = 'BaseApplication',
                    priority = 50,
                    callback = function(self, gameState, services, eventArgs, deskId)
                        if eventArgs.employee.deskId == deskId then
                            eventArgs.stats.productivity = eventArgs.stats.productivity + (self.effect.productivity_add or 8)
                            eventArgs.stats.focus = eventArgs.stats.focus + (self.effect.focus_add or 0.15)
                            table.insert(eventArgs.stats.log.productivity, string.format("+%d from %s", self.effect.productivity_add or 8, self.name))
                            table.insert(eventArgs.stats.log.focus, string.format("+%.2fx from %s", self.effect.focus_add or 0.15, self.name))
                        end
                    end
                }
            }
        }
    },
    {
        id = 'dual_monitors', 
        name = 'Dual Monitor Setup', 
        icon = '🖥️', 
        rarity = 'Uncommon', 
        cost = 1200, 
        description = 'Two monitors for maximum productivity. +12 Productivity to this desk.',
        effect = { 
            type = 'desk_productivity_add', 
            value = 12 
        },
        listeners = {
            onCalculateStats = {
                {
                    phase = 'BaseApplication',
                    priority = 50,
                    callback = function(self, gameState, services, eventArgs, deskId)
                        if eventArgs.employee.deskId == deskId then
                            eventArgs.stats.productivity = eventArgs.stats.productivity + (self.effect.value or 12)
                            table.insert(eventArgs.stats.log.productivity, string.format("+%d from %s", self.effect.value or 12, self.name))
                        end
                    end
                }
            }
        }
    },
    {
        id = 'white_noise_machine', 
        name = 'White Noise Machine', 
        icon = '🔊', 
        rarity = 'Uncommon', 
        cost = 600, 
        description = 'Blocks out distractions. +0.4x Focus to this desk and +0.1x Focus to adjacent desks.',
        effect = { 
            type = 'desk_area_focus', 
            desk_focus_add = 0.4, 
            adjacent_focus_add = 0.1 
        },
        listeners = {
            onCalculateStats = {
                {
                    phase = 'BaseApplication',
                    priority = 50,
                    callback = function(self, gameState, services, eventArgs, deskId)
                        local empDeskId = eventArgs.employee.deskId
                        if not empDeskId then return end
                        
                        -- Bonus for the desk it's on
                        if empDeskId == deskId then
                            eventArgs.stats.focus = eventArgs.stats.focus + (self.effect.desk_focus_add or 0.4)
                            table.insert(eventArgs.stats.log.focus, string.format("+%.2fx from %s", self.effect.desk_focus_add or 0.4, self.name))
                        end

                        -- Bonus for adjacent desks
                        local directions = {"up", "down", "left", "right"}
                        for _, dir in ipairs(directions) do
                            if require("placement"):getNeighboringDeskId(deskId, dir, require("data").GRID_WIDTH, require("data").TOTAL_DESK_SLOTS, gameState.desks) == empDeskId then
                                eventArgs.stats.focus = eventArgs.stats.focus + (self.effect.adjacent_focus_add or 0.1)
                                table.insert(eventArgs.stats.log.focus, string.format("+%.2fx from adjacent %s", self.effect.adjacent_focus_add or 0.1, self.name))
                                break -- Apply only once
                            end
                        end
                    end
                }
            }
        }
    },
    {
        id = 'mini_fridge', 
        name = 'Mini Fridge', 
        icon = '🧊', 
        rarity = 'Uncommon', 
        cost = 900, 
        description = 'Keeps snacks and drinks cold. +2 Productivity to all adjacent desks.',
        effect = { 
            type = 'desk_area_productivity', 
            adjacent_productivity_add = 2 
        },
        listeners = {
            onCalculateStats = {
                {
                    phase = 'BaseApplication',
                    priority = 50,
                    callback = function(self, gameState, services, eventArgs, deskId)
                        local empDeskId = eventArgs.employee.deskId
                        if not empDeskId then return end

                        local directions = {"up", "down", "left", "right"}
                        for _, dir in ipairs(directions) do
                            if require("placement"):getNeighboringDeskId(deskId, dir, require("data").GRID_WIDTH, require("data").TOTAL_DESK_SLOTS, gameState.desks) == empDeskId then
                                eventArgs.stats.productivity = eventArgs.stats.productivity + (self.effect.adjacent_productivity_add or 2)
                                table.insert(eventArgs.stats.log.productivity, string.format("+%d from adjacent %s", self.effect.adjacent_productivity_add or 2, self.name))
                                break -- Apply only once
                            end
                        end
                    end
                }
            }
        }
    },

    -- RARE DECORATIONS --
    {
        id = 'standing_desk', 
        name = 'Standing Desk Converter', 
        icon = '⬆️', 
        rarity = 'Rare', 
        cost = 1500, 
        description = 'Promotes better health and alertness. +10 Productivity and +0.5x Focus.',
        effect = { 
            type = 'desk_mixed_bonus', 
            productivity_add = 10, 
            focus_add = 0.5 
        },
        listeners = {
            onCalculateStats = {
                {
                    phase = 'BaseApplication',
                    priority = 50,
                    callback = function(self, gameState, services, eventArgs, deskId)
                        if eventArgs.employee.deskId == deskId then
                            eventArgs.stats.productivity = eventArgs.stats.productivity + (self.effect.productivity_add or 10)
                            eventArgs.stats.focus = eventArgs.stats.focus + (self.effect.focus_add or 0.5)
                            table.insert(eventArgs.stats.log.productivity, string.format("+%d from %s", self.effect.productivity_add or 10, self.name))
                            table.insert(eventArgs.stats.log.focus, string.format("+%.2fx from %s", self.effect.focus_add or 0.5, self.name))
                        end
                    end
                }
            }
        }
    },
    {
        id = 'personal_assistant_ai', 
        name = 'Personal AI Assistant', 
        icon = '🤖', 
        rarity = 'Rare', 
        cost = 2500, 
        description = 'An AI assistant that handles routine tasks. +15 Productivity to this desk.',
        effect = { 
            type = 'desk_productivity_add', 
            value = 15 
        },
        listeners = {
            onCalculateStats = {
                {
                    phase = 'BaseApplication',
                    priority = 50,
                    callback = function(self, gameState, services, eventArgs, deskId)
                        if eventArgs.employee.deskId == deskId then
                            eventArgs.stats.productivity = eventArgs.stats.productivity + (self.effect.value or 15)
                            table.insert(eventArgs.stats.log.productivity, string.format("+%d from %s", self.effect.value or 15, self.name))
                        end
                    end
                }
            }
        }
    },
    {
        id = 'zen_garden', 
        name = 'Desktop Zen Garden', 
        icon = '🏯', 
        rarity = 'Rare', 
        cost = 1800, 
        description = 'A miniature zen garden for meditation. +0.8x Focus to this desk and reduces negative focus effects by 50%.',
        effect = { 
            type = 'desk_focus_protection', 
            focus_add = 0.8, 
            negative_reduction = 0.5 
        },
        listeners = {
            onCalculateStats = {
                {
                    phase = 'BaseApplication',
                    priority = 50,
                    callback = function(self, gameState, services, eventArgs, deskId)
                        if eventArgs.employee.deskId == deskId then
                            eventArgs.stats.focus = eventArgs.stats.focus + (self.effect.focus_add or 0.8)
                            table.insert(eventArgs.stats.log.focus, string.format("+%.2fx from %s", self.effect.focus_add or 0.8, self.name))
                            
                            -- The reduction of negative effects will be handled by a listener
                            -- on employees with negative focus effects, which will check if the
                            -- employee has this decoration. This is a more complex interaction
                            -- that will be addressed when positional effects are moved to listeners.
                        end
                    end
                }
            }
        }
    },

    -- LEGENDARY DECORATIONS --
    {
        id = 'holographic_display', 
        name = 'Holographic Interface', 
        icon = '✨', 
        rarity = 'Legendary', 
        cost = 5000, 
        description = 'A futuristic holographic workspace. +25 Productivity and +1.0x Focus to this desk.',
        effect = { 
            type = 'desk_mixed_bonus', 
            productivity_add = 25, 
            focus_add = 1.0 
        },
        listeners = {
            onCalculateStats = {
                {
                    phase = 'BaseApplication',
                    priority = 50,
                    callback = function(self, gameState, services, eventArgs, deskId)
                        if eventArgs.employee.deskId == deskId then
                            eventArgs.stats.productivity = eventArgs.stats.productivity + (self.effect.productivity_add or 25)
                            eventArgs.stats.focus = eventArgs.stats.focus + (self.effect.focus_add or 1.0)
                            table.insert(eventArgs.stats.log.productivity, string.format("+%d from %s", self.effect.productivity_add or 25, self.name))
                            table.insert(eventArgs.stats.log.focus, string.format("+%.2fx from %s", self.effect.focus_add or 1.0, self.name))
                        end
                    end
                }
            }
        }
    },
    {
        id = 'personal_coffee_machine', 
        name = 'Personal Espresso Machine', 
        icon = '☕', 
        rarity = 'Legendary', 
        cost = 4000, 
        description = 'The finest coffee at your fingertips. +0.6x Focus to this desk and +0.2x Focus to all adjacent desks.',
        effect = { 
            type = 'desk_area_focus', 
            desk_focus_add = 0.6, 
            adjacent_focus_add = 0.2 
        },
        listeners = {
            onCalculateStats = {
                {
                    phase = 'BaseApplication',
                    priority = 50,
                    callback = function(self, gameState, services, eventArgs, deskId)
                        local empDeskId = eventArgs.employee.deskId
                        if not empDeskId then return end
                        
                        -- Bonus for the desk it's on
                        if empDeskId == deskId then
                            eventArgs.stats.focus = eventArgs.stats.focus + (self.effect.desk_focus_add or 0.6)
                            table.insert(eventArgs.stats.log.focus, string.format("+%.2fx from %s", self.effect.desk_focus_add or 0.6, self.name))
                        end

                        -- Bonus for adjacent desks
                        local directions = {"up", "down", "left", "right"}
                        for _, dir in ipairs(directions) do
                            if require("placement"):getNeighboringDeskId(deskId, dir, require("data").GRID_WIDTH, require("data").TOTAL_DESK_SLOTS, gameState.desks) == empDeskId then
                                eventArgs.stats.focus = eventArgs.stats.focus + (self.effect.adjacent_focus_add or 0.2)
                                table.insert(eventArgs.stats.log.focus, string.format("+%.2fx from adjacent %s", self.effect.adjacent_focus_add or 0.2, self.name))
                                break
                            end
                        end
                    end
                }
            }
        }
    }
}