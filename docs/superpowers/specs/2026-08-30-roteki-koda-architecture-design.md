# Reestruturação do roteki.nvim sobre a arquitetura do koda.nvim

Data: 2026-08-30
Status: aprovado para planejamento

## Contexto

O roteki.nvim é hoje três arquivos: `colors/roteki.lua` (uma linha, chama
`setup()`), `lua/roteki/init.lua` (~100 highlights hardcoded dentro de uma
única função) e `lua/roteki/palette.lua` (nomes crus de cor: `blue`,
`light_blue`, `purple`). Não há testes, README, config de usuário, nem
suporte a variantes.

O [koda.nvim](https://github.com/oskarnurm/koda.nvim) resolve os mesmos
problemas com uma arquitetura em camadas: paleta puramente semântica,
grupos de highlight divididos por domínio, carregamento sob demanda por
plugin instalado, cache em disco e configuração de usuário.

Este documento especifica a adoção dessa arquitetura no roteki,
preservando a paleta de cores existente.

## Objetivos

1. Adotar a arquitetura do koda: mesmos arquivos, mesmas interfaces,
   mesmos mecanismos (cache, `styles`, `on_highlights`, detecção de plugin).
2. Preservar a paleta de cores do roteki, remapeada para chaves semânticas.
3. Deixar o suporte a múltiplas variantes pronto, entregando apenas `dark`.
4. Substituir todo hardcode de cor nos grupos por chaves da paleta.

## Não-objetivos

- Variantes light/moss/glade. A estrutura fica pronta; nenhuma é escrita.
- Diretório `extras/` (temas para ghostty, kitty, wezterm, fzf, lazygit,
  windows-terminal).
- Ajuste fino das cores. A paleta entra conforme o mapeamento abaixo; o
  refinamento é feito depois, com o tema já rodando.

## Arquitetura

```
colors/roteki.lua          -- require("roteki").load()        segue vim.o.background
colors/roteki-dark.lua     -- require("roteki").load("dark")  trava na variante
lua/roteki/init.lua        -- setup / load / get_palette / blend + :RotekiFetch
lua/roteki/config.lua      -- defaults + _version ("0.1.0")
lua/roteki/types.lua       -- LuaCATS: Palette, Config, Highlight(s), HighlightsFn, Cache
lua/roteki/utils.lua       -- read/write, cache, unpack, blend, reload, resolve
lua/roteki/palette/dark.lua
lua/roteki/groups/init.lua       -- orquestração, detecção de plugin, cache
lua/roteki/groups/base.lua       -- :h highlight-groups
lua/roteki/groups/syntax.lua     -- :h syntax
lua/roteki/groups/treesitter.lua -- :h treesitter-highlight
lua/roteki/groups/lsp.lua        -- :h lsp-highlight
lua/roteki/groups/{blink,dashboard,flash,fzf,gitsigns,mason,mini,modes,
                   neotree,oil,rainbow-delimiters,render-markdown,
                   snacks,telescope,trouble}.lua
tests/init.lua
tests/{palette,config,utils,groups,roteki}_spec.lua
.github/workflows/test.yml
README.md
.gitignore
```

Cada arquivo em `groups/` exporta uma única função
`get_hl(colors, opts) -> table<string, Highlight>`. Nenhum deles conhece
config, cache ou variantes: recebe uma paleta e devolve highlights. Isso é
o que permite testar cada grupo isoladamente e o que torna a adição de uma
variante uma mudança de zero linhas em `groups/`.

### Remoções

- `lua/roteki/palette.lua` (substituído por `lua/roteki/palette/dark.lua`)
- `\` — arquivo órfão na raiz, cópia antiga da paleta
- `.DS_Store` e `lua/.DS_Store`, cobertos por um novo `.gitignore`

## Paleta

`lua/roteki/palette/dark.lua` retorna apenas dados. 27 chaves: as 25
semânticas do koda mais `selection` e `black`, que cobrem distinções que o
roteki faz e o koda não.

```lua
---@class roteki.Palette
local palette = {
  bg        = "#151718",
  fg        = "#d0d3d6",
  dim       = "#7E8B96",
  line      = "#232628",  -- CursorLine, CursorColumn, ColorColumn, Folded
  selection = "#265457",  -- EXTRA: Visual, Search, PmenuSel, TelescopeSelection
  black     = "#090909",  -- EXTRA: NormalFloat, Pmenu, StatusLine
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
```

Onde o mapeamento fornecido oferecia duas opções (`line`, `func`, `const`,
`keyword`, `special`, `emphasis`, `danger`), vale a primeira listada. A cor
`#34282a` (antigo `dark_red`) sai da paleta: era um fundo, e fundos de diff
passam a ser derivados por `blend`.

Nota conhecida: a paleta não tem um slot neutro-claro ("branco"). Onde os
grupos precisam de `#eff1f5`, usam `type`. Se isso incomodar no ajuste fino,
a correção é acrescentar uma chave à paleta e ao `palette_spec`.

### Variantes futuras

Adicionar uma variante custa exatamente três coisas:

1. `lua/roteki/palette/<nome>.lua` com as mesmas 27 chaves
2. `colors/roteki-<nome>.lua` com `require("roteki").load("<nome>")`
3. o nome no array `variants` de `tests/palette_spec.lua`

Nada em `groups/` muda. Como só existe `dark`, o default de config aponta
as duas pontas para ela (`theme = { dark = "dark", light = "dark" }`), para
que `vim.o.background = "light"` não tente carregar um módulo inexistente.

## Configuração

```lua
require("roteki").setup({
  transparent = false,
  theme       = { dark = "dark", light = "dark" },
  auto        = true,   -- só carrega highlights de plugins instalados
  cache       = true,
  styles = {
    functions = { bold = true },
    keywords  = { italic = true },
    comments  = { italic = true },
    types     = { bold = true },   -- desvio do koda; preserva Type bold
    strings   = {},
    constants = {},
  },
  colors = {},          -- override por chave, global ou por variante
  on_highlights = function(hl, c) end,
})
```

Os defaults de `styles` reproduzem as decisões visuais atuais do roteki.
`styles.types` é uma chave que o koda não tem, aplicada a `Type` em
`groups/syntax.lua`.

### API pública

- `require("roteki").setup(opts)` — configura; **não aplica o tema**
- `require("roteki").load(variant?)` — aplica; chamado pelos arquivos em `colors/`
- `require("roteki").get_palette(variant?)` — paleta com overrides aplicados
- `require("roteki").blend(fg, bg, alpha)` — mistura duas cores
- `:RotekiFetch` — limpa o cache e recarrega o colorscheme

### Quebra de compatibilidade

Hoje `require("roteki").setup()` aplica o tema. Passa a apenas configurar.
Quem aplica é `vim.cmd("colorscheme roteki")`. Configs de usuário que
dependem do comportamento antigo precisam dessa linha. Isso é documentado
no README.

## Orquestração e cache

`groups/init.lua` segue o koda:

- sempre monta `base`, `syntax`, `treesitter`, `lsp`
- com `auto = true`, consulta `lazy.nvim`, `vim.pack` e `mini.deps` e só
  monta os grupos dos plugins instalados; com `auto = false`, monta todos
- serializa o resultado em `stdpath("cache")/roteki-<variante>.json`,
  com um cache em memória à frente do cache em disco

O mapa `M.plugins` (nome do plugin no gerenciador -> nome do arquivo em
`groups/`) é o mesmo do koda, com as 15 entradas.

### Desvio deliberado: invalidação por paleta

A impressão digital de cache do koda cobre versão, `styles`, `colors` e
`transparent` — não o conteúdo da paleta. Editar `palette/dark.lua` não
invalida o cache, então uma cor ajustada não aparece até rodar
`:KodaFetch`.

Como o ajuste fino de cores é uma atividade planejada e recorrente neste
projeto, a tabela da paleta entra na impressão digital e é comparada com
`vim.deep_equal`. Salvar o arquivo passa a invalidar o cache sozinho.

Optou-se por `deep_equal` em vez de hash: são 27 strings curtas, então um
hash não economiza nada e adiciona uma dependência (`sha256`) e a
possibilidade de colisão.

## Grupos de highlight

Regra geral: as definições vêm do koda, com as cores substituídas pela
paleta do roteki. As exceções abaixo são os pontos em que uma decisão
visual do roteki tem encaixe na arquitetura e é preservada ali.

### base.lua

Preservado do roteki, divergindo do koda:

| Grupo | Definição | koda usa |
|---|---|---|
| `Visual` | `bg = c.selection` | `c.line` |
| `Search` | `link = "Visual"` | igual |
| `CurSearch`, `IncSearch` | `link = "Search"` | `CurSearch` linka `DiffChange` |
| `PmenuSel` | `fg = c.fg, bg = c.selection, bold` | `c.line` |
| `Pmenu` | `fg = c.fg, bg = c.black` | `c.bg` |
| `NormalFloat` | `fg = c.fg, bg = c.black` | `link = "Normal"` |
| `StatusLine` | `fg = c.fg, bg = c.black` | `c.line` |
| `StatusLineNC` | `fg = c.dim, bg = c.black` | `c.line` |
| `EndOfBuffer` | `fg = c.bg` (oculto) | `c.line` |
| `Folded` | `fg = c.dim, bg = c.line` | não define |
| `ModeMsg` | `fg = c.warning` | `link = "Question"` |

`transparent = true` zera o fundo de `Normal`, `NormalFloat`, `FloatBorder`,
`Pmenu`, `StatusLine` e `StatusLineNC`.

### syntax.lua

Do koda, com dois ajustes: `Type` recebe `style = opts.styles.types`, e
`Todo = { fg = c.warning, bold = true }` é preservado do roteki (o koda
deixa `Todo` a cargo do Neovim).

### treesitter.lua

Do koda, sem alterações. São quase todos links para grupos de `syntax.lua`,
o que faz as decisões de `syntax` propagarem automaticamente.

### lsp.lua

Do koda, mais:

- `LspReferenceText = { bg = c.line }`,
  `LspReferenceRead = { bg = c.selection, fg = c.type }`,
  `LspReferenceWrite = { bg = c.type, fg = c.black }` — preservados do
  roteki (commit c07526a)
- `DiagnosticUnderline{Error,Warn,Info,Hint}` com `underline` e `sp` na cor
  correspondente — preservados do roteki
- `DiagnosticInfo = c.info` e `DiagnosticHint = c.dim`. O koda inverte
  (`Hint = c.info`, `Info = c.fg`); aqui a chave semântica `info` serve o
  diagnóstico de informação, que é o mapeamento correto.
- `DiagnosticFloating*` são descartados: o Neovim já os linka aos
  `Diagnostic*` correspondentes por padrão.

### telescope.lua

O koda define apenas `TelescopeMatching`, deixando o resto herdar de
`NormalFloat`/`FloatBorder`. O roteki define bordas, títulos, prefixo e
seleção explicitamente; isso é preservado, com os títulos e o prefixo em
`c.emphasis` (que o mapeamento designa para "títulos (Telescope)") e
`TelescopeSelection` em `c.selection`.

### Demais grupos de plugin

`blink`, `dashboard`, `flash`, `fzf`, `gitsigns`, `mason`, `mini`, `modes`,
`neotree`, `oil`, `rainbow-delimiters`, `render-markdown`, `snacks`,
`trouble`: portados do koda com substituição de paleta, sem ajustes
roteki-específicos. São superfícies que o roteki não cobria; o refinamento
fica para o ajuste fino posterior.

## Mudanças visuais

O que permanece: seleção teal `#265457`, CursorLine `#232628`, floats e
StatusLine sobre `#090909`, itálico em comentários e keywords, bold em
funções e tipos, `LspReference*`, bordas e seleção do Telescope, `Todo`
amarelo, `ModeMsg` amarelo.

O que muda, por adotar a semântica do koda:

| Grupo | Hoje | Novo | Motivo |
|---|---|---|---|
| `Constant`, `Number`, `Boolean` | verde / azul | `const` `#deb4f8` | um slot só, unificado |
| `@function` | verde | `func` `#BCD1FF` | linka em `Function` |
| `@keyword` | branco bold | `keyword` verde itálico | linka em `Keyword` |
| `@variable.builtin` | laranja | `const` roxo | linka em `Constant` |
| `@keyword.import` | ciano bold | `keyword` verde | linka em `Include` |
| `Special` | `light_blue` | `fg` | `special` passa a servir `Identifier` |
| `Identifier` | `fg` | `special` `#AFD8ED` | semântica do koda |
| `CursorLineNr` | `#3f815f` | `special` `#AFD8ED` bold | remove hardcode |
| `LineNr` | `#35393d` | `comment` `#3c4349` | remove hardcode |
| `@parameter` | `#add5e7` itálico | `fg` | remove hardcode |
| `DiagnosticError` | `#34282a` | `danger` `#c2606d` | `#34282a` é cor de fundo |
| `DiagnosticHint` | `comment` | `dim` `#7E8B96` | legibilidade |
| `FloatBorder` | `black` sobre `black` | `border` sobre `black` | borda visível |
| `ColorColumn` | `black` | `line` | consistência com CursorLine |
| `Title` | branco | `emphasis` `#BCD1FF` | conforme mapeamento |
| `DiffAdd/Change/Delete` | não definidos | cor + `blend(cor, bg, 0.2)` | dispensa `dark_red` |

`Identifier` em `c.special` tem impacto limitado na prática: em buffers com
parser treesitter, `@variable` (em `c.fg`) se sobrepõe.

## Testes

`tests/init.lua` acrescenta o plenary ao runtimepath, como no koda.

| Spec | Cobre |
|---|---|
| `palette_spec` | toda variante existente exporta uma tabela e tem as 27 chaves como hex válido |
| `config_spec` | defaults, `extend`, `setup`, merge de opções parciais |
| `utils_spec` | `blend`, ciclo de cache (read/write/clear), `unpack` de styles, `resolve` de variante |
| `groups_spec` | `get_hl` de cada grupo retorna tabela; nenhum valor `nil`; detecção de plugin monta o conjunto certo |
| `roteki_spec` | `load()` define `vim.g.colors_name` e aplica highlights; `get_palette` aplica overrides; cache é invalidado quando a paleta muda |

O `palette_spec` é o que protege a adição de variantes futuras: uma chave
esquecida vira um erro de teste em vez de um highlight sem cor.

Execução local:

```sh
nvim --headless -u tests/init.lua \
  -c "PlenaryBustedDirectory tests/ {minimal_init = 'tests/init.lua'}"
```

## CI

`.github/workflows/test.yml`, disparado em pull request para `main` e por
`workflow_dispatch`. Matriz `ubuntu-latest`/`macos-latest` ×
`stable`/`nightly`, instalando o Neovim com `rhysd/action-setup-vim@v1` e
clonando o plenary antes de rodar a suíte.

## README

Instalação (lazy.nvim e vim.pack), a nota de que `setup()` precisa vir
antes do `colorscheme`, o bloco de configuração default comentado, a API
(`get_palette`, `blend`, `:RotekiFetch`), a lista de plugins suportados e
uma seção curta sobre como adicionar uma variante.

## Ordem de execução

1. Limpeza do repo: remover `\`, `.DS_Store`, criar `.gitignore`
2. `types.lua`, `palette/dark.lua`, `utils.lua`, `config.lua`
3. `groups/`: `base`, `syntax`, `treesitter`, `lsp`, depois `init.lua`
4. `groups/` dos 15 plugins
5. `init.lua` e os arquivos em `colors/`; remover `palette.lua` antigo
6. `tests/`
7. CI e README
8. Validação manual: abrir `syntax_test.ts` e conferir os grupos com
   `:Inspect`

Os passos 2–5 derrubam o tema até estarem completos, já que
`colors/roteki.lua` muda de `setup()` para `load()` no passo 5. Convém
executá-los como uma sequência antes de testar no editor.
