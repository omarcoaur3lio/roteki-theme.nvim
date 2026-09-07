local M = {}

---@type roteki.HighlightsFn
function M.get_hl(c)
  -- stylua: ignore
  return {
    BlinkCmpLabelMatch = { fg = c.const },
    BlinkCmpLabelDetail = { fg = c.comment },
    BlinkCmpLabelDescription = { fg = c.comment },
    BlinkCmpMenu = { link = "NormalFloat" },
    BlinkCmpMenuBorder = { link = "FloatBorder" },
    BlinkCmpMenuSelection = { link = "PmenuSel" },
    BlinkCmpDoc = { link = "NormalFloat" },
    BlinkCmpDocBorder = { link = "FloatBorder" },
  }
end

return M
