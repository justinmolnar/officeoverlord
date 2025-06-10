-- Game Constants (balance these as needed)

return {
    REMOTE_HIRING_BONUS_MODIFIER = 1.3,
    REMOTE_SALARY_MODIFIER = 1.2,
    BASE_RESTOCK_COST = 200,
    DESK_PURCHASE_COST = 1000,
    TOTAL_DESK_SLOTS = 9, -- Fixed 3x3 grid
    GRID_WIDTH = 3,
    STARTING_BUDGET = 20000,
    STARTING_BAILOUTS = 2,
    --BAILOUT_BUDGET_AMOUNT = math.floor(STARTING_BUDGET / 2)
    BASE_CYCLE_DELAY_MS = 500,       -- Base delay for a full round of work if one employee
    PER_EMPLOYEE_CYCLE_DELAY_MS = 250, -- Additional delay per employee in the work round
    OFFICE_DOG_CHANCE = 0.10,       -- 10% chance per employee turn
    MAX_EMPLOYEE_LEVEL = 3,
}
