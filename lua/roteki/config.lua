local M = {}

M._version = "0.1.0"

---@type roteki.Config
M.defaults = {
  transparent = false,

  -- Variantes usadas ao alternar por vim.o.background.
  -- Só existe 'dark'; as duas pontas apontam para ela até haver uma variante clara.
  theme = {
    dark = "dark",
    light = "dark",
  },

  styles = {
    functions = { bold = true },
    keywords = { italic = true },
    comments = { italic = true },
    types = { bold = true },
    strings = {},
    constants = {},
  },

  colors = {},
  auto = true,
  cache = true,

  on_highlights = function(highlights, colors) end,
}

---@type roteki.Config
M.options = vim.deepcopy(M.defaults) -- permite omitir a chamada a setup()

---@param opts roteki.Config|nil
---@return roteki.Config
function M.extend(opts)
  return vim.tbl_deep_extend("force", M.defaults, opts or {})
end

---@param opts roteki.Config|nil
function M.setup(opts)
  M.options = M.extend(opts)
end

return M
