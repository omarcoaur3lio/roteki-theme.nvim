# Roteki koda-based Architecture Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Reestruturar o roteki.nvim de uma tabela única de highlights hardcoded para a arquitetura em camadas do koda.nvim, preservando a paleta de cores do roteki e deixando o suporte a variantes pronto.

**Architecture:** Paleta puramente semântica (27 chaves) em `lua/roteki/palette/<variante>.lua`, consumida por arquivos de grupo em `lua/roteki/groups/` que exportam `get_hl(colors, opts)`. `groups/init.lua` orquestra: monta os grupos core sempre, os de plugin só para plugins instalados, e serializa o resultado num cache em disco cuja impressão digital inclui a paleta. `lua/roteki/init.lua` expõe a API pública; os arquivos em `colors/` são entrypoints de uma linha.

**Tech Stack:** Lua, Neovim ≥ 0.10, plenary.nvim (só para testes), GitHub Actions.

**Spec:** `docs/superpowers/specs/2026-08-30-roteki-koda-architecture-design.md`

## Global Constraints

- **Neovim floor: 0.10.** O código usa `vim.uv`, `vim.fs.joinpath` e `vim.fs.dirname`. O acesso a `vim.pack` (0.12) é sempre guardado por `if vim.pack then`.
- **Zero dependências de runtime.** O plenary é usado apenas em `tests/` e fica em `pack/vendor/start/`, que é gitignored.
- **Prefixo de módulo:** `roteki.*`. Prefixo de arquivo de cache: `roteki-<variante>.json` em `vim.fn.stdpath("cache")`.
- **A paleta tem exatamente 27 chaves**, listadas na Task 2. Toda variante futura deve ter as mesmas 27.
- **Nenhum literal de cor fora de `lua/roteki/palette/`.** Grupos usam chaves da paleta ou `Utils.blend`.
- **Anotações LuaCATS** com os tipos de `lua/roteki/types.lua` em toda função pública.
- **`-- stylua: ignore`** antes de cada tabela de highlights, para preservar o alinhamento em colunas.
- Comandos de teste rodam a partir da raiz do repositório.

---

### Task 1: Limpeza do repositório e infraestrutura de testes

Remove o lixo versionado, cria o `.gitignore` e deixa o plenary disponível para as tasks seguintes. Nada aqui depende do resto do plano, e nenhuma task seguinte roda testes sem isto.

**Files:**
- Delete: `\` (arquivo órfão na raiz), `.DS_Store`, `lua/.DS_Store`
- Create: `.gitignore`
- Create: `tests/init.lua`

**Interfaces:**
- Consumes: nada
- Produces: `tests/init.lua`, usado por todo comando de teste das tasks seguintes como `-u tests/init.lua`

- [ ] **Step 1: Remover os arquivos lixo**

O arquivo `\` está versionado; os dois `.DS_Store` não estão (nunca foram commitados), então basta apagá-los do disco.

```bash
git rm -f '\'
rm -f .DS_Store lua/.DS_Store
```

O arquivo `\` é uma cópia órfã da paleta antiga (com `light_blue = "#A2AABD"`, valor que nem é o atual). Nada o referencia. Confirme com `git ls-files` que ele saiu do índice.

- [ ] **Step 2: Criar o `.gitignore`**

```gitignore
.DS_Store
pack/
```

- [ ] **Step 3: Criar o `tests/init.lua`**

`PlenaryBustedDirectory` já injeta `set rtp+=.` nos processos filhos, mas acrescentar a raiz aqui permite rodar um spec isolado com `-u tests/init.lua`.

```lua
local root = vim.fn.fnamemodify(".", ":p")

vim.opt.runtimepath:append(root)

local plenary_path = root .. "pack/vendor/start/plenary.nvim"
if vim.uv.fs_stat(plenary_path) then
  vim.opt.runtimepath:append(plenary_path)
end
```

- [ ] **Step 4: Instalar o plenary localmente**

```bash
mkdir -p pack/vendor/start
git clone --depth 1 https://github.com/nvim-lua/plenary.nvim pack/vendor/start/plenary.nvim
```

- [ ] **Step 5: Verificar que o runner sobe**

Run: `nvim --headless -u tests/init.lua -c "lua print('plenary:', pcall(require, 'plenary.busted'))" -c "qa!"`
Expected: imprime `plenary: true` (seguido de uma tabela). Se imprimir `false`, o clone do Step 4 falhou.

- [ ] **Step 6: Commit**

```bash
git add -A .gitignore tests/init.lua
git status --short   # deve mostrar D "\\", A .gitignore, A tests/init.lua
git commit -m "chore: add gitignore and test harness, drop stray files"
```

---

### Task 2: Tipos e paleta

Primeiro par de arquivos da nova arquitetura. O `palette_spec` vem antes da paleta e é a rede que protege toda variante futura.

**Files:**
- Create: `lua/roteki/types.lua`
- Create: `lua/roteki/palette/dark.lua`
- Test: `tests/palette_spec.lua`

**Interfaces:**
- Consumes: `tests/init.lua` (Task 1)
- Produces:
  - `require("roteki.palette.dark") -> roteki.Palette` — tabela de 27 chaves `string -> string` (hex `#RRGGBB`)
  - Classes LuaCATS: `roteki.Palette`, `roteki.Config`, `roteki.Highlight`, `roteki.Highlights`, `roteki.HighlightsFn`, `roteki.Cache`

- [ ] **Step 1: Escrever o teste que falha**

Crie `tests/palette_spec.lua`. O array `variants` é o único ponto a editar quando uma variante nova for adicionada.

```lua
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
```

- [ ] **Step 2: Rodar o teste e confirmar que falha**

Run: `nvim --headless -u tests/init.lua -c "PlenaryBustedFile tests/palette_spec.lua" -c "qa!"`
Expected: FAIL — `module 'roteki.palette.dark' not found`

- [ ] **Step 3: Escrever `lua/roteki/types.lua`**

```lua
---@class roteki.Highlight: vim.api.keyset.highlight
---@field style? vim.api.keyset.highlight

---@alias roteki.Highlights table<string, roteki.Highlight>
--- Valores devem ser uma tabela roteki.Highlight.
--- Para linkar em outro grupo, use a propriedade `link`: { link = "Normal" }

---@alias roteki.HighlightsFn fun(colors: roteki.Palette, opts: roteki.Config): roteki.Highlights
--- Recebe paleta e config, devolve definições de highlight

---@class roteki.Cache
--- Dados do colorscheme cacheados em stdpath("cache")
---@field groups roteki.Highlights Grupos compilados
---@field config table Impressão digital usada para invalidação

---@class roteki.Palette
--- Paleta de cores com nomes semânticos
---@field bg string?
---@field fg string?
---@field dim string?
---@field line string?
---@field selection string?
---@field black string?
---@field keyword string?
---@field type string?
---@field operator string?
---@field comment string?
---@field border string?
---@field emphasis string?
---@field func string?
---@field string string?
---@field char string?
---@field special string?
---@field const string?
---@field highlight string?
---@field info string?
---@field success string?
---@field warning string?
---@field danger string?
---@field green string?
---@field orange string?
---@field red string?
---@field pink string?
---@field cyan string?

---@class roteki.Config
--- Opções de configuração do usuário
---@field transparent? boolean
---@field theme? table<"dark"|"light", string>
---@field cache? boolean
---@field styles? table<string, vim.api.keyset.highlight>
---@field colors? table<string, string> | table<"dark", table<string, string>>
---@field auto? boolean
---@field on_highlights? fun(highlights: roteki.Highlights, colors: roteki.Palette)
```

