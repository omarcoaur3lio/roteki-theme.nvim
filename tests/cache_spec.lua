local Utils = require("roteki.utils")

describe("Cache operations", function()
  before_each(function()
    Utils.cache.clear()
  end)

  after_each(function()
    Utils.cache.clear()
  end)

  it("relê o que foi escrito, sem alteração", function()
    local mock_data = {
      groups = { Normal = { fg = "#ffffff", bg = "#000000" } },
      config = { version = "0.1.0", plugins = {} },
    }

    Utils.cache.write("test-key", mock_data)
    local cached = Utils.cache.read("test-key")

    assert.is_not_nil(cached, "Cache read returned nil")
    assert.are.same(mock_data, cached, "Cached data does not match the written data")
  end)

  it("devolve nil para chave inexistente", function()
    assert.is_nil(Utils.cache.read("not-a-cache-file"))
  end)

  it("grava dentro de stdpath('cache') com o prefixo roteki-", function()
    local path = Utils.cache.file("dark")

    assert.is_truthy(path:find(vim.fn.stdpath("cache"), 1, true), "cache file should live in stdpath('cache')")
    assert.is_truthy(path:match("roteki%-dark%.json$"), "unexpected cache filename: " .. path)
  end)

  it("remove todas as entradas no clear", function()
    Utils.cache.write("dummy-key-1", { foo = "bar" })
    Utils.cache.write("dummy-key-2", { fizz = "buzz" })

    assert.is_not_nil(Utils.cache.read("dummy-key-1"))
    assert.is_not_nil(Utils.cache.read("dummy-key-2"))

    Utils.cache.clear()

    assert.is_nil(Utils.cache.read("dummy-key-1"), "Cache 1 was not cleared")
    assert.is_nil(Utils.cache.read("dummy-key-2"), "Cache 2 was not cleared")
  end)
end)

describe("Cache invalidation", function()
  local Config = require("roteki.config")
  local Groups = require("roteki.groups")

  before_each(function()
    Utils.cache.clear()
    Groups._mem_cache = {}
    Config.setup()
  end)

  after_each(function()
    Utils.cache.clear()
    Groups._mem_cache = {}
    Config.setup()
  end)

  it("regenera o cache quando a paleta muda", function()
    local palette = vim.deepcopy(require("roteki.palette.dark"))
    local opts = Config.extend({ cache = true, auto = false })

    Groups.setup(palette, opts, "dark")
    local before = Utils.cache.read("dark")
    assert.is_not_nil(before, "initial cache should be created")
    assert.are.equal(palette.bg, before.groups.Normal.bg)

    palette.bg = "#123456"
    Groups.setup(palette, opts, "dark")
    local after = Utils.cache.read("dark")

    assert.are_not.same(before.config.palette, after.config.palette, "palette fingerprint did not update")
    assert.are.equal("#123456", after.groups.Normal.bg, "highlights were served stale from cache")
  end)

  it("regenera o cache quando os styles mudam", function()
    local palette = require("roteki.palette.dark")

    Groups.setup(palette, Config.extend({ cache = true, auto = false }), "dark")
    local before = Utils.cache.read("dark")

    Groups.setup(palette, Config.extend({ cache = true, auto = false, styles = { comments = { italic = false } } }), "dark")
    local after = Utils.cache.read("dark")

    assert.are_not.same(before.config.opts.styles, after.config.opts.styles, "styles fingerprint did not update")
  end)

  it("não grava nada quando cache=false", function()
    Groups.setup(require("roteki.palette.dark"), Config.extend({ cache = false, auto = false }), "dark")

    assert.is_nil(Utils.cache.read("dark"), "no cache file should be written when cache=false")
  end)
end)

