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
    local emp1 = Employee:getFromState(gameState, emp1InstanceId)
    local emp2 = Employee:getFromState(gameState, emp2InstanceId)

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

local function _handleDropOnEmptyDesk(gameState, employeeData, targetDeskId)
    employeeData.deskId = targetDeskId
    gameState.deskAssignments[targetDeskId] = employeeData.instanceId
    return true
end

local function _handleDropOnOccupiedDesk(self, gameState, employeeData, targetDeskId, originalDeskId, modal)
    local occupantInstanceId = gameState.deskAssignments[targetDeskId]
    local occupantEmployee = Employee:getFromState(gameState, occupantInstanceId)

    if not occupantEmployee then return false end -- Should not happen, but a good safeguard

    if Placement:isPotentialCombineTarget(gameState, occupantEmployee, employeeData) then
        local success, msg = self:combineAndLevelUpEmployees(gameState, occupantEmployee.instanceId, employeeData.instanceId)
        if not success then modal:show("Combine Failed", msg) end
        return success
    else
        if not originalDeskId then
            modal:show("Placement Failed", "Cannot swap with an employee from the shop. Place this employee on an empty desk first.")
            return false
        end
        print("Swapping " .. employeeData.name .. " with " .. occupantEmployee.name)
        -- Perform the swap of the two employees
        gameState.deskAssignments[originalDeskId] = occupantEmployee.instanceId
        occupantEmployee.deskId = originalDeskId
        gameState.deskAssignments[targetDeskId] = employeeData.instanceId
        employeeData.deskId = targetDeskId
        return true
    end
end

function Placement:handleEmployeeDropOnDesk(gameState, employeeData, targetDeskId, originalDeskId, modal)
    local fromShop = (originalDeskId == nil)

    -- The initial validation and event dispatches remain the same
    local placementArgs = { 
        employee = employeeData, 
        targetDeskId = targetDeskId, 
        fromShop = fromShop,
        wasHandled = false,
        success = false,
        message = ""
    }
    require("effects_dispatcher").dispatchEvent("onPlacement", gameState, { modal = modal }, placementArgs)
    
    if placementArgs.wasHandled then
        if not placementArgs.success and placementArgs.message ~= "" then
            modal:show("Can't Merge", placementArgs.message)
        end
        return placementArgs.success
    end
    
    local validationArgs = { employee = employeeData, targetDeskId = targetDeskId, isValid = true, message = "" }
    require("effects_dispatcher").dispatchEvent("onValidatePlacement", gameState, { modal = modal }, validationArgs)

    if not validationArgs.isValid then
        modal:show("Placement Error", validationArgs.message or "This employee cannot be placed here.")
        return false
    end

    if employeeData.variant == 'remote' then modal:show("Invalid Placement", employeeData.fullName .. " is a remote worker and cannot be placed on a desk."); return false end
    local targetDesk = nil
    for _,d in ipairs(gameState.desks) do if d.id == targetDeskId then targetDesk = d; break; end end
    if not targetDesk or targetDesk.status ~= "owned" then modal:show("Placement Error", "Cannot place on a locked or unpurchased desk."); return false end
    
    -- This is the new, refactored logic
    local currentOccupantInstanceId = gameState.deskAssignments[targetDeskId]
    local wasSuccessfullyPlaced = false

    if not currentOccupantInstanceId then
        wasSuccessfullyPlaced = _handleDropOnEmptyDesk(gameState, employeeData, targetDeskId)
    elseif currentOccupantInstanceId == employeeData.instanceId then
        -- Simple case of returning to the same desk, which is implicitly a success.
        wasSuccessfullyPlaced = true
        print(employeeData.name .. " returned to " .. targetDeskId)
    else
        wasSuccessfullyPlaced = _handleDropOnOccupiedDesk(self, gameState, employeeData, targetDeskId, originalDeskId, modal)
    end
    
    if wasSuccessfullyPlaced and fromShop then
        require("effects_dispatcher").dispatchEvent("onHire", gameState, { modal = modal }, { employee = employeeData })
    end

    return wasSuccessfullyPlaced
end

function Placement:handleDecorationDropOnDesk(gameState, decorationData, targetDeskId, modal)
    local targetDesk
    for _, d in ipairs(gameState.desks) do
        if d.id == targetDeskId then
            targetDesk = d
            break
        end
    end

    if not targetDesk or targetDesk.status ~= "owned" then
        modal:show("Placement Error", "Decorations can only be placed on owned desks.")
        return false
    end

    -- Overwrite any existing decoration. The calling function is responsible for handling the old one.
    gameState.deskDecorations[targetDeskId] = decorationData.id

    -- If the decoration being placed came from the inventory, remove it.
    if decorationData.instanceId and decorationData.instanceId:match("^owned%-decoration") then
        for i, ownedDeco in ipairs(gameState.ownedDecorations) do
            if ownedDeco.instanceId == decorationData.instanceId then
                table.remove(gameState.ownedDecorations, i)
                break
            end
        end
    end

    return true
end

function Placement:getDecorationOnDesk(gameState, deskId)
    local decorationId = gameState.deskDecorations[deskId]
    if not decorationId then return nil end

    for _, decoData in ipairs(GameData.ALL_DESK_DECORATIONS) do
        if decoData.id == decorationId then
            return decoData
        end
    end

    return nil
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

