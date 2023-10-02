local M = {}

local time_start = {}

local alpha = 2.0 / (10 + 1)

local times = {}

function M.tic(context)
	time_start[context] = vim.fn.reltime()
end

function M.toc(context, state)
	local elapsed = vim.fn.reltimefloat(vim.fn.reltime(time_start[context]))
	local key = context .. "#" .. state
	if times[key] then
		if times[key].maximum and elapsed > times[key].maximum then
			times[key].maximum = elapsed
		end
		times[key].last = elapsed
		times[key].emavg = alpha * elapsed + (1 - alpha) * (times[key].emavg or 0)
	else
		times[key] = {
			maximum = elapsed,
			emavg = elapsed,
			last = elapsed,
		}
	end
end

function table.unique(t, bArray)
	local check = {}
	local n = {}
	local idx = 1
	for k, v in pairs(t) do
		if not check[v] then
			if bArray then
				n[idx] = v
				idx = idx + 1
			else
				n[k] = v
			end
			check[v] = true
		end
	end
	return n
end
local function sort_by_last(a, b)
	local a = times[a].last
	local b = times[b].last
	return a < b
end
local function show_times()
	local keys = vim.fn.keys(times)
	local contexts = vim.tbl_map(function(item)
		return vim.split(item, "#")[1]
	end, keys)
	table.sort(contexts)
	contexts = table.unique(contexts, true)
	if #contexts == 0 then
		vim.api.nvim_echo({ { "no times" } }, false, {})
		return
	end
	vim.api.nvim_echo({ { string.format([[%42s%11s%17s]], "average", "last", "maximum") } }, false, {})
	for _, c in pairs(contexts) do
		vim.api.nvim_echo({ { "[" .. c .. "]", "Special" } }, false, {})
		local states = vim.tbl_filter(function(item)
			local regex = vim.regex([[^\\V]] .. c .. [[#"]])
			if regex:match_str(item) then
				return false
			else
				return true
			end
		end, keys)
		table.sort(states, sort_by_last)
		for _, s in pairs(states) do
			vim.api.nvim_echo({
				{
					string.format(
						[[  %-25s%12.2gms%12.2gms%12.2gms]],
						s,
						1000 * times[s].emavg,
						1000 * times[s].last,
						1000 * times[s].maximum
					),
				},
			}, false, {})
		end
	end
end

vim.api.nvim_create_user_command("MatchupShowTimes", function()
	show_times()
end, { nargs = 0, range = 1 })

vim.api.nvim_create_user_command("MatchupClearTimes", function()
	times = {}
end, { nargs = 0, range = 1 })

return M
