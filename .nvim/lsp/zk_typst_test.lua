local source = debug.getinfo(1, "S").source
local config_dir = vim.fs.dirname(vim.fs.normalize(source:sub(2)))
local project_root = vim.fs.dirname(vim.fs.dirname(config_dir))
local binary = vim.fs.joinpath(project_root, "zk-typst-test", "target", "release", "zk-typst-test")

return {
  cmd = { binary },
  cmd_cwd = project_root,
  filetypes = { "typst" },
  root_dir = project_root,
  single_file_support = false,
}
