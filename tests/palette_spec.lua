local variants = { "dark" }

-- Toda chave da classe roteki.Palette referenciada pelos arquivos em groups/.
-- Uma chave faltando aqui vira fg/bg nil silencioso em tempo de execução.
local required_keys = {
  "bg", "fg", "dim", "line", "selection", "black",
  "keyword", "type", "operator", "comment", "border",
  "emphasis", "func", "string", "char", "special", "const",
  "highlight", "info", "success", "warning", "danger",
  "green", "orange", "red", "pink", "cyan",
}

describe("Palette integrity:", function()
  it("required_keys cobre as 27 chaves da paleta", function()
    assert.are.equal(27, #required_keys)
  end)

  for _, name in ipairs(variants) do
    describe(name .. ":", function()
      local palette

      before_each(function()
        package.loaded["roteki.palette." .. name] = nil
        palette = require("roteki.palette." .. name)
      end)

      it("exporta uma tabela", function()
        assert.is_table(palette, name .. " palette should return a table")
      end)

      it("não tem chaves além das declaradas", function()
        local allowed = {}
        for _, key in ipairs(required_keys) do
          allowed[key] = true
        end
        for key in pairs(palette) do
          assert.is_true(allowed[key], name .. " palette has an undeclared key: " .. key)
        end
      end)

      for _, key in ipairs(required_keys) do
        it("tem '" .. key .. "' como hex válido", function()
          local value = palette[key]
          assert.is_not_nil(value, name .. " palette is missing key: " .. key)
          assert.is_truthy(
            tostring(value):match("^#%x%x%x%x%x%x$"),
            name .. "." .. key .. " is not a valid hex color: " .. tostring(value)
          )
        end)
      end
    end)
  end
end)
