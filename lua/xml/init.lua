local M = {}

function M.setup()
	local missing = {}
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

	-- The parser gives highlighting, element folds and tree-sitter indenting.
	-- Installing it re-runs the buffer start for XML buffers already open.
	Treesitter.ensure_parser("xml")
end

return M