- [ ] **Step 4: Escrever `lua/roteki/palette/dark.lua`**

```lua
-- stylua: ignore
---@class roteki.Palette
local palette = {
  bg        = "#151718",
  fg        = "#d0d3d6",
  dim       = "#7E8B96",
  line      = "#232628",
  selection = "#265457",
  black     = "#090909",
  keyword   = "#3ab877",
  type      = "#eff1f5",
  operator  = "#d0d3d6",
  comment   = "#3c4349",
  border    = "#3e424b",
  emphasis  = "#BCD1FF",
  func      = "#BCD1FF",
  string    = "#AFD8ED",
  char      = "#AFD8ED",
  special   = "#AFD8ED",
  const     = "#deb4f8",
  highlight = "#BCD1FF",
  info      = "#90DFFF",
  success   = "#3ab877",
  warning   = "#e3c76a",
  danger    = "#c2606d",
  green     = "#3ab877",
  orange    = "#e08d1f",
  red       = "#c2606d",
  pink      = "#aa39a8",
  cyan      = "#90DFFF",
}

return palette
```

- [ ] **Step 5: Rodar o teste e confirmar que passa**

Run: `nvim --headless -u tests/init.lua -c "PlenaryBustedFile tests/palette_spec.lua" -c "qa!"`
Expected: PASS — 30 sucessos, 0 falhas

- [ ] **Step 6: Commit**

```bash
git add lua/roteki/types.lua lua/roteki/palette/dark.lua tests/palette_spec.lua
git commit -m "feat: add semantic palette and LuaCATS types"
```

---

### Task 3: Utils

Blend de cores, cache em disco, unpack de styles e resolução de variante. Não depende de nada do roteki além dos tipos.

**Files:**
- Create: `lua/roteki/utils.lua`
- Test: `tests/utils_spec.lua`
- Test: `tests/cache_spec.lua`

**Interfaces:**
- Consumes: nada em tempo de execução; `resolve` chama `require("roteki.config")`, que só existe na Task 4 — por isso os testes de `resolve` ficam na Task 4.
- Produces:
  - `Utils.read(fname) -> string|nil, string|nil`
  - `Utils.write(fname, data)`
  - `Utils.cache.file(key) -> string`
  - `Utils.cache.read(key) -> roteki.Cache|nil`
  - `Utils.cache.write(key, data)`
  - `Utils.cache.clear()`
  - `Utils.unpack(groups) -> roteki.Highlights`
  - `Utils.blend(foreground, background, alpha) -> string`
  - `Utils.reload()`
  - `Utils.resolve(theme?) -> string`

- [ ] **Step 1: Escrever `tests/utils_spec.lua`**

```lua
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
```

- [ ] **Step 2: Escrever `tests/cache_spec.lua`**

```lua
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
```

- [ ] **Step 3: Rodar os testes e confirmar que falham**

Run: `nvim --headless -u tests/init.lua -c "PlenaryBustedFile tests/utils_spec.lua" -c "qa!"`
Expected: FAIL — `module 'roteki.utils' not found`

- [ ] **Step 4: Escrever `lua/roteki/utils.lua`**

```lua
local M = {}

M.cache = {}

--- Lê um arquivo do disco
---@param fname string
---@return string|nil, string|nil
function M.read(fname)
  local file, err = io.open(fname, "r")
  if not file then
    return nil, err
  end
  local data = file:read("*a")
  file:close()
  return data
end

--- Escreve no arquivo, apagando o conteúdo anterior
---@param fname string
---@param data string
function M.write(fname, data)
  vim.fn.mkdir(vim.fs.dirname(fname), "p")
  local file = assert(io.open(fname, "w+"))
  file:write(data)
  file:close()
end

--- Caminho do arquivo de cache para uma chave
---@param key string
---@return string
function M.cache.file(key)
  return vim.fs.joinpath(vim.fn.stdpath("cache"), "roteki-" .. key .. ".json")
end

--- Lê e decodifica o cache do disco com segurança
---@param key string
---@return roteki.Cache|nil
function M.cache.read(key)
  local data = M.read(M.cache.file(key))
  if not data then
    return nil
  end
  local is_ok, ret = pcall(vim.json.decode, data, { luanil = { object = true, array = true } })
  return is_ok and ret or nil
end

--- Codifica e grava os dados no diretório de cache
---@param key string
---@param data roteki.Cache
function M.cache.write(key, data)
  pcall(M.write, M.cache.file(key), vim.json.encode(data))
end

--- Apaga os arquivos de cache do roteki
function M.cache.clear()
  local files = vim.fn.glob(vim.fn.stdpath("cache") .. "/roteki-*.json", false, true)
  for _, file in ipairs(files) do
    vim.uv.fs_unlink(file)
  end
end

--- Achata a tabela `style` dentro do próprio highlight
---@param groups roteki.Highlights
---@return roteki.Highlights
function M.unpack(groups)
  for _, hl in pairs(groups) do
    if hl.style and type(hl.style) == "table" then
      for k, v in pairs(hl.style) do
        hl[k] = v
      end
      hl.style = nil
    end
  end
  return groups
end

--- Converte hex para uma tabela RGB
---@param hex string
---@return table
local function rgb(hex)
  hex = hex:lower()
  return {
    tonumber(hex:sub(2, 3), 16),
    tonumber(hex:sub(4, 5), 16),
    tonumber(hex:sub(6, 7), 16),
  }
end

--- Mistura duas cores por transparência
---@param foreground string
---@param background string
---@param alpha number Fator de mistura (0 a 1)
---@return string # hex no formato "#RRGGBB"
function M.blend(foreground, background, alpha)
  local fg = rgb(foreground)
  local bg = rgb(background)

  local function blend_channel(i)
    local ret = (alpha * fg[i] + ((1 - alpha) * bg[i]))
    return math.floor(math.min(math.max(0, ret), 255) + 0.5)
  end

  return string.format("#%02X%02X%02X", blend_channel(1), blend_channel(2), blend_channel(3))
end

--- Limpa o cache e recarrega o colorscheme atual
function M.reload()
  M.cache.clear()
  for name, _ in pairs(package.loaded) do
    if name:match("^roteki") and name ~= "roteki.config" then
      package.loaded[name] = nil
    end
  end
  vim.notify("Roteki reloaded", vim.log.levels.INFO)
  vim.cmd.colorscheme(vim.g.colors_name)
end

--- Resolve a variante a partir da config e de vim.o.background
---@param theme string|nil
---@return string
function M.resolve(theme)
  if theme then
    return theme
  end
  -- Cai em vim.o.background quando theme = {} recebe valores inválidos no setup
  return require("roteki.config").options.theme[vim.o.background] or vim.o.background
end

return M
```

- [ ] **Step 5: Rodar os dois specs e confirmar que passam**

Run: `nvim --headless -u tests/init.lua -c "PlenaryBustedFile tests/utils_spec.lua" -c "PlenaryBustedFile tests/cache_spec.lua" -c "qa!"`
Expected: PASS nos dois arquivos, 0 falhas

- [ ] **Step 6: Commit**

```bash
git add lua/roteki/utils.lua tests/utils_spec.lua tests/cache_spec.lua
git commit -m "feat: add utils for blending, caching and variant resolution"
```

---

### Task 4: Config

Defaults do usuário, incluindo `styles.types`, que é a chave a mais em relação ao koda. Fecha o ciclo do `Utils.resolve`, que depende deste módulo.

