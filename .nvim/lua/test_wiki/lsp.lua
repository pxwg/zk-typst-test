local values = require("test_wiki.lsp_values")
local M = {}

function M.command(root)
  return function(dispatchers)
    local closing = false
    local sequence, generation, evaluated = 0, 0, -1
    local running, supports_watching = false, false
    local pending, waiting, published, documents = {}, {}, {}, {}
    local output, versions, last_error = {}, {}, nil
    local timer = vim.uv.new_timer()
    local server = {}

    local function close_timer()
      if not timer:is_closing() then
        timer:stop()
        timer:close()
      end
    end

    local function reply_waiting(err)
      local callbacks = waiting
      waiting = {}
      for _, reply in pairs(callbacks) do
        reply(err)
      end
    end

    local evaluator = require("test_wiki.eval_rpc").start(root, function(code, signal)
      closing = true
      close_timer()
      published = values.publish({}, dispatchers, {}, published)
      for _, finish in pairs(pending) do
        finish({ code = -32603, message = "Evaluator exited" })
      end
      dispatchers.on_exit(code, signal)
    end)

    local function relative_path(uri)
      local path = vim.fs.normalize(vim.uri_to_fname(uri))
      local prefix = root .. "/"
      return path:sub(1, #prefix) == prefix and path:sub(#prefix + 1) or nil
    end

    -- At most one eval is in flight. The LSP owns when to compute; the runtime
    -- only receives an entry and the complete current set of open sources.
    local function evaluate()
      if closing or running or evaluated == generation then
        return
      end
      timer:stop()
      running = true
      local sent_generation = generation
      local sources, sent_versions = vim.empty_dict(), {}
      for uri, document in pairs(documents) do
        sources[relative_path(uri)] = document.text
        sent_versions[uri] = document.version
      end
      evaluator.request("eval", { entry = "lsp.typ", sources = sources }, function(err, result)
        running = false
        if closing then
          return
        end
        if sent_generation ~= generation then
          evaluate()
          return
        end
        evaluated, last_error = sent_generation, err
        output, versions = result and result.output or {}, sent_versions
        server.revision = result and result.revision or (err and err.data and err.data.revision)
        published = values.publish(output, dispatchers, versions, published)
        if err then
          dispatchers.notification("window/logMessage", { type = 1, message = err.message })
        end
        reply_waiting()
      end)
    end

    local function changed()
      generation = generation + 1
      reply_waiting({ code = -32801, message = "Content modified" })
      timer:start(120, 0, vim.schedule_wrap(evaluate))
    end

    function server.request(method, params, callback, notify_reply_callback)
      if closing then
        return false
      end
      sequence = sequence + 1
      local id = sequence
      local requested_generation = generation
      local function finish(err, result)
        if not pending[id] then
          return
        end
        pending[id], waiting[id] = nil, nil
        if notify_reply_callback then
          notify_reply_callback(id)
        end
        callback(err, result)
      end
      pending[id] = finish
      vim.schedule(function()
        if not pending[id] then
          return
        end
        if method == "initialize" then
          supports_watching =
            vim.tbl_get(params, "capabilities", "workspace", "didChangeWatchedFiles", "dynamicRegistration")
          finish(nil, {
            capabilities = {
              positionEncoding = "utf-16",
              textDocumentSync = { openClose = true, change = 1, save = true },
              hoverProvider = true,
              definitionProvider = true,
              codeActionProvider = true,
            },
            serverInfo = { name = "test-wiki", version = "0.1" },
          })
        elseif method == "shutdown" then
          closing = true
          close_timer()
          reply_waiting({ code = -32800, message = "LSP is shutting down" })
          evaluator.request("shutdown", vim.empty_dict(), finish)
        elseif
          method == "textDocument/hover"
          or method == "textDocument/definition"
          or method == "textDocument/codeAction"
        then
          if requested_generation ~= generation then
            finish({ code = -32801, message = "Content modified" })
            return
          end
          local function reply(err)
            err = err or last_error
            finish(err, not err and values.result(output, method, params, versions) or nil)
          end
          if evaluated == generation then
            reply()
          else
            waiting[id] = reply
            evaluate()
          end
        else
          finish({ code = -32601, message = "Unsupported method: " .. method })
        end
      end)
      return true, id
    end

    function server.notify(method, params)
      if method == "exit" then
        server.terminate()
      elseif method == "$/cancelRequest" then
        if pending[params.id] then
          pending[params.id]({ code = -32800, message = "Request cancelled" })
        end
      elseif not closing then
        if method == "initialized" then
          if supports_watching then
            dispatchers.server_request("client/registerCapability", {
              registrations = {
                {
                  id = "note-sources",
                  method = "workspace/didChangeWatchedFiles",
                  registerOptions = {
                    watchers = {
                      {
                        globPattern = { baseUri = vim.uri_from_fname(root), pattern = "**/*.typ" },
                      },
                    },
                  },
                },
              },
            })
          end
          changed()
        elseif method == "workspace/didChangeWatchedFiles" then
          changed()
        elseif params and params.textDocument and relative_path(params.textDocument.uri) then
          local document = params.textDocument
          if method == "textDocument/didOpen" then
            documents[document.uri] = { text = document.text, version = document.version }
            changed()
          elseif method == "textDocument/didChange" then
            -- Full text sync keeps this layer free of another edit/parse engine.
            local current = documents[document.uri]
            if current and document.version > current.version then
              current.text = params.contentChanges[#params.contentChanges].text
              current.version = document.version
              changed()
            end
          elseif method == "textDocument/didClose" then
            documents[document.uri] = nil
            changed()
          elseif method == "textDocument/didSave" then
            changed()
          end
        end
      end
      return true
    end

    function server.is_closing()
      return closing
    end

    function server.terminate()
      closing = true
      close_timer()
      evaluator.terminate()
    end

    return server
  end
end

return M
