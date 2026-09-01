package.path = package.path .. ";/Users/devsynter/workplace/marco/roteki-theme.nvim/lua/?.lua;/Users/devsynter/workplace/marco/roteki-theme.nvim/lua/?/init.lua"
local ok, err = pcall(function()
  vim = {
    o = { background = "dark" },
    fn = { exists = function() return 0 end },
    cmd = function() end,
    g = {},
    api = {
      nvim_set_hl = function(_, group, hl)
        if type(hl) == "table" and hl[1] ~= nil then
          error("Invalid hl table for group " .. group .. ": " .. vim.inspect(hl))
        end
      end
    },
    tbl_keys = function(t) local k={} for i in pairs(t) do k[#k+1]=i end return k end,
    deepcopy = function(t) return t end,
    deep_equal = function() return true end,
    inspect = require("inspect")
  }
  require("roteki").setup()
  require("roteki").load()
end)
if not ok then print(err) end
