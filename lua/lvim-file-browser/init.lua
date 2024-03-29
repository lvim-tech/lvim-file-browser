-- Imports
local fzf_lua = require("fzf-lua")
local path = fzf_lua.path
local actions = require("lvim-file-browser.actions")
local utils = require("lvim-file-browser.utils")
local previewer = require("lvim-file-browser.previewer")

-- Helpers
local entry_to_fullpath = utils.entry_to_fullpath

local function browse(opts)
	opts = opts or {}

	opts.cwd = opts.cwd or vim.loop.cwd()
	opts.prompt = opts.prompt or "Browse❯ "
	opts.previewer = previewer
	opts.fzf_opts = {
		["--header"] = vim.fn.fnameescape(path.HOME_to_tilde(opts.cwd)),
	}

	opts.fn_transform = function(entry)
		return fzf_lua.make_entry.file(entry, { file_icons = true, color_icons = true }):gsub("[*=>@|]$", "")
	end

	opts.actions = {
		["default"] = function(selected)
			if #selected == 0 then
				fzf_lua.actions.resume()
				return false
			end

			local fullpath = entry_to_fullpath(selected[1], opts)

			if vim.fn.isdirectory(fullpath) > 0 then
				browse(vim.tbl_deep_extend("force", opts, { cwd = fullpath }))
			elseif vim.fn.filereadable(fullpath) > 0 then
				fzf_lua.actions.file_edit(selected, opts)
			end
		end,

		["ctrl-g"] = function()
			local fullpath = entry_to_fullpath(opts.cwd, opts)
			local parent = path.parent(fullpath)

			if vim.fn.isdirectory(parent) > 0 then
				browse(vim.tbl_deep_extend("force", opts, { cwd = parent }))
			else
				fzf_lua.actions.resume()
			end
		end,

		["alt-n"] = actions.create,
		["alt-c"] = actions.copy,
		["alt-m"] = actions.move,
		["alt-d"] = actions.delete,
	}

	return fzf_lua.fzf_exec("ls --color=always --almost-all --classify --group-directories-first --literal -1", opts)
end

return { browse = browse, actions = actions }
