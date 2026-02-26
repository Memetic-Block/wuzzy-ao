function nest_info(state, req)
  local result = {
    owner = state.Owner,
    registration_code = state.registration_code,
    nest_registry = state.nest_registry,
    total_documents = state.total_documents,
    total_term_count = state.total_term_count,
    total_content_length = state.total_content_length,
    average_document_term_length = state.average_document_term_length
  }

  local roles = ''
  for role, addresses in pairs(state.acl.roles) do
    roles = roles .. role .. (roles == '' and '' or ',')
    for address, _ in pairs(addresses) do
      result['acl_'..role..'_'..address] = true
    end
  end
  result.roles = roles

  local total_crawlers = 0
  for i, crawler in ipairs(state.crawlers) do
    total_crawlers = total_crawlers + 1
    result['crawler_'..i..'_id'] = crawler.id
    result['crawler_'..i..'_owner'] = crawler.owner
    result['crawler_'..i..'_acl'] = crawler.acl
  end
  result.total_crawlers = total_crawlers

  local total_documents = 0
  for i, document in ipairs(state.documents) do
    total_documents = total_documents + 1
    result['doc_'..i..'_id'] = document.id
    result['doc_'..i..'_owner'] = document.owner
  end
  result.total_documents = total_documents

  return result
end