# xml

XML support for [BeastVim](https://github.com/loctvl842/BeastVim). Built only for the
BeastVim ecosystem - it uses the `Treesitter` global provided by BeastVim. Not usable
standalone.

On load it ensures the tree-sitter `xml` parser, which gives xml buffers highlighting
and folds that follow the element structure.

## Auto-close tag

Typing the `>` of an opening tag writes the closing tag and leaves the cursor between
the two: `<app:label key="team"` + `>` gives `<app:label key="team">|</app:label>`.
One undo removes both, and `.` repeats the pair.

`>` stays a plain character after a self-closing tag (`<br/`), a closing tag, a comment,
declaration or doctype, inside a quoted attribute value, in text (`a < b`), and when the
closing tag is already there. A start tag may wrap over up to 50 lines.

It is not aware of comment or CDATA bodies: typing `<b>` inside a comment still closes it.

## Install

```lua
{
  name = "xml",
  src = gh("BeastVim/xml.bvim"), -- once pushed
  lazy = { filetype = "xml" },
  config = function() require("xml").setup() end,
}
```
