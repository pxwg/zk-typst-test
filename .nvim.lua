local source = debug.getinfo(1, "S").source
local root = vim.fs.dirname(vim.fs.normalize(source:sub(2)))
local project_runtime = vim.fs.joinpath(root, ".nvim")
if not vim.list_contains(vim.opt.runtimepath:get(), project_runtime) then
  vim.opt.runtimepath:append(project_runtime)
end
-- Re-resolve Tinymist after adding the project-local LSP configuration.
vim.lsp.config("tinymist", {})
local note_root = vim.fs.joinpath(root, "note")
local focus_main = vim.fs.joinpath(root, "focus.typ")
local focus_dir = vim.fs.joinpath(root, ".zk-lsp")
local preview_focus_name = "preview-focus-" .. tostring(vim.uv.os_getpid()) .. ".json"
local preview_focus_file = vim.fs.joinpath(focus_dir, preview_focus_name)
local preview_focus_input = ".zk-lsp/" .. preview_focus_name
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

local function write_preview_focus(id)
  vim.fn.mkdir(focus_dir, "p")
  local payload = vim.json.encode({ id = id })
  local current = vim.fn.filereadable(preview_focus_file) == 1
      and table.concat(vim.fn.readfile(preview_focus_file), "\n")
    or ""
  if current ~= payload then
    vim.fn.writefile({ payload }, preview_focus_file)
  end
end

local function configure_preview(id)
  local ok, config = pcall(require, "typst-preview.config")
  if not ok then
    return
  end

  if not config.opts._test_wiki_original_get_main_file then
    config.opts._test_wiki_original_get_main_file = config.opts.get_main_file
    config.opts._test_wiki_original_get_root = config.opts.get_root
  end
  local original_main = config.opts._test_wiki_original_get_main_file
  local original_root = config.opts._test_wiki_original_get_root
  local prefix = root .. "/"

  config.opts.get_main_file = function(path)
    path = vim.fs.normalize(path)
    if path == root or path:sub(1, #prefix) == prefix then
      return focus_main
    end
    return original_main(path)
  end
  config.opts.get_root = function(path)
    path = vim.fs.normalize(path)
    if path == focus_main or path == root or path:sub(1, #prefix) == prefix then
      return root
    end
    return original_root(path)
  end
  config.opts.extra_args = {
    "--input=zk-focus-file=" .. preview_focus_input,
    "--input=zk-repl=true",
  }
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
    typstExtraArgs = {
      "--input=zk-focus-id=" .. id,
      "--input=zk-repl=true",
    },
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

  write_preview_focus(id)
  configure_preview(id)
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

vim.api.nvim_create_autocmd("VimLeavePre", {
  group = group,
  callback = function()
    pcall(vim.fn.delete, preview_focus_file)
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
