local M = {}

--- Configura o tema. Não aplica: use `vim.cmd("colorscheme roteki")`.
---@param opts roteki.Config|nil
function M.setup(opts)
  require("roteki.config").setup(opts)

  -- Recarrega o colorscheme com :RotekiFetch
  vim.api.nvim_create_user_command("RotekiFetch", function()
    require("roteki.utils").reload()
  end, {})
end

--- Devolve a paleta da variante com os overrides do usuário aplicados
---@param theme string|nil
---@return roteki.Palette
function M.get_palette(theme)
  theme = require("roteki.utils").resolve(theme)
  local config = require("roteki.config")
  local palette = require("roteki.palette." .. theme)

  if config.options.colors and type(config.options.colors) == "table" then
    local colors = config.options.colors[theme] or config.options.colors
    palette = vim.tbl_deep_extend("force", palette, colors)
  end

  return palette
end

--- Mistura duas cores por transparência
---@param foreground string
---@param background string
---@param alpha number Fator de mistura (0 a 1)
---@return string # hex no formato "#RRGGBB"
function M.blend(foreground, background, alpha)
  return require("roteki.utils").blend(foreground, background, alpha)
end

--- Aplica o tema
---@param theme string|nil
function M.load(theme)
  local name = theme and "roteki-" .. theme or "roteki"
  theme = require("roteki.utils").resolve(theme)
  local config = require("roteki.config")
  local groups = require("roteki.groups")
  local palette = M.get_palette(theme)

  -- Zera os highlights para que estilos do tema anterior não vazem
  vim.cmd("hi clear")
  if vim.fn.exists("syntax_on") == 1 then
    vim.cmd("syntax reset")
  end
  vim.g.colors_name = name

  local hl_groups = groups.setup(palette, config.options, theme)

  for group, hl in pairs(hl_groups) do
    vim.api.nvim_set_hl(0, group, hl)
  end
end

return M
