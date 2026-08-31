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
