local fname = "reactor_config.txt"

function InitConfig()
    local config = fs.open(fname, "w")

    print("You'll be prompted three times for the following: Reactor ID, Monitor ID, and Reactor Name." ..
              "\nPlease be mindful of the IDs you enter, as they are case-sensitive.\n\n")
    
    print("Enter the Rednet ID of the reactor: ")
    local rID = read()

    print("Enter the Monitor ID (or side): ")
    local monID = read()

    print("Enter the name of the reactor: ")
    local rName = read()

    config.writeLine(rID)
    config.writeLine(monID)
    config.writeLine(rName)

    config.close()

    return rID, monID, rName
end

function ConfigRead()
    local config = fs.open(fname, "r")
    if not config then
        print("Config file does not exist. Let's initialize it.\n\n")
        return InitConfig()
    end

    local rID = config.readLine()
    local monID = config.readLine()
    rName = config.readLine()

    config.close()

    return rID, monID, rName
end
