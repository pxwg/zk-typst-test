local M = {}

local hover_method = "textDocument/hover"
local prepare_rename_method = "textDocument/prepareRename"
local execute_command_method = "workspace/executeCommand"
local cancel_method = "$/cancelRequest"

local function typst_content_text(value)
  if type(value) == "string" then
    return value
  end
  if type(value) ~= "table" then
    return ""
  end
  if value.func == "text" then
    return value.text or ""
  end
  if value.func == "space" then
    return " "
  end
  if value.func == "linebreak" then
    return "\n"
  end
  if value.func == "parbreak" then
    return "\n\n"
  end
  if type(value.children) == "table" then
    return table.concat(vim.tbl_map(typst_content_text, value.children))
  end
  if value.body ~= nil then
    return typst_content_text(value.body)
  end
  return value.text or ""
end

local function markdown_code(value)
  return "`" .. tostring(value):gsub("`", "\\`") .. "`"
end

local function metadata_value_markdown(value)
  local kind = type(value)
  if kind == "string" then
    return markdown_code(value == "" and '""' or value)
  end
  if kind == "number" or kind == "boolean" then
    return markdown_code(value)
  end
  if kind ~= "table" then
    return markdown_code(vim.inspect(value))
  end
  if value.func ~= nil then
    local text = typst_content_text(value)
    return text == "" and markdown_code(vim.inspect(value)) or text
  end
  if vim.islist(value) then
    if #value == 0 then
      return "—"
    end
    return table.concat(vim.tbl_map(metadata_value_markdown, value), ", ")
  end
  return markdown_code(vim.inspect(value):gsub("%s+", " "))
end

local function decode_export_query(result)
  if type(result) ~= "table" or type(result.data) ~= "string" then
    return nil
  end

  local ok, decoded = pcall(vim.base64.decode, result.data)
  if not ok then
    decoded = result.data
  end
  local json_ok, value = pcall(vim.json.decode, decoded)
  return json_ok and value or nil
end

local function hover_result(envelope, range)
  if
    type(envelope) ~= "table"
    or envelope.protocol ~= "zk.hover"
    or envelope.version ~= 1
    or type(envelope.value) ~= "table"
  then
    return nil
  end

  local card = envelope.value
  local title = typst_content_text(card.title)
  if title == "" then
    title = "Untitled note"
  end

  local lines = {
    "### " .. title,
    "",
    markdown_code("@" .. tostring(card.id)),
  }
  local metadata = card.metadata
  if type(metadata) == "table" and not vim.tbl_isempty(metadata) then
    lines[#lines + 1] = ""
    local keys = vim.tbl_keys(metadata)
    table.sort(keys)
    for _, key in ipairs(keys) do
      lines[#lines + 1] = "- **" .. key .. ":** " .. metadata_value_markdown(metadata[key])
    end
  end

  return {
    contents = {
      kind = vim.lsp.protocol.MarkupKind.Markdown,
      value = table.concat(lines, "\n"),
    },
    range = range,
  }
end

local function hover_target(result)
  local id = type(result) == "table" and result.placeholder or nil
  if type(id) == "string" and id:match("^%d%d%d%d%d%d%d%d%d%d$") then
    return id, result.range
  end
end

local function export_query_params(focus_main, id)
  return {
    command = "tinymist.exportQuery",
    arguments = {
      focus_main,
      {
        format = "json",
        selector = "<zk.hover." .. id .. ">",
        field = "value",
        one = true,
        pretty = false,
      },
      { write = false, open = false },
    },
  }
end

local function start_adapter(server_cmd, project_root, dispatchers, config)
  local raw = vim.lsp.rpc.start(server_cmd, dispatchers, {
    cwd = config.cmd_cwd,
    env = config.cmd_env,
    detached = config.detached,
  })
  if vim.fs.normalize(config.root_dir or "") ~= project_root then
    return raw
  end

  local focus_main = vim.fs.joinpath(project_root, "focus.typ")
  local active = {}
  local adapter = {}

  function adapter.request(method, params, callback, notify_reply_callback)
    if method ~= hover_method then
      return raw.request(method, params, callback, notify_reply_callback)
    end

    local state = {
      callback = callback,
      notify_reply_callback = notify_reply_callback,
      cancelled = false,
      finished = false,
    }

    local function finish(err, result)
      if state.cancelled or state.finished then
        return
      end
      state.finished = true
      if state.outer_id then
        active[state.outer_id] = nil
      end
      if state.notify_reply_callback and state.outer_id then
        state.notify_reply_callback(state.outer_id)
      end
      state.callback(err, result, state.outer_id)
    end

    local function send(method_, params_, handler)
      if state.cancelled or state.finished then
        return false
      end
      local ok, request_id = raw.request(method_, params_, function(err, result)
        if not state.cancelled and not state.finished then
          handler(err, result)
        end
      end)
      if ok then
        state.inner_id = request_id
      end
      return ok
    end

    local function fallback()
      if not send(hover_method, params, finish) then
        finish(nil, nil)
      end
    end

    local ok, request_id = raw.request(prepare_rename_method, params, function(err, result)
      if state.cancelled or state.finished then
        return
      end
      local id, range
      if not err then
        id, range = hover_target(result)
      end
      if not id then
        fallback()
        return
      end

      if
        not send(execute_command_method, export_query_params(focus_main, id), function(query_err, query_result)
          if query_err then
            fallback()
            return
          end
          local response = hover_result(decode_export_query(query_result), range)
          if response then
            finish(nil, response)
          else
            fallback()
          end
        end)
      then
        fallback()
      end
    end)

    if not ok then
      return false
    end
    state.outer_id = request_id
    state.inner_id = request_id
    active[request_id] = state
    return true, request_id
  end

  function adapter.notify(method, params)
    if method == cancel_method and type(params) == "table" then
      local state = active[params.id]
      if state then
        state.cancelled = true
        state.finished = true
        active[state.outer_id] = nil
        if state.notify_reply_callback then
          state.notify_reply_callback(state.outer_id)
        end
        return raw.notify(cancel_method, { id = state.inner_id })
      end
    end
    return raw.notify(method, params)
  end

  function adapter.is_closing()
    return raw.is_closing()
  end

  function adapter.terminate()
    for _, state in pairs(active) do
      state.cancelled = true
    end
    active = {}
    raw.terminate()
  end

  return adapter
end

function M.command(server_cmd, project_root)
  project_root = vim.fs.normalize(project_root)
  return function(dispatchers, config)
    return start_adapter(server_cmd, project_root, dispatchers, config)
  end
end

return M
