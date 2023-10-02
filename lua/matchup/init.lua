local M = {}

local function init_option(option, default)
	if vim.g[option] == nil then
		vim.g[option] = default
	end
end

function M.init_options()
	init_option("matchup_matchparen_enabled", 1)

	local offs = { method = "status" }
	if vim.g.matchup_matchparen_status_offscreen == nil or vim.g.matchup_matchparen_status_offscreen == 1 then
		offs = {}
	end
	if vim.g.matchup_matchparen_status_offscreen_manual == 1 then
		offs.method = "status_manual"
	end
	if vim.g.matchup_matchparen_scrolloff == 1 then
		offs.scrolloff = vim.g.matchup_matchparen_scrolloff
	end
	init_option("matchup_matchparen_offscreen", offs)
	init_option("matchup_matchparen_singleton", 0)
	init_option("matchup_matchparen_deferred", 0)
	init_option("matchup_matchparen_deferred_show_delay", 50)
	init_option("matchup_matchparen_deferred_hide_delay", 700)
	init_option("matchup_matchparen_deferred_fade_time", 0)
	init_option("matchup_matchparen_stopline", 400)
	init_option("matchup_matchparen_pumvisible", 1)
	init_option("matchup_matchparen_nomode", "")
	init_option("matchup_matchparen_hi_surround_always", 0)
	init_option("matchup_matchparen_hi_background", 0)
	init_option("matchup_matchparen_start_sign", "▶")
	init_option("matchup_matchparen_end_sign", "◀")

	init_option("matchup_matchparen_timeout", vim.g.matchparen_timeout or 300)
	init_option("matchup_matchparen_insert_timeout", vim.g.matchparen_insert_timeout or 60)

	init_option("matchup_delim_count_fail", 0)
	init_option("matchup_delim_count_max", 8)
	init_option("matchup_delim_start_plaintext", 1)
	init_option("matchup_delim_noskips", 0)
	init_option("matchup_delim_nomids", 0)

	init_option("matchup_motion_enabled", 1)
	init_option("matchup_motion_cursor_end", 1)
	init_option("matchup_motion_override_Npercent", 6)
	init_option("matchup_motion_keepjumps", 0)

	init_option("matchup_text_obj_enabled", 1)
	init_option("matchup_text_obj_linewise_operators", { "d", "y" })

	init_option("matchup_transmute_enabled", 0)
	init_option("matchup_transmute_breakundo", 0)

	init_option("matchup_mouse_enabled", 1)

	init_option("matchup_surround_enabled", 0)

	init_option("matchup_where_enabled", 1)
	init_option("matchup_where_separator", "")

	init_option("matchup_matchpref", {})
end

return M
