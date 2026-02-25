-- Wuzzy Nest Registry for hyper-aos
local json = require('json')
local crypto = require('.crypto')
acl = require('..common.acl')
nests = nests or {}
registration_codes = registration_codes or {}
registration_code_required = registration_code_required ~= false

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

-- Hash a registration code secret using SHA2-512, returning the hex digest.
local function hashRegistrationCode(secret)
  return crypto.digest.sha2_512(secret).asHex()
end

-- Validate a registration code secret against stored hashes.
-- Returns the hash if valid, or nil if no match.
local function validateRegistrationCode(secret)
  local hash = hashRegistrationCode(secret)
  if registration_codes[hash] then
    return hash
  end
  return nil
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
  acl.assertHasOneOfRole(msg.From, { 'owner', 'admin', 'Update-Roles' })
  acl = acl.updateRoles(require('json').decode(msg.Data), acl)
  Send({
    Target = msg.From,
    Action = 'Update-Roles-Response',
    Data = 'OK'
  })
  Send({
    Target = ao.id,
    device = 'patch@1.0',
    acl = acl
  })
end)

-- View ACL Roles --
Handlers.add('View-Roles', 'View-Roles', function (msg)
  Send({
    Target = msg.From,
    Action = 'View-Roles-Response',
    Data = json.encode(acl.state)
  })
end)

-- Toggle-Registration-Code
-- Owner/admin toggles whether a registration code is required for Register-Nest.
-- Tags: Enabled ("true" or "false")
Handlers.add('Toggle-Registration-Code', 'Toggle-Registration-Code', function (msg)
  acl.assertHasOneOfRole(msg.From, { 'owner', 'admin', 'Toggle-Registration-Code' })
  local enabled = msg.Tags['Enabled']
  assert(type(enabled) == 'string', 'Enabled tag is required and must be a string')
  assert(enabled == 'true' or enabled == 'false', 'Enabled tag must be "true" or "false"')

  registration_code_required = (enabled == 'true')

  Send({
    Target = msg.From,
    Action = 'Toggle-Registration-Code-Response',
    Data = registration_code_required and 'enabled' or 'disabled'
  })
  Send({
    Target = ao.id,
    device = 'patch@1.0',
    registration_code_required = registration_code_required
  })
end)

-- Add-Registration-Code
-- Owner/admin stores a SHA2-512 hash of a registration code secret.
-- Tags: Registration-Hash (required, hex-encoded SHA2-512 hash)
Handlers.add('Add-Registration-Code', 'Add-Registration-Code', function (msg)
  acl.assertHasOneOfRole(msg.From, { 'owner', 'admin', 'Add-Registration-Code' })

  local hash = msg.Tags['Registration-Hash']
  assert(
    type(hash) == 'string' and #hash > 0,
    'Registration-Hash tag is required'
  )
  assert(
    hash:match('^[0-9a-fA-F]+$'),
    'Registration-Hash must be a valid hex string'
  )

  registration_codes[hash] = true

  Send({
    Target = msg.From,
    Action = 'Add-Registration-Code-Response',
    Data = 'OK'
  })
  Send({
    Target = ao.id,
    device = 'patch@1.0',
    registration_codes = registration_codes
  })
end)

-- Remove-Registration-Code
-- Owner/admin removes a registration code by its hash.
-- Tags: Registration-Hash (required, hex-encoded SHA2-512 hash to remove)
Handlers.add('Remove-Registration-Code', 'Remove-Registration-Code', function (msg)
  acl.assertHasOneOfRole(msg.From, { 'owner', 'admin', 'Remove-Registration-Code' })

  local hash = msg.Tags['Registration-Hash']
  assert(
    type(hash) == 'string' and #hash > 0,
    'Registration-Hash tag is required'
  )

  assert(registration_codes[hash], 'Registration code not found')
  registration_codes[hash] = nil

  Send({
    Target = msg.From,
    Action = 'Remove-Registration-Code-Response',
    Data = 'OK'
  })
  Send({
    Target = ao.id,
    device = 'patch@1.0',
    registration_codes = registration_codes
  })
end)

