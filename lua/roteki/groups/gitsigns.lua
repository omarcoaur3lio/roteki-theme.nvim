local Utils = require("roteki.utils")

local M = {}

---@type roteki.HighlightsFn
function M.get_hl(c)
  -- stylua: ignore
  return {
    GitSignsAdd              = { fg = c.success },
    GitSignsChange           = { fg = c.warning },
    GitSignsDelete           = { fg = c.danger },
    GitSignsAddInline        = { link = "DiffChange" },
    GitSignsChangeInline     = { link = "DiffChange" },
    GitSignsDeleteInline     = { link = "DiffChange" },
    GitSignsCurrentLineBlame = { fg = Utils.blend(c.fg, c.line, 0.4) },
  }
end

return M