**Files:**
- Create: `lua/roteki/config.lua`
- Test: `tests/config_spec.lua`
- Modify: `tests/utils_spec.lua` (acrescenta o bloco `Utils.resolve`)

**Interfaces:**
- Consumes: `Utils.resolve` (Task 3)
- Produces:
  - `Config._version -> string` (semver, `"0.1.0"`)
  - `Config.defaults -> roteki.Config`
  - `Config.options -> roteki.Config`
  - `Config.extend(opts?) -> roteki.Config`
  - `Config.setup(opts?)`

- [ ] **Step 1: Escrever `tests/config_spec.lua`**

Este spec cobre só o que não precisa de `colorscheme`; os testes de `on_highlights`, `transparent` e override de cor entram na Task 8, quando `load()` existir.

```lua
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
```

- [ ] **Step 2: Acrescentar o bloco `Utils.resolve` ao fim de `tests/utils_spec.lua`**

```lua
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
```

- [ ] **Step 3: Rodar e confirmar que falham**

Run: `nvim --headless -u tests/init.lua -c "PlenaryBustedFile tests/config_spec.lua" -c "qa!"`
Expected: FAIL — `module 'roteki.config' not found`

- [ ] **Step 4: Escrever `lua/roteki/config.lua`**

```lua
local M = {}

M._version = "0.1.0"

---@type roteki.Config
M.defaults = {
  transparent = false,

  -- Variantes usadas ao alternar por vim.o.background.
  -- Só existe 'dark'; as duas pontas apontam para ela até haver uma variante clara.
  theme = {
    dark = "dark",
    light = "dark",
  },

  styles = {
    functions = { bold = true },
    keywords = { italic = true },
    comments = { italic = true },
    types = { bold = true },
    strings = {},
    constants = {},
  },

  colors = {},
  auto = true,
  cache = true,

  on_highlights = function(highlights, colors) end,
}

---@type roteki.Config
M.options = vim.deepcopy(M.defaults) -- permite omitir a chamada a setup()

---@param opts roteki.Config|nil
---@return roteki.Config
function M.extend(opts)
  return vim.tbl_deep_extend("force", M.defaults, opts or {})
end

---@param opts roteki.Config|nil
function M.setup(opts)
  M.options = M.extend(opts)
end

return M
```

- [ ] **Step 5: Rodar os dois specs e confirmar que passam**

Run: `nvim --headless -u tests/init.lua -c "PlenaryBustedFile tests/config_spec.lua" -c "PlenaryBustedFile tests/utils_spec.lua" -c "qa!"`
Expected: PASS nos dois, 0 falhas

- [ ] **Step 6: Commit**

```bash
git add lua/roteki/config.lua tests/config_spec.lua tests/utils_spec.lua
git commit -m "feat: add user config with roteki style defaults"
```

---

### Task 5: Grupos core

Os quatro arquivos que definem o tema de fato. Cada um exporta só `get_hl`.

**Files:**
- Create: `lua/roteki/groups/base.lua`
- Create: `lua/roteki/groups/syntax.lua`
- Create: `lua/roteki/groups/treesitter.lua`
- Create: `lua/roteki/groups/lsp.lua`
- Test: `tests/groups_spec.lua`

**Interfaces:**
- Consumes: `Utils.blend` (Task 3), `Config.extend` (Task 4), `roteki.palette.dark` (Task 2)
- Produces: cada módulo expõe `M.get_hl(colors, opts) -> roteki.Highlights`. `base` e `syntax` usam `opts`; `treesitter` e `lsp` só usam `colors`.

- [ ] **Step 1: Escrever `tests/groups_spec.lua`**

```lua
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
end)
```

- [ ] **Step 2: Rodar e confirmar que falha**

Run: `nvim --headless -u tests/init.lua -c "PlenaryBustedFile tests/groups_spec.lua" -c "qa!"`
Expected: FAIL — `no group files found` ou `module 'roteki.groups.base' not found`

- [ ] **Step 3: Escrever `lua/roteki/groups/base.lua`**

```lua
local Utils = require("roteki.utils")

local M = {}

--- Grupos base, ver `:h highlight-groups`
---@type roteki.HighlightsFn
function M.get_hl(c, opts)
  local bg = opts.transparent and "none" or c.bg
  local float = opts.transparent and "none" or c.black
  -- stylua: ignore
  return {
    Normal            = { fg = c.fg, bg = bg },
    NormalFloat       = { fg = c.fg, bg = float },
    FloatBorder       = { fg = c.border, bg = float },
    Cursor            = { fg = c.fg, bg = c.fg },
    TermCursor        = { link = "Cursor" },
    lCursor           = { link = "Cursor" },
    CursorIM          = { link = "Cursor" },
    CursorColumn      = { bg = c.line },
    CursorLine        = { bg = c.line },
    ColorColumn       = { bg = c.line },
    CursorLineNr      = { fg = c.special, bold = true },
    LineNr            = { fg = c.comment },
    SignColumn        = { bg = bg },
    StatusLine        = { fg = c.fg, bg = float },
    StatusLineNC      = { fg = c.dim, bg = float },
    StatusLineTerm    = { link = "StatusLine" },
    StatusLineTermNC  = { link = "StatusLineNC" },
    WinBar            = { link = "Normal" },
    WinBarNC          = { link = "Normal" },
    WinSeparator      = { fg = c.border },
    VertSplit         = { link = "WinSeparator" },
    Pmenu             = { fg = c.fg, bg = float },
    PmenuSel          = { fg = c.fg, bg = c.selection, bold = true },
    PmenuThumb        = { bg = c.fg },
    PmenuMatch        = { fg = c.const, bold = true },
    Visual            = { bg = c.selection },
    Search            = { link = "Visual" },
    CurSearch         = { link = "Search" },
    IncSearch         = { link = "CurSearch" },
    Substitute        = { link = "DiffAdd" },
    MatchParen        = { fg = c.special, bold = true },
    NonText           = { fg = c.dim },
    EndOfBuffer       = { fg = c.bg },
    Folded            = { fg = c.dim, bg = c.line },
    Question          = { fg = c.const },
    MoreMsg           = { link = "Question" },
    ErrorMsg          = { fg = c.danger },
    WarningMsg        = { fg = c.warning },
    ModeMsg           = { fg = c.warning },
    MsgArea           = { link = "Normal" },
    MsgSeparator      = { fg = c.fg },
    Directory         = { fg = c.emphasis },
    QuickFixLine      = { fg = c.const, underline = true },
    qfLineNr          = { fg = c.comment },
    SpecialKey        = { fg = c.comment },
    TabLineSel        = { fg = c.emphasis, bg = c.line },
    Title             = { fg = c.emphasis, bold = true },
    DiffAdd           = { fg = c.success, bg = Utils.blend(c.success, c.bg, 0.2) },
    DiffChange        = { fg = c.warning, bg = Utils.blend(c.warning, c.bg, 0.2) },
    DiffDelete        = { fg = c.danger,  bg = Utils.blend(c.danger,  c.bg, 0.2) },
    DiffText          = { fg = c.warning, bg = Utils.blend(c.warning, c.bg, 0.4) },
  }
end

return M
```

- [ ] **Step 4: Escrever `lua/roteki/groups/syntax.lua`**

