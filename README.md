# roteki.nvim

Um tema escuro para [Neovim](https://github.com/neovim/neovim), escrito em Lua.

## Instalação

Com [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
  "omarcoaur3lio/roteki-theme.nvim",
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
vim.pack.add({ "https://github.com/omarcoaur3lio/roteki-theme.nvim" })
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
nvim --headless -u tests/init.lua -c "PlenaryBustedDirectory tests/ {minimal_init = 'tests/init.lua', sequential = true}"
```
