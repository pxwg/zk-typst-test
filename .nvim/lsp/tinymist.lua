local source = debug.getinfo(1, "S").source
local config_dir = vim.fs.dirname(vim.fs.normalize(source:sub(2)))
local project_root = vim.fs.dirname(vim.fs.dirname(config_dir))
local adapter = require("test_wiki.tinymist_adapter")

return {
  cmd = adapter.command({ "tinymist" }, project_root),
}
