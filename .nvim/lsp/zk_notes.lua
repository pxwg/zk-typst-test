local source = debug.getinfo(1, "S").source
local config_dir = vim.fs.dirname(vim.fs.normalize(source:sub(2)))
local project_root = vim.fs.dirname(vim.fs.dirname(config_dir))

return {
  cmd = require("test_wiki.lsp").command(project_root),
  filetypes = { "typst" },
  -- The server coalesces edits before evaluation; do not delay document sync too.
  flags = { debounce_text_changes = 0 },
  root_dir = project_root,
  single_file_support = false,
}
