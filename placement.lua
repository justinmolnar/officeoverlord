-- placement.lua
-- Manages the office floor grid, desk purchases, and employee placement/movement/leveling.

local GameData = require("data")
local Employee = require("employee") 
local Drawing = require("drawing")

local function getEmployeeFromGameState(gs, instanceId)
    if not gs or not gs.hiredEmployees or not instanceId then return nil end
    for _, emp in ipairs(gs.hiredEmployees) do
        if emp.instanceId == instanceId then return emp end
    end
    return nil
end

local Placement = {}

function Placement:updateDeskAvailability(gameStateDesks)
    local desk8, desk5, desk7
    if gameStateDesks then
        for _, desk in ipairs(gameStateDesks) do
            if desk.id == "desk-8" then desk8 = desk end
            if desk.id == "desk-5" then desk5 = desk end
            if desk.id == "desk-7" then desk7 = desk end
        end
        if desk8 and desk5 and desk7 and desk8.status == "locked" then
            if desk5.status == "owned" or desk7.status == "owned" then
                desk8.status = "purchasable"
                print("Desk 8 has become purchasable!")
            end
        end
    end
end

function Placement:getOwnedDeskCount(gameState)
    local count = 0
    if gameState and gameState.desks then
        for _, desk in ipairs(gameState.desks) do
            if desk.status == "owned" then count = count + 1 end
        end
    end
    return count
end

function Placement:performReOrgSwap(gameState, emp1InstanceId, emp2InstanceId)
    local emp1 = getEmployeeFromGameState(gameState, emp1InstanceId)
    local emp2 = getEmployeeFromGameState(gameState, emp2InstanceId)

    if not emp1 or not emp2 then return false, "Could not find employees to swap." end
    if emp1.variant == emp2.variant then return false, "Must select one remote and one office worker." end

    -- Identify who is remote and who is in the office
    local remoteEmp = (emp1.variant == 'remote') and emp1 or emp2
    local officeEmp = (emp1.variant == 'remote') and emp2 or emp1
    
    local originalDeskId = officeEmp.deskId

    -- Perform the swap
    -- The office worker becomes remote
    officeEmp.variant = 'remote'
    officeEmp.deskId = nil
    gameState.deskAssignments[originalDeskId] = nil

    -- The remote worker takes the office desk
    remoteEmp.variant = 'standard' -- Or whatever the non-remote variant is
    remoteEmp.deskId = originalDeskId
    gameState.deskAssignments[originalDeskId] = remoteEmp.instanceId

    return true, remoteEmp.name .. " and " .. officeEmp.name .. " have been reorganized."
end

function Placement:isPotentialCombineTarget(gameState, targetEmployeeData, sourceEmployeeData)
    if not sourceEmployeeData then 
        if gameState.selectedEmployeeForPlacementInstanceId then
             sourceEmployeeData = getEmployeeFromGameState(gameState, gameState.selectedEmployeeForPlacementInstanceId)
             if not sourceEmployeeData then return false end
        else
            return false 
        end
    end
    if not targetEmployeeData then return false end

    -- Do not allow combining an employee with itself
    if sourceEmployeeData.instanceId == targetEmployeeData.instanceId then return false end 
    
    local maxLevel = _G.getCurrentMaxLevel(gameState)
    if (targetEmployeeData.level or 1) >= maxLevel then return false end 
    if (sourceEmployeeData.level or 1) >= maxLevel then return false end

    -- To combine, they must be the same base employee ID and the same variant type.
    if sourceEmployeeData.id == targetEmployeeData.id and 
       sourceEmployeeData.variant == targetEmployeeData.variant then
        return true
    end

    return false
end

