--- manifest.lua - validate, parse and resolve Arweave path manifests
---
--- Supports manifest spec versions 0.1.0 and 0.2.0.
--- v0.2.0 adds an optional top-level `fallback` field for unmatched paths.
---
--- @module manifest
--- @alias  M

local json = require('json')

-- ---------------------------------------------------------------------------
-- Type definitions
-- ---------------------------------------------------------------------------

--- @alias ArweaveTxId string  # 43-character base64url Arweave transaction ID

--- @alias ManifestVersion
---| '"0.1.0"'  # Base path manifest spec
---| '"0.2.0"'  # Adds optional fallback for unmatched paths

--- @class RawManifestPathEntry
--- @field id ArweaveTxId  # Transaction ID the path resolves to

--- @class RawManifestIndex
--- @field path string  # Key into the paths table that serves as the default entry

--- @class RawManifestFallback
--- @field id ArweaveTxId  # Transaction ID to use when no path matches (v0.2.0 only)

--- Raw Arweave path manifest as decoded from JSON (before parsing).
--- @class RawManifest
--- @field manifest  string                            # Must be "arweave/paths"
--- @field version   ManifestVersion                   # Spec version
--- @field index     RawManifestIndex                  # Default path entry
--- @field paths     table<string, RawManifestPathEntry>  # Path -> TX ID mapping
--- @field fallback  RawManifestFallback|nil           # Fallback TX ID (v0.2.0 only)

--- A single path entry in a parsed manifest.
--- @class ManifestPathEntry
--- @field path string       # Relative path within the manifest
--- @field id   ArweaveTxId  # Transaction ID the path resolves to

--- Index reference in a parsed manifest.
--- @class ManifestIndex
--- @field path string       # The path key that serves as the default entry
--- @field id   ArweaveTxId  # Transaction ID the index path resolves to

--- Fallback reference in a parsed manifest.
--- @class ManifestFallback
--- @field id ArweaveTxId  # Transaction ID used when no path matches

--- Parsed and validated Arweave path manifest, as returned by `M.parse()`.
--- @class ParsedManifest
--- @field version  ManifestVersion       # Spec version
--- @field index    ManifestIndex          # Resolved index entry
--- @field fallback ManifestFallback|nil   # Fallback entry (v0.2.0 only)
--- @field paths    ManifestPathEntry[]    # All path entries, sorted by path

-- ---------------------------------------------------------------------------
-- Module
-- ---------------------------------------------------------------------------

local M = {}

--- @type string
M.version = '1.0'

--- Supported manifest spec versions
--- @type table<ManifestVersion, boolean>
local SUPPORTED_VERSIONS = {
  ['0.1.0'] = true,
  ['0.2.0'] = true,
}

--- Expected value of the `manifest` field
--- @type string
local MANIFEST_TYPE = 'arweave/paths'

--- Content-Type header set by Arweave gateways for manifest transactions
--- @type string
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

--- Safely decode JSON, returning the decoded table or nil.
--- @param raw string
--- @return RawManifest|nil
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
--- @param data string|RawManifest
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
--- @param data string|RawManifest
--- @return boolean ok
--- @return string|nil err
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
--- Returns a structured `ParsedManifest` on success, or `nil, errorMessage`.
--- @param data string|RawManifest
--- @return ParsedManifest|nil manifest
--- @return string|nil err
function M.parse(data)
  local t = data
  if type(data) == 'string' then
    t = safeDecode(data)
    if t == nil then return nil, 'invalid JSON' end
  end

  local ok, err = M.validate(t)
  if not ok then return nil, err end

  --- @type ManifestPathEntry[]
  local paths = {}
  for path, entry in pairs(t.paths) do
    paths[#paths + 1] = { path = path, id = entry.id }
  end

  -- Sort for deterministic ordering
  table.sort(paths, function(a, b) return a.path < b.path end)

  --- @type ParsedManifest
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

--- Return a flat array of all path entries from a parsed manifest.
--- @param manifest ParsedManifest
--- @return ManifestPathEntry[]
function M.enumerate(manifest)
  --- @type ManifestPathEntry[]
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
--- @param manifest ParsedManifest
--- @param path string
--- @return ArweaveTxId|nil id
--- @return string|nil err
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
--- @param manifest ParsedManifest
--- @return ArweaveTxId|nil id
--- @return string|nil err
function M.resolveIndex(manifest)
  return M.resolve(manifest, manifest.index.path)
end

return M
