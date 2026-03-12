--- terms.lua - tokenize text and compute term frequencies
---
--- Provides term extraction utilities used for document indexing and
--- BM25-compatible inverted index construction.
---
--- @submodule terms_parser

local terms_parser = {}

--- Token pattern: sequences of characters that are neither whitespace nor
--- punctuation. Matches the same tokens previously counted inline by nest.lua.
local TOKEN_PATTERN = '[^%s%p]+'

--- Parse text into a list of lowercased terms.
--- @param text string
--- @return string[]
function terms_parser.parseTerms(text)
  local terms = {}
  for token in text:gmatch(TOKEN_PATTERN) do
    terms[#terms + 1] = token:lower()
  end
  return terms
end

--- Count the number of terms in a text string.
--- @param text string
--- @return integer
function terms_parser.countTerms(text)
  local count = 0
  for _ in text:gmatch(TOKEN_PATTERN) do
    count = count + 1
  end
  return count
end

--- Build a frequency map of lowercased terms in the text.
--- @param text string
--- @return table<string, number>  term → occurrence count
function terms_parser.getTermFrequencies(text)
  local freqs = {}
  for token in text:gmatch(TOKEN_PATTERN) do
    local term = token:lower()
    freqs[term] = (freqs[term] or 0) + 1
  end
  return freqs
end

return terms_parser
