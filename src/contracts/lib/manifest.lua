-- arweave/manifest.lua - validate, parse and resolve Arweave path manifests
--
-- Supports manifest spec versions 0.1.0 and 0.2.0.
-- v0.2.0 adds an optional top-level `fallback` field for unmatched paths.
--
-- @module manifest
-- @alias  M

local json = require('json')

local M = {}
M.version = '1.0'

--- Supported manifest spec versions
local SUPPORTED_VERSIONS = {
  ['0.1.0'] = true,
  ['0.2.0'] = true,
}

--- Expected value of the `manifest` field
local MANIFEST_TYPE = 'arweave/paths'

--- Content-Type header set by Arweave gateways for manifest transactions
local MANIFEST_CONTENT_TYPE = 'application/x.arweave-manifest+json'

-- ---------------------------------------------------------------------------
-- Local helpers
-- ---------------------------------------------------------------------------

--- Check whether a string is a valid 43-character base64url Arweave TX ID.
--- @param id any
--- @return boolean
local function isValidTxId(id)
  if type(id) ~= 'string' then return false end
  if #id ~= 43 then return false end
  return id:match('^[A-Za-z0-9_-]+$') ~= nil
end

--- Safely decode JSON, returning the table or nil.
--- @param raw string
--- @return table|nil
local function safeDecode(raw)
  if type(raw) ~= 'string' then return nil end
  local ok, result = pcall(json.decode, raw)
  if ok and type(result) == 'table' then return result end
  return nil
end

--- Normalise a path by stripping leading and trailing slashes.
--- @param p string
--- @return string
local function normalizePath(p)
  if type(p) ~= 'string' then return '' end
  p = p:gsub('^/+', ''):gsub('/+$', '')
  return p
end

-- ---------------------------------------------------------------------------
-- Detection
-- ---------------------------------------------------------------------------

--- Check whether `data` looks like an Arweave path manifest.
--- Accepts a raw JSON string or an already-decoded table.
--- @param data string|table
--- @return boolean
function M.isManifest(data)
  local t = data
  if type(data) == 'string' then
    t = safeDecode(data)
  end
  if type(t) ~= 'table' then return false end
  if t.manifest ~= MANIFEST_TYPE then return false end
  if not SUPPORTED_VERSIONS[t.version] then return false end
  if type(t.paths) ~= 'table' then return false end
  return true
end

--- Check whether a Content-Type string indicates an Arweave manifest.
--- @param contentType string
--- @return boolean
function M.isManifestContentType(contentType)
  if type(contentType) ~= 'string' then return false end
  return contentType:lower():find(MANIFEST_CONTENT_TYPE, 1, true) ~= nil
end

-- ---------------------------------------------------------------------------
-- Validation
-- ---------------------------------------------------------------------------

--- Validate an Arweave path manifest structure.
--- Returns `true` on success, or `false, errorMessage` on failure.
--- @param data string|table
--- @return boolean, string|nil
function M.validate(data)
  local t = data
  if type(data) == 'string' then
    t = safeDecode(data)
    if t == nil then return false, 'invalid JSON' end
  end
  if type(t) ~= 'table' then
    return false, 'manifest must be a table'
  end

  -- manifest field
  if t.manifest ~= MANIFEST_TYPE then
    return false, 'manifest field must be "' .. MANIFEST_TYPE .. '"'
  end

  -- version
  if not SUPPORTED_VERSIONS[t.version] then
    return false, 'unsupported version: ' .. tostring(t.version)
  end

  -- paths
  if type(t.paths) ~= 'table' then
    return false, 'paths must be a table'
  end

  for path, entry in pairs(t.paths) do
    if type(path) ~= 'string' then
      return false, 'path key must be a string'
    end
    if type(entry) ~= 'table' then
      return false, 'path entry for "' .. path .. '" must be a table'
    end
    if not isValidTxId(entry.id) then
      return false, 'invalid tx id for path "' .. path .. '"'
    end
  end

  -- index
  if type(t.index) ~= 'table' then
    return false, 'index must be a table'
  end
  if type(t.index.path) ~= 'string' then
    return false, 'index.path must be a string'
  end
  if t.paths[t.index.path] == nil then
    return false, 'index.path "' .. t.index.path .. '" not found in paths'
  end

  -- fallback (v0.2.0)
  if t.fallback ~= nil then
    if t.version ~= '0.2.0' then
      return false, 'fallback is only supported in version 0.2.0'
    end
    if type(t.fallback) ~= 'table' then
      return false, 'fallback must be a table'
    end
    if not isValidTxId(t.fallback.id) then
      return false, 'invalid tx id in fallback'
    end
  end

  return true
end

-- ---------------------------------------------------------------------------
-- Parsing
-- ---------------------------------------------------------------------------

--- Parse and validate an Arweave path manifest.
--- Returns a structured manifest object on success, or `nil, errorMessage`.
---
--- Returned shape:
---   { version, index = { path, id }, fallback = { id } | nil,
---     paths = { { path = "...", id = "..." }, ... } }
---
--- @param data string|table
--- @return table|nil, string|nil
function M.parse(data)
  local t = data
  if type(data) == 'string' then
    t = safeDecode(data)
    if t == nil then return nil, 'invalid JSON' end
  end

  local ok, err = M.validate(t)
  if not ok then return nil, err end

  local paths = {}
  for path, entry in pairs(t.paths) do
    paths[#paths + 1] = { path = path, id = entry.id }
  end

  -- Sort for deterministic ordering
  table.sort(paths, function(a, b) return a.path < b.path end)

  local result = {
    version  = t.version,
    index    = { path = t.index.path, id = t.paths[t.index.path].id },
    fallback = nil,
    paths    = paths,
  }

  if t.fallback then
    result.fallback = { id = t.fallback.id }
  end

  return result
end

--- Return a flat array of all { path, id } entries from a parsed manifest.
--- @param manifest table  A manifest returned by M.parse()
--- @return table[]
function M.enumerate(manifest)
  local entries = {}
  for _, entry in ipairs(manifest.paths) do
    entries[#entries + 1] = { path = entry.path, id = entry.id }
  end
  return entries
end

-- ---------------------------------------------------------------------------
-- Resolution
-- ---------------------------------------------------------------------------

--- Resolve a path within a parsed manifest to its TX ID.
--- Returns the TX ID on success, or `nil, errorMessage`.
--- @param manifest table  A manifest returned by M.parse()
--- @param path string
--- @return string|nil, string|nil
function M.resolve(manifest, path)
  path = normalizePath(path)

  for _, entry in ipairs(manifest.paths) do
    if normalizePath(entry.path) == path then
      return entry.id
    end
  end

  -- v0.2.0 fallback
  if manifest.fallback then
    return manifest.fallback.id
  end

  return nil, 'path not found'
end

--- Resolve the index path of a parsed manifest to its TX ID.
--- @param manifest table  A manifest returned by M.parse()
--- @return string|nil, string|nil
function M.resolveIndex(manifest)
  return M.resolve(manifest, manifest.index.path)
end

return M
