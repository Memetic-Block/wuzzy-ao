-- Wuzzy Nest Registry for hyper-aos
local json = require('json')
acl = require('..common.acl')

documents = documents or {}
total_documents = total_documents or 0
total_term_count = total_term_count or 0
total_content_length = total_content_length or 0
average_document_term_length = average_document_term_length or 0
registration_code = registration_code or ao.env.Process.Tags['Registration-Code'] or 'none'
nest_registry = nest_registry or ao.env.Process.Tags['Nest-Registry'] or 'unknown'

-- Update ACL Roles --
Handlers.add('Update-Roles', 'Update-Roles', function (msg)
  acl.assertHasOneOfRole(msg.From, { 'owner', 'admin', 'Update-Roles' })
  acl = acl.updateRoles(require('json').decode(msg.Data), acl)
  Send({
    Target = msg.From,
    Action = 'Update-Roles-Response',
    Data = 'OK'
  })
  Send({
    Target = ao.id,
    device = 'patch@1.0',
    acl = acl
  })
end)

-- View ACL Roles --
Handlers.add('View-Roles', 'View-Roles', function (msg)
  Send({
    Target = msg.From,
    Action = 'View-Roles-Response',
    Data = json.encode(acl.state)
  })
end)

if nest_registry ~= 'unknown' then
  Send({
    Target = nest_registry,
    Action = 'Register-Nest',
    ['Registration-Code'] = registration_code,
    Data = json.encode({ acl = acl, owner = Owner })
  })
end

Send({
  device = 'patch@1.0',
  documents = documents,
  total_documents = total_documents,
  total_term_count = total_term_count,
  total_content_length = total_content_length,
  average_document_term_length = average_document_term_length,
  registration_code = registration_code,
  nest_registry = nest_registry
})
