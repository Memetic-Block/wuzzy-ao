--- The AO module provides functionality for managing the AO environment and handling messages. Returns the ao table.
-- @module ao

local oldao = ao or {}

--- The AO module
--- @class ao
--- @field _version string The semantic version of the ao module (e.g., "0.0.6")
--- @field _module string The Arweave transaction ID of the process's module
--- @field id string The Arweave transaction ID of the process
--- @field authorities table A list of trusted authority addresses for the process
--- @field reference number An auto-incrementing counter used for message and spawn references
--- @field outbox table Contains Output, Messages, Spawns, and Assignments pending delivery
--- @field nonExtractableTags table Tag names excluded from automatic extraction to message root
--- @field nonForwardableTags table Tag names excluded when forwarding messages
--- @field clone function Deep clones a table, preserving metatables and handling circular references
--- @field normalize function Extracts message tags into root-level fields, excluding nonExtractableTags
--- @field sanitize function Returns a clone of a message with non-forwardable tags removed
--- @field init function Initializes the ao environment from the process environment
--- @field log function Appends a value to the outbox Output log
--- @field clearOutbox function Resets the outbox to empty Output, Messages, Spawns, and Assignments
--- @field send function Creates and queues a message to the outbox for delivery
--- @field spawn function Creates and queues a process spawn request to the outbox
--- @field assign function Queues an assignment of a message to one or more processes
--- @field isTrusted function Checks if a message sender or owner is in the authorities list
--- @field result function Compiles and returns the final process result from the outbox
--- @field env table|nil The process environment object, set by ao.init(). Contains Process (with Id, Tags, etc.). Nil before init is called
--- @field isAssignment function Returns whether a message is an assignment (target differs from process ID). Added by the assignment module
--- @field isAssignable function Checks whether a message matches any configured assignable MatchSpec. Added by the assignment module
--- @field addAssignable function Adds a MatchSpec to ao.assignables, optionally with a name. Added by the assignment module
--- @field removeAssignable function Removes a MatchSpec from ao.assignables by name or index. Added by the assignment module
local ao = {
    _version = "0.0.6",
    id = oldao.id or "",
    _module = oldao._module or "",
    authorities = oldao.authorities or {},
    reference = oldao.reference or 0,
    outbox = oldao.outbox or
        {Output = {}, Messages = {}, Spawns = {}, Assignments = {}},
    nonExtractableTags = {
        'Data-Protocol', 'Variant', 'From-Process', 'From-Module', 'Type',
        'From', 'Owner', 'Anchor', 'Target', 'Data', 'Tags', 'Read-Only'
    },
    nonForwardableTags = {
        'Data-Protocol', 'Variant', 'From-Process', 'From-Module', 'Type',
        'From', 'Owner', 'Anchor', 'Target', 'Tags', 'TagArray', 'Hash-Chain',
        'Timestamp', 'Nonce', 'Epoch', 'Signature', 'Forwarded-By',
        'Pushed-For', 'Read-Only', 'Cron', 'Block-Height', 'Reference', 'Id',
        'Reply-To'
    },
    Nonce = nil,
    env = nil
}

--- Checks if a key exists in a list.
-- @lfunction _includes
-- @tparam {table} list The list to check against
-- @treturn {function} A function that takes a key and returns true if the key exists in the list
local function _includes(list)
    return function(key)
        local exists = false
        for _, listKey in ipairs(list) do
            if key == listKey then
                exists = true
                break
            end
        end
        if not exists then return false end
        return true
    end
end

--- Checks if a table is an array.
-- @lfunction isArray
-- @tparam {table} table The table to check
-- @treturn {boolean} True if the table is an array, false otherwise
local function isArray(table)
    if type(table) == "table" then
        local maxIndex = 0
        for k, v in pairs(table) do
            if type(k) ~= "number" or k < 1 or math.floor(k) ~= k then
                return false -- If there's a non-integer key, it's not an array
            end
            maxIndex = math.max(maxIndex, k)
        end
        -- If the highest numeric index is equal to the number of elements, it's an array
        return maxIndex == #table
    end
    return false
end

--- Pads a number with leading zeros to 32 digits.
-- @lfunction padZero32
-- @tparam {number} num The number to pad
-- @treturn {string} The padded number as a string
local function padZero32(num) return string.format("%032d", num) end

