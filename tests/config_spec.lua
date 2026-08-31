local Config = require("roteki.config")

describe("Config.extend", function()
  it("devolve os defaults sem argumento", function()
    assert.are.same(Config.defaults, Config.extend())
  end)

  it("devolve os defaults com tabela vazia", function()
    assert.are.same(Config.defaults, Config.extend({}))
  end)

  it("faz deep-merge das opções do usuário sobre os defaults", function()
    local result = Config.extend({
      transparent = true,
      styles = { keywords = { underline = true } },
    })

    assert.is_true(result.transparent)
    assert.is_true(result.styles.keywords.underline)
    assert.is_true(result.styles.functions.bold, "functions.bold default should be preserved")
    assert.is_true(result.styles.types.bold, "types.bold default should be preserved")
  end)

  it("não muta a tabela de defaults", function()
    local original = Config.defaults.transparent
    Config.extend({ transparent = true })

    assert.are.equal(original, Config.defaults.transparent)
  end)
end)

describe("Config.setup", function()
  after_each(function()
    Config.setup()
  end)

  it("atualiza options com a config do usuário", function()
    Config.setup({ transparent = true })
    assert.is_true(Config.options.transparent)
  end)

  it("volta aos defaults quando chamado sem argumento", function()
    Config.setup({ transparent = true })
    Config.setup()
    assert.is_false(Config.options.transparent)
  end)
end)

describe("Config defaults", function()
  it("tem uma versão semver", function()
    assert.is_string(Config._version)
    assert.is_truthy(Config._version:match("^%d+%.%d+%.%d+$"), "Version should be semver: " .. Config._version)
  end)

  it("traz os valores default esperados", function()
    local d = Config.defaults

    assert.is_false(d.transparent)
    assert.is_true(d.auto)
    assert.is_true(d.cache)
    assert.is_function(d.on_highlights)
    assert.are.same({}, d.colors)
  end)

  it("aponta as duas pontas de theme para 'dark', a única variante existente", function()
    assert.are.equal("dark", Config.defaults.theme.dark)
    assert.are.equal("dark", Config.defaults.theme.light)
  end)

  it("preserva as decisões visuais atuais do roteki em styles", function()
    local s = Config.defaults.styles

    assert.is_true(s.functions.bold)
    assert.is_true(s.keywords.italic)
    assert.is_true(s.comments.italic)
    assert.is_true(s.types.bold)
    assert.are.same({}, s.strings, "strings should carry no style (italic was reverted in cca6d98)")
    assert.are.same({}, s.constants)
  end)
end)

describe("on_highlights callback", function()
  after_each(function()
    Config.setup()
  end)

  it("recebe highlights e paleta", function()
    local captured_hl, captured_colors

    Config.setup({
      cache = false,
      on_highlights = function(highlights, colors)
        captured_hl = highlights
        captured_colors = colors
      end,
    })
    vim.cmd("colorscheme roteki")

    assert.is_table(captured_hl, "on_highlights should receive the highlights table")
    assert.is_table(captured_colors, "on_highlights should receive the palette")
    assert.is_not_nil(captured_hl.Normal, "highlights should contain Normal")
    assert.is_not_nil(captured_colors.bg, "palette should contain bg")
  end)

  it("aplica as mutações feitas no callback", function()
    Config.setup({
      cache = false,
      on_highlights = function(highlights, _)
        highlights.Normal = { fg = "#FF00FF", bg = "#00FF00" }
      end,
    })
    vim.cmd("colorscheme roteki")

    local hl = vim.api.nvim_get_hl(0, { name = "Normal" })

    assert.are.equal(0xFF00FF, hl.fg)
    assert.are.equal(0x00FF00, hl.bg)
  end)

  it("aceita style no callback sem quebrar o colorscheme (Finding 2)", function()
    Config.setup({
      cache = false,
      on_highlights = function(highlights, colors)
        highlights.RotekiTestStyle = { fg = colors.fg, style = { bold = true } }
      end,
    })

    local ok, err = pcall(vim.cmd, "colorscheme roteki")
    assert.is_true(ok, "colorscheme should not fail when on_highlights sets style: " .. tostring(err))

    local hl = vim.api.nvim_get_hl(0, { name = "RotekiTestStyle" })
    assert.is_true(hl.bold, "style.bold set by on_highlights should have been applied")
  end)
end)

describe("Color overrides via get_palette", function()
  local Roteki = require("roteki")

  after_each(function()
    Config.setup()
  end)

  it("aplica overrides globais na paleta", function()
    Config.setup({ colors = { bg = "#111111", fg = "#eeeeee" } })

    local palette = Roteki.get_palette("dark")

    assert.are.equal("#111111", palette.bg)
    assert.are.equal("#eeeeee", palette.fg)
  end)

  it("aplica overrides por variante", function()
    Config.setup({ colors = { dark = { border = "#000000" } } })

    assert.are.equal("#000000", Roteki.get_palette("dark").border)
  end)

  it("preserva as cores não sobrescritas", function()
    local original = Roteki.get_palette("dark")
    local original_keyword = original.keyword

    Config.setup({ colors = { bg = "#111111" } })
    local modified = Roteki.get_palette("dark")

    assert.are.equal("#111111", modified.bg)
    assert.are.equal(original_keyword, modified.keyword, "keyword should be unchanged")
  end)
end)

describe("Transparent mode", function()
  after_each(function()
    Config.setup()
  end)

  it("deixa o fundo de Normal vazio quando transparent=true", function()
    Config.setup({ transparent = true, cache = false })
    vim.cmd("colorscheme roteki")

    local hl = vim.api.nvim_get_hl(0, { name = "Normal" })

    -- Com bg = "none", nvim_get_hl não devolve a chave bg
    assert.is_nil(hl.bg, "Normal bg should be nil (transparent)")
  end)

  it("define um fundo concreto quando transparent=false", function()
    Config.setup({ transparent = false, cache = false })
    vim.cmd("colorscheme roteki")

    assert.is_not_nil(vim.api.nvim_get_hl(0, { name = "Normal" }).bg, "Normal bg should be set")
  end)
end)
