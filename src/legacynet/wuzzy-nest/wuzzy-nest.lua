-- Wuzzy Nest for AO Legacynet
local json = require('json')
local utils = require('.utils')
local neturl = require('..lib.neturl')
acl = require('..common.acl')
version = version or '0.0.1-legacynet'
registry_address = registry_address or ao.env.Process.Tags['Registry-Address'] or nil
total_documents = total_documents or 0
total_term_count = total_term_count or 0
total_content_length = total_content_length or 0
average_document_term_length = average_document_term_length or 0

--- @type table<number, {
---   submitted_by: string,
---   document_id: string,
---   last_crawled_at: string,
---   protocol: string,
---   domain: string,
---   path: string,
---   url: string,
---   content_type: string,
---   content: string,
---   term_count: number,
---   content_length: number,
---   title: string,
---   description: string,
--- }>
documents = documents or {}

--- @type table<number, {
---   url: string,
---   requester_id: string,
---   requested_at: number,
--- }>
--- Pending crawl requests as a numerically indexed FIFO queue
pending_crawl_requests = pending_crawl_requests or {}

-- Helper: Parse and normalize a URL, returning components and normalized form
--- @param url string
--- @return { protocol: string, domain: string, path: string, normalizedUrl: string }
local function parseAndNormalizeUrl(url)
  assert(type(url) == 'string' and url ~= '', 'Missing URL')
  local parsedUrl = neturl.parse(url):normalize()
  local protocol = parsedUrl.scheme
  local domain = parsedUrl.host or parsedUrl.authority
  local path = parsedUrl.path
  if path and path:sub(-1) == '/' then
    path = path:sub(1, -2)
  end
  assert(protocol and domain and path, 'Invalid URL: ' .. url)
  local normalizedUrl = protocol .. '://' .. domain .. path
  return {
    protocol = protocol,
    domain = domain,
    path = path,
    normalizedUrl = normalizedUrl
  }
end

-- Helper: Find a document by ID, returning index and document
--- @param documentId string
--- @return number|nil, table|nil
local function findDocumentByIdWithIndex(documentId)
  for i, doc in ipairs(documents) do
    if doc.document_id == documentId then
      return i, doc
    end
  end
  return nil, nil
end

-- Helper: Update document statistics when adding/updating a document
--- @param content string
--- @param existingDocument table|nil
--- @return { termCount: number, contentLength: number }
local function updateDocumentStats(content, existingDocument)
  local termCount = select(2, string.gsub(content, '[^%s%p]+', ''))
  local oldTermCount = existingDocument and existingDocument.term_count or 0
  total_term_count =
    total_term_count + termCount - oldTermCount

  local contentLength = #content
  local oldContentLength = existingDocument and existingDocument.content_length or 0
  total_content_length =
    total_content_length + contentLength - oldContentLength

  if not existingDocument then
    total_documents = total_documents + 1
  end

  if total_documents > 0 then
    average_document_term_length =
      total_term_count / total_documents
  else
    average_document_term_length = 0
  end

  return {
    termCount = termCount,
    contentLength = contentLength
  }
end

-- Helper: Find a pending crawl request by URL, returning index and entry
--- @param url string
--- @return number|nil, table|nil
local function findPendingCrawlRequestByUrl(url)
  for i, req in ipairs(pending_crawl_requests) do
    if req.url == url then
      return i, req
    end
  end
  return nil, nil
end

-- Helper: Create and upsert a document, returning the documentId
--- @param params { submittedBy: string, url: string, lastCrawledAt: string, contentType: string, content: string, title: string|nil, description: string|nil }
--- @return string documentId
local function upsertDocument(params)
  local parsed = parseAndNormalizeUrl(params.url)
  local documentId = parsed.normalizedUrl

  local existingDocumentIndex, existingDocument = findDocumentByIdWithIndex(documentId)
  local stats = updateDocumentStats(params.content, existingDocument)

  local doc = {
    submitted_by = params.submittedBy,
    document_id = documentId,
    last_crawled_at = params.lastCrawledAt,
    protocol = parsed.protocol,
    domain = parsed.domain,
    path = parsed.path,
    url = params.url,
    content_type = params.contentType,
    content = params.content,
    content_length = stats.contentLength,
    term_count = stats.termCount,
    title = params.title,
    description = params.description
  }

  if existingDocumentIndex then
    documents[existingDocumentIndex] = doc
  else
    table.insert(documents, doc)
  end

  return documentId
