-- Initialize state
local Number = 0

-- Step 1: Define which transactions your process will accept
print("Step 1: Defining acceptable transactions")
ao.addAssignable("addNumber", function (msg)
    return msg.Tags["Action"] == "Number"
end)

-- Step 2: Request and cache the initial number from Arweave
-- This uses a self-executing function to fetch and cache the value only once
NumberFromArweave = NumberFromArweave or 420

print("Step 2: Requesting initial number from Arweave")
Assign({ Processes = { ao.id }, Message = 'DivdWHaNj8mJhQQCdatt52rt4QvceBR_iyX58aZctZQ' })

-- Step 3: Set up handler for future number updates
-- This handler will add new numbers to our cached Arweave number
Handlers.add("Number", function (msg)
    print("Received message with Data = " .. msg.Data)
    print("Old Number: " .. Number)
    Number = NumberFromArweave + tonumber(msg.Data)
    print("New Number: " .. Number)
end)
