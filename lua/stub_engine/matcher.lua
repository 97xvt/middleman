local rule_matcher = {}

local function stub_rule_matches(compiled_stub_rule, request_context)
  if compiled_stub_rule.raw.enabled == false then
    return false
  end

  if compiled_stub_rule.method ~= request_context.method then
    return false
  end

  if compiled_stub_rule.path ~= request_context.path then
    return false
  end

  local body_contains = compiled_stub_rule.raw.body_contains
  if body_contains and not string.find(request_context.body, body_contains, 1, true) then
    return false
  end

  return true
end

function rule_matcher.find_matching_stub_rule(compiled_stubs, request_context)
  for _, compiled_stub_rule in ipairs(compiled_stubs.rules) do
    if stub_rule_matches(compiled_stub_rule, request_context) then
      return compiled_stub_rule
    end
  end

  return nil
end

return rule_matcher
