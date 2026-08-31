local Roteki = require("roteki")
local Config = require("roteki.config")
local Utils = require("roteki.utils")

describe("The colorscheme should", function()
  before_each(function()
    Config.setup()
    Utils.cache.clear()
    require("roteki.groups")._mem_cache = {}
  end)

  it("carregar sem erros", function()
    local ok, err = pcall(vim.cmd, "colorscheme roteki")

    assert.is_true(ok, "Colorscheme failed to load: " .. tostring(err))
  end)

  it("definir vim.g.colors_name", function()
    vim.cmd("colorscheme roteki")
    assert.are.equal("roteki", vim.g.colors_name)

    vim.cmd("colorscheme roteki-dark")
    assert.are.equal("roteki-dark", vim.g.colors_name)
  end)

  it("aplicar highlights no grupo Normal", function()
    vim.cmd("colorscheme roteki")
    local hl = vim.api.nvim_get_hl(0, { name = "Normal" })

    assert.is_not_nil(hl.fg, "Normal foreground should not be nil")
    assert.is_not_nil(hl.bg, "Normal background should not be nil")
    assert.are.equal(Roteki.get_palette("dark").bg, string.format("#%06x", hl.bg))
  end)

  it("aplicar o teal da seleção no Visual", function()
    vim.cmd("colorscheme roteki")
    local hl = vim.api.nvim_get_hl(0, { name = "Visual" })

    assert.are.equal(Roteki.get_palette("dark").selection, string.format("#%06x", hl.bg))
  end)

  it("gerar um arquivo de cache", function()
    vim.cmd("colorscheme roteki")
    local cache = Utils.cache.file(Utils.resolve())

    assert.is_truthy(vim.uv.fs_stat(cache), "Cache file was not created at " .. cache)
  end)

  it("manter a variante dark nos dois valores de background", function()
    local initial = vim.o.background

    for _, background in ipairs({ "dark", "light" }) do
      vim.o.background = background
      vim.cmd("colorscheme roteki")
      local hl = vim.api.nvim_get_hl(0, { name = "Normal" })

      assert.are.equal(
        Roteki.get_palette("dark").bg,
        string.format("#%06x", hl.bg),
        "background=" .. background .. " should still resolve to the dark variant"
      )
    end

    vim.o.background = initial
  end)

  it("expor blend na API pública", function()
    assert.are.equal("#808080", Roteki.blend("#000000", "#FFFFFF", 0.5))
  end)

  it("registrar :RotekiFetch no setup", function()
    Roteki.setup()
    assert.is_not_nil(vim.fn.getcompletion("RotekiFetch", "command")[1], ":RotekiFetch was not registered")
  end)

  it("registrar :RotekiFetch ao carregar sem chamar setup (Finding 4)", function()
    pcall(vim.api.nvim_del_user_command, "RotekiFetch")
    assert.is_nil(vim.fn.getcompletion("RotekiFetch", "command")[1], "test precondition failed: command still registered")

    vim.cmd("colorscheme roteki")

    assert.is_not_nil(
      vim.fn.getcompletion("RotekiFetch", "command")[1],
      ":RotekiFetch should exist after colorscheme roteki even without calling setup()"
    )
  end)
end)
