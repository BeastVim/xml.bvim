# xml

XML support for [BeastVim](https://github.com/loctvl842/BeastVim). Built only for the
BeastVim ecosystem - it uses the `Treesitter` global provided by BeastVim. Not usable
standalone.

On load it ensures the tree-sitter `xml` parser, which gives xml buffers highlighting,
folds that follow the element structure and tree-sitter indenting.

## Install

```lua
{
  name = "xml",
  src = gh("BeastVim/xml.bvim"), -- once pushed
  lazy = { filetype = "xml" },
  config = function() require("xml").setup() end,
}
```