```lua
local M = {}

--- Grupos de syntax, ver `:h syntax`
---@type roteki.HighlightsFn
function M.get_hl(c, opts)
  -- stylua: ignore
  return {
    Comment         = { fg = c.comment, style = opts.styles.comments },
    Constant        = { fg = c.const, style = opts.styles.constants },
    String          = { fg = c.string, style = opts.styles.strings },
    Character       = { fg = c.char, style = opts.styles.strings },
    Number          = { fg = c.const, style = opts.styles.constants },
    Boolean         = { fg = c.const, style = opts.styles.constants },
    Float           = { fg = c.const, style = opts.styles.constants },
    Identifier      = { fg = c.special },
    Function        = { fg = c.func, style = opts.styles.functions },
    Keyword         = { fg = c.keyword, style = opts.styles.keywords },
    Statement       = { fg = c.keyword },
    Conditional     = { link = "Keyword" },
    Repeat          = { link = "Keyword" },
    Label           = { fg = c.keyword },
    Operator        = { fg = c.operator },
    Exception       = { link = "Keyword" },
    PreProc         = { fg = c.fg },
    Include         = { fg = c.keyword },
    Define          = { fg = c.keyword },
    Macro           = { fg = c.const },
    PreCondit       = { fg = c.keyword },
    Type            = { fg = c.type, style = opts.styles.types },
    StorageClass    = { fg = c.keyword },
    Structure       = { fg = c.keyword },
    Typedef         = { fg = c.keyword },
    Special         = { fg = c.fg },
    SpecialChar     = { link = "Special" },
    Tag             = { fg = c.fg },
    Delimiter       = { fg = c.type },
    SpecialComment  = { link = "Comment" },
    Debug           = { fg = c.const },
    Underlined      = { underline = true },
    Error           = { fg = c.danger },
    Todo            = { fg = c.warning, bold = true },
    Added           = { fg = c.success },
    Changed         = { fg = c.warning },
    Removed         = { fg = c.danger },
  }
end

return M
```

- [ ] **Step 5: Escrever `lua/roteki/groups/treesitter.lua`**

Quase tudo são links para os grupos de `syntax.lua`, o que faz as decisões de syntax propagarem sozinhas.

```lua
local M = {}

--- Grupos do Treesitter, ver `:h treesitter-highlight`
---@type roteki.HighlightsFn
function M.get_hl(c)
  -- stylua: ignore
  return {
    ["@variable"]                      = { fg = c.fg },
    ["@variable.builtin"]              = { link = "Constant" },
    ["@variable.parameter"]            = { fg = c.fg },
    ["@variable.parameter.builtin"]    = { fg = c.fg },
    ["@variable.member"]               = { fg = c.fg },
    ["@constant"]                      = { link = "Constant" },
    ["@constant.macro"]                = { link = "Constant" },
    ["@constant.builtin"]              = { link = "Constant" },
    ["@module"]                        = { fg = c.fg },
    ["@module.builtin"]                = { link = "Special" },
    ["@label"]                         = { link = "Structure" },
    ["@string"]                        = { link = "String" },
    ["@string.documentation"]          = { link = "Comment" },
    ["@string.regexp"]                 = { link = "String" },
    ["@string.escape"]                 = { link = "Special" },
    ["@string.special"]                = { link = "Special" },
    ["@string.special.symbol"]         = { link = "Special" },
    ["@string.special.path"]           = { link = "Special" },
    ["@string.special.url"]            = { link = "Underlined" },
    ["@character"]                     = { link = "Character" },
    ["@character.special"]             = { fg = c.special },
    ["@boolean"]                       = { link = "Boolean" },
    ["@number"]                        = { link = "Number" },
    ["@number.float"]                  = { link = "Number" },
    ["@type"]                          = { link = "Type" },
    ["@type.builtin"]                  = { link = "Type" },
    ["@type.definition"]               = { fg = c.fg },
    ["@attribute"]                     = { link = "Keyword" },
    ["@attribute.builtin"]             = { link = "Keyword" },
    ["@property"]                      = { fg = c.fg },
    ["@function"]                      = { link = "Function" },
    ["@function.builtin"]              = { link = "Function" },
    ["@function.call"]                 = { link = "Function" },
    ["@function.macro"]                = { link = "Macro" },
    ["@function.method"]               = { link = "Function" },
    ["@function.method.call"]          = { link = "Function" },
    ["@constructor"]                   = { fg = c.fg },
    ["@operator"]                      = { link = "Operator" },
    ["@keyword"]                       = { link = "Keyword" },
    ["@keyword.coroutine"]             = { link = "Keyword" },
    ["@keyword.function"]              = { link = "Keyword" },
    ["@keyword.operator"]              = { link = "Operator" },
    ["@keyword.import"]                = { link = "Include" },
    ["@keyword.type"]                  = { link = "Keyword" },
    ["@keyword.modifier"]              = { link = "Keyword" },
    ["@keyword.repeat"]                = { link = "Repeat" },
    ["@keyword.return"]                = { fg = c.emphasis },
    ["@keyword.debug"]                 = { link = "Keyword" },
    ["@keyword.exception"]             = { link = "Exception" },
    ["@keyword.conditional"]           = { link = "Conditional" },
    ["@keyword.conditional.ternary"]   = { link = "Conditional" },
    ["@keyword.directive"]             = { link = "Keyword" },
    ["@keyword.directive.define"]      = { link = "Keyword" },
    ["@punctuation"]                   = { link = "Keyword" },
    ["@punctuation.delimiter"]         = { link = "Delimiter" },
    ["@punctuation.bracket"]           = { fg = c.fg },
    ["@punctuation.special"]           = { fg = c.fg },
    ["@comment"]                       = { link = "Comment" },
    ["@comment.documentation"]         = { link = "Comment" },
    ["@comment.error"]                 = { fg = c.danger },
    ["@comment.warning"]               = { fg = c.warning },
    ["@comment.todo"]                  = { fg = c.info },
    ["@comment.note"]                  = { fg = c.emphasis },
    ["@markup.strong"]                 = { bold = true },
    ["@markup.italic"]                 = { italic = true },
    ["@markup.strikethrough"]          = { fg = c.danger, strikethrough = true },
    ["@markup.underline"]              = { underline = true },
    ["@markup.heading"]                = { fg = c.emphasis, bold = true },
    ["@markup.heading.gitcommit"]      = { fg = c.fg },
    ["@markup.heading.1.markdown"]     = { link = "@markup.heading" },
    ["@markup.heading.2.markdown"]     = { link = "@markup.heading" },
    ["@markup.heading.3.markdown"]     = { link = "@markup.heading" },
    ["@markup.heading.4.markdown"]     = { link = "@markup.heading" },
    ["@markup.heading.5.markdown"]     = { link = "@markup.heading" },
    ["@markup.heading.6.markdown"]     = { link = "@markup.heading" },
    ["@markup.quote"]                  = { link = "Comment" },
    ["@markup.math"]                   = { link = "Special" },
    ["@markup.link"]                   = { fg = c.emphasis, underline = true },
    ["@markup.link.label"]             = { fg = c.emphasis, underline = false },
    ["@markup.link.url"]               = { fg = c.info, underline = true },
    ["@markup.raw"]                    = { fg = c.const },
    ["@markup.raw.block"]              = { fg = c.const },
    ["@markup.list"]                   = { fg = c.emphasis },
    ["@markup.list.checked"]           = { fg = c.success },
    ["@markup.list.unchecked"]         = { fg = c.danger },
    ["@diff.plus"]                     = { link = "DiffAdd" },
    ["@diff.minus"]                    = { link = "DiffDelete" },
    ["@diff.delta"]                    = { link = "DiffChange" },
    ["@tag"]                           = { link = "Keyword" },
    ["@tag.builtin"]                   = { fg = c.fg },
    ["@tag.delimiter"]                 = { link = "Keyword" },
    ["@tag.attribute"]                 = { link = "Keyword" },
  }
end

return M
```