--- Deep clones a table recursively, preserving metatables and handling circular references.
-- Non-table values are returned as-is. Previously-seen tables return the existing clone.
-- @function clone
-- @tparam {any} obj The object to clone
-- @tparam {table} seen A table tracking already-cloned objects to handle circular references (default is nil)
-- @treturn {any} A deep copy of the input object
function ao.clone(obj, seen)
    -- Handle non-tables and previously-seen tables.
    if type(obj) ~= 'table' then return obj end
    if seen and seen[obj] then return seen[obj] end

    -- New table; mark it as seen and copy recursively.
    local s = seen or {}
    local res = {}
    s[obj] = res
    for k, v in pairs(obj) do res[ao.clone(k, s)] = ao.clone(v, s) end
    return setmetatable(res, getmetatable(obj))
end

--- Normalizes a message by extracting tags to root-level fields.
-- Copies tag values (excluding nonExtractableTags) from msg.Tags into the message root.
-- @function normalize
-- @tparam {table} msg The message to normalize. Must have a Tags array of {name, value} pairs
-- @treturn {table} The normalized message with tag values accessible as root-level fields
function ao.normalize(msg)
    for _, o in ipairs(msg.Tags) do
        if not _includes(ao.nonExtractableTags)(o.name) then
            msg[o.name] = o.value
        end
    end
    return msg
end

--- Creates a sanitized copy of a message with non-forwardable tags removed.
-- Clones the message and removes all fields matching nonForwardableTags, making it safe for forwarding.
-- @function sanitize
-- @tparam {table} msg The message to sanitize
-- @treturn {table} A new message table with non-forwardable tags removed
function ao.sanitize(msg)
    local newMsg = ao.clone(msg)

    for k, _ in pairs(newMsg) do
        if _includes(ao.nonForwardableTags)(k) then newMsg[k] = nil end
    end

    return newMsg
end

--- Initializes the AO environment, including ID, module, authorities, outbox, and environment.
-- @function init
-- @tparam {table} env The environment object
function ao.init(env)
    if ao.id == "" then ao.id = env.Process.Id end

    if ao._module == "" then
        for _, o in ipairs(env.Process.Tags) do
            if o.name == "Module" then ao._module = o.value end
        end
    end

    for _, o in ipairs(env.Process.Tags) do
        if o.name == "Authority" then
            for part in string.gmatch(o.value, "[^,]+") do
                if part ~= "" and part ~= nil and not _includes(ao.authorities)(part) then
                    table.insert(ao.authorities, part)
                end
            end
        end
    end

    ao.outbox = {Output = {}, Messages = {}, Spawns = {}, Assignments = {}}
    ao.env = env

end

--- Appends a value to the outbox Output log.
-- If Output is currently a string, it is first converted to a table before appending.
-- @function log
-- @tparam {any} txt The value to append to the output log
function ao.log(txt)
    if type(ao.outbox.Output) == 'string' then
        ao.outbox.Output = {ao.outbox.Output}
    end
    table.insert(ao.outbox.Output, txt)
end

--- Resets the outbox to its initial empty state.
-- Re-initializes Output, Messages, Spawns, and Assignments as empty tables.
-- @function clearOutbox
function ao.clearOutbox()
    ao.outbox = {Output = {}, Messages = {}, Spawns = {}, Assignments = {}}
end

--- Sends a message to the target process.
-- Constructs a tagged AO protocol message from the input, adds it to the outbox,
-- and returns a handle with onReply and receive callbacks for response handling.
-- Custom root-level fields are moved into message Tags automatically.
-- @function send
-- @tparam {table} msg The message to send. Must include Target; may include Data, Tags, and custom fields
-- @treturn {table} message The constructed message with Tags, Anchor, onReply, and receive callbacks
function ao.send(msg)
    assert(type(msg) == 'table', 'msg should be a table')
    ao.reference = ao.reference + 1
    local referenceString = tostring(ao.reference)

    local message = {
        Target = msg.Target,
        Data = msg.Data,
        Anchor = padZero32(ao.reference),
        Tags = {
            {name = "Data-Protocol", value = "ao"},
            {name = "Variant", value = "ao.TN.1"},
            {name = "Type", value = "Message"},
            {name = "Reference", value = referenceString}
        }
    }

    -- if custom tags in root move them to tags
    for k, v in pairs(msg) do
        if not _includes({"Target", "Data", "Anchor", "Tags", "From"})(k) then
            table.insert(message.Tags, {name = k, value = v})
        end
    end

    if msg.Tags then
        if isArray(msg.Tags) then
            for _, o in ipairs(msg.Tags) do
                table.insert(message.Tags, o)
            end
        else
            for k, v in pairs(msg.Tags) do
                table.insert(message.Tags, {name = k, value = v})
            end
        end
    end

    -- If running in an environment without the AOS Handlers module, do not add
    -- the onReply and receive functions to the message.
    if not Handlers then return message end

    -- clone message info and add to outbox
    local extMessage = {}
    for k, v in pairs(message) do extMessage[k] = v end

    -- add message to outbox
    table.insert(ao.outbox.Messages, extMessage)

    -- add callback for onReply handler(s)
    message.onReply =
        function(...) -- Takes either (AddressThatWillReply, handler(s)) or (handler(s))
            local from, resolver
            if select("#", ...) == 2 then
                from = select(1, ...)
                resolver = select(2, ...)
            else
                from = message.Target
                resolver = select(1, ...)
            end

            -- Add a one-time callback that runs the user's (matching) resolver on reply
            Handlers.once({From = from, ["X-Reference"] = referenceString},
                          resolver)
        end

    message.receive = function(...)
        local from = message.Target
        if select("#", ...) == 1 then from = select(1, ...) end
        return
            Handlers.receive({From = from, ["X-Reference"] = referenceString})
    end

    return message
