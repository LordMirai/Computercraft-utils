require("mon_utils")
require("reac_enums")

local rID = "BigReactors-Reactor_0"
local monID = "right"

ReactorState = REAC_STOPPED
BREAK_CONDITION = false

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

    local buffer = (r.getEnergyStored() / r.getEnergyCapacity()) * 100

    if not enabled then
        ReactorState = REAC_STOPPED
    elseif ins < 20 then
        ReactorState = REAC_FULL_POWER
    elseif ins > 50 then
        ReactorState = REAC_HALF_POWER
    end

    if buffer > 98 then
        ReactorState = REAC_STOPPED
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


LastChange = os.epoch("utc")

function PollStateChange(r)
    if not r then return end
    if ReactorState == REAC_OVERRIDE then return end
    -- poll the reactor state and update the state if necessary
    local enabled = r.getActive()

    local energyStored = r.getEnergyStored()
    local energyCapacity = r.getEnergyCapacity()
    local buffer = (energyStored / energyCapacity) * 100

    local curTime = os.epoch("utc")
    local delta = curTime - LastChange
    if delta < 5000 then return end -- min time between changes: 5 seconds

    if buffer < 60 then
        SetState(r, REAC_FULL_POWER)
    elseif buffer < 98 then
        SetState(r, REAC_HALF_POWER)
    else
        SetState(r, REAC_STOPPED)
    end

end


function r.EnterOverride()
    SetState(r, REAC_OVERRIDE)
end

function r.LeaveOverride()
    ReactorState = REAC_STOPPED
    LoadState(r)
end


function MainLoop(r, mon)
    -- Function to handle constant updates
    local function UpdateTask()
        while not BREAK_CONDITION do
            PollStateChange(r)
            UpdateMonitor(mon, r)
            os.sleep(0.2)
        end
    end

    -- Function to handle button clicks
    local function ButtonHandlerTask()
        while not BREAK_CONDITION do
            local success, event, side, x, y = pcall(os.pullEventRaw)
            if event == "monitor_touch" then
                for _, btn in ipairs(BUTTONS) do
                    btn(x, y)
                end
            end
        end
    end

    -- Run both tasks in parallel
    parallel.waitForAny(UpdateTask, ButtonHandlerTask)
end


reactor = r -- global reference
-- first run
LoadState(r)
UpdateMonitor(mon, r)

MainLoop(r, mon)