- [ ] **Step 6: Escrever `lua/roteki/groups/lsp.lua`**

`DiagnosticInfo` usa `c.info` e `DiagnosticHint` usa `c.dim` — o koda inverte isso, mas uma chave chamada `info` deve servir o diagnóstico de informação. Os `LspReference*` e os `DiagnosticUnderline*` vêm do roteki atual. Os `DiagnosticFloating*` ficam de fora: o Neovim já os linka nos `Diagnostic*` correspondentes.

```lua
local M = {}

--- Grupos de LSP, ver `:h lsp-highlight` e `:h diagnostic-highlights`
---@type roteki.HighlightsFn
function M.get_hl(c)
  -- stylua: ignore
  return {
    DiagnosticError                          = { fg = c.danger },
    DiagnosticWarn                           = { fg = c.warning },
    DiagnosticInfo                           = { fg = c.info },
    DiagnosticHint                           = { fg = c.dim },
    DiagnosticOK                             = { fg = c.success },
    DiagnosticUnderlineError                 = { underline = true, sp = c.danger },
    DiagnosticUnderlineWarn                  = { underline = true, sp = c.warning },
    DiagnosticUnderlineInfo                  = { underline = true, sp = c.info },
    DiagnosticUnderlineHint                  = { underline = true, sp = c.dim },
    LspInlayHint                             = { fg = c.comment },
    LspReferenceText                         = { bg = c.line },
    LspReferenceRead                         = { bg = c.selection, fg = c.type },
    LspReferenceWrite                        = { bg = c.type, fg = c.black },
    ["@lsp.type.comment"]                    = {}, -- deixa o treesitter decidir
    ["@lsp.type.lifetime"]                   = { fg = c.const },
    ["@lsp.type.modifier"]                   = { link = "Keyword" },
    ["@lsp.type.struct"]                     = { fg = c.fg },
    ["@lsp.typemod.namespace.attribute"]     = { link = "Keyword" },
    ["@lsp.typemod.interface.declaration"]   = { fg = c.fg },
    ["@lsp.typemod.interface.public"]        = { fg = c.fg },
    ["@lsp.typemod.struct.declaration"]      = { fg = c.fg },
    ["@lsp.typemod.enum.declaration"]        = { fg = c.fg },
    ["@lsp.typemod.type.declaration"]        = { fg = c.fg },
    ["@lsp.typemod.class.declaration"]       = { fg = c.fg },
    ["@lsp.typemod.class.globalScope"]       = { fg = c.fg },
    ["@lsp.typemod.generic.attribute"]       = { fg = c.fg },
    ["@lsp.typemod.variable.defaultLibrary"] = { link = "@variable.builtin" },
  }
end

return M
```

- [ ] **Step 7: Rodar o spec e confirmar que passa**

Run: `nvim --headless -u tests/init.lua -c "PlenaryBustedFile tests/groups_spec.lua" -c "qa!"`
Expected: PASS — 5 sucessos, 0 falhas

- [ ] **Step 8: Commit**

```bash
git add lua/roteki/groups/base.lua lua/roteki/groups/syntax.lua \
        lua/roteki/groups/treesitter.lua lua/roteki/groups/lsp.lua tests/groups_spec.lua
git commit -m "feat: add base, syntax, treesitter and lsp highlight groups"
```

---

### Task 6: Grupos de plugin

Quinze arquivos de dados, portados do koda com a paleta do roteki. Nenhum ajuste roteki-específico, exceto `telescope.lua`, que preserva as bordas, títulos e seleção que o roteki já define hoje. O `groups_spec` da Task 5 passa a cobri-los automaticamente pelo glob.

**Files:**
- Create: `lua/roteki/groups/{blink,dashboard,flash,fzf,gitsigns,mason,mini,modes,neotree,oil,rainbow-delimiters,render-markdown,snacks,telescope,trouble}.lua`

**Interfaces:**
- Consumes: `Utils.blend` (Task 3) em `gitsigns`, `mason` e `render-markdown`
- Produces: quinze módulos com `M.get_hl(colors, opts) -> roteki.Highlights`. Os nomes de arquivo são exatamente os valores do mapa `M.plugins` da Task 7.

- [ ] **Step 1: Escrever os cinco arquivos de uma linha**

`lua/roteki/groups/blink.lua`:

```lua
local M = {}

---@type roteki.HighlightsFn
function M.get_hl(c)
  -- stylua: ignore
  return {
    BlinkCmpLabelMatch = { fg = c.const },
  }
end

return M
```

`lua/roteki/groups/dashboard.lua`:

```lua
local M = {}

---@type roteki.HighlightsFn
function M.get_hl(c)
  -- stylua: ignore
  return {
    DashboardProjectTitle = { fg = c.emphasis },
    DashboardMruTitle     = { fg = c.emphasis },
  }
end

return M
```

`lua/roteki/groups/flash.lua`:

```lua
local M = {}

---@type roteki.HighlightsFn
function M.get_hl(c)
  -- stylua: ignore
  return {
    FlashLabel = { bg = c.bg, fg = c.const, bold = true },
  }
end

return M
```

`lua/roteki/groups/fzf.lua`:

```lua
local M = {}

---@type roteki.HighlightsFn
function M.get_hl(c, opts)
  -- stylua: ignore
  return {
    FzfLuaBackdrop = { bg = opts.transparent and "none" or c.bg },
  }
end

return M
```

`lua/roteki/groups/oil.lua`:

```lua
local M = {}

---@type roteki.HighlightsFn
function M.get_hl(c)
  -- stylua: ignore
  return {
    OilCreate = { fg = c.success },
  }
end

return M
```

- [ ] **Step 2: Escrever `gitsigns`, `mason` e `render-markdown` (os que usam blend)**

`lua/roteki/groups/gitsigns.lua`:

```lua
local Utils = require("roteki.utils")

local M = {}

---@type roteki.HighlightsFn
function M.get_hl(c)
  -- stylua: ignore
  return {
    GitSignsAdd              = { fg = c.success },
    GitSignsChange           = { fg = c.warning },
    GitSignsDelete           = { fg = c.danger },
    GitSignsAddInline        = { link = "DiffChange" },
    GitSignsChangeInline     = { link = "DiffChange" },
    GitSignsDeleteInline     = { link = "DiffChange" },
    GitSignsCurrentLineBlame = { fg = Utils.blend(c.fg, c.line, 0.4) },
  }
end

return M
```

`lua/roteki/groups/mason.lua`:

```lua
local Utils = require("roteki.utils")

local M = {}

---@type roteki.HighlightsFn
function M.get_hl(c)
  -- stylua: ignore
  return {
    MasonNormal                      = { link = "Normal" },
    MasonHeader                      = { fg = c.highlight, bg = Utils.blend(c.highlight, c.bg, 0.2), bold = true },
    MasonHeaderSecondary             = { fg = c.const, bg = Utils.blend(c.const, c.bg, 0.2), bold = true },
    MasonHighlight                   = { fg = c.const },
    MasonHighlightBlock              = { fg = c.success, bg = Utils.blend(c.green, c.bg, 0.2) },
    MasonHighlightBlockBold          = { fg = c.highlight, bg = Utils.blend(c.highlight, c.bg, 0.2) },
    MasonHighlightBlockBoldSecondary = { fg = c.const, bg = Utils.blend(c.const, c.bg, 0.2) },
    MasonMutedBlock                  = { fg = c.fg, bg = c.line },
  }
end

return M
```

