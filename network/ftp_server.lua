-- Logs FTP Server (Protocol: "LOGS")
-- Enhanced server with robust client input handling
local modemSide = "back" -- Change this to your modem's side

KVList = {} -- volatile list for file numbers to names

term.clear()
term.setCursorPos(1, 1)

-- Terminal colors for prettier output
local colors = {
    primary = colors.cyan,
    secondary = colors.lightBlue,
    accent = colors.yellow,
    success = colors.lime,
    error = colors.red,
    info = colors.white
}

-- Utility: Colored print
local function printColored(text, color)
    color = color or colors.info
    term.setTextColor(color)
    print(text)
    term.setTextColor(colors.info)
end

-- Setup
rednet.open(modemSide)
term.setTextColor(colors.success)
print("=" .. string.rep("=", 40) .. "=")
print("         LOGS FTP SERVER ONLINE")
print("=" .. string.rep("=", 40) .. "=")
term.setTextColor(colors.primary)
print("Protocol: LOGS")
print("Modem: " .. modemSide)
print("Listening for connections...")
term.setTextColor(colors.info)

-- Ensure logs folder exists
if not fs.exists("/logs") then
    fs.makeDir("/logs")
end

-- Ensure access log exists
if not fs.exists("/accesses.txt") then
    local file = fs.open("/accesses.txt", "w")
    file.writeLine("Access log initialized at " .. textutils.formatTime(os.time(), true))
    file.close()
end

-- Utility: Log access
local function logAccess(id, action)
    local timestamp = textutils.formatTime(os.time(), true)
    local file = fs.open("/accesses.txt", "a")
    file.writeLine("[" .. timestamp .. "] ID " .. id .. ": " .. action)
    file.close()

    printColored(string.format("[%s] Client %d: %s", timestamp, id, action), colors.accent)
end

-- Utility: Safe string handling
local function safeString(str)
    if not str then return "" end
    return tostring(str):gsub("[%c%z]", "") -- Remove control characters
end

-- Utility: Validate filename
local function isValidFilename(filename)
    if not filename or filename == "" then return false end
    -- Check for basic invalid characters (keep it simple for CC)
    if filename:match("[/\\<>:|?*\"]") then return false end
    return true
end


local function handleList(id)
    -- Filter to only show .txt files
    local allFiles = fs.list("/logs")
    local files = {}
    
    for _, file in ipairs(allFiles) do
        if file:match("%.txt$") and not fs.isDir("/logs/" .. file) then
            table.insert(files, file)
        end
    end
    
    local count = #files
    KVList = {} -- Reset the list

    if count == 0 then
        local response = {
            method = "list",
            title = "Log Directory Listing",
            content = "No .txt log files found.\nThe logs directory is empty or contains no .txt files.",
            files = {},
            count = 0
        }
        rednet.send(id, textutils.serialize(response), "LOGS")
        logAccess(id, "Listed logs (empty)")
        return
    end

    local response = "There " .. (count == 1 and "is" or "are") .. " " .. count .. " .txt log" .. (count == 1 and "" or "s") .. " available:\n"
    response = response .. string.rep("-", 35) .. "\n"
    
    for i, filename in ipairs(files) do
        response = response .. string.format("%2d. %s\n", i, filename)
        KVList[i] = filename
    end

    -- Create structured response for list
    local listResponse = {
        method = "list",
        title = "Log Directory Listing",
        content = response,
        files = files,
        count = count
    }

    rednet.send(id, textutils.serialize(listResponse), "LOGS")
    logAccess(id, "Listed " .. count .. " .txt log files")
end


