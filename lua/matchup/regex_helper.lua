local M = {}
-- help /ordinary-atom
-- help non-greedy
-- escape >=< to \> \= \< but if it dont have \>
local escape_vim_magic = function(query)
	query = string.gsub(query, "@", "\\@")
	local regex = [=[(\\)@<![><=](\\)@!]=]
	return vim.fn.substitute(query, "\\v" .. regex, [[\\\0]], "g")
end

M.matchstr = function(search_text, search_query)
	local ok, match = pcall(vim.fn.matchstr, search_text, "\\v" .. escape_vim_magic(search_query))
	if ok then
		return match
	end
end

return M
