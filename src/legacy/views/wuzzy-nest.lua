-- e2gA6WctAPBLhDFgOio8IznVSByCm13u7sglXzU26Wo

-- Helper function to find the nearest word boundary
function findWordBoundary(content, pos, direction)
  if pos <= 1 then return 1 end
  if pos >= #content then return #content end

  local wordPattern = '%w'
  local current = pos

  if direction == 'backward' then
    -- Move backward to find the start of a word or whitespace
    while current > 1 do
      local char = string.sub(content, current, current)
      local prevChar = string.sub(content, current - 1, current - 1)

      -- If we're at the boundary between word and non-word, stop
      if string.match(char, wordPattern) and not string.match(prevChar, wordPattern) then
        break
      end
      -- If we're at whitespace or punctuation, stop
      if string.match(char, '%s') or string.match(char, '%p') then
        break
      end
      current = current - 1
    end
  else -- direction == 'forward'
    -- Move forward to find the end of a word or whitespace
    while current < #content do
      local char = string.sub(content, current, current)
      local nextChar = string.sub(content, current + 1, current + 1)

      -- If we're at the boundary between word and non-word, stop
      if string.match(char, wordPattern) and not string.match(nextChar, wordPattern) then
        current = current + 1
        break
      end
      -- If we're at whitespace or punctuation, stop
      if string.match(char, '%s') or string.match(char, '%p') then
        break
      end
      current = current + 1
    end
  end

  return current
end

-- Helper function to safely extract UTF-8 substrings without breaking multibyte characters
local function safeSubstring(str, startPos, endPos)
  if not str or startPos < 1 then return '' end

  local len = #str
  if startPos > len then return '' end

  -- Ensure endPos is within bounds
  endPos = endPos and math.min(endPos, len) or len
  if endPos < startPos then return '' end

  -- Adjust startPos to not break UTF-8 characters
  while startPos > 1 and startPos <= len do
    local byte = string.byte(str, startPos)
    -- If this is not a UTF-8 continuation byte (10xxxxxx), we're at a character boundary
    if not byte or (byte < 0x80 or byte >= 0xC0) then
      break
    end
    startPos = startPos - 1
  end

  -- Adjust endPos to not break UTF-8 characters
  while endPos < len do
    local byte = string.byte(str, endPos + 1)
    -- If the next byte is not a UTF-8 continuation byte, we're at a character boundary
    if not byte or (byte < 0x80 or byte >= 0xC0) then
      break
    end
    endPos = endPos + 1
  end

  return string.sub(str, startPos, endPos)
end

