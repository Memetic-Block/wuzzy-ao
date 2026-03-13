function nest_info(state, req)
  local result = {
    nest_id = state.nest_id,
    nest_creator = state.nest_creator,
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

function render(template, context)
  return template:gsub("{{(.-)}}", function(key)
    return context[key:match("^%s*(.-)%s*$")] or ""
  end)
end

function index(state, req)
  local html = [[
  <!DOCTYPE html><html lang="en">
  <head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Nest Information</title>
    <style>
      body { font-family: Arial, sans-serif; margin: 20px; }
      h1 { color: #333; }
      table { width: 100%; border-collapse: collapse; margin-top: 20px; }
      th, td { border: 1px solid #ccc; padding: 8px; text-align: left; }
      th { background-color: #f4f4f4; }
    </style>
  </head>
  <body>
    <h1>Nest {{nest_id}}</h1>
    <table>
      <tr><th>Key</th><th>Value</th></tr>
      <tr><td>Nest Creator</td><td>{{nest_creator}}</td></tr>
      <tr><td>Registration Code</td><td>{{registration_code}}</td></tr>
      <tr><td>Nest Registry</td><td>{{nest_registry}}</td></tr>
      <tr><td>Total Documents</td><td>{{total_documents}}</td></tr>
      <tr><td>Total Term Count</td><td>{{total_term_count}}</td></tr>
      <tr><td>Total Content Length</td><td>{{total_content_length}}</td></tr>
      <tr><td>Average Document Term Length</td><td>{{average_document_term_length}}</td></tr>
      <tr><td>Roles</td><td>{{roles}}</td></tr>
      <tr><td>Total Crawlers</td><td>{{total_crawlers}}</td></tr>
      <tr><td>Total Documents</td><td>{{total_documents}}</td></tr>
    </table>
  </body>
  </html>
  ]]
  return render(html, nest_info(state, req))
end
