local M = {}

M.resolve_bufnr = function(bufnr)
  vim.validate { bufnr = { bufnr, 'n', true } }
  if bufnr == nil or bufnr == 0 then
    return vim.api.nvim_get_current_buf()
  end
  return bufnr
end

return M
