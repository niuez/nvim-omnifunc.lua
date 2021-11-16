# nvim-omnifunc.lua

Neovim omnifunc creater with builtin LSP written in lua.

## Setting

### `omnifunc.lsp.create_lsp_omnifunc(completion_to_complete)`

`completion_to_complete` is a function converting `CokmpletionItem(LSP's result textDocument/completion)` to `complete-item(item for omnifunc)`. `create_lsp_omnifunc` return omnifunc stype function. 

you can also use `omnifunc.lsp.default_completion_to_complete`. its implementation is used in `vim.lsp.util.text_document_completion_list_to_complete_items`.

## Example(for ccls)

```lua
local omnifunc = require'nvim_omnifunc'

function _G.cclsomnifunc(findstart, base)
  -- you can instead to use `omnifunc.lsp.default_completion_to_complete`
  return omnifunc.lsp.create_lsp_omnifunc(function(completion_item, ctx)
    local info = completion_item.label
    local word = omnifunc.lsp.get_completion_word(completion_item)
    return {
      word = word,
      abbr = word,
      kind = vim.lsp.util._get_completion_item_kind_name(completion_item.kind),
      menu = '',
      info = info,
      icase = 1,
      dup = 1,
      empty = 1,
      user_data = {
        nvim = {
          lsp = {
            completion_item = completion_item
          }
        }
      },
    }
  end)(findstart, base)
end

local ccls_on_attach = function(client, bufnr)
  local function buf_set_option(...) vim.api.nvim_buf_set_option(bufnr, ...) end

  buf_set_option('omnifunc', "v:lua.cclsomnifunc") -- setting omnifunc
end

require('lspconfig').ccls.setup({
  init_options = {
    clang = {
      extraArgs = {"--std=c++17"}
    };
  },
  on_attach = ccls_on_attach
})
```