`lua/roteki/groups/render-markdown.lua`:

```lua
local Utils = require("roteki.utils")

local M = {}

---@type roteki.HighlightsFn
function M.get_hl(c)
  local heading = Utils.blend(c.fg, c.bg, 0.1)
  -- stylua: ignore
  return {
    RenderMarkdownCode = { bg = c.line },
    RenderMarkdownH1Bg = { bg = heading },
    RenderMarkdownH2Bg = { bg = heading },
    RenderMarkdownH3Bg = { bg = heading },
    RenderMarkdownH4Bg = { bg = heading },
    RenderMarkdownH5Bg = { bg = heading },
    RenderMarkdownH6Bg = { bg = heading },
  }
end

return M
```

- [ ] **Step 3: Escrever `mini`, `modes`, `neotree`, `rainbow-delimiters` e `trouble`**

`lua/roteki/groups/mini.lua`:

```lua
local M = {}

---@type roteki.HighlightsFn
function M.get_hl(c)
  -- stylua: ignore
  return {
    MiniPickMatchRanges      = { fg = c.const },
    MiniStatuslineModeNormal = { fg = c.bg, bg = c.fg },
    MiniJump2dSpot           = { fg = c.fg, bg = c.line, bold = true },
    MiniIconsGrey            = { fg = c.fg },
    MiniIconsAzure           = { fg = c.emphasis },
    MiniIconsBlue            = { fg = c.info },
    MiniIconsCyan            = { fg = c.cyan },
    MiniIconsGreen           = { fg = c.success },
    MiniIconsOrange          = { fg = c.orange },
    MiniIconsPurple          = { fg = c.pink },
    MiniIconsRed             = { fg = c.danger },
    MiniIconsYellow          = { fg = c.warning },
  }
end

return M
```

`lua/roteki/groups/modes.lua`:

```lua
local M = {}

---@type roteki.HighlightsFn
function M.get_hl(c)
  -- stylua: ignore
  return {
    ModesCopy    = { bg = c.keyword },
    ModesDelete  = { bg = c.danger },
    ModesFormat  = { bg = c.func },
    ModesReplace = { bg = c.warning },
    ModesVisual  = { bg = c.highlight },
    ModesInsert  = { bg = c.const },
  }
end

return M
```

`lua/roteki/groups/neotree.lua`:

```lua
local M = {}

---@type roteki.HighlightsFn
function M.get_hl(c)
  -- stylua: ignore
  return {
    NeoTreeGitModified  = { fg = c.warning },
    NeoTreeGitAdded     = { fg = c.success },
    NeoTreeGitDeleted   = { fg = c.danger, strikethrough = true },
    NeoTreeGitStaged    = { fg = c.success },
    NeoTreeGitConflict  = { fg = c.red },
    NeoTreeGitUntracked = { fg = c.orange },
    NeoTreeGitUnstaged  = { fg = c.orange },
  }
end

return M
```

`lua/roteki/groups/rainbow-delimiters.lua`:

```lua
local M = {}

---@type roteki.HighlightsFn
function M.get_hl(c)
  -- stylua: ignore
  return {
    RainbowDelimiterRed    = { fg = c.const },
    RainbowDelimiterYellow = { fg = c.info },
    RainbowDelimiterBlue   = { fg = c.success },
    RainbowDelimiterOrange = { fg = c.cyan },
    RainbowDelimiterGreen  = { fg = c.pink },
    RainbowDelimiterViolet = { fg = c.danger },
    RainbowDelimiterCyan   = { fg = c.emphasis },
  }
end

return M
```

`lua/roteki/groups/trouble.lua`:

```lua
local M = {}

---@type roteki.HighlightsFn
function M.get_hl(c)
  -- stylua: ignore
  return {
    TroubleFsCount             = { fg = c.danger },
    TroubleDirectory           = { fg = c.emphasis },
    TroubleIconDirectory       = { fg = c.emphasis },
    TroubleQfFilename          = { fg = c.emphasis },
    TroubleQfCount             = { fg = c.warning },
    TroubleLspCount            = { fg = c.warning },
    TroubleDiagnosticsCount    = { fg = c.danger },
    TroubleDiagnosticsBaseName = { fg = c.emphasis },
  }
end

return M
```

- [ ] **Step 4: Escrever `lua/roteki/groups/snacks.lua`**

```lua
local M = {}

---@type roteki.HighlightsFn
function M.get_hl(c)
  -- stylua: ignore
  return {
    -- Picker
    SnacksPickerDir           = { fg = c.keyword },
    SnacksPickerMatch         = { fg = c.const },
    -- Notifier
    SnacksNotifierBorderDebug = { fg = c.comment },
    SnacksNotifierIconDebug   = { fg = c.comment },
    SnacksNotifierTitleDebug  = { fg = c.comment },
    SnacksNotifierFooterDebug = { fg = c.comment },
    SnacksNotifierBorderError = { fg = c.danger },
    SnacksNotifierIconError   = { fg = c.danger },
    SnacksNotifierTitleError  = { fg = c.danger },
    SnacksNotifierFooterError = { fg = c.danger },
    SnacksNotifierBorderInfo  = { fg = c.info },
    SnacksNotifierIconInfo    = { fg = c.info },
    SnacksNotifierTitleInfo   = { fg = c.info },
    SnacksNotifierFooterInfo  = { fg = c.info },
    SnacksNotifierBorderTrace = { fg = c.fg },
    SnacksNotifierIconTrace   = { fg = c.fg },
    SnacksNotifierTitleTrace  = { fg = c.fg },
    SnacksNotifierFooterTrace = { fg = c.fg },
    SnacksNotifierBorderWarn  = { fg = c.warning },
    SnacksNotifierIconWarn    = { fg = c.warning },
    SnacksNotifierTitleWarn   = { fg = c.warning },
    SnacksNotifierFooterWarn  = { fg = c.warning },
    -- Input
    SnacksInputTitle          = { fg = c.emphasis },
    SnacksInputIcon           = { fg = c.const },
    SnacksInputPrompt         = { fg = c.comment },
    -- Dashboard
    SnacksDashboardHeader     = { fg = c.fg },
  }
end

return M
```

- [ ] **Step 5: Escrever `lua/roteki/groups/telescope.lua`**

O koda define só `TelescopeMatching` e deixa o resto herdar. O roteki define bordas, títulos, prefixo e seleção explicitamente; isso é preservado, com títulos em `c.emphasis` (o mapeamento designa `emphasis` para "títulos (Telescope)") e a seleção no teal.

```lua
local M = {}

---@type roteki.HighlightsFn
function M.get_hl(c, opts)
  local bg = opts.transparent and "none" or c.bg
  -- stylua: ignore
  return {
    TelescopeBorder        = { fg = c.border, bg = bg },
    TelescopePromptBorder  = { link = "TelescopeBorder" },
    TelescopeResultsBorder = { link = "TelescopeBorder" },
    TelescopePreviewBorder = { link = "TelescopeBorder" },
    TelescopeTitle         = { fg = c.emphasis, bold = true },
    TelescopePromptTitle   = { link = "TelescopeTitle" },
    TelescopeResultsTitle  = { link = "TelescopeTitle" },
    TelescopePreviewTitle  = { link = "TelescopeTitle" },
    TelescopePromptPrefix  = { fg = c.emphasis, bold = true },
    TelescopeSelection     = { bg = c.selection },
    TelescopeMatching      = { fg = c.const, bold = true },
  }
end

return M
```

- [ ] **Step 6: Rodar o `groups_spec` e confirmar que os 15 novos arquivos passam pelo glob**

