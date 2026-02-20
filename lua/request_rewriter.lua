local project_config = require("project_config")

local request_rewriter = {}

function request_rewriter.apply()
  local path = ngx.var.uri or ""

  -- First matching rule wins to keep behavior deterministic.
  for _, rule in ipairs(project_config.get_rewrites()) do
    local rewritten_path, replacements, rewrite_error = ngx.re.sub(
      path,
      rule.from,
      rule.to,
      rule.options or "jo"
    )

    if rewrite_error then
      ngx.log(ngx.ERR, "rewrite rule failed: ", tostring(rewrite_error))
      return
    end

    if replacements and replacements > 0 then
      if rewritten_path ~= path then
        -- Rewrite only the path; query string is preserved by nginx.
        ngx.req.set_uri(rewritten_path, false)
      end
      return
    end
  end
end

return request_rewriter
