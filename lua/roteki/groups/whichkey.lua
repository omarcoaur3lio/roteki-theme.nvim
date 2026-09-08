local M = {}

---@type roteki.HighlightsFn
function M.get_hl(c, opts)
  return {
    WhichKeyNormal = { bg = c.bg },
    WhichKeyBorder = { fg = c.border, bg = c.bg },
    WhichKey          = { fg = c.keyword },
    WhichKeyGroup     = { fg = c.emphasis },
    WhichKeyDesc      = { fg = c.dim },
    WhichKeySeparator = { fg = c.dim },
    WhichKeyValue     = { fg = c.fg },
  }
end

return M
