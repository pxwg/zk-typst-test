-- One evaluator process and newline-delimited JSON-RPC connection per LSP client.
local M = {}

function M.start(root, on_exit)
  local socket = "/tmp/zk-eval-" .. vim.uv.os_getpid() .. "-" .. vim.uv.hrtime() .. ".sock"
  local binary = vim.fs.joinpath(root, "zk-eval/target/release/zk-eval")
  local process, pipe
  local closing, connected = false, false
  local sequence, attempts = 0, 0
  local pending, outbox = {}, {}
  local received = ""
  local rpc = {}

  local function close_pipe()
    if pipe and not pipe:is_closing() then
      pipe:close()
    end
    connected = false
  end

  local function reject(message)
    local callbacks = pending
    pending, outbox = {}, {}
    for _, callback in pairs(callbacks) do
      callback({ code = -32603, message = message })
    end
  end

  local function fail(message)
    if closing then
      return
    end
    closing = true
    close_pipe()
    reject(message)
    if process then
      process:kill(15)
    end
  end

  local function write(message)
    pipe:write(
      message,
      vim.schedule_wrap(function(err)
        if err then
          fail("Evaluator write failed: " .. err)
        end
      end)
    )
  end

  function rpc.request(method, params, callback)
    if closing then
      vim.schedule(function()
        callback({ code = -32603, message = "Evaluator is stopped" })
      end)
      return
    end
    sequence = sequence + 1
    pending[sequence] = callback
    local message = vim.json.encode({ jsonrpc = "2.0", id = sequence, method = method, params = params }) .. "\n"
    if connected then
      write(message)
    else
      outbox[#outbox + 1] = message
    end
  end

  function rpc.terminate()
    fail("Evaluator stopped")
  end

  local function connect()
    if closing then
      return
    end
    attempts = attempts + 1
    pipe = vim.uv.new_pipe(false)
    pipe:connect(
      socket,
      vim.schedule_wrap(function(err)
        if closing then
          close_pipe()
          return
        end
        if err then
          close_pipe()
          if attempts < 200 then
            vim.defer_fn(connect, 25)
          else
            fail("Could not connect to evaluator: " .. err)
          end
          return
        end
        connected = true
        pipe:read_start(vim.schedule_wrap(function(read_err, chunk)
          if closing then
            return
          end
          if read_err or not chunk then
            fail(read_err or "Evaluator disconnected")
            return
          end
          received = received .. chunk
          while true do
            local newline = received:find("\n", 1, true)
            if not newline then
              break
            end
            local line = received:sub(1, newline - 1)
            received = received:sub(newline + 1)
            local ok, response = pcall(vim.json.decode, line, { luanil = { object = true } })
            if not ok or type(response) ~= "table" then
              fail("Invalid evaluator response")
              return
            end
            local callback = pending[response.id]
            pending[response.id] = nil
            if callback then
              callback(response.error, response.result)
            end
          end
        end))
        for _, message in ipairs(outbox) do
          write(message)
        end
        outbox = {}
      end)
    )
  end

  -- Defer startup so the owner has installed its request/exit handlers first.
  vim.schedule(function()
    if closing then
      on_exit(0, 0)
      return
    end
    local ok, result = pcall(
      vim.system,
      { binary, "serve", "--root", root, "--socket", socket },
      { text = true },
      function(exit)
        vim.schedule(function()
          closing = true
          close_pipe()
          reject(exit.stderr ~= "" and exit.stderr or "Evaluator exited")
          vim.uv.fs_unlink(socket)
          on_exit(exit.code, exit.signal)
        end)
      end
    )
    if not ok then
      fail("Cannot start evaluator; run cargo build --release --manifest-path zk-eval/Cargo.toml. " .. tostring(result))
      on_exit(1, 0)
      return
    end
    process = result
    connect()
  end)

  return rpc
end

return M