-- Helper function to handle file retrieval for both get and read
local function handleFileRetrieval(id, filename, method)
    if not filename then
        rednet.send(id, "ERROR: No filename provided", "LOGS")
        logAccess(id, "FAILED " .. string.upper(method) .. " - No filename")
        return
    end

    -- Sanitize input
    filename = safeString(filename):trim()
    if filename == "" then
        rednet.send(id, "ERROR: Empty filename provided", "LOGS")
        logAccess(id, "FAILED " .. string.upper(method) .. " - Empty filename")
        return
    end

    -- Check if filename is a number and use KVList lookup
    local actualFilename = filename
    local fileNumber = tonumber(filename)
    if fileNumber then
        if KVList[fileNumber] then
            actualFilename = KVList[fileNumber]
        else
            rednet.send(id, "ERROR: Invalid file number '" .. filename .. "'", "LOGS")
            logAccess(id, "FAILED " .. string.upper(method) .. " - Invalid file number: " .. filename)
            return
        end
    end

    local path = "/logs/" .. actualFilename
    if fs.exists(path) and not fs.isDir(path) then
        local file = fs.open(path, "r")
        if not file then
            rednet.send(id, "ERROR: Could not open file '" .. actualFilename .. "'", "LOGS")
            logAccess(id, "FAILED " .. string.upper(method) .. " - Cannot open: " .. actualFilename)
            return
        end
        
        local content = file.readAll()
        file.close()
        
        -- Create structured response
        local response = {
            method = method,
            title = actualFilename,
            content = content or "",
            filesize = #(content or "")
        }
        
        rednet.send(id, textutils.serialize(response), "LOGS")
        logAccess(id, string.upper(method) .. " file '" .. actualFilename .. "' (" .. #(content or "") .. " bytes)")
    else
        rednet.send(id, "ERROR: File '" .. actualFilename .. "' not found", "LOGS")
        logAccess(id, "FAILED " .. string.upper(method) .. " - File not found: " .. actualFilename)
    end
end

local function handleGet(id, filename)
    handleFileRetrieval(id, filename, "get")
end

local function handleRead(id, filename)
    handleFileRetrieval(id, filename, "read")
end


local function handleAccesses(id, count)
    local maxLines = tonumber(count) or 20 -- default to 20 lines
    
    if not fs.exists("/accesses.txt") then
        rednet.send(id, "ERROR: Access log not found", "LOGS")
        return
    end
    
    local file = fs.open("/accesses.txt", "r")
    local lines = {}
    local line = file.readLine()
    
    -- Read all lines into table
    while line do
        table.insert(lines, line)
        line = file.readLine()
    end
    file.close()
    
    -- Get the last maxLines entries
    local startIndex = math.max(1, #lines - maxLines + 1)
    local recentLines = {}
    
    for i = startIndex, #lines do
        table.insert(recentLines, lines[i])
    end
    
    local content = table.concat(recentLines, "\n")
    
    -- Create structured response
    local response = {
        method = "accesses",
        title = "Last " .. math.min(maxLines, #lines) .. " Access Log Entries",
        content = content,
        totalEntries = #lines,
        requestedCount = maxLines
    }
    
    rednet.send(id, textutils.serialize(response), "LOGS")
    logAccess(id, "ACCESSES viewed last " .. maxLines .. " entries")
end


local function handleSend(id, filename, content)
    if not filename or not content then
        rednet.send(id, "ERROR: Missing filename or content", "LOGS")
        logAccess(id, "FAILED SEND - Missing filename or content")
        return
    end

    -- Sanitize inputs
    filename = safeString(filename):trim()
    content = safeString(content)

    if filename == "" then
        rednet.send(id, "ERROR: Empty filename provided", "LOGS")
        logAccess(id, "FAILED SEND - Empty filename")
        return
    end

    if not isValidFilename(filename) then
        rednet.send(id, "ERROR: Invalid filename '" .. filename .. "'", "LOGS")
        logAccess(id, "FAILED SEND - Invalid filename: " .. filename)
        return
    end

    -- Ensure .txt extension for consistency
    if not filename:match("%.txt$") then
        filename = filename .. ".txt"
    end

    local path = "/logs/" .. filename
    
    -- Check if file already exists and warn
    local fileExists = fs.exists(path)
    
    local file = fs.open(path, "w")
    if not file then
        rednet.send(id, "ERROR: Could not create file '" .. filename .. "'", "LOGS")
        logAccess(id, "FAILED SEND - Cannot create file: " .. filename)
        return
    end
    
    file.write(content)
    file.close()
    
    -- Create structured response for send
    local sendResponse = {
        method = "send",
        title = filename,
        content = fileExists and "File overwritten successfully" or "File saved successfully",
        filesize = #content,
        overwritten = fileExists
    }
    
    rednet.send(id, textutils.serialize(sendResponse), "LOGS")
    local action = fileExists and "OVERWRITE" or "UPLOAD"
    logAccess(id, action .. " file '" .. filename .. "' (" .. #content .. " bytes)")
end

local commandHandlers = {
    list = function(id) handleList(id) end,
    get = function(id, a1, a2) handleGet(id, a1) end,
    read = function(id, a1, a2) handleRead(id, a1) end, -- read-only access to logs
    send = function(id, a1, a2) handleSend(id, a1, a2) end,
    accesses = function(id, a1, a2) handleAccesses(id, a1) end -- view access history
}



-- Main server loop with enhanced error handling
local TIMEOUT = 5

-- Add string trim function
string.trim = string.trim or function(s)
    return s:match("^%s*(.-)%s*$")
end

while true do
    ::continue::

    local id, message = rednet.receive("LOGS", TIMEOUT)
    
    if not id then
        os.sleep(0.1) -- No message received, wait a bit
        goto continue
    end
    
    -- Handle ping requests for server discovery
    if message == "ping" then
        rednet.send(id, "pong", "LOGS")
        printColored("Client " .. id .. " discovered server", colors.secondary)
        goto continue
    end
    
    -- Sanitize and parse the message
    message = safeString(message):trim()
    if message == "" then
        rednet.send(id, "ERROR: Empty command", "LOGS")
        logAccess(id, "FAILED - Empty command")
        goto continue
    end
    
    local parts = {}
    for word in string.gmatch(message, "%S+") do
        table.insert(parts, word)
    end

    if #parts == 0 then
        rednet.send(id, "ERROR: No command provided", "LOGS")
        logAccess(id, "FAILED - No command")
        goto continue
    end

    local command = parts[1]:lower() -- Make commands case-insensitive
    local arg1 = parts[2]
    local arg2 = table.concat(parts, " ", 3) -- for send, allows spaces in content

    local handler = commandHandlers[command]
    if handler then
        -- Wrap handler in pcall for error protection
        local success, error = pcall(handler, id, arg1, arg2)
        if not success then
            rednet.send(id, "ERROR: Server error processing command", "LOGS")
            printColored("ERROR handling command '" .. command .. "' from client " .. id .. ": " .. tostring(error), colors.error)
            logAccess(id, "ERROR - " .. command .. " failed: " .. tostring(error))
        end
    else
        rednet.send(id, "ERROR: Unknown command '" .. tostring(command) .. "'", "LOGS")
        logAccess(id, "FAILED - Unknown command: " .. tostring(command))
    end
end