function Placement:handleEmployeeDropOnDesk(gameState, employeeData, targetDeskId, originalDeskId)
    local wasSuccessfullyPlaced = false
    local fromShop = (originalDeskId == nil)

    local placementArgs = { 
        employee = employeeData, 
        targetDeskId = targetDeskId, 
        fromShop = fromShop,
        wasHandled = false,
        success = false,
        message = ""
    }
    require("effects_dispatcher").dispatchEvent("onPlacement", gameState, placementArgs)
    
    if placementArgs.wasHandled then
        if not placementArgs.success and placementArgs.message ~= "" then
            Drawing.showModal("Can't Merge", placementArgs.message)
        end
        return placementArgs.success
    end

    if employeeData.special and employeeData.special.placement_restriction then
        if employeeData.special.placement_restriction == 'not_top_row' then
            local deskIndex = tonumber(string.match(targetDeskId, "desk%-(%d+)"))
            if deskIndex and math.floor(deskIndex / GameData.GRID_WIDTH) == 0 then
                Drawing.showModal("Placement Error", employeeData.name .. " is sensitive to sunlight and cannot be placed in the top row."); return false
            end
        end
    end

    if employeeData.variant == 'remote' then Drawing.showModal("Invalid Placement", employeeData.fullName .. " is a remote worker and cannot be placed on a desk."); return false end
    local targetDesk = nil
    for _,d in ipairs(gameState.desks) do if d.id == targetDeskId then targetDesk = d; break; end end
    if not targetDesk or targetDesk.status ~= "owned" then Drawing.showModal("Placement Error", "Cannot place on a locked or unpurchased desk."); return false end
    local currentOccupantInstanceId = gameState.deskAssignments[targetDeskId]

    if currentOccupantInstanceId then
        if currentOccupantInstanceId == employeeData.instanceId then 
            gameState.deskAssignments[targetDeskId] = employeeData.instanceId; employeeData.deskId = targetDeskId; print(employeeData.name .. " returned to " .. targetDeskId); wasSuccessfullyPlaced = true
        else
            local occupantEmployee = getEmployeeFromGameState(gameState, currentOccupantInstanceId)
            if occupantEmployee then
                if Placement:isPotentialCombineTarget(gameState, occupantEmployee, employeeData) then
                    local success, msg = self:combineAndLevelUpEmployees(gameState, occupantEmployee.instanceId, employeeData.instanceId)
                    if not success then Drawing.showModal("Combine Failed", msg) end; return success 
                else
                    if not originalDeskId then Drawing.showModal("Placement Failed", "Cannot swap with an employee from the shop. Place this employee on an empty desk first."); return false end
                    print("Swapping " .. employeeData.name .. " with " .. occupantEmployee.name)
                    gameState.deskAssignments[originalDeskId] = occupantEmployee.instanceId; occupantEmployee.deskId = originalDeskId
                    gameState.deskAssignments[targetDeskId] = employeeData.instanceId; employeeData.deskId = targetDeskId; wasSuccessfullyPlaced = true
                end
            end
        end
    else 
        employeeData.deskId = targetDeskId; gameState.deskAssignments[targetDeskId] = employeeData.instanceId; wasSuccessfullyPlaced = true
    end
    
    if wasSuccessfullyPlaced and fromShop then
        require("effects_dispatcher").dispatchEvent("onHire", gameState, { employee = employeeData })
    end

    return wasSuccessfullyPlaced
end

