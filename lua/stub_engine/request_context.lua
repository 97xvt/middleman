local request_context_builder = {}

local function read_request_body()
  ngx.req.read_body()

  local body = ngx.req.get_body_data()
  if body then
    return body
  end

  local body_file = ngx.req.get_body_file()
  if not body_file then
    return ""
  end

  local file = io.open(body_file, "rb")
  if not file then
    return ""
  end

  local data = file:read("*a") or ""
  file:close()
  return data
end

local function get_request_path()
  -- request_uri keeps the original incoming path even if rewrite_by_lua mutates ngx.var.uri.
  local request_uri = ngx.var.request_uri or ""
  local query_start = string.find(request_uri, "?", 1, true)
  if query_start then
    return string.sub(request_uri, 1, query_start - 1)
  end

  if request_uri ~= "" then
    return request_uri
  end

  return ngx.var.uri or ""
end

function request_context_builder.build(compiled_stubs)
  local request_context = {
    method = ngx.req.get_method(),
    path = get_request_path(),
    body = ""
  }

  if compiled_stubs.needs_body then
    request_context.body = read_request_body()
  end

  return request_context
end

return request_context_builder
