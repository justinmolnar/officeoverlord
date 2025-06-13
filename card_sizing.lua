-- card_sizing.lua
-- Centralized card sizing utility to stop the madness of duplicated calculations

local CardSizing = {}

function CardSizing.getStandardCardDimensions()
    local screenW = love.graphics.getWidth()
    local padding = 10
    local shopWidth = math.floor(screenW * 0.16)
    local shopCardPadding = 5
    local cardWidth = shopWidth - 2 * shopCardPadding
    local cardHeight = 140
    
    return {
        width = cardWidth,
        height = cardHeight,
        shopWidth = shopWidth,
        shopPadding = shopCardPadding
    }
end

-- Convenience functions for when you just need one dimension
function CardSizing.getCardWidth()
    return CardSizing.getStandardCardDimensions().width
end

function CardSizing.getCardHeight()
    return CardSizing.getStandardCardDimensions().height
end

return CardSizing