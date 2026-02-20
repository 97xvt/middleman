local project_config = require("project_config")
local compiler = require("stub_engine.compiler")
local request_context = require("stub_engine.request_context")
local matcher = require("stub_engine.matcher")
local responder = require("stub_engine.responder")

local stub_engine = {}
local compiled_stubs = compiler.compile(project_config.load_stubs())

function stub_engine.try()
  local request_context_data = request_context.build(compiled_stubs)
  local matched_stub_rule = matcher.find_matching_stub_rule(compiled_stubs, request_context_data)

  if not matched_stub_rule then
    return false
  end

  if matched_stub_rule.raw.name then
    ngx.log(ngx.INFO, "stub matched: ", matched_stub_rule.raw.name)
  end

  responder.write_stub_response(matched_stub_rule.raw.response or {})
  return true
end

return stub_engine
