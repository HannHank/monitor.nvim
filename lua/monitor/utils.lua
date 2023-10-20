local M = {}
function M.is_white_space(str)
	return str:gsub("%s", "") == ""
end

function M.an_index_of(val, t)
	for k, v in ipairs(t) do
		if v == val then return k end
	end
end

function M.is_string_in_list(str, list)
	for _, v in ipairs(list) do
		if v == str then
			return true
		end
	end
	return false
end

return M