end

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

Handlers.add('View-Roles', 'View-Roles', function (msg)
  ao.send({
    Target = msg.From,
    Action = 'View-Roles-Response',
    Data = json.encode(acl.state)
  })
end)

Handlers.add('View-State', 'View-State', function (msg)
  ao.send({
    Target = msg.From,
    Action = 'View-State-Response',
    Data = json.encode({
      owner = Owner,
      acl = acl.state,
      state = {
        -- documents = documents, -- NB: Omit documents from state response for now (can be large)
        total_documents = total_documents,
        total_term_count = total_term_count,
        total_content_length = total_content_length,
        average_document_term_length = average_document_term_length,
        pending_crawl_requests = pending_crawl_requests
      }
    })
  })
end)

Handlers.add('Register', 'Register',function (msg)
  acl.utils.assertHasOneOfRole(msg.From, { 'owner', 'admin', 'Register' })
  if msg.Tags['Registry-Address'] then
    registry_address = msg.Tags['Registry-Address']
  end
   ao.send({
    Target = registry_address,
    Action = 'Register-Nest',
    Data = json.encode({
      owner = Owner,
      acl = acl.state
    })
  })
end)

Handlers.add('Index-Document', 'Index-Document', function (msg)
  acl.utils.assertHasOneOfRole(msg.From, { 'owner', 'admin', 'Index-Document' })

  local url = msg.Tags['Document-URL']
  assert(url, 'Missing Document-URL')

  local lastCrawledAt = msg.Tags['Document-Last-Crawled-At']
  assert(type(lastCrawledAt) == 'string', 'Missing Document-Last-Crawled-At')

  local contentType = msg.Tags['Document-Content-Type']
  assert(type(contentType) == 'string' and contentType ~= '', 'Missing or invalid Document-Content-Type')

  assert(msg.Data and #msg.Data > 0, 'Missing Document Content')

  local documentId = upsertDocument({
    submittedBy = msg.From,
    url = url,
    lastCrawledAt = lastCrawledAt,
    contentType = contentType,
    content = msg.Data,
    title = msg.Tags['Document-Title'],
    description = msg.Tags['Document-Description']
  })

  -- Notify original requester if this was a queued crawl request
  local pendingIndex, pendingRequest = findPendingCrawlRequestByUrl(documentId)
  if pendingRequest then
    ao.send({
      Target = pendingRequest.requester_id,
      Action = 'Crawl-Completed',
      ['Document-Id'] = documentId,
      ['URL'] = url,
      ['Crawler-Id'] = msg.From,
      Data = 'OK'
    })
    table.remove(pending_crawl_requests, pendingIndex)
  end

  ao.send({
    device = 'patch@1.0',
    documents = documents,
    total_documents = total_documents,
    total_term_count = total_term_count,
    total_content_length = total_content_length,
    average_document_term_length = average_document_term_length,
    pending_crawl_requests = pending_crawl_requests
  })

  ao.send({
    Target = msg.From,
    Action = 'Index-Document-Result',
    ['Document-Id'] = documentId,
    Data = 'OK'
  })
end)

Handlers.add('Bulk-Index-Document', 'Bulk-Index-Document', function (msg)
  acl.utils.assertHasOneOfRole(msg.From, { 'owner', 'admin', 'Index-Document' })

  assert(msg.Data and #msg.Data > 0, 'Missing Documents Data')
  local documents = json.decode(msg.Data)
  assert(type(documents) == 'table', 'Documents must be a JSON array')

  local indexed = {}
  local errors = {}

  for i, docData in ipairs(documents) do
    local ok, err = pcall(function()
      assert(type(docData.url) == 'string', 'Missing url')
      assert(type(docData.content) == 'string' and #docData.content > 0, 'Missing content')
      assert(type(docData.last_crawled_at) == 'string', 'Missing last_crawled_at')
      assert(type(docData.content_type) == 'string', 'Missing content_type')

      local documentId = upsertDocument({
        submittedBy = msg.From,
        url = docData.url,
        lastCrawledAt = docData.last_crawled_at,
        contentType = docData.content_type,
        content = docData.content,
        title = docData.title,
        description = docData.description
      })

      table.insert(indexed, documentId)
    end)

    if not ok then
      table.insert(errors, { index = i, error = err })
    end
  end

  ao.send({
    device = 'patch@1.0',
    documents = documents,
    total_documents = total_documents,
    total_term_count = total_term_count,
    total_content_length = total_content_length,
    average_document_term_length = average_document_term_length
  })

  ao.send({
    Target = msg.From,
    Action = 'Bulk-Index-Document-Result',
    Data = json.encode({
      indexed = indexed,
      indexed_count = #indexed,
      errors = errors,
      error_count = #errors
    })
  })
end)

Handlers.add('Remove-Document', 'Remove-Document', function (msg)
  acl.utils.assertHasOneOfRole(
    msg.From,
    { 'owner', 'admin', 'Remove-Document' }
  )

  local documentId = msg.Tags['Document-Id']
  assert(documentId, 'Document-Id is required')
  local existingIndex, existingDocument = findDocumentByIdWithIndex(documentId)
  assert(existingDocument, 'Document not found')

  table.remove(documents, existingIndex)
  total_documents = total_documents - 1

  ao.send({
    device = 'patch@1.0',
    documents = documents,
    total_documents = total_documents
  })

  ao.send({
    Target = msg.From,
    Action = 'Remove-Document-Result',
    ['Document-Id'] = documentId,
    Data = 'OK'
  })
end)

-- Search handler - STUB: returns all documents (no ranking/filtering)
-- TODO: Port search modules (simple, bm25) for full search functionality
Handlers.add('Search', 'Search', function (msg)
  local query = msg.Tags['Query']
  assert(type(query) == 'string' and query ~= '', 'Missing Search Query')
  local searchType = msg.Tags['Search-Type'] or 'simple'

  -- STUB: Return all documents as hits (no actual search/ranking)
  local hits = {}
  for _, doc in ipairs(documents) do
    table.insert(hits, {
      document_id = doc.document_id,
      url = doc.url,
      title = doc.title,
      description = doc.description,
      score = 1
    })
  end

  ao.send({
    Target = msg.From,
    Action = 'Search-Result',
    Data = json.encode({
      search_type = searchType,
      hits = hits,
      total_count = #hits
    })
  })
end)

Handlers.add('Queue-Crawl-Request', 'Queue-Crawl-Request', function (msg)
  acl.utils.assertHasOneOfRole(msg.From, { 'owner', 'admin', 'Queue-Crawl-Request' })

  local url = msg.Tags['URL']
  local parsed = parseAndNormalizeUrl(url)
  local normalizedUrl = parsed.normalizedUrl

  -- Only queue if not already pending (first-in wins, no update)
  local existingIndex = findPendingCrawlRequestByUrl(normalizedUrl)
  if not existingIndex then
    table.insert(pending_crawl_requests, {
      url = normalizedUrl,
      requester_id = msg.From,
      requested_at = msg.Timestamp or 0
    })
  end

  ao.send({
    Target = msg.From,
    Action = 'Queue-Crawl-Request-Result',
    ['URL'] = url,
    ['Normalized-URL'] = normalizedUrl,
    Data = 'OK'
  })
  ao.send({
    device = 'patch@1.0',
    pending_crawl_requests = pending_crawl_requests
  })
end)

-- Patch initial state to device
ao.send({
  device = 'patch@1.0',
  documents = documents,
  total_documents = total_documents,
  total_term_count = total_term_count,
  total_content_length = total_content_length,
  average_document_term_length = average_document_term_length,
  pending_crawl_requests = pending_crawl_requests,
  registry_address = registry_address
})
