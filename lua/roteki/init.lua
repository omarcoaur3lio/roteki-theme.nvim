local M = {}
local palette = require("roteki.palette").colors

function M.setup()
  -- Set global background
  vim.g.colors_name = "roteki"

  local highlights = {
    -- Basic UI
    Normal = { fg = palette.fg, bg = palette.bg },
    NormalFloat = { fg = palette.fg, bg = palette.black },
    CursorLine = { bg = palette.line_highlight },
    LineNr = { fg = "#8f969b" },
    CursorLineNr = { fg = "#547f86" },
    Visual = { bg = palette.selection },
    Search = { bg = "#313a3d" },
    IncSearch = { bg = "#313a3d" },
    StatusLine = { fg = palette.fg, bg = palette.black },
    StatusLineNC = { fg = palette.grey, bg = palette.black },
    VertSplit = { fg = palette.border },
    WinSeparator = { fg = palette.border },
    SignColumn = { bg = palette.bg },
    EndOfBuffer = { fg = palette.bg },
    ColorColumn = { bg = palette.black },
    Directory = { fg = palette.blue },
    ErrorMsg = { fg = palette.red },
    WarningMsg = { fg = palette.yellow },
    Folded = { fg = palette.grey, bg = palette.black },
    Pmenu = { fg = palette.fg, bg = palette.black },
    PmenuSel = { fg = palette.white, bg = palette.selection },
    Comment = { fg = palette.comment, italic = true },

    -- Syntax
    Constant = { fg = palette.green },
    String = { fg = "#9ddef8", italic = true },
    Number = { fg = palette.green },
    Boolean = { fg = palette.green },
    Float = { fg = palette.green },
    Identifier = { fg = palette.fg },
    Function = { fg = palette.blue, bold = true },
    Statement = { fg = palette.green, italic = true },
    Operator = { fg = palette.fg },
    Keyword = { fg = palette.green, italic = true },
    PreProc = { fg = palette.green },
    Type = { fg = palette.white, bold = true },
    Special = { fg = palette.blue },
    Underlined = { underline = true },
    Error = { fg = palette.red },
    Todo = { fg = palette.yellow, bold = true },

    -- TreeSitter
    ["@variable"] = { fg = palette.fg },
    ["@variable.builtin"] = { fg = "#809fb6", bold = true },
    ["@function"] = { fg = palette.blue, bold = true },
    ["@function.call"] = { fg = palette.green, italic = true },
    ["@keyword"] = { fg = palette.green, italic = true },
    ["@keyword.function"] = { fg = palette.blue, bold = true },
    ["@string"] = { fg = "#9ddef8", italic = true },
    ["@number"] = { fg = palette.green },
    ["@type"] = { fg = palette.white, bold = true },
    ["@constructor"] = { fg = palette.white, bold = true },
    ["@parameter"] = { fg = "#add5e7", italic = true },
    ["@comment"] = { fg = palette.comment, italic = true },
    ["@punctuation.bracket"] = { fg = palette.fg },
    ["@punctuation.delimiter"] = { fg = palette.grey },
    ["@tag"] = { fg = palette.green },
    ["@tag.delimiter"] = { fg = "#88bb10" },
    ["@tag.attribute"] = { fg = palette.white },

    -- LSP
    LspReferenceText = { bg = palette.grey },
    LspReferenceRead = { bg = palette.grey },
    LspReferenceWrite = { bg = palette.grey },
    DiagnosticError = { fg = palette.red },
    DiagnosticWarn = { fg = palette.yellow },
    DiagnosticInfo = { fg = palette.cyan },
    DiagnosticHint = { fg = palette.cyan },
  }

  for group, opts in pairs(highlights) do
    vim.api.nvim_set_hl(0, group, opts)
  end
end

return M
