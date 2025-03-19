BUTTONS = {}

function UpdateMonitor(mon, reactor)
    mon.setCursorPos(1, 1)
    mon.clear()
    mon.write("Reactor Status")

    -- * State
    mon.setCursorPos(1, 2)
    local state = reactor.STATE or REAC_STOPPED
    local stateText = REAC_STATUS[state]
    local stateColor = REAC_STATUS_COLOR[state]
    mon.setTextColor(stateColor)
    mon.write("State: " .. stateText)
    mon.setTextColor(colors.white)

    -- * Active
    mon.setCursorPos(1, 3)
    mon.write("Active: ")
    mon.setTextColor(reactor.getActive() and colors.green or colors.red)
    mon.write(tostring(reactor.getActive()))
    mon.setTextColor(colors.white)

    -- * Energy
    mon.setCursorPos(1, 4)
    mon.write("Energy: ")
    local energyStored = reactor.getEnergyStored()
    local energyCapacity = reactor.getEnergyCapacity()
    local energyPercentage = (energyStored / energyCapacity) * 100
    if energyPercentage > 75 then
        mon.setTextColor(colors.green)
    elseif energyPercentage > 25 then
        mon.setTextColor(colors.yellow)
    else
        mon.setTextColor(colors.red)
    end
    mon.write(string.format("%d/%d (%.1f%%)", energyStored, energyCapacity, energyPercentage))
    mon.setTextColor(colors.white)

    -- * Fuel
    mon.setCursorPos(1, 5)
    mon.write("Fuel: ")
    local fuelAmount = reactor.getFuelAmount()
    local fuelCapacity = reactor.getFuelAmountMax()
    local fuelPercentage = (fuelAmount / fuelCapacity) * 100
    if fuelPercentage > 75 then
        mon.setTextColor(colors.green)
    elseif fuelPercentage > 25 then
        mon.setTextColor(colors.yellow)
    else
        mon.setTextColor(colors.red)
    end
    mon.write(string.format("%d/%d (%.1f%%)", fuelAmount, fuelCapacity, fuelPercentage))
    mon.setTextColor(colors.white)

    -- * Control Rods
    mon.setCursorPos(1, 6)
    mon.write("Control Rod Insertion: ")
    local rodLevel = reactor.getControlRodLevel(1)
    if rodLevel < 25 then
        mon.setTextColor(colors.green)
    elseif rodLevel < 75 then
        mon.setTextColor(colors.yellow)
    else
        mon.setTextColor(colors.red)
    end
    mon.write(string.format("%.1f%%", rodLevel))
    mon.setTextColor(colors.white)

    DrawButtons(mon)
end

function CreateButton(mon, x, y, w, h, label, callback)
    -- Draw the button
    mon.setBackgroundColor(colors.gray)
    for i = 0, h - 1 do
        mon.setCursorPos(x, y + i)
        mon.write(string.rep(" ", w))
    end
    mon.setCursorPos(x + math.floor((w - #label) / 2), y + math.floor(h / 2))
    mon.setTextColor(colors.white)
    mon.write(label)
    mon.setBackgroundColor(colors.black)

    -- Return a function to handle clicks
    return function(clickX, clickY)
        if clickX >= x and clickX < x + w and clickY >= y and clickY < y + h then
            callback()
        end
    end
end

local function BreakProg()
    BREAK_CONDITION = true
end

local function ToggleReactorState()
    print("Toggling reactor state")
    reactor.setActive(not reactor.getActive())
end

local function IncreaseRodLevel()
    print("Increasing rod level")
    local newLevel = math.min(reactor.getControlRodLevel(1) + 10, 100)
    for i = 1, reactor.getNumberOfControlRods() do
        reactor.setControlRodLevel(i, newLevel)
    end
end

local function DecreaseRodLevel()
    print("Decreasing rod level")
    local newLevel = math.max(reactor.getControlRodLevel(1) - 10, 0)
    for i = 1, reactor.getNumberOfControlRods() do
        reactor.setControlRodLevel(i, newLevel)
    end
end

local function ToggleOverride()
    print("Toggling override")
    if reactor.STATE == REAC_OVERRIDE then
        reactor.LeaveOverride()
    else
        reactor.EnterOverride()
    end
end

function DrawButtons(mon)
    local b1 = CreateButton(mon, 2, 8, 12, 1, "Toggle State", ToggleReactorState)
    local b2 = CreateButton(mon, 2, 10, 12, 1, "Rod +10%", IncreaseRodLevel)
    local b3 = CreateButton(mon, 2, 12, 12, 1, "Rod -10%", DecreaseRodLevel)
    local b4 = CreateButton(mon, 2, 14, 12, 1, "Override", ToggleOverride)
    local b5 = CreateButton(mon, 1, 50, 1, 1, "X", BreakProg)

    BUTTONS = {b1, b2, b3, b4}
end