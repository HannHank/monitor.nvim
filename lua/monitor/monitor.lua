local popup = require("plenary.popup")
local utils = require("monitor.utils")
local M = {}
Monitor_win_id = nil
Monitor_bufnr = nil
function M.close_menu()
	vim.api.nvim_win_close(Monitor_win_id, true)
	Monitor_win_id = nil
	Monitor_bufnr = nil
end

local function create_window()
	if Monitor_win_id ~= nil and vim.api.nvim_win_is_valid(Monitor_win_id) then
		M.close_menu()
		return
	end
	local width = 60
	local height = 10
	local borderchars = { "─", "│", "─", "│", "╭", "╮", "╯", "╰" }
	local bufnr = vim.api.nvim_create_buf(false, false)
	local win_id, win = popup.create(bufnr, {
		title = "Monitor",
		highlight = "MonitorWindow",
		borderchars = borderchars,
		minheight = height,
		minwidth = width,
		line = math.floor(((vim.o.lines - height) / 2) - 1),
		col = math.floor((vim.o.columns - width) / 2),
	})
	vim.api.nvim_win_set_option(
		win.border.win_id,
		"winhl",
		"Normal:MonitorBorder")
	return {
		bufnr = bufnr,
		win_id = win_id,
	}
end

local function get_menu_items()
	local lines = vim.api.nvim_buf_get_lines(Monitor_bufnr, 0, -1, true)
	local indices = {}

	for _, line in pairs(lines) do
		if not utils.is_white_space(line) then
			table.insert(indices, line)
		end
	end

	return indices
end

local function getActiveDisplays()
	local handle, err = io.popen("xrandr --listactivemonitors")
	if not handle then
		print("Error: " .. err)
		return
	end
	local result = handle:read("*a")
	local content = {}
	for line in result:gmatch("[^\r\n]+") do
		local words = {}
		-- not elegant but the last word is always the active monitor
		for word in line:gmatch("%S+") do
			table.insert(words, word)
		end
		if #words == 4 then
			table.insert(content, words[#words])
		end
	end
	handle:close()
	return content
end


local function getConnectedDisplays()
	local activeDisplays = getActiveDisplays()
	local handle, err = io.popen("xrandr")
	if not handle then
		print("Error: " .. err)
		return
	end
	local result = handle:read("*a")
	local content = {}
	local index = 0
	for line in result:gmatch("[^\r\n]+") do
		if line:match("(%S+ connected)") then
			local current_monitor = line:match("(%S+) connected")
			if line:match("primary") then
				line = "[0] " .. line:match("(%S+ connected)") .. " (primary)"
				-- if activeDisplays ~= nil then
				-- 	table.remove(activeDisplays,
				-- 		utils.an_index_of(current_monitor, activeDisplays))
				-- end
			else
				if utils.is_string_in_list(current_monitor, activeDisplays) then
					-- if activeDisplays ~= nil then
					-- 	table.remove(activeDisplays,
					-- 		utils.an_index_of(current_monitor, activeDisplays))
					-- end
					line = "[" .. index .. "] " .. line:match("(%S+ connected)")
				else
					line = "[-1] " .. line
				end
			end
			table.insert(content, line)
			index = index + 1
		end
	end
	-- if activeDisplays ~= nil then
	-- 	for i, line in pairs(activeDisplays) do
	-- 	    -- substract -1 because of primary display
	-- 		table.insert(content, "[" .. (i + index - 1) .. "] " .. line .. " connected")
	-- 	end
	-- end
	handle:close()
	return content
end
local function removeNotConnectedDisplays()
	local activeDisplays = getActiveDisplays()
	if activeDisplays ~= nil then
		local handle, err = io.popen("xrandr")
		local result = handle:read("*a")
		if not handle then
			print("Error: " .. err)
			return
		end
		for line in result:gmatch("[^\r\n]+") do
			local monitor = line:match("(%S+) connected")
			if monitor ~= nil then
				table.remove(activeDisplays, utils.an_index_of(monitor, activeDisplays))
			end
		end
		-- now remove all left overs dangling config
		local output = ""
		for _, lostActiveMonitor in pairs(activeDisplays) do
			output = output .. " --output " .. lostActiveMonitor .. " --off"
		end
		-- remove them

		local cmd = "xrandr " .. output
		local handle, err = io.popen(cmd)
	else
		print("Error no active Monitor")
		return
	end
end

function M.activate(options)
	removeNotConnectedDisplays()
	local lines = get_menu_items()
	-- find primary display
	local primaryIndex = nil
	for index, line in pairs(lines) do
		if line:match("primary") then
			primaryIndex = index
		end
	end
	local primary = "--output " .. lines[primaryIndex]:match("(%S+) connected") .. " --primary --auto"
	local output = primary
	for index, line in pairs(lines) do
		if index ~= primaryIndex then
			local sameAs = false
			local displayGroup = tonumber(line:match("%[([-]?%d+)%]"))
			if displayGroup == -1 then
				output = output .. " --output " ..
				    line:match("(%S+) connected") ..
				    " --auto --off"
			end
			for _index, _line in pairs(lines) do
				if tonumber(_line:match("%[(%d+)%]")) == displayGroup and _index ~= index then
					sameAs = true
					output = output .. " --output " ..
					    line:match("(%S+) connected") ..
					    " --auto --same-as " .. _line:match("(%S+) connected")
				end
			end
			if not sameAs then
				if index > primaryIndex then
					output = output .. " --output " ..
					    line:match("(%S+) connected") ..
					    " --auto --right-of " .. lines[primaryIndex]:match("(%S+) connected")
				else
					output = output .. " --output " ..
					    line:match("(%S+) connected") ..
					    " --auto --left-of " .. lines[primaryIndex]:match("(%S+) connected")
				end
			end
		end
	end
	if options.close then
		M.close_menu()
	end
	local cmd = "xrandr " .. output
	local handle, err = io.popen(cmd)
	-- print(cmd)
end

function M.monitor(...)
	local args = { ... }
	-- loop over all result lines
	local content = getConnectedDisplays()
	local win_info = create_window()
	if win_info == nil then
		return
	end
	Monitor_win_id = win_info.win_id
	Monitor_bufnr = win_info.bufnr
	-- check for toggle
	vim.api.nvim_win_set_option(Monitor_win_id, "number", true)
	vim.api.nvim_buf_set_name(Monitor_bufnr, "Monitor-menu")
	vim.api.nvim_buf_set_lines(Monitor_bufnr, 0, #content, false, content)
	vim.api.nvim_buf_set_option(Monitor_bufnr, "filetype", "monitor")
	vim.api.nvim_buf_set_option(Monitor_bufnr, "buftype", "acwrite")
	vim.api.nvim_buf_set_option(Monitor_bufnr, "bufhidden", "delete")
	vim.api.nvim_buf_set_keymap(
		Monitor_bufnr,
		"n",
		"<CR>",
		"<Cmd>lua require('monitor.monitor').activate({close=true})<CR>",
		{}
	)
	vim.api.nvim_buf_set_keymap(
		Monitor_bufnr,
		"n",
		"<space>t",
		"<Cmd>lua require('monitor.monitor').activate({close=false})<CR>",
		{}
	)
	vim.api.nvim_buf_set_keymap(
		Monitor_bufnr,
		"n",
		"q",
		"<Cmd>lua require('monitor.monitor').close_menu()<CR>",
		{ silent = true }
	)
	vim.api.nvim_buf_set_keymap(
		Monitor_bufnr,
		"n",
		"<Esc>",
		"<Cmd>lua require('monitor.monitor').close_menu()<CR>",
		{ silent = true }
	)
end

return M
