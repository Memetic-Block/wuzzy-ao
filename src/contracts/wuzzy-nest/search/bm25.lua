local BM25Search = {}

function BM25Search._InverseDocumentFrequency(totalHits, totalDocuments)
  return totalHits > 0 and math.log(
    1 + ((totalDocuments - totalHits + 0.5) / (totalHits + 0.5))
  ) or 0
end

-- TODO -> split query into terms
-- TODO -> Use term count for document length
function BM25Search.search(query, documents, opts)
  local StringUtils = require('..common.strings')
  local B = opts and opts.b or 0.75
  local K = opts and opts.k or 1.2
  local hits = {}
  local totalDocLength = 0

  for _, doc in ipairs(documents) do
    totalDocLength = totalDocLength + #doc.Content
    local count = StringUtils.count(doc.Content, query)
    if count > 0 then
      table.insert(hits, { count = count, doc = doc })
    end
  end

  if #documents == 0 then
    return hits -- No documents to search
  end
  local avgDocLength = totalDocLength / #documents
  local idf = BM25Search._InverseDocumentFrequency(#hits, #documents)
  for _, hit in ipairs(hits) do
    hit.score = idf * (
      (hit.count * (K + 1)) /
      (hit.count + (K * (1 - B + (B * (#hit.doc.Content / avgDocLength)))))
    )
  end

  -- Sort by score DESC in each document
  table.sort(hits, function(a, b) return a.score > b.score end)

  return hits
end

return BM25Search