describe("on_highlights x cache (Finding 1)", function()
  local Config = require("roteki.config")
  local Groups = require("roteki.groups")

  before_each(function()
    Utils.cache.clear()
    Groups._mem_cache = {}
    Config.setup()
  end)

  after_each(function()
    Utils.cache.clear()
    Groups._mem_cache = {}
    Config.setup()
  end)

  it("não acumula mutações do hook entre cargas com cache=true", function()
    local colors = require("roteki.palette.dark")
    local opts = Config.extend({
      cache = true,
      auto = false,
      on_highlights = function(hl, c)
        hl.Comment.fg = Utils.blend(hl.Comment.fg, c.bg, 0.5)
      end,
    })

    local hl1 = Groups.setup(colors, opts, "dark")
    local first = hl1.Comment.fg

    local hl2 = Groups.setup(colors, opts, "dark")
    local second = hl2.Comment.fg

    local hl3 = Groups.setup(colors, opts, "dark")
    local third = hl3.Comment.fg

    assert.are.equal(first, second, "on_highlights compounded on load #2")
    assert.are.equal(second, third, "on_highlights compounded on load #3")
  end)

  it("não deixa valor de um hook antigo vazar quando o novo hook para de tocar o grupo", function()
    local colors = require("roteki.palette.dark")
    local default_comment = colors.comment

    local hl1 = Groups.setup(colors, Config.extend({
      cache = true,
      auto = false,
      on_highlights = function(hl, _)
        hl.Comment = { fg = "#FF0000" }
      end,
    }), "dark")
    assert.are.equal("#FF0000", hl1.Comment.fg)

    local hl2 = Groups.setup(colors, Config.extend({
      cache = true,
      auto = false,
      on_highlights = function(hl, _)
        hl.Title = { fg = "#00FF00" }
      end,
    }), "dark")

    assert.are.equal(default_comment, hl2.Comment.fg, "stale on_highlights mutation from a previous hook leaked into this load")
  end)
end)

describe("Corrupt cache recovery (Finding 3)", function()
  local Config = require("roteki.config")
  local Groups = require("roteki.groups")

  before_each(function()
    Utils.cache.clear()
    Groups._mem_cache = {}
  end)

  after_each(function()
    Utils.cache.clear()
    Groups._mem_cache = {}
  end)

  it("Utils.cache.read devolve nil quando o JSON decodifica para um escalar", function()
    Utils.write(Utils.cache.file("dark"), "123")

    assert.is_nil(Utils.cache.read("dark"), "a bare scalar should not be treated as valid cache data")
  end)

  it("Groups.setup não lança e regenera quando config.opts está ausente no cache", function()
    Utils.write(Utils.cache.file("dark"), vim.json.encode({ groups = {}, config = { version = Config._version } }))

    local colors = require("roteki.palette.dark")
    local ok, hl = pcall(Groups.setup, colors, Config.extend({ cache = true, auto = false }), "dark")

    assert.is_true(ok, "Groups.setup should not throw on a malformed cache shape: " .. tostring(hl))
    assert.is_not_nil(hl.Normal, "highlights should have been regenerated, not served broken")
  end)
end)

describe("Fingerprint aliasing on opts (Finding 5)", function()
  local Config = require("roteki.config")
  local Groups = require("roteki.groups")

  before_each(function()
    Utils.cache.clear()
    Groups._mem_cache = {}
  end)

  after_each(function()
    Utils.cache.clear()
    Groups._mem_cache = {}
  end)

  it("detecta mudança de styles feita in-place no mesmo opts entre cargas", function()
    local colors = require("roteki.palette.dark")
    local opts = Config.extend({ cache = true, auto = false })

    local hl1 = Groups.setup(colors, opts, "dark")
    assert.is_true(hl1.Keyword.italic, "sanity check: default styles.keywords.italic should be true")

    -- Muta o MESMO objeto que foi usado como fonte da fingerprint, sem chamar Config.setup de novo
    opts.styles.keywords.italic = false

    local hl2 = Groups.setup(colors, opts, "dark")

    assert.is_falsy(hl2.Keyword.italic, "in-place mutation of opts.styles was not detected — fingerprint aliased opts")
  end)
end)
