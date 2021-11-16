local util = require 'nvim_omnifunc.util'
local M = {
  util = util
}

local adjust_start_col = function(lnum, line, items, encoding)
  local min_start_char = nil
  for _, item in pairs(items) do
    if item.textEdit and item.textEdit.range.start.line == lnum - 1 then
      if min_start_char and min_start_char ~= item.textEdit.range.start.character then
        return nil
      end
      min_start_char = item.textEdit.range.start.character
    end
  end
  if min_start_char then
    if encoding == 'utf-8' then
      return min_start_char
    else
      return vim.str_byteindex(line, min_start_char, encoding == 'utf-16')
    end
  else
    return nil
  end
end


local sort_completion_items = function(items)
  table.sort(items, function(a, b)
    return (a.sortText or a.label) < (b.sortText or b.label)
  end)
end

M.get_completion_word = function(item)
  if item.textEdit ~= nil and item.textEdit.newText ~= nil and item.textEdit.newText ~= "" then
    local insert_text_format = vim.lsp.protocol.InsertTextFormat[item.insertTextFormat]
    if insert_text_format == "PlainText" or insert_text_format == nil then
      return item.textEdit.newText
    else
      return vim.lsp.util.parse_snippet(item.textEdit.newText)
    end
  elseif item.insertText ~= nil and item.insertText ~= "" then
    local insert_text_format = vim.lsp.protocol.InsertTextFormat[item.insertTextFormat]
    if insert_text_format == "PlainText" or insert_text_format == nil then
      return item.insertText
    else
      return vim.lsp.util.parse_snippet(item.insertText)
    end
  end
  return item.label
end

local remove_unmatch_completion_items = function(items, prefix)
  return vim.tbl_filter(function(item)
    local word = M.get_completion_word(item)
    return vim.startswith(word, prefix)
  end, items)
end

local completion_list_to_complete_items = function(result, prefix, ctx, completion_to_complete)
  local items = vim.lsp.util.extract_completion_items(result)
  if vim.tbl_isempty(items) then
    return {}
  end

  items = remove_unmatch_completion_items(items, prefix)
  sort_completion_items(items)

  local matches = {}

  for _, completion_item in ipairs(items) do
    table.insert(matches, completion_to_complete(completion_item, ctx))
  end

  return matches
end

-- completion_to_complete implementation by vim.lsp.util.text_document_completion_list_to_complete_items
M.default_completion_to_complete = function(completion_item, ctx)
  local info = ' '
  local documentation = completion_item.documentation
  if documentation then
    if type(documentation) == 'string' and documentation ~= '' then
      info = documentation
    elseif type(documentation) == 'table' and type(documentation.value) == 'string' then
      info = documentation.value
      -- else
      -- TODO(ashkan) Validation handling here?
    end
  end

  local word = M.get_completion_word(completion_item)
  return {
    word = word,
    abbr = completion_item.label,
    kind = vim.lsp.util._get_completion_item_kind_name(completion_item.kind),
    menu = completion_item.detail or '',
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
end


-- completion_to_complete(completion_item, prefix)
-- Parameters:
--   completion_item: the item of a result $textDocument/completionc call
--   ctx: ctx of lsp-handler
-- Return:
--   [complete-item]
M.create_lsp_omnifunc = function(completion_to_complete)
  return function(findstart, base)
    local bufnr = util.resolve_bufnr()

    local pos = vim.api.nvim_win_get_cursor(0)
    local line = vim.api.nvim_get_current_line()
    local line_to_cursor = line:sub(1, pos[2])

    -- Get the start position of the current keyword
    local textMatch = vim.fn.match(line_to_cursor, '\\k*$')

    local params = vim.lsp.util.make_position_params()

    local items = {}
    vim.lsp.buf_request(bufnr, 'textDocument/completion', params, function(err, result, ctx)
      if err or not result or vim.fn.mode() ~= "i" then return end

      -- Completion response items may be relative to a position different than `textMatch`.
      -- Concrete example, with sumneko/lua-language-server:
      --
      -- require('plenary.asy|
      --         ▲       ▲   ▲
      --         │       │   └── cursor_pos: 20
      --         │       └────── textMatch: 17
      --         └────────────── textEdit.range.start.character: 9
      --                                 .newText = 'plenary.async'
      --                  ^^^
      --                  prefix (We'd remove everything not starting with `asy`,
      --                  so we'd eliminate the `plenary.async` result
      --
      -- `adjust_start_col` is used to prefer the language server boundary.
      --
      local client = vim.lsp.get_client_by_id(ctx.client_id)
      local encoding = client and client.offset_encoding or 'utf-16'
      local candidates = vim.lsp.util.extract_completion_items(result)
      local startbyte = adjust_start_col(pos[1], line, candidates, encoding) or textMatch
      local prefix = line:sub(startbyte + 1, pos[2])
      local matches = completion_list_to_complete_items(result, prefix, ctx, completion_to_complete)
      -- local matches = vim.lsp.util.text_document_completion_list_to_complete_items(result, prefix)
      -- TODO(ashkan): is this the best way to do this?
      vim.list_extend(items, matches)
      vim.fn.complete(startbyte + 1, items)
      -- vim.api.nvim_notify(dump(result), vim.log.levels.ERROR, {})
      -- vim.api.nvim_notify(dump(items), vim.log.levels.ERROR, {})
    end)

    -- Return -2 to signal that we should continue completion so that we can
    -- async complete.
    return -2
  end
end

return M
