return {
  search = function (query, documents)
    local StringUtils = require('..common.strings')
    local hits = {}
    for _, doc in ipairs(documents) do
      local count = StringUtils.count(doc.Content, query)
      if count > 0 then
        table.insert(hits, { score = count, doc = doc })
      end
    end

    -- Sort by score DESC in each document
    table.sort(hits, function(a, b) return a.score > b.score end)

    return hits
  end
}
