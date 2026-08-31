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
