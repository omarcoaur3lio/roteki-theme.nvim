local Utils = require("roteki.utils")
local Config = require("roteki.config")

local M = {}

M._mem_cache = {}

-- stylua: ignore
M.plugins = {
  ["blink.cmp"]               = "blink",
  ["dashboard-nvim"]          = "dashboard",
  ["flash.nvim"]              = "flash",
  ["fzf-lua"]                 = "fzf",
  ["gitsigns.nvim"]           = "gitsigns",
  ["mason.nvim"]              = "mason",
  ["mini.nvim"]               = "mini",
  ["modes.nvim"]              = "modes",
  ["neo-tree.nvim"]           = "neotree",
  ["oil.nvim"]                = "oil",
  ["rainbow-delimiters.nvim"] = "rainbow-delimiters",
  ["render-markdown.nvim"]    = "render-markdown",
  ["snacks.nvim"]             = "snacks",
  ["telescope.nvim"]          = "telescope",
  ["trouble.nvim"]            = "trouble",
}

--- Devolve os highlights de um grupo específico
---@param name string
---@param colors roteki.Palette
---@param opts roteki.Config
---@return roteki.Highlights
function M.get_highlights(name, colors, opts)
  return require("roteki.groups." .. name).get_hl(colors, opts)
end

--- Monta (ou lê do cache) o conjunto completo de highlights
---@param colors roteki.Palette
---@param opts roteki.Config
---@param theme string|nil
---@return roteki.Highlights
---@return table<string, boolean> # conjunto de grupos montados, usado nos testes
function M.setup(colors, opts, theme)
  -- Os grupos core são sempre montados
  local groups = {
    base = true,
    syntax = true,
    treesitter = true,
    lsp = true,
  }

  -- Highlights de plugin só para os que o gerenciador conhece.
  -- Suporta lazy.nvim, vim.pack e mini.deps. Com `auto = false`, monta todos.
  if not opts.auto then
    for _, group in pairs(M.plugins) do
      groups[group] = true
    end
  else
    if package.loaded.lazy then
      local lazy_plugins = require("lazy.core.config").plugins
      for plugin, group in pairs(M.plugins) do
        if lazy_plugins[plugin] then
          groups[group] = true
        end
      end
      if not groups.mini then -- módulos mini.* avulsos
        for plugin_name, _ in pairs(lazy_plugins) do
          if plugin_name:match("^mini%.") then
            groups.mini = true
            break
          end
        end
      end
    end
    if vim.pack then
      local ok, packdata = pcall(vim.pack.get, nil, { info = false })
      if ok and packdata then
        for _, plugin in ipairs(packdata) do
          local group = M.plugins[plugin.spec.name]
          if group then
            groups[group] = true
          end
          if not groups.mini and plugin.spec.name:match("^mini%.") then
            groups.mini = true
          end
        end
      end
    end
    if _G.MiniDeps then
      for _, plugin in ipairs(_G.MiniDeps.get_session()) do
        if M.plugins[plugin.name] then
          groups[M.plugins[plugin.name]] = true
        end
        if not groups.mini and plugin.name:match("^mini%.") then
          groups.mini = true
        end
      end
    end
  end

  -- Ordena os nomes para que a chave de cache seja estável
  local names = vim.tbl_keys(groups)
  table.sort(names)

  -- Impressão digital do cache. `palette` é um desvio deliberado do koda:
  -- sem ela, editar lua/roteki/palette/*.lua serviria highlights velhos do
  -- cache até alguém rodar :RotekiFetch.
  local config = {
    plugins = names,
    version = Config._version,
    palette = colors,
    opts = {
      styles = opts.styles,
      colors = opts.colors,
      transparent = opts.transparent,
    },
  }

  local function cache_valid(c)
    return c
      and c.version == config.version
      and c.opts.transparent == config.opts.transparent
      and vim.deep_equal(c.plugins, config.plugins)
      and vim.deep_equal(c.palette, config.palette)
      and vim.deep_equal(c.opts.styles, config.opts.styles)
      and vim.deep_equal(c.opts.colors, config.opts.colors)
  end

  local cache_key = theme or vim.o.background
  local hl

  -- Cache em memória primeiro
  local mem = M._mem_cache[cache_key]
  if mem and cache_valid(mem.config) then
    hl = mem.groups
  end

  -- Depois o cache em disco
  if not hl then
    local cache = opts.cache and Utils.cache.read(cache_key)
    hl = cache and cache_valid(cache.config) and cache.groups
    if hl then
      M._mem_cache[cache_key] = { groups = hl, config = config }
    end
  end

  -- Cache miss: monta do zero
  if not hl then
    hl = {}
    for group in pairs(groups) do
      for k, v in pairs(M.get_highlights(group, colors, opts)) do
        hl[k] = v
      end
    end
    Utils.unpack(hl)
    if opts.cache then
      Utils.cache.write(cache_key, { groups = hl, config = config })
      M._mem_cache[cache_key] = { groups = hl, config = config }
    end
  end

  opts.on_highlights(hl, colors)

  return hl, groups
end

return M
