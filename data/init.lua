-- data/init.lua
local data = {}

-- Load the raw constants first
local constants = require("data.constants")
for key, value in pairs(constants) do
    data[key] = value
end

-- NOW calculate any values that depend on other constants
data.BAILOUT_BUDGET_AMOUNT = math.floor(data.STARTING_BUDGET / 2)

-- Continue loading the rest of your data
data.BASE_EMPLOYEE_CARDS = require("data.employees")
data.ALL_UPGRADES = require("data.upgrades")
data.ALL_SPRINTS = require("data.sprints")
data.ALL_GADGETS = require("data.gadgets")
data.GLADOS_NEGATIVE_MODIFIERS = require("data.modifiers")
data.ALL_DESK_DECORATIONS = require("data.desk_decorations") 

return data