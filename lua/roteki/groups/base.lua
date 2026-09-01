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
    PmenuThumb        = { bg = c.border },
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