-- Function to search and highlight matches in document content
function searchAndHighlight(content, queryPattern, contextLength)
  local matches = {}
  local count = 0

  -- First, collect all matches
  local searchPos = 1
  while true do
    local first, last = string.find(content, queryPattern, searchPos)
    if first == nil then break end
    count = count + 1
    table.insert(matches, { first = first, last = last })
    searchPos = last + 1
  end

  if count == 0 then
    return 0, ''
  end

  -- Build highlighted content by merging overlapping segments
  local segments = {}

  -- Create segments with context for each match
  for i, match in ipairs(matches) do
    local rawContextStart = math.max(1, match.first - contextLength)
    local rawContextEnd = math.min(#content, match.last + contextLength)

    -- Adjust to word boundaries
    local contextStart = findWordBoundary(content, rawContextStart, 'backward')
    local contextEnd = findWordBoundary(content, rawContextEnd, 'forward')

    table.insert(segments, {
      start = contextStart,
      ending = contextEnd,
      matchStart = match.first,
      matchEnd = match.last
    })
  end

  -- Merge overlapping segments
  local mergedSegments = {}
  table.sort(segments, function(a, b) return a.start < b.start end)

  for i, segment in ipairs(segments) do
    if #mergedSegments == 0 then
      table.insert(mergedSegments, segment)
    else
      local lastSegment = mergedSegments[#mergedSegments]
      if segment.start <= lastSegment.ending then
        -- Overlapping segments, merge them
        lastSegment.ending = math.max(lastSegment.ending, segment.ending)
        -- Add this match to the segment
        if not lastSegment.matches then
          lastSegment.matches = {{ start = lastSegment.matchStart, ending = lastSegment.matchEnd }}
          lastSegment.matchStart = nil
          lastSegment.matchEnd = nil
        end
        table.insert(lastSegment.matches, { start = segment.matchStart, ending = segment.matchEnd })
      else
        -- Non-overlapping segment
        table.insert(mergedSegments, segment)
      end
    end
  end

  -- Build highlighted content from merged segments
  local highlightedContent = ''
  for i, segment in ipairs(mergedSegments) do
    if i > 1 then
      highlightedContent = highlightedContent .. ' '
    end

    if segment.matches then
      -- Multiple matches in this segment
      local segmentContent = safeSubstring(content, segment.start, segment.ending)
      local offset = segment.start - 1

      -- Sort matches by position
      table.sort(segment.matches, function(a, b) return a.start < b.start end)

      local lastPos = 1
      for j, match in ipairs(segment.matches) do
        local relativeStart = match.start - offset
        local relativeEnd = match.ending - offset

        -- Add content before match
        highlightedContent = highlightedContent .. safeSubstring(segmentContent, lastPos, relativeStart - 1)
        -- Add highlighted match
        highlightedContent = highlightedContent .. '<strong class="wuzzy-hit">' ..
          safeSubstring(segmentContent, relativeStart, relativeEnd) .. '</strong>'

        lastPos = relativeEnd + 1
      end
      -- Add remaining content after last match
      highlightedContent = highlightedContent .. safeSubstring(segmentContent, lastPos)
    else
      -- Single match in this segment
      local before = safeSubstring(content, segment.start, segment.matchStart - 1)
      local match = safeSubstring(content, segment.matchStart, segment.matchEnd)
      local after = safeSubstring(content, segment.matchEnd + 1, segment.ending)

      highlightedContent = highlightedContent .. before ..
        '<strong class="wuzzy-hit">' .. match .. '</strong>' .. after
    end
  end

  return count, highlightedContent
end

function nest_info(base, req)
  local state = base.WuzzyNest.State
  local result = {
    owner = base.owner,
    total_documents = state.TotalDocuments,
    total_term_count = state.TotalTermCount,
    total_content_length = state.TotalContentLength,
    average_document_term_length = state.AverageDocumentTermLength,
    total_crawlers = #state.Crawlers
  }

  for i, doc in ipairs(state.Documents) do
    result['document_'..i..'_id'] = doc.DocumentId
    result['document_'..i..'_title'] = doc.Title
    result['document_'..i..'_description'] = doc.Description
    result['document_'..i..'_url'] = doc.URL
    result['document_'..i..'_content_type'] = doc.ContentType
    result['document_'..i..'_term_count'] = doc.TermCount
    result['document_'..i..'_last_crawled_at'] = doc.LastCrawledAt
    result['document_'..i..'_content_length'] = doc.ContentLength
  end

  for i, task in ipairs(state.Crawlers) do
    result['crawler_'..i..'_id'] = task.CrawlerId
    result['crawler_'..i..'_creator'] = task.Creator
    result['crawler_'..i..'_owner'] = task.Owner
    result['crawler_'..i..'_name'] = task.Name
  end

  return result
end

function search_simple(base, req)
  local state = base.WuzzyNest.State
  local query = req.query
  local from = req.from or 0
  local pageSize = req.page_size or 10
  local contextLength = req.context_length or 100
  local hits = {}
  -- Use a safer pattern that preserves Unicode characters
  -- For ASCII characters, make case-insensitive; for non-ASCII, use exact match
  local queryPattern = string.gsub(query, '[a-zA-Z]', function (c)
    return string.format('[%s%s]', string.lower(c), string.upper(c))
  end)
  for i, doc in ipairs(state.Documents) do
    local count, highlightedContent = searchAndHighlight(doc.Content, queryPattern, contextLength)

    if count > 0 then
      table.insert(
        hits,
        { idx = i, score = count, doc = doc, highlighted = highlightedContent }
      )
    end
  end

  -- Sort by score DESC in each document
  table.sort(
    hits,
    function(a, b)
      return a.score > b.score
    end
  )

  return format_result('simple', hits, from, pageSize)
end

function search_bm25(base, req)
  local state = base.WuzzyNest.State
  local query = req.query
  local from = req.from or 0
  local pageSize = req.page_size or 10
  local contextLength = req.context_length or 100
  local B = req.b or 0.75
  local K = req.k or 1.2
  local hits = {}
  -- Use a safer pattern that preserves Unicode characters
  -- For ASCII characters, make case-insensitive; for non-ASCII, use exact match
  local queryPattern = string.gsub(query, '[a-zA-Z]', function (c)
    return string.format('[%s%s]', string.lower(c), string.upper(c))
  end)

  -- TODO -> split query into terms

  local function _inverseDocumentFrequency(totalHits, totalDocuments)
    return totalHits > 0 and math.log(
      1 + ((totalDocuments - totalHits + 0.5) / (totalHits + 0.5))
    ) or 0
  end

  if state.TotalDocuments == 0 or state.AverageDocumentTermLength == 0 then
    return hits -- No documents to search
  end

  for i, doc in ipairs(state.Documents) do
    local count, highlightedContent = searchAndHighlight(doc.Content, queryPattern, contextLength)

    if count > 0 then
      table.insert(hits, { idx = i, count = count, doc = doc, highlighted = highlightedContent })
    end
  end

  local idf = _inverseDocumentFrequency(#hits, state.TotalDocuments)
  for _, hit in ipairs(hits) do
    hit.score = idf * (
      (hit.count * (K + 1)) /
      (
        hit.count + (
          K * (
            1 - B + (B * (#hit.doc.Content / state.AverageDocumentTermLength))
          )
        )
      )
    )
  end

  -- Sort by score DESC in each document
  table.sort(hits, function(a, b) return a.score > b.score end)

  return format_result('bm25', hits, from, pageSize)
end

function format_result(searchType, hits, from, pageSize)
  from = from or 0
  pageSize = pageSize or 10

  local totalHits = #hits
  local startIndex = from + 1
  local endIndex = math.min(startIndex + pageSize - 1, totalHits)

  local results = {
    ['total_hits'] = totalHits,
    ['search_type'] = searchType,
    ['from'] = from,
    ['page_size'] = pageSize,
    ['has_more'] = (from + pageSize) < totalHits,
  }

  -- Only include results for the current offset range
  local resultIndex = 1
  for i = startIndex, endIndex do
    local hit = hits[i]
    if hit then
      results[resultIndex..'_idx'] = hit.idx
      results[resultIndex..'_score'] = hit.score
      results[resultIndex..'_count'] = hit.count
      results[resultIndex..'_docid'] = hit.doc.DocumentId
      results[resultIndex..'_title'] = hit.doc.Title
      results[resultIndex..'_description'] = hit.doc.Description
      results[resultIndex..'_content'] = hit.highlighted
      resultIndex = resultIndex + 1
    end
  end

  results['result_count'] = resultIndex - 1

  return results
end
