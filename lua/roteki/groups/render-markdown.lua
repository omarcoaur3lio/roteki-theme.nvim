local Utils = require("roteki.utils")

local M = {}

---@type roteki.HighlightsFn
function M.get_hl(c)
  local heading = Utils.blend(c.fg, c.bg, 0.1)
  -- stylua: ignore
  return {
    RenderMarkdownCode = { bg = c.line },
    RenderMarkdownH1Bg = { bg = heading },
    RenderMarkdownH2Bg = { bg = heading },
    RenderMarkdownH3Bg = { bg = heading },
    RenderMarkdownH4Bg = { bg = heading },
    RenderMarkdownH5Bg = { bg = heading },
    RenderMarkdownH6Bg = { bg = heading },
  }
end

return M
