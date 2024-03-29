-- Imports
local path = require('fzf-lua.path')

-- Helpers
local function entry_to_fullpath(entry, opts)
  local file = path.entry_to_file(entry)
  local fullpath = file.path
  if not path.is_absolute(fullpath) then
    fullpath = path.join({ opts.cwd or vim.loop.cwd(), fullpath })
  end

  return fullpath
end

local function input(prompt, text, completion)
  local ok, res = pcall(vim.fn.input, {
    prompt = prompt,
    default = text,
    completion = completion,
    cancelreturn = 3,
  })
  if res == 3 then
    ok, res = false, nil
  end

  return ok and vim.fn.trim(res) or nil
end

return { entry_to_fullpath = entry_to_fullpath, input = input }
