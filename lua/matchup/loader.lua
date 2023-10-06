local M = {}
local perf = require("matchup.perf")
local ts_engine = require("treesitter-matchup.internal")
local regex_helper = require("matchup.regex_helper")

local function init_buffer()
	vim.api.nvim_call_function("matchup#loader#init_buffer", {})
end

local regex_empty_str = vim.regex([[^\s*$]])

function M.init_delim_lists_fast(mps)
	local lists = { delim_tex = { regex = {}, regex_capture = {} } }
	local sets = vim.fn.split(mps, ",")
	local seen = {}

	for _, s in pairs(sets) do
		if not regex_empty_str:match_str(s) then
			if s == "[:]" or s == [=[\[:\]]=] then
				s = [=[\[:]]=]
			end

			if not vim.tbl_contains(seen, s) then
				seen[s] = 1

				local words = vim.fn.split(s, ":")
				if #words >= 2 then
					table.insert(lists.delim_tex.regex, {
						open = words[1],
						close = words[#words],
						mid = "",
						mid_list = {},
						augments = {},
					})
					table.insert(lists.delim_tex.regex_capture, {
						open = words[1],
						close = words[#words],
						mid = "",
						mid_list = {},
						need_grp = {},
						grp_renu = {},
						aug_comp = {},
						has_zs = 0,
						extra_list = { {}, {} },
						extra_info = { has_zs = 0 },
					})
				end
			end
		end
	end

	-- TODO if this is empty!
	-- generate combined lists
	lists.delim_all = {}
	lists.all = {}
	for _, k in pairs({ "regex", "regex_capture" }) do
		lists.delim_all[k] = lists.delim_tex[k]
		lists.all[k] = lists.delim_all[k]
	end

	return lists
end

function M.init_delim_lists(no_words, filter_words)
	local lists = {
		delim_tex = {
			regex = {},
			regex_capture = {},
			midmap = {},
		},
	}

	-- very tricky examples:
	-- good: let b:match_words = '\(\(foo\)\(bar\)\):\3\2:end\1'
	-- bad:  let b:match_words = '\(foo\)\(bar\):more\1:and\2:end\1\2'

	-- *subtlety*: there is a huge assumption in matchit:
	--   ``It should be possible to resolve back references
	--     from any pattern in the group.''
	-- we don't explicitly check this, but the behavior might
	-- be unpredictable if such groups are encountered.. (ref-1)

	local filetype = vim.bo.filetype
	if vim.g.matchup_hotfix and vim.fn.has_key(vim.g.matchup_hotfix, filetype) then
		vim.api.nvim_command([=[call call(g:matchup_hotfix[&filetype], [])]=])
	elseif vim.g["matchup_hotfix_" .. filetype] then
		vim.api.nvim_command([=[call call(g:matchup_hotfix_{&filetype}, [])]=])
	elseif vim.b.matchup_hotfix then
		vim.api.nvim_command([=[call call(b:matchup_hotfix, [])]=])
	end

	-- parse matchpairs and b:match_words
	local match_words = (not no_words) and (vim.b.match_words or "") or ""
	if not vim.fn.empty(match_words) and match_words ~= ":" then
		match_words = vim.b.match_words
	end
	local simple = vim.fn.empty(match_words)

	local mps = vim.fn.escape(vim.bo.matchpairs, "[$^.*~\\/?]")
	if vim.b.matchup_delim_nomatchpairs and not vim.fn.empty(mps) then
		match_words = match_words .. (simple and "" or ",") .. mps
	end

	if simple then
		return M.init_delim_lists_fast(match_words)
	end

	local sets = vim.fn.split(match_words, vim.g["matchup#re#not_bslash"] .. ",")

	if filter_words then
		vim.fn.filter(sets, [[v:val =~? "^[^a-zA-Z]\\{3,18\\}$"]])
		if vim.fn.empty(sets) then
			return M.init_delim_lists_fast(match_words)
		end
	end

	local seen = {}
	for _, s in pairs(sets) do
		-- very special case, escape bare [:]
		-- TODO: the bare [] bug might show up in other places too
		if s == "[:]" or s == [=[\[:\]]=] then
			s = [=[\[:]]=]
		end

		if not vim.fn.has_key(seen, s) then
			seen[s] = true

			if not regex_empty_str:match_str(s) then
				local words = vim.fn.split(s, vim.g["matchup#re#not_bslash" .. ":"])

				if #words >= 2 then
					-- stores series-level information
					local extra_info = {}

					-- stores information for each word

					local extra_list = {}

					-- pre-process various \g{special} instructions
					local replacement = {
						hlend = [[\%(hlend\)\{0}]],
						syn = "",
					}
					for i = 1, #words do
						local special_flags = {}
						_G.__matchup_helper = function(submatch1, submatch2)
							table.insert(special_flags, { submatch1, submatch2 })
							return replacement[submatch1]
						end
						words[i] = vim.fn.substitute(
							words[i],
							vim.g["matchup#re#gspec"],
							[[\=luaeval("__matchup_helper('" .. submatch(1) ..  "', '" .. submatch(2) .. "')")]],
							"g"
						)
						_G.__matchup_helper = nil
						for _, v in pairs(special_flags) do
							local f = v[1]
							local a = v[2]
							extra_list[i][f] = vim.fn.len(a) > 0 and a or 1
						end
					end

					--- we will resolve backrefs to produce two sets of words,
					--- one with \(foo\)s and one with \1s, along with a set of
					--- bookkeeping structures
					local words_backref = vim.deepcopy(words)

					--- *subtlety*: backref numbers refer to the capture groups
					--- in the 'open' pattern so we have to carefully keep track
					--- of the group renumbering
					local group_renumber = {}
					local augment_comp = {}
					local all_needed_groups = {}

					--- *subtlety*: when replacing things like \1 with \(...\)
					--- the insertion could possibly contain back references of
					--- its own; this poses a very difficult bookkeeping problem,
					--- so we just disallow it.. (ref-2)

					--- get the groups like \(foo\) in the 'open' pattern
					local cg = vim.api.nvim_call_function("matchup#loader#get_capture_groups", { words[1] })

					-- if any of these contain \d raise a warning
					-- and substitute it out (ref-2)
					for _, cg_i in vim.fn.keys(cg) do
						if regex_helper.matchstr(cg[cg_i].str, vim.g["matchup#re#backref"]) then
							vim.api.nvim_echo({
								{
									"match-up: capture group" .. cg[cg_i].str .. "should not contain backrefs (ref-2)",
									"WarningMsg",
								},
							}, false, {})

							cg[cg_i].str = vim.fn.substitute(cg[cg_i].str, vim.g["matchup#re#backref"], "", "g")
						end
					end
					-- for the 'open' pattern, create a series of replacements
					-- of the capture groups with corresponding \9, \8, ..., \1
					-- this must be done deepest to shallowest
					local augments = {}
					local order = vim.api.nvim_call_function("matchup#loader#capture_group_replacement_order", { cg })

					local curaug = words[1]
					-- TODO: \0 should match the whole pattern..
					-- augments[0] is the original words[0] with original capture groups
					augments[0] = curaug -- XXX does putting this in 0 make sense?
					for _, j in pairs(order) do
						-- these indexes are not invalid because we work backwards
						curaug = vim.fn.strpart(curaug, 0, cg[j].pos[0])
							.. ([[\]] .. j)
							.. vim.fn.strpart(curaug, cg[j].pos[1])
						augments[j] = curaug
					end

					for i = 2, #words do
					end
				end
			end
		end
	end
end

function M.remove_capture_groups(re)
	local sub_grp = [[\(\\\@<!\(\\\\\)*\)\@<=\\(]]
	return vim.fn.substitute(re, sub_grp, [[\\%(]], "g")
end

function M.capture_group_replacement_order(cg)
	local keys = vim.fn.keys(cg)
	local order = vim.fn.reverse(vim.fn.sort(keys, "N"))
	table.sort(order, function(a, b)
		return b.depth < a.depth
	end)
	return order
end

local function init_buffer_lua()
	perf.tic("loader_init_buffer")

	local has_ts = false
	local no_words = false
	local filt_words = false

	local current_buf = vim.api.nvim_get_current_buf()
	if ts_engine.is_enabled(current_buf) then
		has_ts = true
		if ts_engine.get_option(current_buf, "include_match_words") then
			filt_words = true
		else
			no_words = true
		end
	end

	local has_ts_hl = false
	if ts_engine.is_hl_enabled(current_buf) then
		has_ts_hl = true

		if ts_engine.get_option(current_buf, "additional_vim_regex_highlighting") then
			if vim.vn.empty(vim.bo.syntax) then
				vim.bo.syntax = "ON"
			else
				local group = vim.api.nvim_create_augroup("matchup_syntax", { clear = true })
				vim.api.nvim_create_autocmd({ "VimEnter" }, {
					pattern = "*",
					callback = function()
						if vim.fn.empty(vim.bo.syntax) then
							vim.bo.synatx = "ON"
						end
					end,
				})
			end
		end

		-- initialize lists of delimiter pairs and regular expressions
		-- this is the data obtained from parsing b:match_words
	end
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
