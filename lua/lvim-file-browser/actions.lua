-- Imports
local actions = require("fzf-lua.actions")
local path = require("fzf-lua.path")
local utils = require("fzf-lua.utils")
local fb_utils = require("lvim-file-browser.utils")

-- Helpers
local entry_to_fullpath = fb_utils.entry_to_fullpath
local input = fb_utils.input

local function filter_valid_sources(selected, opts)
	local sources = {}

	for _, entry in ipairs(selected) do
		local fullpath_to_source = entry_to_fullpath(entry, opts)

		if vim.fn.isdirectory(fullpath_to_source) > 0 or vim.fn.filereadable(fullpath_to_source) > 0 then
			table.insert(sources, fullpath_to_source)
		end
	end

	return sources
end

local fs = {}

fs.exists = function(target)
	return vim.fn.isdirectory(target) > 0 or vim.fn.filereadable(target) > 0
end

fs.create_directory = function(directory)
	if fs.exists(directory) then
		return
	end

	if vim.fn.executable("mkdir") then
		vim.fn.system(vim.list_extend({ "mkdir", "-p", "--" }, { directory }))
	else
		-- TODO: Handle recursive creation with `vim.loop`
		vim.loop.fs_mkdir(directory, 493) -- 0x755
	end
end

fs.create_file = function(file)
	if fs.exists(file) then
		return
	end

	if vim.fn.executable("touch") then
		vim.fn.system(vim.list_extend({ "touch", "--" }, { file }))
	else
		local file_handler = vim.loop.fs_open(file, "w", 420) -- 0x644
		if file_handler then
			vim.loop.fs_close(file_handler)
		end
	end
end

fs.copy = function(sources, destination)
	if vim.fn.executable("cp") then
		vim.fn.system(vim.list_extend(vim.list_extend({ "cp", "-r", "--" }, sources), { destination }))
	else
		for _, source in ipairs(sources) do
			if vim.fn.isdirectory(source) > 0 then
			-- TODO: Handle recursive copy with `vim.loop`
			else
				vim.loop.fs_copyfile(
					source,
					vim.fn.isdirectory(destination) > 0 and path.join({ destination, path.basename(source) })
						or destination
				)
			end
		end
	end
end

fs.move = function(sources, destination)
	if vim.fn.executable("mv") then
		vim.fn.system(vim.list_extend(vim.list_extend({ "mv", "--" }, sources), { destination }))
	else
		for _, source in ipairs(sources) do
			if vim.fn.isdirectory(source) > 0 then
			-- TODO: Handle recursive move with `vim.loop`
			else
				if
					vim.loop.fs_copyfile(
						source,
						vim.fn.isdirectory(destination) > 0 and path.join({ destination, path.basename(source) })
							or destination
					)
				then
					vim.loop.fs_unlink(source)
				end
			end
		end
	end
end

fs.delete = function(sources)
	if vim.fn.executable("rm") then
		vim.fn.system(vim.list_extend({ "rm", "-rf", "--" }, sources))
	else
		for _, source in ipairs(sources) do
			if vim.fn.isdirectory(source) > 0 then
			-- TODO: Handle recursive delete with `vim.loop`
			else
				for _, source in ipairs(sources) do
					if vim.fn.isdirectory(source) > 0 then
						vim.loop.fs_rmdir(source)
					elseif vim.fn.filereadable(source) > 0 then
						vim.loop.fs_unlink(source)
					end
				end
			end
		end
	end
end

fs.ensure_parent_directory_exists = function(sources, destination)
	local destination_parent = path.parent(destination)

	if (#sources > 1 or vim.fn.isdirectory(sources[1]) > 0) and vim.fn.filereadable(destination) > 0 then
		utils.err("Destination must be a directory")
		return false
	end

	if #sources == 1 and vim.fn.isdirectory(destination_parent) == 0 then
		fs.create_directory(destination_parent)
	elseif #sources > 1 and vim.fn.isdirectory(destination) == 0 then
		fs.create_directory(destination)
	end

	return true
end

-- Actions
local M = {}

M.create = {
	function(selected, opts)
		local destination = input("Create " .. path.add_trailing(path.HOME_to_tilde(opts.cwd)), nil, "file")
		if not destination or #destination == 0 then
			return false
		end

		local fullpath_to_destination = entry_to_fullpath(destination, opts)
		if fs.exists(path.remove_trailing(fullpath_to_destination)) then
			utils.err("Already exists")
			return false
		end

		if path.ends_with_separator(fullpath_to_destination) then
			-- Directory
			fs.create_directory(fullpath_to_destination)
		else
			-- File
			fs.create_directory(path.parent(fullpath_to_destination))
			fs.create_file(fullpath_to_destination)
		end

		return true
	end,
	actions.resume,
}

M.rename = {
	function(selected, opts)
		if #selected == 0 then
			return false
		end

		local fullpath_to_file = entry_to_fullpath(selected[1], opts)
		local relpath_to_file = path.HOME_to_tilde(fullpath_to_file)

		local target_file = input("Rename to " .. path.parent(relpath_to_file), path.basename(relpath_to_file), "file")
		if not target_file or #target_file == 0 then
			return false
		end

		local fullpath_to_target_file = entry_to_fullpath(target_file, opts)
		if vim.fn.filereadable(fullpath_to_target_file) == 0 or (input("Overwrite? [y/n] ") == "y") then
			vim.loop.fs_rename(fullpath_to_file, fullpath_to_target_file)
		end

		return true
	end,
	actions.resume,
}

M.copy = {
	function(selected, opts)
		local sources = filter_valid_sources(selected, opts)
		if #sources == 0 then
			return false
		end

		local destination = input(
			"Copy to ",
			path.join({ path.HOME_to_tilde(opts.cwd), #sources == 1 and path.basename(sources[1]) or "" }),
			"file"
		)
		if not destination or #destination == 0 then
			return false
		end

		local fullpath_to_destination = entry_to_fullpath(destination, opts)

		if fs.ensure_parent_directory_exists(sources, fullpath_to_destination) then
			fs.copy(sources, fullpath_to_destination)
		end

		return true
	end,
	actions.resume,
}

M.move = {
	function(selected, opts)
		local sources = filter_valid_sources(selected, opts)
		if #sources == 0 then
			return false
		end

		local destination = input(
			"Move to ",
			path.join({ path.HOME_to_tilde(opts.cwd), #sources == 1 and path.basename(sources[1]) or "" }),
			"file"
		)
		if not destination or #destination == 0 then
			return false
		end

		local fullpath_to_destination = entry_to_fullpath(destination, opts)

		if fs.ensure_parent_directory_exists(sources, fullpath_to_destination) then
			fs.move(sources, fullpath_to_destination)
		end

		return true
	end,
	actions.resume,
}

M.delete = {
	function(selected, opts)
		local sources = filter_valid_sources(selected, opts)
		if #sources == 0 then
			return false
		end

		local msg
		if #sources > 1 then
			msg = "Delete " .. #sources .. " entries?"
		else
			local source = sources[1]
			if vim.fn.isdirectory(source) > 1 then
				source = path.add_trailing(source)
			end

			msg = 'Delete "' .. path.HOME_to_tilde(source) .. '"?'
		end

		if input(msg .. " [y/n] ") ~= "y" then
			return false
		end

		fs.delete(sources)

		return true
	end,
	actions.resume,
}

return M