-- List-Registration-Codes
-- View stored registration code hashes (not the secrets).
Handlers.add('List-Registration-Codes', 'List-Registration-Codes', function (msg)
  local hashes = {}
  for hash, _ in pairs(registration_codes) do
    table.insert(hashes, hash)
  end

  Send({
    Target = msg.From,
    Action = 'List-Registration-Codes-Response',
    total = tostring(#hashes),
    Data = json.encode(hashes)
  })
end)

-- Register-Nest
-- Completes registration by validating a Registration-Code secret against stored hashes
-- and extracting owner and ACL from the nest's state.
-- Tags: Registration-Code (required when registration_code_required is true)
Handlers.add('Register-Nest', 'Register-Nest', function (msg)
  local codeHash = nil

  if registration_code_required then
    local code = msg.Tags['Registration-Code']
    assert(
      type(code) == 'string' and #code > 0,
      'Registration-Code tag is required'
    )

    codeHash = validateRegistrationCode(code)
    assert(
      codeHash ~= nil,
      'Invalid registration code'
    )
  end

  local nestState = parseNestState(msg.Data)
  local idx = findNestIndex(msg.From)

  assert(idx == nil, 'Nest is already registered: ' .. tostring(msg.From))
  table.insert(nests, {
    id = msg.From,
    owner = nestState.owner,
    acl = nestState.acl
  })

  -- Burn the used registration code
  local registration_codes_updated = false
  if codeHash ~= nil then
    registration_codes[codeHash] = nil
    registration_codes_updated = true
  end

  Send({
    Target = msg.From,
    Action = 'Register-Nest-Response',
    Data = 'OK'
  })
  if registration_codes_updated then
    Send({
      Target = ao.id,
      device = 'patch@1.0',
      nests = nests,
      registration_codes = registration_codes
    })
  else
    Send({
      Target = ao.id,
      device = 'patch@1.0',
      nests = nests
    })
  end
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

  Send({
    Target = msg.From,
    Action = 'Unregister-Response',
    Data = 'OK'
  })
  Send({
    Target = ao.id,
    device = 'patch@1.0',
    nests = nests
  })
end)

-- Batch-Unregister
-- Owner/Admin can unregister multiple nests at once by providing a list of nest IDs.
-- data: JSON-encoded array of nest IDs to unregister.
Handlers.add('Batch-Unregister', 'Batch-Unregister', function (msg)
  acl.assertHasOneOfRole(msg.From, { 'owner', 'admin', 'Batch-Unregister' })

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

  Send({
    Target = msg.From,
    Action = 'Batch-Unregister-Response',
    Data = 'OK'
  })
  Send({
    Target = ao.id,
    device = 'patch@1.0',
    nests = nests
  })
end)

-- Update-Registration
-- A nest process updates its registration (owner and ACL).
-- data: JSON-encoded state (same format as View-State-Response).
Handlers.add('Update-Registration', 'Update-Registration', function (msg)
  local idx = findNestIndex(msg.From)
  assert(
    idx ~= nil,
    'Nest is not registered: ' .. tostring(msg.From)
  )

  local nestState = parseNestState(msg.Data)
  nests[idx].owner = nestState.owner
  nests[idx].acl = nestState.acl

  Send({
    Target = msg.From,
    Action = 'Update-Registration-Response',
    Data = 'OK'
  })
  Send({
    Target = ao.id,
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

  Send({
    Target = msg.From,
    Action = 'List-Nests-Response',
    next_cursor = page.nextCursor or '',
    has_more = tostring(page.hasMore),
    total = tostring(page.total),
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

  Send({
    Target = msg.From,
    Action = 'List-Nests-By-Address-Response',
    next_cursor = page.nextCursor or '',
    has_more = tostring(page.hasMore),
    total = tostring(page.total),
    Data = json.encode(page.items)
  })
end)

-- View-State
-- Returns the full registry state.
Handlers.add('View-State', 'View-State', function (msg)
  Send({
    Target = msg.From,
    Action = 'View-State-Response',
    Data = json.encode({
      nests = nests,
      acl = acl.state,
      registration_codes = registration_codes,
      registration_code_required = registration_code_required
    })
  })
end)

Send({
  Target = ao.id,
  device = 'patch@1.0',
  acl = acl,
  nests = nests,
  registration_codes = registration_codes,
  registration_code_required = registration_code_required
})