end

--- Spawns a new AO process.
-- Constructs a tagged spawn request, adds it to the outbox, and returns a handle
-- with onReply and receive callbacks for tracking the spawned process.
-- Custom root-level fields are moved into spawn Tags automatically.
-- @function spawn
-- @tparam {string} module The Arweave transaction ID of the module to use for the new process
-- @tparam {table} msg The spawn configuration. May include Data, Tags, and custom fields
-- @treturn {table} spawn The constructed spawn request with Tags, Anchor, onReply, and receive callbacks
function ao.spawn(module, msg)
    assert(type(module) == "string", "Module source id is required!")
    assert(type(msg) == 'table', 'Message must be a table')
    -- inc spawn reference
    ao.reference = ao.reference + 1
    local spawnRef = tostring(ao.reference)

    local spawn = {
        Data = msg.Data or "NODATA",
        Anchor = padZero32(ao.reference),
        Tags = {
            {name = "Data-Protocol", value = "ao"},
            {name = "Variant", value = "ao.TN.1"},
            {name = "Type", value = "Process"},
            {name = "From-Process", value = ao.id},
            {name = "From-Module", value = ao._module},
            {name = "Module", value = module},
            {name = "Reference", value = spawnRef}
        }
    }

    -- if custom tags in root move them to tags
    for k, v in pairs(msg) do
        if not _includes({"Target", "Data", "Anchor", "Tags", "From"})(k) then
            table.insert(spawn.Tags, {name = k, value = v})
        end
    end

    if msg.Tags then
        if isArray(msg.Tags) then
            for _, o in ipairs(msg.Tags) do
                table.insert(spawn.Tags, o)
            end
        else
            for k, v in pairs(msg.Tags) do
                table.insert(spawn.Tags, {name = k, value = v})
            end
        end
    end

    -- If running in an environment without the AOS Handlers module, do not add
    -- the after and receive functions to the spawn.
    if not Handlers then return spawn end

    -- clone spawn info and add to outbox
    local extSpawn = {}
    for k, v in pairs(spawn) do extSpawn[k] = v end

    table.insert(ao.outbox.Spawns, extSpawn)

    -- add 'after' callback to returned table
    -- local result = {}
    spawn.onReply = function(callback)
        Handlers.once({
            Action = "Spawned",
            From = ao.id,
            ["Reference"] = spawnRef
        }, callback)
    end

    spawn.receive = function()
        return Handlers.receive({
            Action = "Spawned",
            From = ao.id,
            ["Reference"] = spawnRef
        })

    end

    return spawn
end

