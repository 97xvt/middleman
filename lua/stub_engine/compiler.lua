local compiler = {}

local function get_stub_rules(stub_rules)
  if type(stub_rules) ~= "table" then
    return {}
  end

  return stub_rules
end

function compiler.compile(stub_rules)
  local compiled_stubs = {
    rules = {},
    needs_body = false
  }

  for _, stub_rule in ipairs(get_stub_rules(stub_rules)) do
    if type(stub_rule) == "table" then
      local compiled_stub_rule = {
        raw = stub_rule,
        method = string.upper(stub_rule.method or "GET"),
        path = stub_rule.path or ""
      }

      if stub_rule.enabled ~= false and stub_rule.body_contains then
        compiled_stubs.needs_body = true
      end

      compiled_stubs.rules[#compiled_stubs.rules + 1] = compiled_stub_rule
    end
  end

  return compiled_stubs
end

return compiler
