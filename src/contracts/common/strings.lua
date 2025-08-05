return {
  starts_with = function(str, start)
    return str:sub(1, #start) == start
  end,
  count = function(base, pattern)
    return select(2, string.gsub(base, pattern, ""))
  end
}