Run: `nvim --headless -u tests/init.lua -c "PlenaryBustedFile tests/groups_spec.lua" -c "qa!"`
Expected: PASS — 5 sucessos, 0 falhas. O teste "devolve highlights sem cor nil" agora percorre 19 arquivos.

- [ ] **Step 7: Conferir a contagem de arquivos**

Run: `ls lua/roteki/groups/*.lua | wc -l`
Expected: `19` (4 core + 15 de plugin; `init.lua` ainda não existe)

- [ ] **Step 8: Commit**

```bash
git add lua/roteki/groups/
git commit -m "feat: add highlight groups for 15 supported plugins"
```

---

### Task 7: Orquestração e cache

O módulo que junta tudo: escolhe quais grupos montar, monta e cacheia. Aqui entra o único desvio funcional deliberado em relação ao koda — a paleta na impressão digital do cache.

**Files:**
- Create: `lua/roteki/groups/init.lua`
- Modify: `tests/groups_spec.lua` (acrescenta os blocos de detecção)
- Modify: `tests/cache_spec.lua` (acrescenta o bloco de invalidação)

**Interfaces:**
- Consumes: `Utils.cache.*`, `Utils.unpack` (Task 3), `Config._version`, `Config.extend` (Task 4), todos os módulos de `groups/` (Tasks 5 e 6)
- Produces:
  - `Groups.plugins -> table<string, string>` — nome do plugin no gerenciador para nome do arquivo em `groups/`
  - `Groups.get_highlights(name, colors, opts) -> roteki.Highlights`
  - `Groups.setup(colors, opts, theme?) -> roteki.Highlights, table<string, boolean>` — o segundo retorno é o conjunto de grupos montados, usado pelos testes

- [ ] **Step 1: Acrescentar os testes de detecção ao fim de `tests/groups_spec.lua`**

```lua
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
```

- [ ] **Step 2: Acrescentar o teste de invalidação por paleta ao fim de `tests/cache_spec.lua`**

Este é o teste que prova o desvio em relação ao koda: no koda, editar a paleta não invalida o cache.

```lua
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
```

- [ ] **Step 3: Rodar e confirmar que falham**

Run: `nvim --headless -u tests/init.lua -c "PlenaryBustedFile tests/cache_spec.lua" -c "qa!"`
Expected: FAIL — `module 'roteki.groups' not found`

- [ ] **Step 4: Escrever `lua/roteki/groups/init.lua`**

```lua
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
```

- [ ] **Step 5: Rodar os dois specs e confirmar que passam**

Run: `nvim --headless -u tests/init.lua -c "PlenaryBustedFile tests/groups_spec.lua" -c "PlenaryBustedFile tests/cache_spec.lua" -c "qa!"`
Expected: PASS nos dois, 0 falhas

- [ ] **Step 6: Commit**

```bash
git add lua/roteki/groups/init.lua tests/groups_spec.lua tests/cache_spec.lua
git commit -m "feat: add group orchestration with palette-aware cache"
```

---

### Task 8: API pública e entrypoints

Fecha a arquitetura e derruba o `init.lua` antigo. Ao fim desta task o tema volta a carregar no editor.

**Files:**
- Rewrite: `lua/roteki/init.lua`
- Rewrite: `colors/roteki.lua`
- Create: `colors/roteki-dark.lua`
- Delete: `lua/roteki/palette.lua`
- Test: `tests/roteki_spec.lua`
- Modify: `tests/config_spec.lua` (acrescenta os blocos de integração)

**Interfaces:**
- Consumes: `Groups.setup` (Task 7), `Config.setup/options` (Task 4), `Utils.resolve/reload/blend` (Task 3), `roteki.palette.dark` (Task 2)
- Produces:
  - `require("roteki").setup(opts?)` — configura e registra `:RotekiFetch`; **não aplica o tema**
  - `require("roteki").load(theme?)` — aplica o tema
  - `require("roteki").get_palette(theme?) -> roteki.Palette`
  - `require("roteki").blend(fg, bg, alpha) -> string`

- [ ] **Step 1: Escrever `tests/roteki_spec.lua`**

```lua
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
end)
```

- [ ] **Step 2: Acrescentar os blocos de integração ao fim de `tests/config_spec.lua`**

```lua
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
```

- [ ] **Step 3: Rodar e confirmar que falha**

Run: `nvim --headless -u tests/init.lua -c "PlenaryBustedFile tests/roteki_spec.lua" -c "qa!"`
Expected: FAIL — o `colorscheme roteki` atual chama `setup()`, que ainda aplica os highlights antigos; `vim.g.colors_name` e o teste do Visual falham.

- [ ] **Step 4: Reescrever `lua/roteki/init.lua`**

Nota: a versão antiga forçava `vim.opt.termguicolors = true`. Isso sai — colorschemes não devem mexer em opções globais, e o Neovim ≥ 0.10 detecta suporte a cor sozinho.

```lua
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
```

- [ ] **Step 5: Reescrever os entrypoints e remover a paleta antiga**

`colors/roteki.lua` (uma linha, segue `vim.o.background`):

```lua
require("roteki").load()
```

`colors/roteki-dark.lua` (trava na variante):

```lua
require("roteki").load("dark")
```

```bash
git rm lua/roteki/palette.lua
```

- [ ] **Step 6: Rodar a suíte inteira e confirmar que passa**

Run: `nvim --headless -u tests/init.lua -c "PlenaryBustedDirectory tests/ {minimal_init = 'tests/init.lua'}" -c "qa!"`
Expected: PASS em todos os arquivos, 0 falhas e 0 erros

- [ ] **Step 7: Commit**

```bash
git add lua/roteki/init.lua colors/roteki.lua colors/roteki-dark.lua \
        tests/roteki_spec.lua tests/config_spec.lua
git commit -m "feat: rewrite public API over the new architecture

BREAKING CHANGE: setup() no longer applies the theme. Call
vim.cmd(\"colorscheme roteki\") after setup()."
```

---

### Task 9: CI e README

**Files:**
- Create: `.github/workflows/test.yml`
- Create: `README.md`

**Interfaces:**
- Consumes: `tests/` (Tasks 1-8), a API pública da Task 8
- Produces: nada consumido por outra task

- [ ] **Step 1: Escrever `.github/workflows/test.yml`**

```yaml
name: tests

on:
  pull_request:
    branches:
      - main
  workflow_dispatch:

jobs:
  unit_tests:
    name: test (${{ matrix.os }}, ${{ matrix.nvim-version }})
    runs-on: ${{ matrix.os }}
    strategy:
      fail-fast: false
      matrix:
        os: [ubuntu-latest, macos-latest]
        nvim-version: [stable, nightly]

    steps:
      - uses: actions/checkout@v4

      - name: Install Neovim (${{ matrix.nvim-version }})
        uses: rhysd/action-setup-vim@v1
        with:
          neovim: true
          version: ${{ matrix.nvim-version }}

      - name: Install Plenary
        shell: bash
        run: |
          mkdir -p pack/vendor/start
          git clone --depth 1 https://github.com/nvim-lua/plenary.nvim pack/vendor/start/plenary.nvim

      - name: Run Tests
        shell: bash
        run: |
          nvim --headless -u tests/init.lua -c "PlenaryBustedDirectory tests/ {minimal_init = 'tests/init.lua'}"
```

- [ ] **Step 2: Escrever o `README.md`**

````markdown
# roteki.nvim

