local M = {}

-- How many lines above the cursor a start tag may begin (attributes can wrap).
local MAX_TAG_LINES = 50

local function termcodes(keys)
	return vim.api.nvim_replace_termcodes(keys, true, true, true)
end

--- Drop quoted attribute values: a `>` inside one belongs to the value.
---@param s string
---@return string stripped
---@return boolean open  the text ends inside a quoted value
local function strip_quoted(s)
	local out, quote = {}, nil
	for c in s:gmatch(".") do
		if quote then
			if c == quote then
				quote = nil
			end
		elseif c == '"' or c == "'" then
			quote = c
		else
			out[#out + 1] = c
		end
	end
	return table.concat(out), quote ~= nil
end

--- The closing tag to add when `>` is typed after `before` (the text up to the
--- cursor, start tag included) and before `after` (the rest of the line).
--- Nil when `>` should stay a plain character.
---@param before string
---@param after string
---@return string?
function M.closing_tag(before, after)
	local lt = before:match(".*()<")
	if not lt then
		return nil
	end
	local tag, open_quote = strip_quoted(before:sub(lt + 1))
	if open_quote then
		return nil
	end
	-- `</x`, `<!--`, `<?xml`, `< b` do not start with a name
	local name, rest = tag:match("^([%a_][%w:._-]*)(.*)$")
	if not name or (rest ~= "" and not rest:match("^%s")) then
		return nil
	end
	-- already closed (`<a>`) or self-closing (`<br/`)
	if rest:find(">", 1, true) or rest:match("/%s*$") then
		return nil
	end
	local closing = "</" .. name .. ">"
	if after:sub(1, #closing) == closing then
		return nil
	end
	return closing
end

--- Keys for the `>` just typed at the cursor: the key itself plus, after an
--- opening tag, its closing tag with the cursor left in between. `<C-g>U` keeps
--- the cursor moves inside the same undo block as the typing.
---@return string keys  raw bytes
function M.gt()
	local row, col = unpack(vim.api.nvim_win_get_cursor(0))
	local lines = vim.api.nvim_buf_get_lines(0, math.max(0, row - 1 - MAX_TAG_LINES), row, false)
	local line = lines[#lines]
	lines[#lines] = line:sub(1, col)
	local closing = M.closing_tag(table.concat(lines, "\n"), line:sub(col + 1))
	if not closing then
		return termcodes(">")
	end
	return termcodes(">" .. closing .. string.rep("<C-g>U<Left>", #closing))
end

--- Run `gt` and feed its keys to the front of the typeahead. Reached through the
--- `<Cmd>` that `keys` returns, so it runs when the key is consumed, in order.
function M.press()
	vim.api.nvim_feedkeys(M.gt(), "ni", false)
end

--- The rhs of the insert mapping (use with `expr`): a constant `<Cmd>` that defers
--- every decision to `press`. It must not look at the buffer itself: Neovim
--- evaluates `expr` mappings while peeking at queued keys, before the characters
--- typed ahead of the key are in the buffer.
---@return string keys  raw bytes
function M.keys()
	return termcodes("<Cmd>lua require('xml.autoclose').press()<CR>")
end

return M
