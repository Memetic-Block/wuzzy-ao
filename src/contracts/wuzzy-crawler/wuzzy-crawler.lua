local WuzzyCrawler = {
  State = {
    NestId = nil,
    ArioNetworkProcessId = nil,
    CrawlRequests = {},
    AntRecordRequests = {}
  }
}

WuzzyCrawler.State.NestId = WuzzyCrawler.State.NestId or
  ao.env.Process.Tags['Nest-Id']
WuzzyCrawler.State.ArioNetworkProcessId =
  WuzzyCrawler.State.ArioNetworkProcessId or
    ao.env.Process.Tags['Ario-Network-Process-Id']

function WuzzyCrawler.init()
  local json = require('json')
  local base64 = require('.base64')
  local ACL = require('..common.acl')
  local StringUtils = require('..common.strings')
  local WeaveDrive = require('..common.weavedrive')

  require('..common.handlers.acl')(ACL)
  require('..common.handlers.state')(WuzzyCrawler)

  Handlers.add(
    'Request-Crawl',
    Handlers.utils.hasMatchingTag('Action', 'Request-Crawl'),
    function (msg)
      ACL.assertHasOneOfRole(msg.From, { 'owner', 'admin', 'Request-Crawl' })

      local url = msg.Tags['URL']
      assert(url ~= nil, 'URL tag is required for Request-Crawl')

      if
        StringUtils.starts_with(url, 'https://') or
          StringUtils.starts_with(url, 'http://')
      then
        -- TODO -> Handle HTTP/HTTPS protocol
        -- ao.send({
        --   Target = WuzzyCrawler.State.NestId,
        --   device = 'relay@1.0',
        --   Data = json.encode({
        --     mode = 'call',
        --     method = 'GET',
        --     ['0'] = { path = url }
        --   })
        -- })

        -- ao.send({
        --   Target = msg.From,
        --   Action = 'Request-Crawl-Response',
        --   Data = 'Crawl request sent to relay device'
        -- })
        ao.send({
          Target = msg.From,
          Action = 'Request-Crawl-Response',
          Data = 'http://|https:// protocol is not implemented yet'
        })
      elseif StringUtils.starts_with(url, 'arns://') then
        -- TODO -> Handle undernames
        local name = string.gsub(url, 'arns://', '')
        WuzzyCrawler.State.CrawlRequests[name] = msg.From
        ao.send({
          Target = WuzzyCrawler.State.ArioNetworkProcessId,
          Action = 'Record',
          Name = name
        })
        ao.send({
          Target = msg.From,
          Action = 'Request-Crawl-Response',
          Data = 'Record request sent to ARNS registry: '..name
        })
      elseif StringUtils.starts_with(url, 'ar://') then
        -- TODO -> Handle AR protocol (not implemented yet)
        ao.send({
          Target = msg.From,
          Action = 'Request-Crawl-Response',
          Data = 'ar:// protocol is not implemented yet'
        })
      else
        ao.send({
          Target = msg.From,
          Action = 'Request-Crawl-Response',
          Data = 'Unsupported URL protocol'
        })
      end
    end
  )

  Handlers.add(
    'Record-Notice',
    Handlers.utils.hasMatchingTag('Action', 'Record-Notice'),
    function (msg)
      if msg.From == WuzzyCrawler.State.ArioNetworkProcessId then
        local name = msg.Tags['Name']
        if type(name) ~= 'string' or name == '' then return end
        local requestor = WuzzyCrawler.State.CrawlRequests[name]
        if not requestor then return end

        -- TODO -> validate msg.Data as StoredRecord
        --- @class StoredRecord
        --- @field processId string The process id of the record
        --- @field startTimestamp number The start timestamp of the record
        --- @field type 'lease' | 'permabuy' The type of the record (lease/permabuy)
        --- @field undernameLimit number The undername limit of the record
        --- @field purchasePrice number The purchase price of the record
        --- @field endTimestamp number|nil The end timestamp of the record
        local record = json.decode(msg.Data)
        local subdomain = '@' -- TODO -> Handle subdomains
        WuzzyCrawler.State.AntRecordRequests[record.processId] = {
          name = name,
          subdomain = subdomain
        }
        ao.send({
          Target = record.processId,
          Action = 'Record',
          ['Sub-Domain'] = subdomain -- TODO -> Handle subdomains
        })
      elseif WuzzyCrawler.State.AntRecordRequests[msg.From] then
        local request = WuzzyCrawler.State.AntRecordRequests[msg.From]
        local requestor = WuzzyCrawler.State.CrawlRequests[request.name]
        if not requestor then return end

        -- TODO -> validate msg.Data as AntRecord
        --- @class AntRecord
        --- @field transactionId string The transaction id of the record
        --- @field ttlSeconds number The time-to-live seconds of the record
        --- @field priority integer|nil The sort order of the record - must be nil or 1 or greater
        local record = json.decode(msg.Data)
        local result, err = WuzzyCrawler.fetchAndParseTransaction(
          record.transactionId
        )
        if not result or err then
          ao.send({
            Target = requestor,
            Action = 'Crawl-Response',
            Data = 'Crawl request failed: ' .. (err or 'Unknown Error')
          })
        else
          ao.send({
            Target = requestor,
            Action = 'Crawl-Response',
            Data = 'Crawl request successful: ' .. result.message
          })

          -- TODO -> Send to Wuzzy-Nest
          ao.send({
            Target = WuzzyCrawler.State.NestId,
            Action = 'Index',
            Data = result.content,
            Tags = {
              ['Index-Type'] = 'ARNS',
              ['Document-ARNS-Name'] = request.name,
              ['Document-ARNS-Sub-Domain'] = '@', -- TODO -> Handle subdomains
              ['Document-Content-Type'] = result.contentType,
              ['Document-Transaction-Id'] = record.transactionId
            }
          })
        end

        WuzzyCrawler.State.AntRecordRequests[request.name] = nil
      end
    end
  )

  WuzzyCrawler.fetchAndParseTransaction = function (transactionId)
    --- @class TransactionHeaders
    --- @field tags { [number]: { name: string, value: string } }
    --- @field id string The transaction id
    --- @field owner string The owner pubkey of the transaction
    --- @field ownerAddress string The owner address of the transaction
    --- @field signature string The signature of the transaction
    --- @field format number The format of the transaction
    --- @field target string The target of the transaction
    --- @field quantity string The quantity of the transaction
    --- @field data_root string The data root of the transaction
    --- @field last_tx string The last transaction id anchor
    --- @field data_size string The data size of the transaction
    --- @field reward string The reward of the transaction
    local tx, getTxErr = WeaveDrive.getTx(transactionId)
    if getTxErr then
      return nil, 'Unable to fetch transaction headers: ' .. getTxErr
    end

    -- TODO -> Validate tx as TransactionHeaders
    -- TODO -> Don't fetch data if too large

    local contentType = 'unknown'
    for _, tag in ipairs(tx.tags) do
      for _, pad in ipairs({ '', '==', '=' }) do
        local success, result = pcall(base64.decode, tag.name..pad)
        if
          success and result == 'Content-Type' and
            type(tag.value) == 'string'
        then
          for _, pad2 in ipairs({ '', '==', '=' }) do
            local success2, result2 = pcall(
              base64.decode,
              tag.value..pad2
            )
            if success2 and result2 and result2 ~= '' then
              contentType = result2
              break
            end
          end
          break
        end
      end
    end

    -- TODO -> Don't fetch data if contentType is unsupported
    local txData, getDataErr = WeaveDrive.getData(transactionId)
    if getDataErr then
      return nil, 'Unable to fetch transaction data: ' .. getDataErr
    end
    if not txData or txData == '' then
      return nil, 'Transaction data is empty'
    end
    if contentType == 'application/x.arweave-manifest+json' then
      -- TODO -> Validate dataMsg.Data as Arweave manifest
      -- TODO -> Safely decode JSON
      --- @class ArweaveManifest
      --- @field manifest 'arweave/paths' The manifest type
      --- @field version string The manifest version
      --- @field index { path: string } The index file of the manifest
      --- @field fallback? { id: string } The fallback file of the manifest
      --- @field paths { [string]: { id: string } } The paths of the manifest
      local manifest = json.decode(txData)
      local index = manifest.paths[manifest.index.path]

      -- TODO -> Use fallback.id for 404s
      -- TODO -> Look for robots.txt in the manifest paths
      -- TODO -> Look for sitemap.xml in the manifest paths
      -- TODO -> Crawl index and paths

      if index then
        -- TODO -> Track that this was a manifest crawl with index info
        return WuzzyCrawler.fetchAndParseTransaction(index.id)
      end

      -- TODO -> Handle manifest without index
      return {
        message = 'Arweave manifest received',
        contentType = contentType,
        content = txData
      }
    elseif contentType == 'text/html' then
      return {
        message = 'HTML content received',
        contentType = contentType,
        content = txData
      }
    elseif contentType == 'text/plain' then
      return {
        message = 'Plain text content received: ' .. txData,
        contentType = contentType,
        content = txData
      }
    else
      return nil, 'Crawl request failed: Unsupported content type: '
        .. contentType
    end
  end
end

WuzzyCrawler.init()
