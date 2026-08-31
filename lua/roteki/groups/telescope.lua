local M = {}

---@type roteki.HighlightsFn
function M.get_hl(c, opts)
  local bg = opts.transparent and "none" or c.bg
  -- stylua: ignore
  return {
    TelescopeBorder        = { fg = c.border, bg = bg },
    TelescopePromptBorder  = { link = "TelescopeBorder" },
    TelescopeResultsBorder = { link = "TelescopeBorder" },
    TelescopePreviewBorder = { link = "TelescopeBorder" },
    TelescopeTitle         = { fg = c.emphasis, bold = true },
    TelescopePromptTitle   = { link = "TelescopeTitle" },
    TelescopeResultsTitle  = { link = "TelescopeTitle" },
    TelescopePreviewTitle  = { link = "TelescopeTitle" },
    TelescopePromptPrefix  = { fg = c.emphasis, bold = true },
    TelescopeSelection     = { bg = c.selection },
    TelescopeMatching      = { fg = c.const, bold = true },
  }
end

return M
