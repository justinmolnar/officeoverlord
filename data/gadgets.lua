-- Gadgets provided by Q


return {
    {
        id = 'gadget_cash', name = 'Briefcase of Cash', 
        description = 'A simple, non-traceable briefcase of cash. Gain $3000 at the start of this sprint.',
        effect = { type = 'budget_add_flat', value = 3000 },
        listeners = {
            onUse = function(self, gameState, eventArgs)
                if not gameState.ventureCapitalActive then
                    gameState.budget = gameState.budget + (self.effect.value or 3000)
                end
                eventArgs.showModal = {
                    title = "Gadget from Q!",
                    message = "The Quartermaster provided a '" .. self.name .. "'.\n" .. self.description
                }
            end
        }
    },
    {
        id = 'gadget_pen', name = 'Exploding Pen', 
        description = 'Not as dangerous as it sounds. Your highest-base-productivity employee gets +10 permanent base productivity.',
        effect = { type = 'perm_prod_boost_highest_prod', value = 10 },
        listeners = {
            onUse = function(self, gameState, eventArgs)
                local highestProdEmp = nil
                for _, emp in ipairs(gameState.hiredEmployees) do
                    if not highestProdEmp or emp.baseProductivity > highestProdEmp.baseProductivity then
                        highestProdEmp = emp
                    end
                end
                if highestProdEmp then
                    highestProdEmp.baseProductivity = highestProdEmp.baseProductivity + (self.effect.value or 10)

                    eventArgs.showModal = {
                        title = "Gadget from Q!",
                        message = "The Quartermaster provided a '" .. self.name .. "'.\n" .. highestProdEmp.fullName .. " has been permanently boosted!"
                    }
                end
            end
        }
    },  
}