local source = debug.getinfo(1, "S").source
local root = vim.fs.dirname(vim.fs.normalize(source:sub(2)))
local note_root = vim.fs.joinpath(root, "note")
local focus_main = vim.fs.joinpath(root, "focus.typ")
local group = vim.api.nvim_create_augroup("test_wiki_tinymist_focus", { clear = true })
local pinned = {}
local client_focus = {}

local function note_id(bufnr)
  local path = vim.fs.normalize(vim.api.nvim_buf_get_name(bufnr))
  local prefix = note_root .. "/"
  if path:sub(1, #prefix) ~= prefix then
    return nil
  end
  return path:sub(#prefix + 1):match("^(%d%d%d%d%d%d%d%d%d%d)%.typ$")
end

local function is_project_client(client)
  return client.name == "tinymist" and vim.fs.normalize(client.root_dir or "") == root
end

local function pin_main(client, bufnr)
  if pinned[client.id] then
    return
  end
  pinned[client.id] = true
  client:request("workspace/executeCommand", {
    command = "tinymist.pinMain",
    arguments = { focus_main },
    title = "Pin test-wiki focus entry",
  }, function(err)
    if err then
      pinned[client.id] = nil
      vim.schedule(function()
        vim.notify("Tinymist focus pin failed: " .. vim.inspect(err), vim.log.levels.WARN)
      end)
    end
  end, bufnr)
end

local function configure(client, bufnr, id)
  if not id or not is_project_client(client) then
    return
  end

  pin_main(client, bufnr)
  if client_focus[client.id] == id then
    return
  end
  client_focus[client.id] = id

  client.settings = client.settings or {}
  client.settings.tinymist = vim.tbl_deep_extend("force", client.settings.tinymist or {}, {
    projectResolution = "singleFile",
    typstExtraArgs = { "--input=zk-focus-id=" .. id },
  })
  client:notify("workspace/didChangeConfiguration", { settings = client.settings })

  -- Force reevaluation of the stable main after changing this client's inputs.
  client:notify("workspace/didChangeWatchedFiles", {
    changes = {
      { uri = vim.uri_from_fname(focus_main), type = 2 },
    },
  })
end

local function update(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local id = note_id(bufnr)
  if not id then
    return
  end

  for _, client in ipairs(vim.lsp.get_clients({ name = "tinymist" })) do
    configure(client, bufnr, id)
  end
end

vim.api.nvim_create_autocmd({ "BufEnter", "WinEnter" }, {
  group = group,
  pattern = "*.typ",
  callback = function(args)
    update(args.buf)
  end,
})

vim.api.nvim_create_autocmd("LspAttach", {
  group = group,
  callback = function(args)
    local client = vim.lsp.get_client_by_id(args.data.client_id)
    if client then
      local current = vim.api.nvim_get_current_buf()
      configure(client, current, note_id(current))
    end
  end,
})

vim.schedule(function()
  update(vim.api.nvim_get_current_buf())
end)
