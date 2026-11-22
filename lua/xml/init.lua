local M = {}

-- Upstream folds `element` whole, which hides its closing tag when closed. Ending
-- the fold one line early keeps `</tag>` on screen under the opening line.
-- Elements with nothing between their tags get no fold of their own.
local FOLDS = [[
((element) @fold
  (#offset! @fold 0 0 -1 0))

[
  (doctypedecl)
  (Comment)
] @fold
]]

--- Install the buffer-local `>` mapping.
---@param buf integer
local function attach(buf)
	Key.safe_set("i", ">", function()
		return require("xml.autoclose").keys()
	end, { buffer = buf, expr = true, replace_keycodes = false, noremap = true, desc = "XML: close the opening tag", group = "XML" })
end

function M.setup()
	local missing = {}
	if not Key then
		table.insert(missing, "Key")
	end
	if not Treesitter then
		table.insert(missing, "Treesitter")
	end
	if #missing > 0 then
		vim.notify(
			"xml requires BeastVim's global " .. table.concat(missing, ", ") .. " (this plugin only works inside the BeastVim ecosystem)",
			vim.log.levels.ERROR,
			{ title = "xml" }
		)
		return
	end

	-- `query.set` rather than a queries/xml/folds.scm file: which of two files wins
	-- depends on runtimepath order, and the installer syncs the upstream one into
	-- BeastVim's site dir.
	vim.treesitter.query.set("xml", "folds", FOLDS)

	-- The parser gives highlighting and the folds above. Installing it re-runs the
	-- buffer start for XML buffers already open.
	Treesitter.ensure_parser("xml")

	vim.api.nvim_create_autocmd("FileType", {
		group = vim.api.nvim_create_augroup("BeastXml", { clear = true }),
		pattern = "xml",
		callback = function(args)
			attach(args.buf)
		end,
	})

	-- setup() runs on the FileType event that lazy-loaded this plugin, after
	-- which the autocmd above would be too late for the buffers already open.
	for _, buf in ipairs(vim.api.nvim_list_bufs()) do
		if vim.bo[buf].filetype == "xml" then
			attach(buf)
		end
	end
end

return M
