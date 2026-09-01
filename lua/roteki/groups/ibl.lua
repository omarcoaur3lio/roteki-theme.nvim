local M = {}

---@type roteki.HighlightsFn
function M.get_hl(c)
  -- stylua: ignore
  return {
    IblIndent = { fg = c.border },
    IblScope  = { fg = c.comment },
  }
end

return M