--- Registers a hint from an incoming message's From-Process tag.
-- Parses the From-Process tag value for hint and hint-ttl parameters
-- (format: "processId&hint=value&ttl=value"), storing them in ao._hints.
-- Enforces a bounded registry of 1000 entries, evicting the oldest entry
-- by TTL when the limit is exceeded.
-- @function registerHint
-- @tparam {table} msg The incoming message, potentially containing hint metadata in its From-Process tag
function ao.registerHint(msg)
  -- check if From-Process tag exists
  local fromProcess = nil
  local hint = nil
  local hintTTL = nil

  -- find From-Process tag
  if msg.Tags then
      for name, value in pairs(msg.Tags) do
          if name == "From-Process" then
              -- split by & to get process, hint, and ttl
              local parts = {}

              for part in string.gmatch(value, "[^&]+") do
                  table.insert(parts, part)
              end
              local hintParts = {}
              if parts[2] then
                  for item in string.gmatch(parts[2], "[^=]+") do
                      table.insert(hintParts, item)
                  end
              end
              local ttlParts = {}
              if parts[3] then
                  for item in string.gmatch(parts[3], "[^=]+") do
                      table.insert(ttlParts, item)
                  end
              end

              fromProcess = parts[1] or nil
              hint = hintParts[2] or nil
              hintTTL = ttlParts[2] or nil
              break
          end
      end
  end

  -- if we found a hint, store it in the registry
  if hint then
      if not ao._hints then
          ao._hints = {}
      end
      if not fromProcess then
        ---@diagnostic disable-next-line: need-check-nil
        ao._hints[fromProcess] = {
            hint = hint,
            ttl = hintTTL
        }
      end
  end
  -- enforce bounded registry of 1000 keys
  if ao._hints then
      local count = 0
      local oldest = nil
      local oldestKey = nil

      -- count keys and find oldest entry
      for k, v in pairs(ao._hints) do
          count = count + 1
          if not oldest or v.ttl < oldest then
              oldest = v.ttl
              oldestKey = k
          end
      end

      -- if over 1000 entries, remove oldest
      if count > 1000 and oldestKey then
          ao._hints[oldestKey] = nil
      end
  end
end

--- Assigns a message to one or more processes by adding it to the outbox Assignments.
-- Validates that the assignment contains both a Processes table and a Message string.
-- @function assign
-- @tparam {table} assignment The assignment table. Must contain Processes (table of process IDs) and Message (string message ID)
function ao.assign(assignment)
    assert(type(assignment) == 'table', 'assignment should be a table')
    assert(type(assignment.Processes) == 'table', 'Processes should be a table')
    assert(type(assignment.Message) == "string", "Message should be a string")
    table.insert(ao.outbox.Assignments, assignment)
end


--- Checks if a message is trusted.
-- The default security model of AOS processes: Trust all and *only* those on the ao.authorities list.
-- @function isTrusted
-- @tparam {table} msg The message to check
-- @treturn {boolean} True if the message is trusted, false otherwise
function ao.isTrusted(msg)
    for _, authority in ipairs(ao.authorities) do
        if msg.From == authority then return true end
        if msg.Owner == authority then return true end
    end
    return false
end

--- Compiles and returns the final process result from the outbox.
-- If an error is present in the outbox or input result, returns only the Error field.
-- Otherwise, returns Output, Messages, Spawns, and Assignments.
-- @function result
-- @tparam {table} result The result object, may contain Output and/or Error fields
-- @treturn {table} The compiled result with either {Error} or {Output, Messages, Spawns, Assignments}
function ao.result(result)
    -- if error then only send the Error to CU
    if ao.outbox.Error or result.Error then
        return {Error = result.Error or ao.outbox.Error}
    end
    return {
        Output = result.Output or ao.outbox.Output,
        Messages = ao.outbox.Messages,
        Spawns = ao.outbox.Spawns,
        Assignments = ao.outbox.Assignments
    }
end


--- Add the MatchSpec to the ao.assignables table. A optional name may be provided.
-- This implies that ao.assignables may have both number and string indices.
-- Added in the assignment module.
-- @function addAssignable
-- @tparam ?string|number|any nameOrMatchSpec The name of the MatchSpec
--        to be added to ao.assignables. if a MatchSpec is provided, then
--        no name is included
-- @tparam ?any matchSpec The MatchSpec to be added to ao.assignables. Only provided
--        if its name is passed as the first parameter
-- @treturn ?string|number name The name of the MatchSpec, either as provided
--          as an argument or as incremented
-- @see assignment

--- Remove the MatchSpec, either by name or by index
-- If the name is not found, or if the index does not exist, then do nothing.
-- Added in the assignment module.
-- @function removeAssignable
-- @tparam {string|number} name The name or index of the MatchSpec to be removed
-- @see assignment

--- Return whether the msg is an assignment or not. This can be determined by simply check whether the msg's Target is this process' id
-- Added in the assignment module.
-- @function isAssignment
-- @param msg The msg to be checked
-- @treturn boolean isAssignment
-- @see assignment

--- Check whether the msg matches any assignable MatchSpec.
-- If not assignables are configured, the msg is deemed not assignable, by default.
-- Added in the assignment module.
-- @function isAssignable
-- @param msg The msg to be checked
-- @treturn boolean isAssignable
-- @see assignment

-- Export the ao module as a typed global so consuming files resolve all fields.
---@type ao
_G.ao = ao

return ao
