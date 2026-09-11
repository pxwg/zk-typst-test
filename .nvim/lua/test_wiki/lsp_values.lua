-- Translate source-backed announcements, without interpreting note semantics.
local M = {}

local function location(origin)
  return { uri = vim.uri_from_fname(origin.source), range = origin["range-utf16"] }
end

local function before(a, b)
  return a.line < b.line or (a.line == b.line and a.character < b.character)
end

local function matches(origin, params)
  local loc = location(origin)
  if loc.uri ~= params.textDocument.uri then
    return false
  end
  local range = loc.range
  if params.position then
    return not before(params.position, range.start) and before(params.position, range["end"])
  end
  local requested = params.range
  if not before(requested.start, requested["end"]) then
    return not before(requested.start, range.start) and before(requested.start, range["end"])
  end
  return before(requested.start, range["end"]) and before(range.start, requested["end"])
end

function M.result(output, method, params, versions)
  if method == "textDocument/hover" then
    for _, item in ipairs(output["lsp.hover"] or {}) do
      if matches(item["applies-to"], params) then
        return { contents = item.contents, range = item["applies-to"]["range-utf16"] }
      end
    end
  elseif method == "textDocument/definition" then
    for _, item in ipairs(output["lsp.definition"] or {}) do
      if matches(item["applies-to"], params) then
        return location(item.target)
      end
    end
  elseif method == "textDocument/codeAction" then
    local actions = {}
    for _, report in ipairs(output["lsp.code-actions"] or {}) do
      for _, item in ipairs(report.actions) do
        local only = params.context and params.context.only
        local allowed = not only
          or vim.iter(only):any(function(kind)
            return item.kind == kind or vim.startswith(item.kind or "", kind .. ".")
          end)
        if allowed and matches(item["applies-to"], params) then
          local changes = {}
          for _, edit in ipairs(item.edit.edits) do
            local loc = location(edit.origin)
            local document = changes[loc.uri]
            if not document then
              document = { textDocument = { uri = loc.uri, version = versions[loc.uri] or vim.NIL }, edits = {} }
              changes[loc.uri] = document
            end
            table.insert(document.edits, { range = loc.range, newText = edit["new-text"] })
          end
          actions[#actions + 1] = {
            title = item.title,
            kind = item.kind,
            isPreferred = item["is-preferred"],
            disabled = item.disabled and { reason = item.disabled } or nil,
            data = item.data,
            edit = { documentChanges = vim.tbl_values(changes) },
          }
        end
      end
    end
    return actions
  end
end

function M.publish(output, dispatchers, versions, previous)
  local documents = {}
  for _, report in ipairs(output["lsp.publish-diagnostics"] or {}) do
    local uri = location(report.document).uri
    documents[uri] = documents[uri] or {}
    for _, item in ipairs(report.diagnostics) do
      table.insert(documents[uri], {
        range = item.origin["range-utf16"],
        message = item.message,
        severity = item.severity,
        code = item.code,
        source = item.source,
        tags = item.tags,
        data = item.data,
      })
    end
  end
  for uri in pairs(previous) do
    documents[uri] = documents[uri] or {}
  end
  local current = {}
  for uri, diagnostics in pairs(documents) do
    dispatchers.notification("textDocument/publishDiagnostics", {
      uri = uri,
      version = versions[uri],
      diagnostics = diagnostics,
    })
    if #diagnostics > 0 then
      current[uri] = true
    end
  end
  return current
end

return M
