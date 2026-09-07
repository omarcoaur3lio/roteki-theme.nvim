local palette = require("roteki.palette.dark")

local theme = {}

theme.normal = {
  a = { bg = palette.emphasis, fg = palette.bg, gui = 'bold' },
  b = { bg = palette.black, fg = palette.fg },
  c = { bg = palette.line, fg = palette.fg },
}

theme.insert = {
  a = { bg = palette.success, fg = palette.bg, gui = 'bold' },
  b = { bg = palette.black, fg = palette.fg },
  c = { bg = palette.line, fg = palette.fg },
}

theme.visual = {
  a = { bg = palette.selection, fg = palette.type, gui = 'bold' },
  b = { bg = palette.black, fg = palette.fg },
  c = { bg = palette.line, fg = palette.fg },
}

theme.replace = {
  a = { bg = palette.orange, fg = palette.bg, gui = 'bold' },
  b = { bg = palette.black, fg = palette.fg },
  c = { bg = palette.line, fg = palette.fg },
}

theme.command = {
  a = { bg = palette.const, fg = palette.bg, gui = 'bold' },
  b = { bg = palette.black, fg = palette.fg },
  c = { bg = palette.line, fg = palette.fg },
}

theme.inactive = {
  a = { bg = palette.bg, fg = palette.dim, gui = 'bold' },
  b = { bg = palette.bg, fg = palette.dim },
  c = { bg = palette.bg, fg = palette.dim },
}

return theme
