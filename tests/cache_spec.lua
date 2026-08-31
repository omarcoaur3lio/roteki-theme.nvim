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
