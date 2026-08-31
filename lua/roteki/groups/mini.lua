local M = {}

---@type roteki.HighlightsFn
function M.get_hl(c)
  -- stylua: ignore
  return {
    MiniPickMatchRanges      = { fg = c.const },
    MiniStatuslineModeNormal = { fg = c.bg, bg = c.fg },
    MiniJump2dSpot           = { fg = c.fg, bg = c.line, bold = true },
    MiniIconsGrey            = { fg = c.fg },
    MiniIconsAzure           = { fg = c.emphasis },
    MiniIconsBlue            = { fg = c.info },
    MiniIconsCyan            = { fg = c.cyan },
    MiniIconsGreen           = { fg = c.success },
    MiniIconsOrange          = { fg = c.orange },
    MiniIconsPurple          = { fg = c.pink },
    MiniIconsRed             = { fg = c.danger },
    MiniIconsYellow          = { fg = c.warning },
  }
end

return M
