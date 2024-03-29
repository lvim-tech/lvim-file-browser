-- Imports
local path = require("fzf-lua.path")
local builtin = require("fzf-lua.previewer.builtin")

-- Previewer
local FileBrowserPreviewer = builtin.buffer_or_file:extend()

function FileBrowserPreviewer:new(o, opts, fzf_win)
	FileBrowserPreviewer.super.new(self, o, opts, fzf_win)
	setmetatable(self, FileBrowserPreviewer)

	return self
end

function FileBrowserPreviewer:populate_preview_buf(entry_str)
	if not self.win or not self.win:validate_preview() then
		return
	end

	local entry = self:parse_entry(entry_str)
	if vim.tbl_isempty(entry) then
		return
	end

	if self._job_id and self._job_id > 0 then
		vim.fn.jobstop(self._job_id)
		self._job_id = nil
	end

	if vim.fn.isdirectory(entry.path) > 0 then
		local tmpbuf = self:get_tmp_buffer()

		self:populate_terminal_cmd(
			tmpbuf,
			{ "ls", "--color=always", "--almost-all", "--classify", "--group-directories-first", "--literal", "-1" },
			entry
		)
	else
		self.super.populate_preview_buf(self, entry_str)
	end
end

function FileBrowserPreviewer:update_border(entry)
	if vim.fn.isdirectory(entry.path) > 0 then
		self.win:update_title(" " .. path.basename(entry.path) .. " ")
		self.win:update_scrollbar(entry.no_scrollbar)
	else
		self.super.update_border(self, entry)
	end
end

return FileBrowserPreviewer
