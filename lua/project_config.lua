--------------------------------------------------------------------------------
-- project_config: loads and validates project configuration.
--
-- Defaults:
--   Middleman works out of the box with no config files. When no override files
--   exist, built-in defaults are used:
--
--   - project config defaults to {} (no rewrites, default stubs path)
--   - stubs default to a single health-check endpoint:
--       GET /_health -> 200 { "status": "middleman ok", "source": "stub" }
--
-- Overrides:
--   Create config/project.local.lua to configure rewrites or a custom stubs path.
--   Create config/stubs.local.lua to define your own stub rules.
--   These *.local.lua files are git-ignored. See README.md for the full format.
--
-- config/project.local.lua must return a table:
--   return {
--     rewrites = {                                   -- optional
--       { from = "^/local/(.*)$", to = "/api/$1" }, -- PCRE patterns, first match wins
--     },
--     stubs_file = "/app/config/stubs.local.lua",   -- optional, absolute container path
--   }
--
-- config/stubs.local.lua must return a table (list of stub definitions):
--   return {
--     { name = "health", method = "GET", path = "/_health",
--       response = { status = 200, json = { status = "ok" } } },
--   }
--
-- When an override file exists but contains errors, startup fails fast with a
-- clear message. Defaults are only used when the file is absent.
--------------------------------------------------------------------------------
local project_config = {}

local PROJECT_CONFIG_PATH = "/app/config/project.local.lua"
local DEFAULT_STUBS_PATH = "/app/config/stubs.local.lua"

-- Built-in stubs used when no stubs file exists and no custom stubs_file is set.
local DEFAULT_STUBS = {
  {
    name = "health",
    method = "GET",
    path = "/_health",
    response = {
      status = 200,
      json = {
        status = "middleman ok",
        source = "stub"
      }
    }
  }
}

--- Load a Lua file that must return a table. Errors if the file is missing or invalid.
local function load_lua_table(path, label)
  -- Use loadfile+pcall so syntax/runtime errors in local config fail clearly at startup.
  local chunk, load_error = loadfile(path)
  if not chunk then
    error(label .. " file not found: " .. path .. " (" .. tostring(load_error) .. ")")
  end

  local ok, data = pcall(chunk)
  if not ok then
    error("failed to load " .. label .. " file: " .. path .. " (" .. tostring(data) .. ")")
  end

  if type(data) ~= "table" then
    error(label .. " must return a table: " .. path)
  end

  return data
end

--- Try to load a Lua file that returns a table. If the file does not exist,
--- returns the provided default and logs at INFO level. If the file exists but
--- has syntax/runtime errors, raises an error (fail-fast on bad config).
local function load_lua_table_optional(path, label, default)
  local f = io.open(path, "r")
  if not f then
    ngx.log(ngx.INFO, label .. " not found at " .. path .. ", using built-in defaults")
    return default
  end
  f:close()

  local data = load_lua_table(path, label)
  ngx.log(ngx.INFO, label .. " loaded from " .. path)
  return data
end

local function validate_rewrite_rules(config)
  if config.rewrites == nil then
    return
  end

  if type(config.rewrites) ~= "table" then
    error("project config field 'rewrites' must be a table")
  end

  for index, rule in ipairs(config.rewrites) do
    if type(rule) ~= "table" then
      error("rewrite rule at index " .. index .. " must be a table")
    end

    if type(rule.from) ~= "string" or rule.from == "" then
      error("rewrite rule at index " .. index .. " is missing required string field 'from'")
    end

    if type(rule.to) ~= "string" then
      error("rewrite rule at index " .. index .. " is missing required string field 'to'")
    end

    if rule.options ~= nil and type(rule.options) ~= "string" then
      error("rewrite rule at index " .. index .. " field 'options' must be a string when provided")
    end
  end
end

local function validate_project_config(config)
  if config.stubs_file ~= nil and type(config.stubs_file) ~= "string" then
    error("project config field 'stubs_file' must be a string when provided")
  end

  validate_rewrite_rules(config)
end

function project_config.load_project()
  local config = load_lua_table_optional(PROJECT_CONFIG_PATH, "project config", {})
  validate_project_config(config)
  return config
end

function project_config.get_rewrites()
  local config = project_config.load_project()
  return config.rewrites or {}
end

function project_config.load_stubs()
  local config = project_config.load_project()

  if config.stubs_file then
    -- User explicitly configured a stubs file; it must exist.
    return load_lua_table(config.stubs_file, "stubs config")
  end

  -- No explicit stubs_file: try the default path, fall back to built-in stubs.
  return load_lua_table_optional(DEFAULT_STUBS_PATH, "stubs config", DEFAULT_STUBS)
end

function project_config.validate_startup()
  -- Validate config at startup. Uses built-in defaults when no override files exist.
  local config = project_config.load_project()

  if config.stubs_file then
    load_lua_table(config.stubs_file, "stubs config")
  else
    load_lua_table_optional(DEFAULT_STUBS_PATH, "stubs config", DEFAULT_STUBS)
  end
end

return project_config
