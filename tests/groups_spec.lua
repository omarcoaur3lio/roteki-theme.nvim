local Palette = require("roteki.palette.dark")
local Config = require("roteki.config")

describe("Group files", function()
  local opts = Config.extend()

  it("carrega todo arquivo em roteki/groups sem erro de sintaxe", function()
    local files = vim.split(vim.fn.glob("lua/roteki/groups/*.lua"), "\n")
    assert.is_true(#files > 0, "no group files found — is the cwd the repo root?")

    for _, file in ipairs(files) do
      local name = vim.fn.fnamemodify(file, ":t:r")
      if name ~= "init" then
        local ok, mod = pcall(require, "roteki.groups." .. name)

        assert.is_true(ok, "Failed to load file: " .. name)
        assert.is_table(mod, "Module " .. name .. " did not return a table")
        assert.is_function(mod.get_hl, "Module " .. name .. " does not export get_hl")
      end
    end
  end)

  it("devolve highlights sem cor nil", function()
    local files = vim.split(vim.fn.glob("lua/roteki/groups/*.lua"), "\n")

    for _, file in ipairs(files) do
      local name = vim.fn.fnamemodify(file, ":t:r")
      if name ~= "init" then
        local hl = require("roteki.groups." .. name).get_hl(Palette, opts)
        assert.is_table(hl, name .. ".get_hl did not return a table")

        for group, def in pairs(hl) do
          for _, key in ipairs({ "fg", "bg", "sp" }) do
            if def[key] ~= nil then
              assert.is_truthy(
                tostring(def[key]):match("^#%x%x%x%x%x%x$") or def[key] == "none",
                name .. "." .. group .. "." .. key .. " is not a color: " .. tostring(def[key])
              )
            end
          end
        end
      end
    end
  end)

  it("mantém as decisões visuais do roteki em base", function()
    local hl = require("roteki.groups.base").get_hl(Palette, opts)

    assert.are.equal(Palette.selection, hl.Visual.bg, "Visual should use the teal selection")
    assert.are.equal(Palette.selection, hl.PmenuSel.bg)
    assert.are.equal(Palette.line, hl.CursorLine.bg)
    assert.are.equal(Palette.black, hl.StatusLine.bg)
    assert.are.equal(Palette.black, hl.NormalFloat.bg)
    assert.are.equal(Palette.border, hl.FloatBorder.fg)
  end)

  it("zera os fundos quando transparent=true", function()
    local hl = require("roteki.groups.base").get_hl(Palette, Config.extend({ transparent = true }))

    assert.are.equal("none", hl.Normal.bg)
    assert.are.equal("none", hl.NormalFloat.bg)
    assert.are.equal("none", hl.StatusLine.bg)
    assert.are.equal("none", hl.Pmenu.bg)
  end)

  it("propaga styles do config para os grupos de syntax", function()
    local hl = require("roteki.groups.syntax").get_hl(Palette, opts)

    assert.is_true(hl.Function.style.bold)
    assert.is_true(hl.Keyword.style.italic)
    assert.is_true(hl.Comment.style.italic)
    assert.is_true(hl.Type.style.bold, "Type must honour styles.types")
  end)

  it("só dereferencia chaves que existem na paleta", function()
    local files = vim.split(vim.fn.glob("lua/roteki/groups/*.lua"), "\n")

    for _, file in ipairs(files) do
      local name = vim.fn.fnamemodify(file, ":t:r")
      if name ~= "init" then
        local unknown = {}
        local guarded = setmetatable({}, {
          __index = function(_, key)
            table.insert(unknown, tostring(key))
            return nil
          end,
        })
        for k, v in pairs(Palette) do
          rawset(guarded, k, v)
        end

        require("roteki.groups." .. name).get_hl(guarded, opts)

        assert.are.same({}, unknown, name .. " dereferenced palette keys that do not exist: " .. table.concat(unknown, ", "))
      end
    end
  end)
end)

describe("Plugin detection", function()
  local Groups = require("roteki.groups")
  local Utils = require("roteki.utils")
  local colors = require("roteki.palette.dark")
  local original_pack = vim.pack
  local original_minideps = _G.MiniDeps

  before_each(function()
    package.loaded["lazy"] = nil
    package.loaded["lazy.core.config"] = nil
    Groups._mem_cache = {}
    Utils.cache.clear()
  end)

  after_each(function()
    vim.pack = original_pack
    _G.MiniDeps = original_minideps
    package.loaded["lazy"] = nil
    package.loaded["lazy.core.config"] = nil
    Groups._mem_cache = {}
    Utils.cache.clear()
  end)

  it("monta só os grupos core quando nenhuma API de gerenciador está presente", function()
    vim.pack = nil
    _G.MiniDeps = nil

    local _, loaded = Groups.setup(colors, Config.extend({ auto = true, cache = false }), "dark")

    assert.is_true(loaded.base, "base group should be loaded")
    assert.is_true(loaded.syntax)
    assert.is_true(loaded.treesitter)
    assert.is_true(loaded.lsp)
    assert.is_nil(loaded.gitsigns, "gitsigns should NOT be loaded")
  end)

  it("monta só os grupos core quando vim.pack devolve lista vazia", function()
    vim.pack = { get = function() return {} end }
    _G.MiniDeps = nil

    local _, loaded = Groups.setup(colors, Config.extend({ auto = true, cache = false }), "dark")

    assert.is_true(loaded.base)
    assert.is_nil(loaded.gitsigns, "gitsigns should NOT be loaded")
  end)

  it("monta todos os plugins quando auto=false", function()
    local _, loaded = Groups.setup(colors, Config.extend({ auto = false, cache = false }), "dark")

    assert.is_true(loaded.telescope, "Telescope should be loaded")
    assert.is_true(loaded.blink, "Blink should be loaded")
    assert.is_true(loaded.snacks)
  end)

  it("respeita a detecção do lazy.nvim", function()
    vim.pack = nil
    _G.MiniDeps = nil
    package.loaded.lazy = true
    package.loaded["lazy.core.config"] = {
      plugins = { ["telescope.nvim"] = { name = "telescope.nvim" } },
    }

    local _, loaded = Groups.setup(colors, Config.extend({ auto = true, cache = false }), "dark")

    assert.is_true(loaded.telescope, "Telescope should be loaded")
    assert.is_nil(loaded.blink, "Blink should NOT be loaded")
  end)

  it("respeita a detecção do vim.pack", function()
    _G.MiniDeps = nil
    vim.pack = {
      get = function()
        return { { active = true, spec = { name = "blink.cmp" } } }
      end,
    }

    local _, loaded = Groups.setup(colors, Config.extend({ auto = true, cache = false }), "dark")

    assert.is_true(loaded.blink, "Blink should be loaded via vim.pack")
    assert.is_nil(loaded.telescope, "Telescope should NOT be loaded")
  end)

  it("detecta módulos mini.* avulsos", function()
    vim.pack = nil
    _G.MiniDeps = nil
    package.loaded.lazy = true
    package.loaded["lazy.core.config"] = {
      plugins = { ["mini.pick"] = { name = "mini.pick" } },
    }

    local _, loaded = Groups.setup(colors, Config.extend({ auto = true, cache = false }), "dark")

    assert.is_true(loaded.mini, "standalone mini.* modules should enable the mini group")
  end)

  it("todo valor de Groups.plugins tem um arquivo correspondente", function()
    for plugin, group in pairs(Groups.plugins) do
      local ok = pcall(require, "roteki.groups." .. group)
      assert.is_true(ok, "plugin '" .. plugin .. "' maps to missing group file: " .. group)
    end
  end)
end)
