local values = require("test_wiki.lsp_values")
local M = {}

function M.command(root)
  return function(dispatchers)
    local closing = false
    local sequence = 0
    local pending, published = {}, {}
    local server = {}
    local evaluator = require("test_wiki.eval_rpc").start(root, function(code, signal)
      closing = true
      published = values.publish({}, dispatchers, {}, published)
      for _, finish in pairs(pending) do
        finish({ code = -32603, message = "Evaluator exited" })
      end
      dispatchers.on_exit(code, signal)
    end)

    local function evaluate(callback)
      evaluator.request("eval", { entry = "lsp.typ" }, function(err, result)
        if closing then
          return
        end
        published = values.publish(result and result.output or {}, dispatchers, {}, published)
        if callback then
          callback(err, result and result.output)
        elseif err then
          dispatchers.notification("window/logMessage", { type = 1, message = err.message })
        end
      end)
    end

    function server.request(method, params, callback, notify_reply_callback)
      if closing then
        return false
      end
      sequence = sequence + 1
      local id = sequence
      local function finish(err, result)
        if not pending[id] then
          return
        end
        pending[id] = nil
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
          evaluator.request("shutdown", vim.empty_dict(), finish)
        elseif
          method == "textDocument/hover"
          or method == "textDocument/definition"
          or method == "textDocument/codeAction"
        then
          evaluate(function(err, output)
            finish(err, output and values.result(output, method, params, {}))
          end)
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
      elseif not closing and (method == "textDocument/didOpen" or method == "textDocument/didSave") then
        evaluate()
      end
      return true
    end

    function server.is_closing()
      return closing
    end

    function server.terminate()
      closing = true
      evaluator.terminate()
    end

    return server
  end
end

return M
