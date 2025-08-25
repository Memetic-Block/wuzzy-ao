package.path = './src/contracts/?.lua;' ..
  './src/contracts/common/?.lua;' ..
  './src/contracts/wuzzy-nest/?.lua;' ..
  './src/contracts/wuzzy-crawler/?.lua;' ..
  package.path

-- NB: Preserve original print() as AO overwrites it
_G._print = print

-- require('spec.hyper-aos')
require('spec.manual-hyper-aos')

-- ---@diagnostic disable-next-line: deprecated
-- ao.init({
--   process = {
--     commitments = {
--       ['mock-commitment-one'] = { alg = 'rsa-pss-sha512' }
--     }
--   }
-- })

_G.package.loaded['json'] = require('.json')
_G.module = 'mock-module-id'
_G.owner = 'mock-owner-address'
_G.authority = 'mock-authority-address'
_G.authorities = { _G.authority }
_G.id = 'mock-process-id'
_G.process = {
  Tags = {
    ['Nest-Id'] = 'mock-nest-id'
  }
}

function GetHandler(name)
  local handler = require('.utils').find(
    function (val) return val.name == name end,
    _G.Handlers.list
  )
  assert(handler, 'Handler not found: ' .. name)
  return handler
end

function CacheOriginalGlobals()
  -- NB: Preserve a reference to original AO globals to enable test spies
  _G._send = _G.send
  _G._spawn = _G.spawn
end

function RestoreOriginalGlobals()
  -- NB: Restore original AO globals after using test spies
  _G.send = _G._send
  _G.spawn = _G._spawn
end

local cookbookHtmlFile = io.open('spec/cookbook.html', 'rb')
if not cookbookHtmlFile then
  print('no test html file!')
  return nil
end
_G.CookbookHtmlContent = cookbookHtmlFile:read('*a')
cookbookHtmlFile:close()

local cookbookLinksFile = io.open('spec/cookbook-links.json', 'rb')
if not cookbookLinksFile then
  print('no test links json file!')
  return nil
end
local cookbookLinksContent = cookbookLinksFile:read('*a')
cookbookLinksFile:close()
_G.CookbookLinks = require('json').decode(cookbookLinksContent)
