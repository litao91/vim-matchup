local M = {}
local function init_buffer()
	vim.api.nvim_call_function("matchup#loader#init_buffer", {})
end

local function bufwinenter()
	vim.api.nvim_call_function("matchup#loader#bufwinenter", {})
end

function M.init_module()
	local group = vim.api.nvim_create_augroup("matchup_filetype", { clear = true })
	vim.api.nvim_create_autocmd({ "FileType" }, {
		pattern = "*",
		group = group,
		callback = function()
			init_buffer()
		end,
	})
	if vim.g.matchup_delim_start_plaintext then
		vim.api.nvim_create_autocmd({ "BufWinEnter", "CmdWinEnter" }, {
			pattern = "*",
			callback = function()
				bufwinenter()
			end,
		})
	end
end

return M
