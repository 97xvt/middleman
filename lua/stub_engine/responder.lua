local cjson = require("cjson.safe")

local stub_responder = {}

local function apply_response_headers(headers)
  if type(headers) ~= "table" then
    return
  end

  for key, value in pairs(headers) do
    ngx.header[key] = tostring(value)
  end
end

local function set_default_content_type(content_type)
  -- Preserve explicitly configured content-type from response.headers.
  if not ngx.header["content-type"] then
    ngx.header["content-type"] = content_type
  end
end

local function write_body_and_exit(status, body, default_content_type)
  if default_content_type then
    set_default_content_type(default_content_type)
  end

  if body ~= nil then
    ngx.print(body)
  end

  return ngx.exit(status)
end

local function read_stub_response_file(path)
  local file, err = io.open("/app/" .. path, "rb")
  if not file then
    return nil, err
  end

  local data = file:read("*a")
  file:close()
  return data
end

function stub_responder.write_stub_response(response)
  local status = tonumber(response.status) or 200
  ngx.status = status

  apply_response_headers(response.headers)

  if response.file then
    local file_body, file_err = read_stub_response_file(response.file)
    if not file_body then
      -- Returning structured 500 here makes broken stub files obvious during dev.
      local error_body = cjson.encode({ error = "stub file read failed", detail = file_err })
      if not error_body then
        error_body = "{\"error\":\"stub file read failed\"}"
      end
      ngx.status = 500
      return write_body_and_exit(500, error_body, "application/json")
    end

    return write_body_and_exit(status, file_body, "application/json")
  end

  if response.json ~= nil then
    return write_body_and_exit(status, cjson.encode(response.json), "application/json")
  end

  if response.text ~= nil then
    return write_body_and_exit(status, tostring(response.text), "text/plain; charset=utf-8")
  end

  return ngx.exit(status)
end

return stub_responder
