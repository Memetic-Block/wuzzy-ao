return function (WuzzyCrawler)
  local json = require('json')

  Handlers.add(
    'View-State',
    Handlers.utils.hasMatchingTag('Action', 'View-State'),
    function (msg)
      Send({
        Target = msg.From,
        Action = 'View-State-Response',
        Data = json.encode(WuzzyCrawler.State)
      })
    end
  )
end
