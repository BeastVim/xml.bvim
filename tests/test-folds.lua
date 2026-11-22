-- =========================================================================
-- Test: xml folds keep the closing tag visible
-- =========================================================================
-- Run from the plugin root as: NVIM_APPNAME=BeastVim nvim --clean --headless -l tests/test-folds.lua
-- (the xml parser and its queries are looked up under BeastVim's site dir)
-- Exit code: 0 = PASS, 1 = FAIL
-- =========================================================================

vim.opt.runtimepath:prepend(vim.fn.getcwd())
vim.opt.runtimepath:append(vim.fn.stdpath("data") .. "/site")
package.path = "./lua/?.lua;./lua/?/init.lua;" .. package.path

_G.Key = { safe_set = function() end }
_G.Treesitter = { ensure_parser = function() end }

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

if not pcall(vim.treesitter.language.add, "xml") then
	io.write("  SKIP: no xml parser installed\n")
	os.exit(0)
end

require("xml").setup()

local lines = {
	"<root>", -- 1
	'  <app:group name="inner">', -- 2
	'    <app:item id="1"/>', -- 3
	'    <app:item id="2"/>', -- 4
	"  </app:group>", -- 5
	"  <empty>", -- 6
	"  </empty>", -- 7
	"  <one>x</one>", -- 8
	"  <!--", -- 9
	"    note", -- 10
	"  -->", -- 11
	"</root>", -- 12
}
vim.cmd("enew")
vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
vim.bo.filetype = "xml"
vim.treesitter.start(0, "xml")
vim.wo.foldmethod = "expr"
vim.wo.foldexpr = "v:lua.vim.treesitter.foldexpr()"
vim.wo.foldlevel = 99

--- Open every fold, close the one under `row`, return the closed range as {first, last} (or nil).
local function closed_after_zc(row)
	vim.cmd("normal! zR")
	vim.api.nvim_win_set_cursor(0, { row, 0 })
	vim.cmd("normal! zc")
	local first = vim.fn.foldclosed(row)
	return first ~= -1 and { first, vim.fn.foldclosedend(row) } or nil
end

io.write("\n--- closing tag stays visible ---\n")
assert_eq("element folds from its opening tag to the line before its closing tag", closed_after_zc(2), { 2, 4 })
assert_eq("root keeps its closing tag", closed_after_zc(1), { 1, 11 })
assert_eq("zc inside the body closes that element", closed_after_zc(3), { 2, 4 })

io.write("\n--- nothing between the tags ---\n")
assert_eq("neighbouring tags have no fold of their own, the root closes", closed_after_zc(6), { 1, 11 })
assert_eq("one-line element has no fold of its own, the root closes", closed_after_zc(8), { 1, 11 })

io.write("\n--- other fold targets are unchanged ---\n")
assert_eq("a multi-line comment still folds", closed_after_zc(9), { 9, 11 })

io.write(string.format("\n%d passed, %d failed\n", passed, failed))
os.exit(failed == 0 and 0 or 1)
