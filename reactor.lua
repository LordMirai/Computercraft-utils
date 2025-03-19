require("mon_utils")
require("reac_enums")

local rID = "BigReactors-Reactor_0"
local monID = "right"

local r = peripheral.wrap(rID)

if not r then
    print("Couldn't find reactor")
    return
end

local mon = peripheral.wrap(monID)

if not mon then
    print("Couldn't find monitor")
    return
end

ReactorState = REAC_STOPPED

function SetAllRods(val)
    for i = 1, r.getNumberOfControlRods() do
        r.setControlRodLevel(i, val)
    end
end

function LoadState(r) -- get current working state from reactor
    if not r then return end
    if ReactorState == REAC_OVERRIDE then return end
    -- read reactor state and buffer, select the correct state
    local enabled = r.getActive()
    local ins = r.getControlRodLevel(1)

    if not enabled then
        ReactorState = REAC_STOPPED
    elseif ins < 20 then
        ReactorState = REAC_FULL_POWER
    elseif ins >= 50 then
        ReactorState = REAC_HALF_POWER
    end

    r.STATE = ReactorState

    print(string.format("Loaded state: %s", REAC_STATUS[ReactorState]))
end

function SetState(r, newState)
    if not r then return end
    if ReactorState == REAC_OVERRIDE then return end
    -- set the reactor state
    if r.STATE == newState then return end -- no need to change state if it's already set
    if newState == REAC_STOPPED then
        r.setActive(false)
    elseif newState == REAC_FULL_POWER then
        SetAllRods(0)
        r.setActive(true)
    elseif newState == REAC_HALF_POWER then
        SetAllRods(50)
        r.setActive(true)
    end

    print(string.format("Set state: %s", REAC_STATUS[newState]))
    ReactorState = newState
    r.STATE = newState
end

function PollStateChange(r)
    if not r then return end
    if ReactorState == REAC_OVERRIDE then return end
    -- poll the reactor state and update the state if necessary
    local enabled = r.getActive()

    local energyStored = r.getEnergyStored()
    local energyCapacity = r.getEnergyCapacity()
    local buffer = (energyStored / energyCapacity) * 100

    if buffer < 60 then
        SetState(r, REAC_FULL_POWER)
    elseif buffer < 95 then
        SetState(r, REAC_HALF_POWER)
    else
        SetState(r, REAC_STOPPED)
    end

end

function ConstantUpdate(r, mon)
    if not r or not mon then return end

    while true do
        PollStateChange(r)
        UpdateMonitor(mon, r)
        os.sleep(2)
    end
end


LoadState(r)
UpdateMonitor(mon, r)

-- Start the constant update function
ConstantUpdate(r, mon)