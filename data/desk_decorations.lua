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
        }
    }
}