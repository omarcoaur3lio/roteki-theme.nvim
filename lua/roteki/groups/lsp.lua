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
