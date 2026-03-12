--- bm25.lua - BM25 ranking for term/document index pairs
---
--- Stateless search module that scores documents against a multi-term query
--- using the Okapi BM25 ranking function.  All corpus data (inverted index,
--- document list, aggregate stats) is passed in as arguments so the module
--- holds no global state.
---
--- Depends on the `terms` sibling module for query tokenisation.
---
--- @module bm25

local terms = require('..lib.terms')

local M = {}

--- Default BM25 tuning parameters (standard Okapi BM25 values).
--- @type number
M.k1 = 1.2
--- @type number
M.b = 0.75

--- Compute the BM25 inverse document frequency for a single term.
---
--- Uses the non-negative variant that adds 1 inside the logarithm so that
--- very common terms never produce a negative IDF.
---
--- @param totalDocuments integer  total number of documents in the corpus (N)
--- @param documentFrequency integer  number of documents containing the term (n)
--- @return number idf
function M.idf(totalDocuments, documentFrequency)
  return math.log(
    (totalDocuments - documentFrequency + 0.5) / (documentFrequency + 0.5) + 1
  )
end

--- Compute the BM25 score contribution of a single term in a single document.
---
--- @param termFrequency number       occurrences of the term in the document (tf)
--- @param idf number                 inverse document frequency for the term
--- @param documentLength number      number of terms in the document (dl)
--- @param averageDocumentLength number  average document length across the corpus (avgdl)
--- @param k1 number                  term-frequency saturation parameter
--- @param b number                   length-normalisation parameter
--- @return number score
function M.score(termFrequency, idf, documentLength, averageDocumentLength, k1, b)
  local numerator = termFrequency * (k1 + 1)
  local denominator = termFrequency + k1 * (1 - b + b * (documentLength / averageDocumentLength))
  return idf * numerator / denominator
end

--- Search the corpus for documents matching a multi-term query, ranked by BM25.
---
--- @param query string                                     the search query (may contain multiple terms)
--- @param term_index table<string, table<string, number>>  inverted index: term → { documentId → tf }
--- @param documents table<number, Document>                array of Document records (needs DocumentId, TermCount)
--- @param total_documents integer                          total number of documents in the corpus
--- @param average_document_term_length number              average TermCount across the corpus
--- @param opts? { k1?: number, b?: number, limit?: number }  optional overrides
--- @return { DocumentId: string, Score: number }[]         results sorted by score descending
function M.search(query, term_index, documents, total_documents, average_document_term_length, opts)
  opts = opts or {}
  local k1 = opts.k1 or M.k1
  local b  = opts.b  or M.b
  local limit = opts.limit

  if total_documents == 0 or not query or query == '' then
    return {}
  end

  -- Tokenise and deduplicate query terms
  local queryTerms = terms.parseTerms(query)
  if #queryTerms == 0 then return {} end

  local seen = {}
  local uniqueTerms = {}
  for _, t in ipairs(queryTerms) do
    if not seen[t] then
      seen[t] = true
      uniqueTerms[#uniqueTerms + 1] = t
    end
  end

  -- Build a fast lookup from DocumentId → TermCount (document length)
  local docLength = {}
  for _, doc in ipairs(documents) do
    docLength[doc.DocumentId] = doc.TermCount
  end

  -- Accumulate BM25 scores per document across all query terms
  --- @type table<string, number>
  local scores = {}
  for _, term in ipairs(uniqueTerms) do
    local postings = term_index[term]
    if postings then
      local df = 0
      for _ in pairs(postings) do df = df + 1 end

      local termIdf = M.idf(total_documents, df)

      for docId, tf in pairs(postings) do
        local dl = docLength[docId] or 0
        local s = M.score(tf, termIdf, dl, average_document_term_length, k1, b)
        scores[docId] = (scores[docId] or 0) + s
      end
    end
  end

  -- Collect into an array and sort descending by score
  local results = {}
  for docId, s in pairs(scores) do
    results[#results + 1] = { DocumentId = docId, Score = s }
  end
  table.sort(results, function(a, b) return a.Score > b.Score end)

  -- Apply optional limit
  if limit and limit > 0 and #results > limit then
    local trimmed = {}
    for i = 1, limit do trimmed[i] = results[i] end
    return trimmed
  end

  return results
end

return M
