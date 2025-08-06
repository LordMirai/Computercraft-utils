-- LOGS FTP Client Terminal
-- Connects to LOGS FTP Server for file management

local modemSide = "back" -- Change this to your modem's side
local serverID = nil -- Will be set after server discovery

-- Terminal colors
local colors = {
    primary = colors.cyan,
    secondary = colors.lightBlue,
    accent = colors.yellow,
    success = colors.lime,
    error = colors.red,
    text = colors.white,
    background = colors.black
}

-- Setup
rednet.open(modemSide)

-- Screen size detection
local function getScreenType()
    local w, h = term.getSize()
    if w <= 13 or h <= 9 then
        return "pocket"  -- Pocket computer
    elseif w <= 25 or h <= 15 then
        return "compact" -- Small monitor or tablet
    else
        return "full"    -- Regular monitor or computer
    end
end

-- Utility Functions
local function centerText(text, y)
    local w, h = term.getSize()
    if #text <= w then
        term.setCursorPos(math.floor((w - #text) / 2) + 1, y)
        term.write(text)
    else
        -- Text too long, truncate and center
        local truncated = text:sub(1, w - 3) .. "..."
        term.setCursorPos(1, y)
        term.write(truncated)
    end
end

local function clearScreen()
    term.setBackgroundColor(colors.background)
    term.setTextColor(colors.text)
    term.clear()
    term.setCursorPos(1, 1)
end

local function printColored(text, color)
    color = color or colors.text
    term.setTextColor(color)
    print(text)
    term.setTextColor(colors.text)
end

-- Wrap text to fit screen width
local function printWrapped(text, color)
    color = color or colors.text
    term.setTextColor(color)
    
    local w, h = term.getSize()
    local words = {}
    for word in text:gmatch("%S+") do
        table.insert(words, word)
    end
    
    local line = ""
    for i, word in ipairs(words) do
        local testLine = line == "" and word or line .. " " .. word
        if #testLine <= w then
            line = testLine
        else
            if line ~= "" then
                print(line)
                line = word
            else
                -- Single word longer than line, just print it
                print(word)
            end
        end
    end
    
    if line ~= "" then
        print(line)
    end
    
    term.setTextColor(colors.text)
end

-- Adaptive prompt function
local function promptUser(fullPrompt, shortPrompt)
    local w, h = term.getSize()
    local prompt = (w >= 30) and fullPrompt or shortPrompt
    
    term.setTextColor(colors.accent)
    write(prompt)
    term.setTextColor(colors.text)
    return read()
end

local function printHeader(title)
    local w, h = term.getSize()
    term.setTextColor(colors.primary)
    
    -- Adaptive header based on screen width
    if w >= 30 then
        print(string.rep("=", w))
        centerText(title, select(2, term.getCursorPos()))
        print()
        term.setTextColor(colors.primary)
        print(string.rep("=", w))
    elseif w >= 15 then
        print(string.rep("-", w))
        centerText(title, select(2, term.getCursorPos()))
        print()
        print(string.rep("-", w))
    else
        -- Very compact header for pocket computers
        local shortTitle = title
        if #title > w then
            shortTitle = title:sub(1, w - 3) .. "..."
        end
        print(shortTitle)
        print(string.rep("-", math.min(w, #shortTitle)))
    end
    
    term.setTextColor(colors.text)
end

-- Splash Screen
local function showSplash()
    clearScreen()
    
    local w, h = term.getSize()
    
    -- Adaptive splash screen based on screen size
    if w >= 35 and h >= 15 then
        -- Full logo for larger screens
        local logoY = math.floor(h / 2) - 4
        
        term.setTextColor(colors.primary)
        centerText("[" .. string.rep("=", w - 2) .. "]", logoY)
        centerText("|" .. string.rep(" ", w - 2) .. "|", logoY + 1)
        centerText("|        LOGS FTP CLIENT        |", logoY + 2)
        centerText("|" .. string.rep(" ", w - 2) .. "|", logoY + 3)
        centerText("|     File Transfer Terminal    |", logoY + 4)
        centerText("|" .. string.rep(" ", w - 2) .. "|", logoY + 5)
        centerText("[" .. string.rep("=", w - 2) .. "]", logoY + 6)

        term.setTextColor(colors.accent)
        centerText("Initializing connection...", logoY + 8)
    elseif w >= 20 and h >= 10 then
        -- Compact logo for medium screens
        local logoY = math.floor(h / 2) - 2
        
        term.setTextColor(colors.primary)
        centerText(string.rep("=", math.min(w, 20)), logoY)
        centerText("LOGS FTP CLIENT", logoY + 1)
        centerText("File Transfer", logoY + 2)
        centerText(string.rep("=", math.min(w, 20)), logoY + 3)

        term.setTextColor(colors.accent)
        centerText("Connecting...", logoY + 5)
    else
        -- Minimal logo for pocket computers
        local logoY = math.floor(h / 2) - 1
        
        term.setTextColor(colors.primary)
        centerText("LOGS FTP", logoY)
        centerText(string.rep("-", math.min(w, 10)), logoY + 1)

        term.setTextColor(colors.accent)
        centerText("Connecting", logoY + 3)
    end
    
    term.setTextColor(colors.text)
    sleep(1.2)
end

-- Server Discovery
local function discoverServer()
    local screenType = getScreenType()
    local searchMsg = (screenType == "pocket") and "Finding server..." or "Searching for LOGS server..."
    
    printColored(searchMsg, colors.secondary)
    
    -- Send broadcast to find server
    rednet.broadcast("ping", "LOGS")
    
    local timeout = 5
    local startTime = os.clock()
    
    while os.clock() - startTime < timeout do
        local id, response = rednet.receive("LOGS", 1)
        if id then
            serverID = id
            local successMsg = (screenType == "pocket") and ":) Found: " .. id or ":)  Found LOGS server at ID: " .. id
            printColored(successMsg, colors.success)
            return true
        end
    end
    
    local errorMsg = (screenType == "pocket") and ":( No server" or ":(  No LOGS server found"
    printColored(errorMsg, colors.error)
    return false
end

-- Send command to server
local function sendCommand(command)
    if not serverID then
        local screenType = getScreenType()
        local errorMsg = (screenType == "pocket") and "Error: No server" or "Error: Not connected to server"
        printColored(errorMsg, colors.error)
        return nil
    end
    
    rednet.send(serverID, command, "LOGS")
    
    -- Wait for response
    local id, response = rednet.receive("LOGS", 10)
    if id == serverID then
        return response
    else
        local screenType = getScreenType()
        local errorMsg = (screenType == "pocket") and "Error: No response" or "Error: No response from server"
        printColored(errorMsg, colors.error)
        return nil
    end
end

-- Parse server response
local function parseResponse(response)
    if not response then
        return nil
    end
    
    -- Check if it's a serialized response
    local success, parsed = pcall(textutils.unserialize, response)
    if success and type(parsed) == "table" then
        return parsed
    else
        -- Plain text response (likely an error)
        return { content = response, method = "plain" }
    end
end

-- Display formatted response
local function displayResponse(parsed)
    if not parsed then
        printColored("No response received", colors.error)
        return
    end
    
    if parsed.method == "plain" or parsed.content:find("ERROR:") then
        if parsed.content:find("ERROR:") then
            printColored(parsed.content, colors.error)
        else
            printColored(parsed.content, colors.text)
        end
        return
    end
    
    -- Display structured response
    if parsed.title then
        printHeader(parsed.title)
    end
    
    if parsed.content then
        if parsed.method == "list" then
            term.setTextColor(colors.secondary)
            print(parsed.content)
        elseif parsed.method == "read" then
            -- Make title bigger for read operations
            term.setTextColor(colors.primary)
            print("\n")
            term.setTextColor(colors.text)
            print(parsed.content)
        elseif parsed.method == "accesses" then
            term.setTextColor(colors.accent)
            print("Total entries: " .. (parsed.totalEntries or "Unknown"))
            print("Showing: " .. (parsed.requestedCount or "All"))
            print()
            term.setTextColor(colors.text)
            print(parsed.content)
        else
            term.setTextColor(colors.text)
            print(parsed.content)
        end
    end
    
    if parsed.method == "send" then
        printColored(":)  File uploaded successfully!", colors.success)
    end
end

-- Command Handlers
local function handleList()
    local screenType = getScreenType()
    local statusMsg = (screenType == "pocket") and "Getting list..." or "Fetching file list..."
    printColored(statusMsg, colors.secondary)
    local response = sendCommand("list")
    local parsed = parseResponse(response)
    displayResponse(parsed)
end

local function handleGet()
    local filename = promptUser("Enter filename or number: ", "File/num: ")
    
    if filename and filename ~= "" then
        local screenType = getScreenType()
        local statusMsg = (screenType == "pocket") and "Getting: " .. filename or "Downloading file: " .. filename
        printColored(statusMsg, colors.secondary)
        local response = sendCommand("get " .. filename)
        local parsed = parseResponse(response)
        
        if parsed and parsed.content and not parsed.content:find("ERROR:") then
            -- Create CC-friendly default filename
            local fName = parsed.title or filename
            -- Replace spaces with underscores
            fName = fName:gsub("%s+", "_")
            -- Ensure .txt extension if not present
            if not fName:match("%.txt$") then
                fName = fName .. ".txt"
            end
            
            -- Prompt for local filename
            local localName = promptUser("Save as (press Enter for '" .. fName .. "'): ", "Save as: ")
            
            if localName == "" then
                localName = fName
            else
                -- Apply same transformations to user input
                localName = localName:gsub("%s+", "_")
                if not localName:match("%.txt$") then
                    localName = localName .. ".txt"
                end
            end
            
            -- Save file locally
            local file = fs.open(localName, "w")
            file.write(parsed.content)
            file.close()
            
            printColored("File saved as: " .. localName, colors.success)
        else
            displayResponse(parsed)
        end
    else
        printColored("No filename provided", colors.error)
    end
end

local function handleRead()
    local filename = promptUser("Enter filename or number: ", "File/num: ")
    
    if filename and filename ~= "" then
        local screenType = getScreenType()
        local statusMsg = (screenType == "pocket") and "Reading: " .. filename or "Reading file: " .. filename
        printColored(statusMsg, colors.secondary)
        local response = sendCommand("read " .. filename)
        local parsed = parseResponse(response)
        displayResponse(parsed)
    else
        printColored("No filename provided", colors.error)
    end
end

local function handleSend()
    -- Show available .txt files in root directory
    local txtFiles = {}
    local allFiles = fs.list("/")
    
    for _, file in ipairs(allFiles) do
        if file:match("%.txt$") and not fs.isDir(file) then
            table.insert(txtFiles, file)
        end
    end
    
    if #txtFiles > 0 then
        local w, h = term.getSize()
        term.setTextColor(colors.secondary)
        
        if w >= 40 then
            print("Available .txt files in root directory:")
        elseif w >= 20 then
            print("Available .txt files:")
        else
            print("Files:")
        end
        
        for i, file in ipairs(txtFiles) do
            if w >= 25 then
                print(i .. ". " .. file)
            else
                -- Compact display for small screens
                local displayName = file
                if #file > w - 4 then
                    displayName = file:sub(1, w - 7) .. "..."
                end
                print(i .. "." .. displayName)
            end
        end
        print()
    end
    
    local filename = promptUser("Enter filename to upload (or number from list): ", "Upload file: ")
    
    if not filename or filename == "" then
        printColored("No filename provided", colors.error)
        return
    end
    
    -- Check if it's a number referring to the txt files list
    local fileNumber = tonumber(filename)
    if fileNumber and txtFiles[fileNumber] then
        filename = txtFiles[fileNumber]
    end
    
    if not fs.exists(filename) then
        printColored("File not found: " .. filename, colors.error)
        return
    end
    
    if fs.isDir(filename) then
        printColored("Cannot upload directory", colors.error)
        return
    end
    
    -- Prompt for server filename
    local serverName = promptUser("Enter name for file on server (press Enter for '" .. fs.getName(filename) .. "'): ", "Server name: ")
    
    if serverName == "" then
        serverName = fs.getName(filename)
    end
    
    -- Read file content
    local file = fs.open(filename, "r")
    local content = file.readAll()
    file.close()
    
    printColored("Uploading file as: " .. serverName, colors.secondary)
    local response = sendCommand("send " .. serverName .. " " .. content)
    local parsed = parseResponse(response)
    displayResponse(parsed)
end

local function handleAccesses()
    local count = promptUser("Enter number of entries to view (default 20): ", "Entries: ")
    
    if count == "" then
        count = "20"
    end
    
    printColored("Fetching access log...", colors.secondary)
    local response = sendCommand("accesses " .. count)
    local parsed = parseResponse(response)
    displayResponse(parsed)
end

-- Help display
local function showHelp()
    local w, h = term.getSize()
    
    if w >= 30 then
        printHeader("LOGS FTP Client - Commands")
    else
        printHeader("Commands")
    end
    
    term.setTextColor(colors.accent)
    print("Available Commands:")
    print()
    
    term.setTextColor(colors.secondary)
    
    -- Adaptive command display based on screen width
    if w >= 45 then
        -- Full descriptions for wide screens
        print("list     - List all files on the server")
        print("get      - Download a file from the server")
        print("read     - Read a file from the server (view only)")
        print("send     - Upload a file to the server")
        print("accesses - View server access log")
        print("help     - Show this help menu")
        print("clear    - Clear the screen")
        print("reconnect- Reconnect to server")
        print("exit     - Exit the client")
        print()
        
        term.setTextColor(colors.text)
        printWrapped("Note: For 'get' and 'read' commands, you can use either the filename or the number from the file list.")
    elseif w >= 25 then
        -- Medium descriptions
        print("list - List files")
        print("get  - Download file")
        print("read - View file")
        print("send - Upload file")
        print("accesses - Access log")
        print("help - Show help")
        print("clear - Clear screen")
        print("reconnect - Reconnect")
        print("exit - Exit")
        print()
        
        term.setTextColor(colors.text)
        printWrapped("Use filename or number for get/read commands.")
    else
        -- Compact for pocket computers
        print("list, get, read")
        print("send, accesses")
        print("help, clear")
        print("reconnect, exit")
        print()
        
        term.setTextColor(colors.text)
        printWrapped("Use file# for get/read")
    end
end

-- Main menu
local function showMenu()
    local w, h = term.getSize()
    
    term.setTextColor(colors.primary)
    print()
    
    if w >= 35 then
        print("Connected to server ID: " .. serverID)
        print("Type 'help' for available commands")
        print(string.rep("-", math.min(w, 40)))
    elseif w >= 20 then
        print("Server: " .. serverID)
        print("Type 'help' for commands")
        print(string.rep("-", w))
    else
        print("ID: " .. serverID)
        print("'help' for cmds")
        print(string.rep("-", w))
    end
    
    term.setTextColor(colors.text)
end

-- Main application loop
local function main()
    showSplash()
    
    if not discoverServer() then
        printColored("Failed to connect to server. Exiting...", colors.error)
        return
    end
    
    clearScreen()
    printHeader("LOGS FTP Client Terminal")
    showMenu()
    
    while true do
        local w, h = term.getSize()
        local prompt = (w >= 15) and "LOGS> " or "> "
        
        term.setTextColor(colors.accent)
        write(prompt)
        term.setTextColor(colors.text)
        local input = read()
        
        if not input then
            break
        end
        
        local command = input:lower():trim()
        
        if command == "exit" or command == "quit" then
            printColored("Goodbye!", colors.accent)
            break
        elseif command == "help" then
            showHelp()
        elseif command == "clear" or command == "cls" then
            clearScreen()
            printHeader("LOGS FTP Client Terminal")
            showMenu()
        elseif command == "list" or command == "ls" then
            handleList()
        elseif command == "get" or command == "download" then
            handleGet()
        elseif command == "read" or command == "cat" then
            handleRead()
        elseif command == "send" or command == "upload" then
            handleSend()
        elseif command == "accesses" or command == "log" then
            handleAccesses()
        elseif command == "reconnect" then
            serverID = nil
            if discoverServer() then
                printColored(":)  Reconnected successfully", colors.success)
                showMenu()
            end
        elseif command == "" then
            -- Do nothing for empty input
        else
            printColored("Unknown command: " .. command, colors.error)
            printColored("Type 'help' for available commands", colors.secondary)
        end
        
        print() -- Add spacing between commands
    end
end

-- String utility function
string.trim = string.trim or function(s)
    return s:match("^%s*(.-)%s*$")
end

-- Start the application
main()

-- Cleanup
rednet.close(modemSide)
