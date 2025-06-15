-- modifier_manager.lua
-- Manages selection, filtering, and assignment of work item modifiers

local GameData = require("data")

local ModifierManager = {}

-- Probability curves that change based on game progression
local PROGRESSION_MODIFIERS = {
   -- Base probabilities increase as game progresses
   probabilityBySprintIndex = {
       [1] = 0.20,  -- Sprint 1: 20% chance
       [2] = 0.25,  -- Sprint 2: 25% chance  
       [3] = 0.30,  -- Sprint 3: 30% chance
       [4] = 0.35,  -- Sprint 4: 35% chance
       [5] = 0.40,  -- Sprint 5: 40% chance
       [6] = 0.45,  -- Sprint 6: 45% chance
       [7] = 0.50,  -- Sprint 7: 50% chance
       [8] = 0.55   -- Sprint 8: 55% chance
   },
   
   -- Rarity weights shift toward higher rarities in later sprints
   rarityWeightsBySprintRange = {
       early = { -- Sprints 1-2
           Common = 60,
           Uncommon = 25,
           Rare = 10,
           Legendary = 4,
           ["Cosmic Horror"] = 0,
           Experimental = 1
       },
       mid = { -- Sprints 3-5
           Common = 45,
           Uncommon = 30,
           Rare = 15,
           Legendary = 8,
           ["Cosmic Horror"] = 1,
           Experimental = 1
       },
       late = { -- Sprints 6-8
           Common = 35,
           Uncommon = 30,
           Rare = 20,
           Legendary = 12,
           ["Cosmic Horror"] = 2,
           Experimental = 1
       }
   }
}

-- Minimum rarity requirements
local MIN_RARITY_BY_TYPE = {
   regular = nil,    -- No minimum for regular items
   boss = "Uncommon" -- Boss items must be Uncommon or higher
}

function ModifierManager:getAvailableModifiers()
   return GameData.ALL_MODIFIERS
end

function ModifierManager:getProgressionWeights(sprintIndex)
   if sprintIndex <= 2 then
       return PROGRESSION_MODIFIERS.rarityWeightsBySprintRange.early
   elseif sprintIndex <= 5 then
       return PROGRESSION_MODIFIERS.rarityWeightsBySprintRange.mid
   else
       return PROGRESSION_MODIFIERS.rarityWeightsBySprintRange.late
   end
end

