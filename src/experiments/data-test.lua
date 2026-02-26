-- Data-Test Contract
--
-- Isolated test contract for exercising the AO data API:
--   - ao.addAssignable / ao.removeAssignable
--   - Assign({ Processes, Message })
--   - Handler-based processing of assigned Arweave transactions
--
-- Mirrors the patterns described in:
--   https://cookbook_ao.arweave.net/references/api/data.html

local json = require('json')

--- @type table<string, string>  Cached Arweave data keyed by transaction ID
cached_data = cached_data or {}

--- @type table<string, { from: string, tx_id: string, status: string, data: string|nil, error: string|nil }>
pending_requests = pending_requests or {}

--- @type table<string, true>  Set of assignable names currently registered
registered_assignables = registered_assignables or {}

-- ─── Assignable Management ────────────────────────────────────────────────────

-- Add-Assignable
-- Register a named assignable condition.
-- Tags: Assignable-Name (required), Match-Tag (optional), Match-Value (optional)
--
-- If Match-Tag and Match-Value are provided, the assignable matches messages
-- where msg.Tags[Match-Tag] == Match-Value.
-- If only Assignable-Name is provided, the assignable accepts all messages.
Handlers.add('Add-Assignable', 'Add-Assignable', function (msg)
  local name = msg.Tags['Assignable-Name']
  assert(name and #name > 0, 'Missing Assignable-Name')

  local matchTag = msg.Tags['Match-Tag']
  local matchValue = msg.Tags['Match-Value']

  if matchTag and matchValue then
    ao.addAssignable(name, function (m)
      return m.Tags[matchTag] == matchValue
    end)
  else
    ao.addAssignable(name, function ()
      return true
    end)
  end

  registered_assignables[name] = true

  Send({
    Target = msg.From,
    Action = 'Add-Assignable-Response',
    Data = json.encode({
      name = name,
      matchTag = matchTag,
      matchValue = matchValue,
      registered = true
    })
  })
end)

-- Remove-Assignable
-- Unregister a named assignable.
-- Tags: Assignable-Name (required)
Handlers.add('Remove-Assignable', 'Remove-Assignable', function (msg)
  local name = msg.Tags['Assignable-Name']
  assert(name and #name > 0, 'Missing Assignable-Name')
  assert(registered_assignables[name], 'Assignable not found: ' .. name)

  ao.removeAssignable(name)
  registered_assignables[name] = nil

  Send({
    Target = msg.From,
    Action = 'Remove-Assignable-Response',
    Data = json.encode({ name = name, removed = true })
  })
end)

-- List-Assignables
-- Returns the set of currently registered assignable names.
Handlers.add('List-Assignables', 'List-Assignables', function (msg)
  local names = {}
  for name, _ in pairs(registered_assignables) do
    table.insert(names, name)
  end
  table.sort(names)

  Send({
    Target = msg.From,
    Action = 'List-Assignables-Response',
    Data = json.encode({ assignables = names })
  })
end)

-- ─── Assign / Fetch Data ──────────────────────────────────────────────────────

-- Request-Data
-- Initiates an Assign for a given Arweave transaction.
-- Tags: Tx-Id (required)
Handlers.add('Request-Data', 'Request-Data', function (msg)
  local txId = msg.Tags['Tx-Id']
  assert(txId and #txId > 0, 'Missing Tx-Id')

  pending_requests[txId] = {
    from = msg.From,
    tx_id = txId,
    status = 'pending',
    data = nil,
    error = nil
  }

  Assign({
    Processes = { ao.id },
    Message = txId
  })

  Send({
    Target = msg.From,
    Action = 'Request-Data-Response',
    Data = json.encode({
      tx_id = txId,
      status = 'assigned'
    })
  })
end)

-- ─── Receive Assigned Data ────────────────────────────────────────────────────

-- Receive-Data
-- Handler for processing assigned Arweave data arriving via the data pipeline.
-- Matches messages tagged with Action = "Assigned-Data".
Handlers.add('Receive-Data', { Action = 'Assigned-Data' }, function (msg)
  local txId = msg.Id
  local data = msg.Data

  -- Cache the data
  if data then
    cached_data[txId] = data
  end

  -- Resolve any pending request for this tx
  local request = pending_requests[txId]
  if request then
    request.status = 'completed'
    request.data = data

    Send({
      Target = request.from,
      Action = 'Data-Delivered',
      ['Tx-Id'] = txId,
      Data = data or ''
    })
  end
end)

-- ─── Query State ──────────────────────────────────────────────────────────────

-- View-Cached-Data
-- Returns all cached Arweave data.
Handlers.add('View-Cached-Data', 'View-Cached-Data', function (msg)
  Send({
    Target = msg.From,
    Action = 'View-Cached-Data-Response',
    Data = json.encode(cached_data)
  })
end)

-- Get-Cached-Data
-- Returns cached data for a specific transaction.
-- Tags: Tx-Id (required)
Handlers.add('Get-Cached-Data', 'Get-Cached-Data', function (msg)
  local txId = msg.Tags['Tx-Id']
  assert(txId and #txId > 0, 'Missing Tx-Id')

  local data = cached_data[txId]

  Send({
    Target = msg.From,
    Action = 'Get-Cached-Data-Response',
    ['Tx-Id'] = txId,
    ['Found'] = data and 'true' or 'false',
    Data = data or ''
  })
end)

-- View-Pending-Requests
-- Returns all pending/completed data requests.
Handlers.add('View-Pending-Requests', 'View-Pending-Requests', function (msg)
  Send({
    Target = msg.From,
    Action = 'View-Pending-Requests-Response',
    Data = json.encode(pending_requests)
  })
end)

-- View-State
-- Returns the full contract state for debugging.
Handlers.add('View-State', 'View-State', function (msg)
  local assignable_names = {}
  for name, _ in pairs(registered_assignables) do
    table.insert(assignable_names, name)
  end
  table.sort(assignable_names)

  Send({
    Target = msg.From,
    Action = 'View-State-Response',
    Data = json.encode({
      cached_data_count = #(function()
        local keys = {}
        for k in pairs(cached_data) do keys[#keys+1] = k end
        return keys
      end)(),
      pending_request_count = #(function()
        local keys = {}
        for k in pairs(pending_requests) do keys[#keys+1] = k end
        return keys
      end)(),
      registered_assignables = assignable_names
    })
  })
end)
