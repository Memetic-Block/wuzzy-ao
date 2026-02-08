-- Wuzzy Nest Registry for AO Legacynet
local json = require('json')
acl = require('..common.acl')
nests = nests or {}
registry_whitelist_enabled = registry_whitelist_enabled or true

local MAX_PAGE_SIZE = 1000
local DEFAULT_PAGE_SIZE = 100

-- Find the index of a nest by its id, or nil if not found.
local function findNestIndex(nestId)
  for i, nest in ipairs(nests) do
    if nest.id == nestId then
      return i
    end
  end
  return nil
end

-- Paginate an array of nest entries ({ id, owner, acl }).
-- Returns { items = [...], nextCursor = string|nil, hasMore = bool, total = number }
local function paginate(entries, cursor, limit)
  limit = math.min(tonumber(limit) or DEFAULT_PAGE_SIZE, MAX_PAGE_SIZE)
  if limit < 1 then limit = DEFAULT_PAGE_SIZE end

  -- Sort entries by id for deterministic ordering
  table.sort(entries, function (a, b) return a.id < b.id end)

  local total = #entries
  local startIdx = 1

  if cursor ~= nil and cursor ~= '' then
    for i, entry in ipairs(entries) do
      if entry.id == cursor then
        startIdx = i + 1
        break
      end
    end
  end

  local items = {}
  local lastId = nil

  for i = startIdx, math.min(startIdx + limit - 1, total) do
    table.insert(items, entries[i])
    lastId = entries[i].id
  end

  local hasMore = (startIdx + limit - 1) < total

  return {
    items = items,
    nextCursor = hasMore and lastId or nil,
    hasMore = hasMore,
    total = total
  }
end

-- Parse and validate nest state from a View-State-Response message.
-- Returns { owner = string, acl = table }
local function parseNestState(data)
  assert(
    type(data) == 'string' and #data > 0,
    'State data is required'
  )
  local nestState = json.decode(data)
  assert(type(nestState) == 'table', 'State data must be a valid JSON object')
  assert(type(nestState.acl) == 'table', 'State must include acl')
  assert(
    type(nestState.owner) == 'string' and #nestState.owner > 0,
    'State must include owner'
  )
  return nestState
end

-- Update ACL Roles --
Handlers.add('Update-Roles', 'Update-Roles', function (msg)
  acl.utils.assertHasOneOfRole(msg.From, { 'owner', 'admin', 'Update-Roles' })

  acl.utils.updateRoles(json.decode(msg.Data))

  ao.send({
    Target = msg.From,
    Action = 'Update-Roles-Response',
    Data = 'OK'
  })
  ao.send({
    device = 'patch@1.0',
    acl = acl.state
  })
end)

-- View ACL Roles --
Handlers.add('View-Roles', 'View-Roles', function (msg)
  ao.send({
    Target = msg.From,
    Action = 'View-Roles-Response',
    Data = json.encode(acl.state)
  })
end)

Handlers.add('Toggle-Whitelist', 'Toggle-Whitelist', function (msg)
  acl.utils.assertHasOneOfRole(msg.From, { 'owner', 'admin', 'Toggle-Whitelist' })
  local enabled = msg.Tags['Enabled']
  assert(type(enabled) == 'string', 'Enabled tag is required and must be a string')
  assert(enabled == 'true' or enabled == 'false', 'Enabled tag must be "true" or "false"')

  registry_whitelist_enabled = (enabled == 'true')

  ao.send({
    Target = msg.From,
    Action = 'Toggle-Whitelist-Response',
    Data = registry_whitelist_enabled and 'enabled' or 'disabled'
  })
  ao.send({
    device = 'patch@1.0',
    registry_whitelist_enabled = registry_whitelist_enabled
  })
end)

-- Register-Nest
-- Completes registration or update by extracting owner and ACL from the nest's state.
Handlers.add('Register-Nest', 'Register-Nest', function (msg)
  if registry_whitelist_enabled then
    acl.utils.assertHasOneOfRole(msg.From, { 'Register-Nest' })
  end

  local nestState = parseNestState(msg.Data)
  local idx = findNestIndex(msg.From)

  assert(idx == nil, 'Nest is already registered: ' .. tostring(msg.From))
  table.insert(nests, {
    id = msg.From,
    owner = nestState.owner,
    acl = nestState.acl
  })

  ao.send({
    device = 'patch@1.0',
    nests = nests
  })
end)