function ModifierManager:calculateModifierProbability(gameState, sprintIndex, workItemIndex, isBossItem)
   -- Boss items always get modifiers
   if isBossItem then
       return 1.0
   end
   
   -- Base probability from progression curve
   local baseProbability = PROGRESSION_MODIFIERS.probabilityBySprintIndex[sprintIndex] or 0.35
   
   -- Modifiers that affect probability
   local probabilityModifiers = 1.0
   
   -- Check for upgrades that affect modifier frequency
   local eventArgs = { 
       baseProbability = baseProbability,
       probabilityMultiplier = 1.0,
       bonusProbability = 0.0
   }
   require("effects_dispatcher").dispatchEvent("onCalculateModifierProbability", gameState, {}, eventArgs)
   
   -- Apply event modifications
   local finalProbability = (eventArgs.baseProbability + eventArgs.bonusProbability) * eventArgs.probabilityMultiplier
   
   -- Work item position modifiers
   if workItemIndex == 3 then -- Boss items (though they're already 1.0)
       finalProbability = finalProbability * 1.0
   elseif workItemIndex == 2 then -- Second work item slightly more likely
       finalProbability = finalProbability * 1.1
   end
   
   -- Team composition effects
   local teamSize = #gameState.hiredEmployees
   if teamSize >= 6 then
       finalProbability = finalProbability * 1.15 -- More employees = more chaos
   elseif teamSize <= 2 then
       finalProbability = finalProbability * 0.8 -- Small teams get fewer modifiers
   end
   
   -- Clamp between 0 and 1
   return math.max(0, math.min(1, finalProbability))
end

function ModifierManager:filterModifiersByContext(modifiers, context)
   local filtered = {}
   
   for _, modifier in ipairs(modifiers) do
       local isValid = true
       
       -- Filter by sprint restrictions if any
       if modifier.sprintRestrictions then
           if modifier.sprintRestrictions.notInSprints then
               for _, restrictedSprint in ipairs(modifier.sprintRestrictions.notInSprints) do
                   if context.sprintIndex == restrictedSprint then
                       isValid = false
                       break
                   end
               end
           end
           
           if modifier.sprintRestrictions.onlyInSprints then
               local foundMatch = false
               for _, allowedSprint in ipairs(modifier.sprintRestrictions.onlyInSprints) do
                   if context.sprintIndex == allowedSprint then
                       foundMatch = true
                       break
                   end
               end
               if not foundMatch then
                   isValid = false
               end
           end
       end
       
       -- Filter by work item type restrictions
       if modifier.workItemRestrictions then
           if modifier.workItemRestrictions.notForBoss and context.isBossItem then
               isValid = false
           end
           
           if modifier.workItemRestrictions.onlyForBoss and not context.isBossItem then
               isValid = false
           end
       end
       
       -- Filter by game state requirements
       if modifier.requirements then
           if modifier.requirements.minEmployees and context.employeeCount < modifier.requirements.minEmployees then
               isValid = false
           end
           
           if modifier.requirements.maxEmployees and context.employeeCount > modifier.requirements.maxEmployees then
               isValid = false
           end
           
           if modifier.requirements.hasUpgrade then
               local hasRequired = false
               for _, upgradeId in ipairs(context.purchasedUpgrades) do
                   if upgradeId == modifier.requirements.hasUpgrade then
                       hasRequired = true
                       break
                   end
               end
               if not hasRequired then
                   isValid = false
               end
           end
       end
       
       if isValid then
           table.insert(filtered, modifier)
       end
   end
   
   return filtered
end

function ModifierManager:selectModifierByRarity(modifiers, minRarity, sprintIndex)
   if #modifiers == 0 then return nil end
   
   -- Convert rarity names to numeric values for comparison
   local rarityValues = {
       Common = 1,
       Uncommon = 2,
       Rare = 3,
       Legendary = 4,
       ["Cosmic Horror"] = 5,
       Experimental = 6
   }
   
   local minRarityValue = minRarity and rarityValues[minRarity] or 0
   
   -- Get progression-appropriate weights
   local weights = self:getProgressionWeights(sprintIndex)
   
   -- Create weighted pool based on rarity
   local weightedPool = {}
   
   for _, modifier in ipairs(modifiers) do
       local modifierRarityValue = rarityValues[modifier.rarity] or 1
       
       -- Only include modifiers that meet minimum rarity requirement
       if modifierRarityValue >= minRarityValue then
           local weight = weights[modifier.rarity] or 1
           for _ = 1, weight do
               table.insert(weightedPool, modifier)
           end
       end
   end
   
   if #weightedPool == 0 then
       print("WARNING: No modifiers available meeting rarity requirement: " .. tostring(minRarity))
       return nil
   end
   
   local randomIndex = love.math.random(#weightedPool)
   return weightedPool[randomIndex]
end

function ModifierManager:shouldAssignModifier(gameState, sprintIndex, workItemIndex, isBossItem)
   local probability = self:calculateModifierProbability(gameState, sprintIndex, workItemIndex, isBossItem)
   local roll = love.math.random()
   
   print(string.format("Modifier probability check: %.2f%% (rolled %.2f%%)", 
       probability * 100, roll * 100))
   
   return roll < probability
end

function ModifierManager:assignModifierToWorkItem(gameState, sprintIndex, workItemIndex)
    local sprint = GameData.ALL_SPRINTS[sprintIndex]
    if not sprint then return nil end
    
    local workItem = sprint.workItems[workItemIndex]
    if not workItem then return nil end
    
    -- Determine work item type
    local isBossItem = workItem.id and workItem.id:find("boss") ~= nil
    local workItemType = isBossItem and "boss" or "regular"
    
    -- Check if we should assign a modifier using new probability system
    if not self:shouldAssignModifier(gameState, sprintIndex, workItemIndex, isBossItem) then
        print("No modifier assigned to " .. workItem.name .. " (probability check failed)")
        self:logModifierAssignment(gameState, sprintIndex, workItemIndex, false, nil)
        return nil
    end
    
    -- Build context for filtering
    local context = {
        sprintIndex = sprintIndex,
        workItemIndex = workItemIndex,
        isBossItem = isBossItem,
        employeeCount = #gameState.hiredEmployees,
        purchasedUpgrades = gameState.purchasedPermanentUpgrades or {}
    }
    
    -- Get and filter available modifiers
    local allModifiers = self:getAvailableModifiers()
    local filteredModifiers = self:filterModifiersByContext(allModifiers, context)
    
    if #filteredModifiers == 0 then
        print("No valid modifiers available for " .. workItem.name)
        return nil
    end
    
    -- Select modifier based on minimum rarity requirements and progression
    local minRarity = MIN_RARITY_BY_TYPE[workItemType]
    local selectedModifier = self:selectModifierByRarity(filteredModifiers, minRarity, sprintIndex)
    
    if selectedModifier then
        print("=== MODIFIER ASSIGNMENT ===")
        print("Assigned modifier '" .. selectedModifier.name .. "' (" .. selectedModifier.rarity .. ") to " .. workItem.name)
        print("Modifier ID: " .. selectedModifier.id)
        print("Description: " .. selectedModifier.description)
        if selectedModifier.listeners then
            print("Listeners available:")
            for eventName, handlers in pairs(selectedModifier.listeners) do
                print("  - " .. eventName .. " (" .. #handlers .. " handlers)")
            end
        else
            print("ERROR: No listeners found for modifier!")
        end
        print("========================")
        
        -- Create a copy of the modifier for this work item
        local modifierInstance = {}
        for k, v in pairs(selectedModifier) do
            if type(v) == "table" then
                modifierInstance[k] = {}
                for nk, nv in pairs(v) do
                    if type(nv) == "table" then
                        modifierInstance[k][nk] = {}
                        for nnk, nnv in pairs(nv) do
                            modifierInstance[k][nk][nnk] = nnv
                        end
                    else
                        modifierInstance[k][nk] = nv
                    end
                end
            else
                modifierInstance[k] = v
            end
        end
        
        self:logModifierAssignment(gameState, sprintIndex, workItemIndex, true, selectedModifier)
        return modifierInstance
    end
    
    return nil
end

function ModifierManager:assignModifiersToSprint(gameState, sprintIndex)
   local sprint = GameData.ALL_SPRINTS[sprintIndex]
   if not sprint then return end
   
   print("Assigning modifiers to Sprint " .. sprintIndex .. ": " .. sprint.sprintName)
   
   for workItemIndex, workItem in ipairs(sprint.workItems) do
       -- Only assign if the work item doesn't already have a modifier
       if not workItem.modifier then
           local modifier = self:assignModifierToWorkItem(gameState, sprintIndex, workItemIndex)
           if modifier then
               workItem.modifier = modifier
           end
       end
   end
end

function ModifierManager:previewUpcomingModifiers(gameState, sprintIndex, lookaheadCount)
   local previews = {}
   lookaheadCount = lookaheadCount or 1
   
   for i = 0, lookaheadCount - 1 do
       local targetSprintIndex = sprintIndex + i
       local sprint = GameData.ALL_SPRINTS[targetSprintIndex]
       
       if sprint then
           local sprintPreviews = {}
           
           for workItemIndex, workItem in ipairs(sprint.workItems) do
               if workItem.modifier then
                   table.insert(sprintPreviews, {
                       workItemName = workItem.name,
                       modifierName = workItem.modifier.name,
                       modifierDescription = workItem.modifier.description,
                       rarity = workItem.modifier.rarity
                   })
               end
           end
           
           if #sprintPreviews > 0 then
               previews[targetSprintIndex] = sprintPreviews
           end
       end
   end
   
   return previews
end

function ModifierManager:initializeSprintModifiers(gameState)
   -- Don't assign modifiers at game start - wait until sprints are accessed
   print("Modifier Manager initialized - modifiers will be assigned dynamically")
end

function ModifierManager:ensureSprintHasModifiers(gameState, sprintIndex)
   local sprint = GameData.ALL_SPRINTS[sprintIndex]
   if not sprint then return end
   
   -- Check if this sprint already has modifiers assigned
   local hasModifiers = false
   for _, workItem in ipairs(sprint.workItems) do
       if workItem.modifier then
           hasModifiers = true
           break
       end
   end
   
   -- If no modifiers exist, assign them now
   if not hasModifiers then
       print("Dynamically assigning modifiers to Sprint " .. sprintIndex .. ": " .. sprint.sprintName)
       self:assignModifiersToSprint(gameState, sprintIndex)
   end
end

function ModifierManager:getWorkItemWithModifier(gameState, sprintIndex, workItemIndex)
   -- Ensure the sprint has modifiers before returning the work item
   self:ensureSprintHasModifiers(gameState, sprintIndex)
   
   local sprint = GameData.ALL_SPRINTS[sprintIndex]
   if sprint and sprint.workItems[workItemIndex] then
       return sprint.workItems[workItemIndex]
   end
   
   return nil
end

function ModifierManager:getModifierStatistics(gameState)
   local stats = {
       totalWorkItems = 0,
       modifiedWorkItems = 0,
       modifiersByRarity = {
           Common = 0,
           Uncommon = 0,
           Rare = 0,
           Legendary = 0,
           ["Cosmic Horror"] = 0,
           Experimental = 0
       }
   }
   
   for sprintIndex = 1, gameState.currentSprintIndex do
       local sprint = GameData.ALL_SPRINTS[sprintIndex]
       if sprint then
           for workItemIndex, workItem in ipairs(sprint.workItems) do
               stats.totalWorkItems = stats.totalWorkItems + 1
               
               if workItem.modifier then
                   stats.modifiedWorkItems = stats.modifiedWorkItems + 1
                   local rarity = workItem.modifier.rarity or "Common"
                   stats.modifiersByRarity[rarity] = (stats.modifiersByRarity[rarity] or 0) + 1
               end
           end
       end
   end
   
   stats.modificationRate = stats.totalWorkItems > 0 and (stats.modifiedWorkItems / stats.totalWorkItems) or 0
   
   return stats
end

function ModifierManager:logModifierAssignment(gameState, sprintIndex, workItemIndex, assigned, modifier)
   local workItem = GameData.ALL_SPRINTS[sprintIndex].workItems[workItemIndex]
   local isBoss = workItem.id and workItem.id:find("boss") ~= nil
   
   local logEntry = string.format("Sprint %d, Item %d (%s): %s", 
       sprintIndex, 
       workItemIndex, 
       isBoss and "BOSS" or "regular",
       assigned and ("ASSIGNED " .. modifier.name .. " (" .. modifier.rarity .. ")") or "NO MODIFIER"
   )
   
   print("MODIFIER LOG: " .. logEntry)
   
   -- Could also write to a file for analysis
   -- love.filesystem.append("modifier_log.txt", logEntry .. "\n")
end

return ModifierManager