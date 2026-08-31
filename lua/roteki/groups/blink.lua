local M = {}

---@type roteki.HighlightsFn
function M.get_hl(c)
  -- stylua: ignore
  return {
    BlinkCmpLabelMatch = { fg = c.const },
  }
end

return M