-- Unregister
-- A nest process removes itself from the registry.
Handlers.add('Unregister', 'Unregister', function (msg)
  local idx = findNestIndex(msg.From)
  assert(
    idx ~= nil,
    'Nest is not registered: ' .. tostring(msg.From)
  )

  table.remove(nests, idx)

  ao.send({
    Target = msg.From,
    Action = 'Unregister-Response',
    Data = 'OK'
  })
  ao.send({
    device = 'patch@1.0',
    nests = nests
  })
end)

-- Batch-Unregister
-- Owner/Admin can unregister multiple nests at once by providing a list of nest IDs.
-- Data: JSON-encoded array of nest IDs to unregister.
Handlers.add('Batch-Unregister', 'Batch-Unregister', function (msg)
  acl.utils.assertHasOneOfRole(msg.From, { 'owner', 'admin', 'Batch-Unregister' })

  assert(
    type(msg.Data) == 'string' and #msg.Data > 0,
    'Data is required'
  )
  local nestIds = json.decode(msg.Data)
  assert(type(nestIds) == 'table', 'Data must be a JSON array of nest IDs')

  local idsToRemove = {}
  for _, nestId in ipairs(nestIds) do
    idsToRemove[nestId] = true
  end
  for i = #nests, 1, -1 do
    if idsToRemove[nests[i].id] then
      table.remove(nests, i)
    end
  end

  ao.send({
    Target = msg.From,
    Action = 'Batch-Unregister-Response',
    Data = 'OK'
  })
  ao.send({
    device = 'patch@1.0',
    nests = nests
  })
end)

-- Update-Registration
-- A nest process updates its registration (owner and ACL).
-- Data: JSON-encoded state (same format as View-State-Response).
Handlers.add('Update-Registration', 'Update-Registration', function (msg)
  local idx = findNestIndex(msg.From)
  assert(
    idx ~= nil,
    'Nest is not registered: ' .. tostring(msg.From)
  )

  local nestState = parseNestState(msg.Data)
  nests[idx].owner = nestState.owner
  nests[idx].acl = nestState.acl

  ao.send({
    Target = msg.From,
    Action = 'Update-Registration-Response',
    Data = 'OK'
  })
  ao.send({
    device = 'patch@1.0',
    nests = nests
  })
end)

-- List-Nests
-- Returns registered nests with pagination and optional owner filter.
-- Tags: Cursor (optional), Limit (optional, default 100, max 1000), Owner (optional)
Handlers.add('List-Nests', 'List-Nests', function (msg)
  local ownerFilter = msg.Tags['Owner']
  local entries = {}

  for _, nest in ipairs(nests) do
    if ownerFilter == nil or ownerFilter == '' or nest.owner == ownerFilter then
      table.insert(entries, nest)
    end
  end

  local page = paginate(entries, msg.Tags['Cursor'], msg.Tags['Limit'])

  ao.send({
    Target = msg.From,
    Action = 'List-Nests-Response',
    ['Next-Cursor'] = page.nextCursor or '',
    ['Has-More'] = tostring(page.hasMore),
    ['Total'] = tostring(page.total),
    Data = json.encode(page.items)
  })
end)

-- List-Nests-By-Address
-- Returns nests where the given address is owner or has any ACL role, with pagination.
-- Tags: Address (optional, defaults to msg.From), Cursor (optional), Limit (optional, default 100, max 1000)
Handlers.add('List-Nests-By-Address', 'List-Nests-By-Address', function (msg)
  local address = msg.Tags['Address'] or msg.From
  assert(
    type(address) == 'string' and #address > 0,
    'Address is required'
  )

  local entries = {}

  for _, nest in ipairs(nests) do
    local matched = false

    if nest.owner == address then
      matched = true
    end

    if not matched and type(nest.acl) == 'table' and type(nest.acl.roles) == 'table' then
      for _, members in pairs(nest.acl.roles) do
        if type(members) == 'table' and members[address] then
          matched = true
          break
        end
      end
    end

    if matched then
      table.insert(entries, nest)
    end
  end

  local page = paginate(entries, msg.Tags['Cursor'], msg.Tags['Limit'])

  ao.send({
    Target = msg.From,
    Action = 'List-Nests-By-Address-Response',
    ['Next-Cursor'] = page.nextCursor or '',
    ['Has-More'] = tostring(page.hasMore),
    ['Total'] = tostring(page.total),
    Data = json.encode(page.items)
  })
end)

-- View-State
-- Returns the full registry state.
Handlers.add('View-State', 'View-State', function (msg)
  ao.send({
    Target = msg.From,
    Action = 'View-State-Response',
    Data = json.encode({ nests = nests, acl = acl.state })
  })
end)

-- Patch initial state to device
ao.send({
  device = 'patch@1.0',
  nests = nests
})