Um tema escuro para [Neovim](https://github.com/neovim/neovim), escrito em Lua.

## Instalação

Com [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
  "sgtmarcoaurelio/roteki-theme-nvim",
  lazy = false,
  priority = 1000,
  config = function()
    -- require("roteki").setup({ transparent = true })
    vim.cmd("colorscheme roteki")
  end,
}
```

Com [vim.pack](https://neovim.io/doc/user/pack.html#vim.pack):

```lua
vim.pack.add({ "https://github.com/sgtmarcoaurelio/roteki-theme-nvim" })
-- require("roteki").setup({ transparent = true })
vim.cmd("colorscheme roteki")
```

> [!IMPORTANT]
> `setup()` apenas configura — quem aplica o tema é `vim.cmd("colorscheme roteki")`.
> Chame `setup()` **antes** do `colorscheme`.

## Configuração

```lua
require("roteki").setup({
  transparent = false, -- fundo transparente

  -- Variantes usadas ao alternar por vim.o.background.
  -- Só existe 'dark'; as duas pontas apontam para ela.
  theme = { dark = "dark", light = "dark" },

  -- Carrega highlights só dos plugins instalados.
  -- Suporta lazy.nvim, mini.deps e vim.pack.
  auto = true,  -- false carrega TODOS os highlights de plugin

  cache = true, -- cacheia o tema para startup mais rápido

  -- Estilo aplicado a cada grupo de sintaxe. Ver `:help nvim_set_hl`.
  styles = {
    functions = { bold = true },
    keywords  = { italic = true },
    comments  = { italic = true },
    types     = { bold = true },
    strings   = {},
    constants = {}, -- inclui números e booleanos
  },

  -- Sobrescreve cores. As chaves estão em lua/roteki/palette/.
  colors = {
    -- Para todas as variantes:
    -- func = "#4078F2",

    -- Ou por variante:
    -- dark = { func = "#4078F2" },
  },

  -- Modifica ou estende grupos de highlight
  on_highlights = function(hl, c)
    -- hl.LineNr = { fg = c.info }
    -- hl.Comment = { fg = c.emphasis, italic = true }
    -- hl.MinhaCorCustom = { fg = "#fb2b2b" }
  end,
})
```

## API

```lua
local roteki = require("roteki")

local colors = roteki.get_palette("dark")     -- paleta com overrides aplicados
local shade  = roteki.blend(colors.danger, colors.bg, 0.3) -- mistura duas cores
```

`:RotekiFetch` limpa o cache e recarrega os highlights. Útil ao ajustar cores —
embora editar um arquivo de paleta já invalide o cache sozinho.

## Paleta

A paleta é semântica: os grupos de highlight nomeiam o *papel* da cor, não a cor.
São 27 chaves em `lua/roteki/palette/dark.lua`.

| Estrutura | Sintaxe | Semântica | Cores diretas |
|---|---|---|---|
| `bg` `fg` `dim` `line` `selection` `black` `border` | `keyword` `type` `operator` `comment` `func` `string` `char` `special` `const` `emphasis` | `info` `success` `warning` `danger` `highlight` | `green` `orange` `red` `pink` `cyan` |

### Adicionando uma variante

1. Crie `lua/roteki/palette/<nome>.lua` com as mesmas 27 chaves
2. Crie `colors/roteki-<nome>.lua` com `require("roteki").load("<nome>")`
3. Acrescente `"<nome>"` ao array `variants` em `tests/palette_spec.lua`
4. Aponte `theme` para ela no `setup()`, se quiser troca automática

Nada em `lua/roteki/groups/` precisa mudar.

## Plugins suportados

blink.cmp, dashboard-nvim, flash.nvim, fzf-lua, gitsigns.nvim, mason.nvim,
mini.nvim, modes.nvim, neo-tree.nvim, oil.nvim, rainbow-delimiters.nvim,
render-markdown.nvim, snacks.nvim, telescope.nvim, trouble.nvim

Com `auto = true` (default), só entram os que o seu gerenciador de plugins conhece.

## Testes

```sh
mkdir -p pack/vendor/start
git clone --depth 1 https://github.com/nvim-lua/plenary.nvim pack/vendor/start/plenary.nvim
nvim --headless -u tests/init.lua -c "PlenaryBustedDirectory tests/ {minimal_init = 'tests/init.lua'}"
```
````

- [ ] **Step 3: Validar o YAML**

Run: `nvim --headless -c "lua print(vim.fn.filereadable('.github/workflows/test.yml'))" -c "qa!"`
Expected: `1`

- [ ] **Step 4: Rodar a suíte uma última vez**

Run: `nvim --headless -u tests/init.lua -c "PlenaryBustedDirectory tests/ {minimal_init = 'tests/init.lua'}" -c "qa!"`
Expected: PASS, 0 falhas e 0 erros

- [ ] **Step 5: Commit**

```bash
git add .github/workflows/test.yml README.md
git commit -m "docs: add README and CI workflow"
```

---

### Task 10: Validação manual no editor

A suíte prova que os highlights são aplicados; ela não prova que o resultado é agradável de olhar. Esta task é a inspeção visual, e é onde o ajuste fino de cores começa.

**Files:**
- Modify: nenhum, salvo correções que a inspeção revelar

**Interfaces:**
- Consumes: tudo
- Produces: nada

- [ ] **Step 1: Abrir o arquivo de teste de sintaxe com o tema novo**

Run: `nvim -c "colorscheme roteki" syntax_test.ts`
Expected: o buffer carrega com o tema aplicado, sem mensagem de erro.

- [ ] **Step 2: Inspecionar os grupos que mudaram de cor**

Com o cursor sobre cada construção, rode `:Inspect` e confira contra a tabela de mudanças da spec:

| Sobre o quê | Grupo esperado | Cor esperada |
|---|---|---|
| um número | `Number` -> `Constant` | `#deb4f8` |
| um booleano | `Boolean` -> `Constant` | `#deb4f8` |
| nome de função | `@function` -> `Function` | `#BCD1FF` bold |
| `const`, `return` | `@keyword` -> `Keyword` | `#3ab877` itálico |
| `import` | `@keyword.import` -> `Include` | `#3ab877` |
| uma string | `@string` -> `String` | `#AFD8ED` |
| um comentário | `@comment` -> `Comment` | `#3c4349` itálico |
| um tipo | `@type` -> `Type` | `#eff1f5` bold |

- [ ] **Step 3: Conferir a UI**

- `V` para selecionar: fundo teal `#265457`
- `:set cursorline`: fundo `#232628`
- `:split`: separador em `#3e424b`
- `:lua vim.diagnostic.open_float()` num arquivo com erro: borda visível
- Um popup de completion: fundo `#090909`, item selecionado em teal

- [ ] **Step 4: Confirmar que o cache invalida ao editar a paleta**

```bash
nvim -c "colorscheme roteki" -c "qa!"
```

Edite `lua/roteki/palette/dark.lua` trocando `bg` para `#FF0000`, abra o Neovim de novo com `colorscheme roteki` e confirme que o fundo ficou vermelho **sem** rodar `:RotekiFetch`. Depois reverta a cor.

Este é o desvio deliberado em relação ao koda; se falhar, a impressão digital da Task 7 está errada.

- [ ] **Step 5: Anotar os ajustes desejados**

Qualquer cor que tenha ficado ruim é ajuste de paleta ou de grupo, não de arquitetura. Anote e trate como trabalho separado — a estrutura está entregue.

- [ ] **Step 6: Commit de eventuais correções**

```bash
git add -A
git commit -m "fix: adjust colors found during manual validation"
```

Se nada precisou de correção, não há commit nesta task.
