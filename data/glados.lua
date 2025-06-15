--Glados modifiers

return {
    { 
        description = 'Neurotoxin leak reduces all employee Focus by 20% for the next item.',
        effect = { type = 'temp_focus_penalty', value = 0.8 },
        listeners = {
            onApply = {
                {
                    phase = 'BaseApplication',
                    priority = 50,
                    callback = function(self, gameState)
                        gameState.temporaryEffectFlags.globalFocusMultiplier = self.effect.value
                    end
                }
            }
        }
    },
    { 
        description = 'Surprise "performance-based salary adjustments" increase all salaries by 20% for the next item.',
        effect = { type = 'temp_salary_increase', value = 1.2 },
        listeners = {
            onApply = {
                {
                    phase = 'BaseApplication',
                    priority = 50,
                    callback = function(self, gameState)
                        gameState.temporaryEffectFlags.globalSalaryMultiplier = self.effect.value
                    end
                }
            }
        }
    },
    {
        description = 'The Enrichment Center has scheduled "mandatory maintenance" on the top floor. Top row of desks is disabled.',
        effect = { type = 'disable_top_row' },
        listeners = {
            onApply = {
                {
                    phase = 'BaseApplication',
                    priority = 50,
                    callback = function(self, gameState)
                        gameState.temporaryEffectFlags.isTopRowDisabled = true
                    end
                }
            }
        }
    },
    {
        description = 'Remote work privileges have been temporarily suspended for... testing purposes.',
        effect = { type = 'disable_remote_workers' },
        listeners = {
            onApply = {
                {
                    phase = 'BaseApplication',
                    priority = 50,
                    callback = function(self, gameState)
                        gameState.temporaryEffectFlags.isRemoteWorkDisabled = true
                    end
                }
            }
        }
    },
}