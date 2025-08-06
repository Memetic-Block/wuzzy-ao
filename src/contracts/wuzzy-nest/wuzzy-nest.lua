local WuzzyNest = {
  State = {
    --- This state holds the indexed documents
    --- @type { [number]: {
    ---   SubmittedBy: string,
    ---   TransactionId: string,
    ---   IndexType: string,
    ---   ARNSName: string,
    ---   ARNSSubDomain: string,
    ---   ContentType: string,
    ---   Content: string } }
    Documents = {},
    TotalTermCount = 0
  }
}

function WuzzyNest.init()
  local json = require('json')
  local ACL = require('..common.acl')
  local SimpleSearch = require('.search.simple')
  local BM25Search = require('.search.bm25')

  require('..common.handlers.acl')(ACL)
  require('..common.handlers.state')(WuzzyNest)

  Handlers.add(
    'Index',
    Handlers.utils.hasMatchingTag('Action', 'Index'),
    function (msg)
      -- TODO -> restrict to known crawlers
      -- TODO -> validate message

      local indexType = msg.Tags['Index-Type']
      local arnsName = msg.Tags['Document-ARNS-Name']
      local subdomain = msg.Tags['Document-ARNS-Sub-Domain']
      local contentType = msg.Tags['Document-Content-Type']
      local transactionId = msg.Tags['Document-Transaction-Id']

      -- TODO -> Add term count of Content
      local termCount = #msg.Data
      WuzzyNest.State.TotalTermCount =
        WuzzyNest.State.TotalTermCount + termCount
      table.insert(WuzzyNest.State.Documents, {
        SubmittedBy = msg.From,
        TransactionId = transactionId,
        IndexType = indexType,
        ARNSName = arnsName,
        ARNSSubDomain = subdomain,
        ContentType = contentType,
        Content = msg.Data
      })

      ao.send({
        Target = msg.From,
        Action = 'Index-Response',
        Data = 'OK'
      })
    end
  )

  Handlers.add(
    'Search',
    Handlers.utils.hasMatchingTag('Action', 'Search'),
    function (msg)
      local query = msg.Tags['Query']
      local searchType = msg.Tags['Search-Type'] or 'simple'

      local hits = {}
      if searchType == 'simple' then
        hits = SimpleSearch.search(query, WuzzyNest.State.Documents)
      elseif searchType == 'bm25' then
        hits = BM25Search.search(query, WuzzyNest.State.Documents)
      end

      ao.send({
        Target = msg.From,
        Action = 'Search-Response',
        Data = json.encode({
          SearchType = searchType,
          Hits = hits,
          TotalCount = #hits
        })
      })
    end
  )
end

WuzzyNest.init()
