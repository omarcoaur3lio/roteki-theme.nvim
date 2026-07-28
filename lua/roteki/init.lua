local M = {}
local palette = require("roteki.palette").colors

function M.setup()
  -- Forçar cores reais no terminal
  vim.opt.termguicolors = true
  -- Set global background
  vim.g.colors_name = "roteki"

  local highlights = {
    -- Basic UI
    Normal = { fg = palette.fg, bg = palette.bg },
    NormalFloat = { fg = palette.white, bg = palette.black },
    CursorLine = { bg = palette.line_highlight },
    LineNr = { fg = "#35393d" },
    CursorLineNr = { fg = "#3f815f" },
    Visual = { bg = palette.selection },
    Search = { bg = palette.selection },
    IncSearch = { bg = palette.selection },
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
    Folded = { fg = palette.grey, bg = palette.line_highlight },
    Pmenu = { fg = palette.fg, bg = palette.black },
    PmenuSel = { fg = palette.white, bg = palette.selection },
    Comment = { fg = palette.comment, italic = true },

    -- Syntax
    Constant = { fg = palette.green },
    String = { fg = palette.light_blue, italic = true },
    Number = { fg = palette.blue },
    Boolean = { fg = palette.blue },
    Float = { fg = palette.green },
    Identifier = { fg = palette.fg },
    Function = { fg = palette.blue, bold = true },
    Statement = { fg = palette.green, italic = true },
    Operator = { fg = palette.fg },
    Keyword = { fg = palette.green, italic = true },
    PreProc = { fg = palette.green },
    Type = { fg = palette.white, bold = true },
    Special = { fg = palette.light_blue, bold = false },
    Underlined = { underline = true, fg = palette.red },
    Error = { fg = palette.red },
    Todo = { fg = palette.yellow, bold = true },

    -- TreeSitter
    ["@variable"] = { fg = palette.fg },
    ["@variable.builtin"] = { fg = palette.orange },
    ["@function"] = { fg = palette.green, bold = true},
    ["@function.call"] = { fg = palette.white },
    ["@keyword"] = { fg = palette.white, bold = true },
    ["@keyword.function"] = { fg = palette.blue, bold = true },
    ["@string"] = { fg = palette.light_blue },
    ["@number"] = { fg = palette.purple },
    ["@boolean"] = { fg = palette.purple },
    ["@type"] = { fg = palette.white },
    ["@constructor"] = { fg = palette.white, bold = true },
    ["@parameter"] = { fg = "#add5e7", italic = true },
    ["@comment"] = { fg = palette.comment, italic = true },
    ["@punctuation.bracket"] = { fg = palette.fg },
    ["@punctuation.delimiter"] = { fg = palette.fg },
    ["@tag"] = { fg = palette.green, bold = true },
    ["@tag.delimiter"] = { fg = palette.fg },
    ["@tag.delimiter.tsx"] = { fg = palette.fg },
    ["@tag.delimiter.jsx"] = { fg = palette.fg },
    ["@tag.attribute"] = { fg = palette.fg },
    ["@keyword.import"] = { fg = palette.cyan, bold = true},

    -- LSP

    LspReferenceText = { bg = palette.fg, fg = palette.black },
    LspReferenceRead = { bg = palette.selection, fg = palette.white },
    LspReferenceWrite = { bg = palette.white, fg = palette.black },

    DiagnosticError = { fg = palette.dark_red },
    DiagnosticWarn = { fg = palette.yellow },
    DiagnosticInfo = { fg = palette.cyan },
    DiagnosticHint = { fg = palette.comment },
    DiagnosticUnderlineError = { underline = true, sp = palette.dark_red },
    DiagnosticUnderlineWarn = { underline = true, sp = palette.comment },
    DiagnosticUnderlineInfo = { underline = true, sp = palette.blue },
    DiagnosticUnderlineHint = { underline = true, sp = palette.comment },

    DiagnosticFloatingError = { fg = palette.red },
    DiagnosticFloatingWarn = { fg = palette.yellow },
    DiagnosticFloatingInfo = { fg = palette.cyan },
    DiagnosticFloatingHint = { fg = palette.fg },

    FloatBorder = { fg = palette.black, bg = palette.black },

    -- Telescope
    TelescopeBorder = { fg = palette.border, bg = palette.bg },
    TelescopePromptBorder = { fg = palette.border, bg = palette.bg },
    TelescopeResultsBorder = { fg = palette.border, bg = palette.bg },
    TelescopePreviewBorder = { fg = palette.border, bg = palette.bg },
    TelescopePromptTitle = { fg = palette.white, bold = true },
    TelescopeResultsTitle = { fg = palette.white, bold = true },
    TelescopePreviewTitle = { fg = palette.white, bold = true },
    TelescopePromptPrefix = { fg = palette.white, bold = true },
    TelescopeSelection = { bg = palette.selection },
    TelescopeMatching = { fg = palette.white, bold = true },
  
    MsgArea = { fg = palette.fg, bg = palette.bg },
    ModeMsg = { fg = palette.yellow, bg = palette.bg },
  }

  for group, opts in pairs(highlights) do
    vim.api.nvim_set_hl(0, group, opts)
  end
end

return M
