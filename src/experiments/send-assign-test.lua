test_assign_value = test_assign_value or 'initial'
sister_process = sister_process or ''  -- Replace with actual sister process ID

ao.addAssignable('allowAll', function (msg) return true end)

Handlers.add('Test-Assign', 'Test-Assign', function (msg)
  assert(msg.From == Owner or msg.From == ao.id or msg.From == sister_process, 'Unauthorized sender: ' .. msg.From)
  print('Received Test-Assign with Data = ' .. msg.Data)
  test_assign_value = msg.Data
  Send({ device = 'patch@1.0', test_assign_value = test_assign_value })
end)

Send({ device = 'patch@1.0', test_assign_value = test_assign_value, sister_process = sister_process })

-- Send({ Target = ao.id, Action = 'Test-Assign', Data = 'hello from assignment!', Assignments = { '1dzon0chEvWU8IsOVMccMVvFxRBjI_RCgiXyT32Pxx0' } })
-- Send({ Target = ao.id, Action = 'Test-Assign', Data = '22222222', Assignments = { '1dzon0chEvWU8IsOVMccMVvFxRBjI_RCgiXyT32Pxx0' } })