function Placement:handleEmployeeDropOnRemote(gameState, employeeData, originalDeskId, modal)
    local fromShop = (originalDeskId == nil)
    if employeeData.variant ~= 'remote' then 
        modal:show("Invalid Action", employeeData.name .. " is an office worker and cannot be moved to the remote team this way.")
        return false 
    end
    if originalDeskId then gameState.deskAssignments[originalDeskId] = nil end
    employeeData.deskId = nil 

    if fromShop then
        require("effects_dispatcher").dispatchEvent("onHire", gameState, { modal = modal }, { employee = employeeData })
    end

    return true
end

function Placement:handleEmployeeDropOnRemoteEmployee(gameState, draggedEmployeeData, targetRemoteEmployeeInstanceId, modal)
    print("Placement:handleEmployeeDropOnRemoteEmployee: Dragged " .. draggedEmployeeData.name .. " onto remote " .. targetRemoteEmployeeInstanceId)
    local targetEmployee = getEmployeeFromGameState(gameState, targetRemoteEmployeeInstanceId)

    if not targetEmployee or targetEmployee.variant ~= 'remote' then return false end
    
    if draggedEmployeeData.variant ~= 'remote' then
        modal:show("Combine Error", "Cannot combine office worker " .. draggedEmployeeData.name .. " with remote worker " .. targetEmployee.name .. ".")
        return false
    end

    if self:isPotentialCombineTarget(gameState, targetEmployee, draggedEmployeeData) then
        local success, msg = self:combineAndLevelUpEmployees(gameState, targetEmployee.instanceId, draggedEmployeeData.instanceId)
        if not success then
             modal:show("Combine Failed", msg)
        end
        return success
    else
        modal:show("Cannot Combine", "These remote employees cannot be combined.")
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

    -- Get the dynamic cost instead of using a static one
    local purchaseCost = self:getDeskPurchaseCost(gameState)

    if gameState.budget < purchaseCost then
        return false, "Not enough budget to buy this desk. Need $" .. purchaseCost
    end

    gameState.budget = gameState.budget - purchaseCost
    desk.status = "owned"
    desk.cost = 0 
    
    self:updateDeskAvailability(gameState.desks) 
    
    return true, desk.id .. " purchased and now available!"
end

function Placement:getDeskPurchaseCost(gameState)
    local initialOwnedDesks = 4 -- Desks 0, 1, 3, 4 start as owned
    local currentlyOwnedDesks = self:getOwnedDeskCount(gameState)
    local desksPurchased = currentlyOwnedDesks - initialOwnedDesks
    
    local cost = GameData.BASE_DESK_PURCHASE_COST + (desksPurchased * 1000)
    return cost
end

function Placement:getNeighboringDeskId(deskId, direction, gridWidth, totalDeskSlots, desksData)
    if not deskId then return nil end -- Prevent crash if deskId is nil
    local match = string.match(deskId, "desk%-(%d+)") if not match then return nil end
    local currentIndex = tonumber(match) ; local neighborIndex = -1
    local row = math.floor(currentIndex / gridWidth); local col = currentIndex % gridWidth
    if direction == "up" then if row > 0 then neighborIndex = currentIndex - gridWidth end
    elseif direction == "down" then if row < (math.ceil(totalDeskSlots / gridWidth) - 1) then neighborIndex = currentIndex + gridWidth end
    elseif direction == "left" then if col > 0 then neighborIndex = currentIndex - 1 end
    elseif direction == "right" then if col < gridWidth - 1 then neighborIndex = currentIndex + 1 end
    end
    if neighborIndex >= 0 and neighborIndex < totalDeskSlots then
        -- Check if the neighbor desk actually exists in our defined desks
        for _, desk in ipairs(desksData) do if desk.id == "desk-" .. neighborIndex then return desk.id end end
    end
    return nil
end

function Placement:generatePositionalOverlays(sourceEmployee, sourceDeskId, gameState)
    if not sourceEmployee or not sourceEmployee.positionalEffects or not sourceDeskId then
        return {}
    end

    local overlays = {}
    for direction, effect in pairs(sourceEmployee.positionalEffects) do
        local directionsToParse = (direction == "all_adjacent" or direction == "sides") and {"up", "down", "left", "right"} or {direction}
        if direction == "sides" then directionsToParse = {"left", "right"} end

        for _, dir in ipairs(directionsToParse) do
            -- NOTE: This now correctly calls the centralized getNeighboringDeskId function
            local targetDeskId = Placement:getNeighboringDeskId(sourceDeskId, dir, GameData.GRID_WIDTH, GameData.TOTAL_DESK_SLOTS, gameState.desks)
            if targetDeskId then
                local bonusValue, bonusText, bonusColor
                if effect.productivity_add then
                    bonusValue = effect.productivity_add * (effect.scales_with_level and (sourceEmployee.level or 1) or 1)
                    bonusText = string.format("%+d P", bonusValue)
                    bonusColor = {0.1, 0.65, 0.35, 0.75} -- Green
                elseif effect.focus_add then
                    bonusValue = effect.focus_add * (effect.scales_with_level and (sourceEmployee.level or 1) or 1)
                    bonusText = string.format("%+.1f F", bonusValue)
                    bonusColor = {0.25, 0.55, 0.9, 0.75} -- Blue
                elseif effect.focus_mult then
                    bonusText = string.format("x%.1f F", effect.focus_mult)
                    bonusColor = {0.8, 0.3, 0.8, 0.75} -- Purple for multipliers
                end
                
                if bonusText then
                    table.insert(overlays, { 
                        targetDeskId = targetDeskId, 
                        text = bonusText, 
                        color = bonusColor 
                    })
                end
            end
        end
    end
    return overlays
end


return Placement