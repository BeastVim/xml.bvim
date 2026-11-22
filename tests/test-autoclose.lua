-- =========================================================================
-- Test: xml auto-close tag
-- =========================================================================
-- Run from the plugin root as: nvim --clean --headless -l tests/test-autoclose.lua
-- Exit code: 0 = PASS, 1 = FAIL
-- =========================================================================

vim.opt.runtimepath:prepend(vim.fn.getcwd())
package.path = "./lua/?.lua;./lua/?/init.lua;" .. package.path

-- BeastVim globals the plugin expects.
_G.Key = {
	safe_set = function(mode, lhs, rhs, opts)
		local o = vim.deepcopy(opts)
		o.group = nil -- consumed by the real Key lib, not a vim.keymap option
		vim.keymap.set(mode, lhs, rhs, o)
	end,
}
local ensured = {}
_G.Treesitter = {
	ensure_parser = function(lang)
		table.insert(ensured, lang)
	end,
}

local passed, failed = 0, 0

local function assert_eq(name, got, expected)
	if vim.deep_equal(got, expected) then
		passed = passed + 1
		io.write("  PASS: " .. name .. "\n")
	else
		failed = failed + 1
		io.write("  FAIL: " .. name .. " - expected " .. vim.inspect(expected) .. ", got " .. vim.inspect(got) .. "\n")
	end
end

local autoclose = require("xml.autoclose")

io.write("\n--- closing_tag ---\n")
assert_eq("plain name", autoclose.closing_tag("<class", ""), "</class>")
assert_eq("prefixed name keeps the prefix", autoclose.closing_tag("<app:label", ""), "</app:label>")
assert_eq("attributes", autoclose.closing_tag('<app:label key="team"', ""), "</app:label>")
assert_eq("single quoted attribute", autoclose.closing_tag("<a b='c'", ""), "</a>")
assert_eq("tag after text and tags", autoclose.closing_tag("<root><x>text <item", ""), "</item>")
assert_eq("start tag wrapped over lines", autoclose.closing_tag('<item\n  a="1"\n  b="2"', ""), "</item>")
assert_eq("> inside a complete quoted value", autoclose.closing_tag('<a href="x>y"', ""), "</a>")
assert_eq("double quote inside single quotes", autoclose.closing_tag([[<a b='say "hi"']], ""), "</a>")
assert_eq("name with dots and dashes", autoclose.closing_tag("<a.b-c_d", ""), "</a.b-c_d>")
assert_eq("self-closing", autoclose.closing_tag("<br/", ""), nil)
assert_eq("self-closing with space", autoclose.closing_tag("<br /", ""), nil)
assert_eq("closing tag", autoclose.closing_tag("</class", ""), nil)
assert_eq("comment", autoclose.closing_tag("<!-- note --", ""), nil)
assert_eq("declaration", autoclose.closing_tag('<?xml version="1.0"?', ""), nil)
assert_eq("doctype", autoclose.closing_tag("<!DOCTYPE note", ""), nil)
assert_eq("> inside an open quoted value", autoclose.closing_tag('<a href="x', ""), nil)
assert_eq("not a tag: space after <", autoclose.closing_tag("a < b", ""), nil)
assert_eq("no < at all", autoclose.closing_tag("text only", ""), nil)
assert_eq("tag already closed", autoclose.closing_tag("<root><x>", ""), nil)
assert_eq("closer already there", autoclose.closing_tag("<class", "</class>"), nil)
assert_eq("other closer there", autoclose.closing_tag("<class", "</other>"), "</class>")
assert_eq("name must not be a prefix of garbage", autoclose.closing_tag("<a$b", ""), nil)

io.write("\n--- > mapping ---\n")
require("xml").setup()
assert_eq("ensures the xml parser", ensured, { "xml" })

local function keys(s)
	vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(s, true, true, true), "xt", false)
end

--- Load `lines` into a fresh xml buffer, put the cursor at (row, col) and feed
--- `typed`. Returns the resulting lines.
local function run(lines, cursor, typed)
	local buf = vim.api.nvim_create_buf(true, false)
	vim.api.nvim_set_current_buf(buf)
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
	vim.bo[buf].filetype = "xml"
	-- the runtime's xml indent script re-indents on `>`; only the tag text is under test
	vim.bo[buf].indentexpr = ""
	vim.api.nvim_win_set_cursor(0, cursor)
	keys(typed)
	local result = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
	vim.api.nvim_buf_delete(buf, { force = true })
	return result
end

assert_eq("<class> closes itself", run({ "" }, { 1, 0 }, "i<class><Esc>"), { "<class></class>" })
assert_eq("cursor sits between the tags", run({ "" }, { 1, 0 }, "i<class>hello<Esc>"), { "<class>hello</class>" })
assert_eq("attributes and prefix", run({ "" }, { 1, 0 }, 'i<app:label key="team">x<Esc>'), { '<app:label key="team">x</app:label>' })
assert_eq("nested on a new line", run({ "" }, { 1, 0 }, "i<class><CR><item>v<Esc>"), { "<class>", "<item>v</item></class>" })
assert_eq("self-closing adds nothing", run({ "" }, { 1, 0 }, "i<br/><Esc>"), { "<br/>" })
assert_eq("closing tag adds nothing", run({ "" }, { 1, 0 }, "i</class><Esc>"), { "</class>" })
assert_eq("comment adds nothing", run({ "" }, { 1, 0 }, "i<!-- x --><Esc>"), { "<!-- x -->" })
assert_eq("quoted > adds nothing, the real one closes", run({ "" }, { 1, 0 }, 'i<a href="x>y"><Esc>'), { '<a href="x>y"></a>' })
assert_eq("existing closer is not doubled", run({ "<class</class>" }, { 1, 6 }, "i><Esc>"), { "<class></class>" })
assert_eq("start tag wrapped over lines", run({ "<item", '  a="1"' }, { 2, 6 }, "A><Esc>"), { "<item", '  a="1"></item>' })

vim.cmd("enew!")
vim.bo.filetype = "xml"
keys("i<class>x<Esc>")
keys("u")
assert_eq("one undo reverts the > and the closing tag", vim.api.nvim_buf_get_lines(0, 0, -1, false), { "" })

assert_eq("dot repeats the typed tag with its closer", run({ "", "" }, { 1, 0 }, "i<a>x<Esc>j."), { "<a>x</a>", "<a>x</a>" })

io.write("\n--- other filetypes ---\n")
vim.cmd("enew!")
vim.bo.filetype = "text"
keys("i<class><Esc>")
assert_eq("no mapping outside xml", vim.api.nvim_buf_get_lines(0, 0, -1, false), { "<class>" })

io.write(string.format("\n%d passed, %d failed\n", passed, failed))
os.exit(failed == 0 and 0 or 1)
