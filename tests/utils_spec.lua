local Utils = require("roteki.utils")

describe("Utils.blend", function()
  it("devolve o foreground em alpha=1", function()
    assert.are.equal("#FF0000", Utils.blend("#FF0000", "#0000FF", 1))
  end)

  it("devolve o background em alpha=0", function()
    assert.are.equal("#0000FF", Utils.blend("#FF0000", "#0000FF", 0))
  end)

  it("mistura no ponto médio em alpha=0.5", function()
    -- cada canal = 127.5 -> arredonda para 128 = 0x80
    assert.are.equal("#808080", Utils.blend("#000000", "#FFFFFF", 0.5))
  end)

  it("trata cores idênticas em qualquer alpha", function()
    local color = "#ABCDEF"
    assert.are.equal("#ABCDEF", Utils.blend(color, color, 0))
    assert.are.equal("#ABCDEF", Utils.blend(color, color, 0.5))
    assert.are.equal("#ABCDEF", Utils.blend(color, color, 1))
  end)

  it("devolve sempre uma string hex de 7 caracteres", function()
    local result = Utils.blend("#123456", "#654321", 0.3)
    assert.is_truthy(result:match("^#%x%x%x%x%x%x$"), "Expected '#RRGGBB', got: " .. result)
  end)

  it("aceita hex em caixa alta ou baixa", function()
    assert.are.equal(Utils.blend("#abcdef", "#000000", 0.5), Utils.blend("#ABCDEF", "#000000", 0.5))
  end)
end)

describe("Utils.unpack", function()
  it("achata a tabela style dentro do highlight", function()
    local result = Utils.unpack({ TestGroup = { fg = "#ffffff", style = { bold = true, italic = true } } })

    assert.is_true(result.TestGroup.bold)
    assert.is_true(result.TestGroup.italic)
    assert.is_nil(result.TestGroup.style, "style key should be removed after unpacking")
  end)

  it("deixa highlights sem style intactos", function()
    local result = Utils.unpack({ Plain = { fg = "#aaaaaa", bg = "#000000" } })

    assert.are.equal("#aaaaaa", result.Plain.fg)
    assert.are.equal("#000000", result.Plain.bg)
    assert.is_nil(result.Plain.style)
  end)

  it("trata style vazio", function()
    local result = Utils.unpack({ Empty = { fg = "#111111", style = {} } })

    assert.are.equal("#111111", result.Empty.fg)
    assert.is_nil(result.Empty.style)
  end)

  it("faz o style vencer atributos já presentes", function()
    local result = Utils.unpack({ Overlap = { fg = "#aaaaaa", bold = false, style = { bold = true } } })

    assert.is_true(result.Overlap.bold)
  end)
end)

describe("Utils.resolve", function()
  local Config = require("roteki.config")
  local initial_background = vim.o.background

  before_each(function()
    Config.setup()
  end)

  after_each(function()
    Config.setup()
    vim.o.background = initial_background
  end)

  it("devolve a variante explícita quando informada", function()
    assert.are.equal("dark", Utils.resolve("dark"))
  end)

  it("resolve pelos defaults para 'dark' em qualquer background", function()
    vim.o.background = "dark"
    assert.are.equal("dark", Utils.resolve())

    vim.o.background = "light"
    assert.are.equal("dark", Utils.resolve())
  end)

  it("segue o mapeamento configurado pelo usuário", function()
    Config.setup({ theme = { dark = "dark", light = "solarized" } })

    vim.o.background = "light"
    assert.are.equal("solarized", Utils.resolve())
  end)

  it("cai em vim.o.background quando a config não tem o mapeamento", function()
    Config.setup({ theme = {} })

    vim.o.background = "dark"
    assert.are.equal("dark", Utils.resolve())
  end)
end)