function Placement:handleEmployeeDropOnRemote(gameState, employeeData, originalDeskId)
    local fromShop = (originalDeskId == nil)
    if employeeData.variant ~= 'remote' then 
        Drawing.showModal("Invalid Action", employeeData.name .. " is an office worker and cannot be moved to the remote team this way.")
        return false 
    end
    if originalDeskId then gameState.deskAssignments[originalDeskId] = nil end
    employeeData.deskId = nil 

    if fromShop and employeeData.special and employeeData.special.type == 'virus_on_hire' then
        local potentialTargets = {}
        for _, emp in ipairs(gameState.hiredEmployees) do 
            if emp.instanceId ~= employeeData.instanceId and emp.rarity ~= 'Legendary' and not emp.isSmithCopy then 
                table.insert(potentialTargets, emp) 
            end 
        end
        
        local smithData = nil
        for _, card in ipairs(GameData.BASE_EMPLOYEE_CARDS) do 
            if card.id == 'agent_smith1' then 
                smithData = card
                break 
            end 
        end

        for i=1, 2 do
            if #potentialTargets > 0 and smithData then
                local targetIndex = love.math.random(#potentialTargets) 
                local victim = potentialTargets[targetIndex]
                victim.isSmithCopy = true 
                victim.weeklySalary = smithData.weeklySalary
                print(victim.name .. " has been assimilated by Agent Smith.")
                table.remove(potentialTargets, targetIndex)
            end
        end
    end

    return true
end

function Placement:handleEmployeeDropOnRemoteEmployee(gameState, draggedEmployeeData, targetRemoteEmployeeInstanceId)
    print("Placement:handleEmployeeDropOnRemoteEmployee: Dragged " .. draggedEmployeeData.name .. " onto remote " .. targetRemoteEmployeeInstanceId)
    local targetEmployee = getEmployeeFromGameState(gameState, targetRemoteEmployeeInstanceId)

    if not targetEmployee or targetEmployee.variant ~= 'remote' then return false end
    
    if draggedEmployeeData.variant ~= 'remote' then
        Drawing.showModal("Combine Error", "Cannot combine office worker " .. draggedEmployeeData.name .. " with remote worker " .. targetEmployee.name .. ".")
        return false
    end

    if self:isPotentialCombineTarget(gameState, targetEmployee, draggedEmployeeData) then
        local success, msg = self:combineAndLevelUpEmployees(gameState, targetEmployee.instanceId, draggedEmployeeData.instanceId)
        if not success then
             Drawing.showModal("Combine Failed", msg)
        end
        return success
    else
        Drawing.showModal("Cannot Combine", "These remote employees cannot be combined.")
    end
    return false
end

function Placement:combineAndLevelUpEmployees(gameState, targetInstanceId, sourceInstanceId)
    local targetEmp, sourceEmp
    local sourceEmpIndex = -1

    targetEmp = getEmployeeFromGameState(gameState, targetInstanceId)
    for i, emp in ipairs(gameState.hiredEmployees) do
        if emp.instanceId == sourceInstanceId then sourceEmp = emp; sourceEmpIndex = i; break; end
    end

    if not targetEmp or not sourceEmp then return false, "Combine Error: Employee instance not found." end
    if targetEmp.id ~= sourceEmp.id then return false, "Cannot Combine: Employees not of the same base type." end
    if targetEmp.variant ~= sourceEmp.variant then return false, "Cannot Combine: Employees must both be of the same variant (e.g. both remote)." end
    
    local maxLevel = _G.getCurrentMaxLevel(gameState)
    if (targetEmp.level or 1) >= maxLevel then 
        return false, "Cannot Combine: Target employee is already max level." 
    end

    local statsT = Employee:calculateStatsWithPosition(targetEmp, gameState.hiredEmployees, gameState.deskAssignments, gameState.purchasedPermanentUpgrades, gameState.desks, gameState)
    local statsS = Employee:calculateStatsWithPosition(sourceEmp, gameState.hiredEmployees, gameState.deskAssignments, gameState.purchasedPermanentUpgrades, gameState.desks, gameState)
    targetEmp.baseProductivity = math.floor(math.max(statsT.currentProductivity, statsS.currentProductivity) * 1.75) 
    targetEmp.baseFocus = math.max(statsT.currentFocus, statsS.currentFocus) * 1.5 
    targetEmp.weeklySalary = math.floor(math.max(targetEmp.weeklySalary, sourceEmp.weeklySalary) * 1.8) 
    
    targetEmp.level = (targetEmp.level or 1) + 1
    targetEmp.isTraining = true

    if sourceEmp.deskId and gameState.deskAssignments[sourceEmp.deskId] == sourceInstanceId then
        gameState.deskAssignments[sourceEmp.deskId] = nil 
    end

    if sourceEmpIndex ~= -1 then
        table.remove(gameState.hiredEmployees, sourceEmpIndex)
    else
        return false, "Internal error during combine (source index)."
    end
    
    if gameState.selectedEmployeeForPlacementInstanceId == sourceInstanceId then
         gameState.selectedEmployeeForPlacementInstanceId = nil
    end
   
    return true, targetEmp.name .. " reached Level " .. targetEmp.level .. "!"
end

function Placement:attemptBuyDesk(gameState, deskIdToBuy)
    local desk = nil
    for _, d in ipairs(gameState.desks) do if d.id == deskIdToBuy then desk = d; break end end

    if not desk or desk.status ~= "purchasable" then
        return false, "This desk is not available for purchase or already owned."
    end
    if gameState.budget < desk.cost then
        return false, "Not enough budget to buy this desk. Need $" .. desk.cost
    end

    gameState.budget = gameState.budget - desk.cost
    desk.status = "owned"
    desk.cost = 0 
    
    self:updateDeskAvailability(gameState.desks) 
    
    return true, desk.id .. " purchased and now available!"
end

return Placement