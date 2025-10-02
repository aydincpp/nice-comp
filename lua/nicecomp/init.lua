local completion = {
    buf = vim.api.nvim_create_buf(false, true),
    win = {
        id = nil,
        opts = nil,  -- set later in setup
    },
    items = {
        lsp = {},
        buffer = {},  -- placeholder
        snippet = {}, -- placeholder
    },
    selected_item = nil,
    cached_lines = {}
}

local doc = {
    buf = vim.api.nvim_create_buf(false, true),
    win = {
        id = nil,
        opts = nil,  -- set later in setup
    },
}

local M = {}
-- Default opts
local default_opts = {
    formatting = {
        kind_icons = {
            [1]  = '󰦨', -- Text
            [2]  = '', -- Method
            [3]  = '󰊕', -- Function
            [4]  = '', -- Constructor
            [5]  = '', -- Field
            [6]  = '', -- Variable
            [7]  = '', -- Class
            [8]  = '', -- Interface
            [9]  = '', -- Module
            [10] = '', -- Property
            [11] = '', -- Unit
            [12] = '', -- Value
            [13] = '', -- Enum
            [14] = '', -- Keyword
            [15] = '', -- Snippet
            [16] = '', -- Color
            [17] = '', -- File
            [18] = '', -- Reference
            [19] = '', -- Folder
            [20] = '', -- EnumMember
            [21] = '', -- Constant
            [22] = '', -- Struct
            [23] = '󰐰', -- Event
            [24] = '', -- Operator
            [25] = '', -- TypeParameter
        },
        selected_item_prefix = '',
    },
    window = {
        style = {
            width = 40,         -- width? lol I decide, not you
            height = 10,        -- height? your opinion does not matter
            border = 'rounded', -- this one you can touch, try not to break it
        },
    },
    mapping = {
        show_win = {
            mode = 'i',
            lhs = '<C-Space>',
            rhs = 'NiceComp show',
        },
        confirm_item = {
            mode = 'i',
            lhs = '<C-y>',
            rhs = 'NiceComp confirm',
        },
        next_item = {
            mode = 'i',
            lhs = '<C-n>',
            rhs = 'NiceComp next',
        },
        prev_item = {
            mode = 'i',
            lhs = '<C-p>',
            rhs = 'NiceComp prev',
        },
        show_doc = {
            mode = 'i',
            lhs  = '<C-Space>',
            rhs  = 'NiceComp doc',
        }
    },
}

M.opts = {}

---Apply user-defined key mappings from the plugin options.
---@return nil
---Apply user-defined key mappings from the plugin options.
---@return nil
function M.apply_mappings()
    if not M.opts.mapping then return end

    -- Previous item
    vim.keymap.set(
        M.opts.mapping.prev_item.mode,
        M.opts.mapping.prev_item.lhs,
        function()
            if M.completion_win_is_open() then
                return "<cmd>" .. M.opts.mapping.prev_item.rhs .. "<CR>"
            else
                return M.opts.mapping.prev_item.lhs
            end
        end,
        { noremap = true, silent = true, expr = true }
    )

    -- Next item
    vim.keymap.set(
        M.opts.mapping.next_item.mode,
        M.opts.mapping.next_item.lhs,
        function()
            if M.completion_win_is_open() then
                return "<cmd>" .. M.opts.mapping.next_item.rhs .. "<CR>"
            else
                return M.opts.mapping.next_item.lhs
            end
        end,
        { noremap = true, silent = true, expr = true }
    )
    -- Show window / show doc
    vim.keymap.set(
        M.opts.mapping.show_win.mode,
        M.opts.mapping.show_win.lhs,
        function()
            if not M.completion_win_is_open() then
                return "<cmd>" .. M.opts.mapping.show_win.rhs .. "<CR>"
            else
                return "<cmd>" .. M.opts.mapping.show_doc.rhs .. "<CR>"
            end
        end,
        { noremap = true, silent = true, expr = true }
    )

    -- Confirm item
    vim.keymap.set(
        M.opts.mapping.confirm_item.mode,
        M.opts.mapping.confirm_item.lhs,
        function()
            if M.completion_win_is_open() then
                return "<cmd>" .. M.opts.mapping.confirm_item.rhs .. "<CR>"
            else
                return M.opts.mapping.confirm_item.lhs
            end
        end,
        { noremap = true, silent = true, expr = true }
    )
end

---Setup the plugin with user options.
---@param user_opts table? Optional table of user configuration to override defaults.
---@return nil
M.setup = function(user_opts)
    M.opts = vim.tbl_deep_extend('force', default_opts, user_opts or {})

    -- Initialize completion window opts
    completion.win.opts = {
        relative = 'cursor',
        style    = 'minimal',
        border   = M.opts.window.style.border,
        width    = M.opts.window.style.width,
        height   = M.opts.window.style.height,
        col      = 0,
        row      = 1,
    }

    -- Initialize doc window opts
    doc.win.opts = {
        relative  = 'editor',
        style     = 'minimal',
        border    = M.opts.window.style.border,
        width     = M.opts.window.style.width,
        height    = M.opts.window.style.height,
        focusable = true,
        mouse     = true,
        col       = 0,
        row       = 1,
    }

    M.apply_mappings()

    ---User command to control the NiceComp completion plugin.
    ---@usage :NiceComp <show|hide|next|prev|confirm|doc>
    vim.api.nvim_create_user_command('NiceComp', function(opts)
        local arg = opts.args
        if arg == 'show' then
            M.completion_items_fetch_lsp()
        elseif arg == 'hide' then
            M.completion_win_hide()
        elseif arg == 'next' then
            M.completion_item_select(1)
        elseif arg == 'prev' then
            M.completion_item_select(-1)
        elseif arg == 'confirm' then
            M.completion_item_confirm()
        elseif arg == 'doc' then
            M.doc_fetch_lines()
        else
            print('Unknown argument: ' .. arg)
        end
    end, {
        nargs = 1,
        complete = function()
            return { 'show', 'hide', 'next', 'prev', 'confirm', 'doc' }
        end,
    })

    -- Hide the completion popup when leaving insert mode.
    vim.api.nvim_create_autocmd('InsertLeave', {
        group = vim.api.nvim_create_augroup('nicecomp-insert-leave', { clear = true }),
        callback = function()
            M.completion_win_hide() -- hide completion window
            M.doc_win_hide()        -- hide doc window
        end
    })

    ---trigger the completion popup while in insert mode.
    vim.api.nvim_create_autocmd('textchangedi', {
        group = vim.api.nvim_create_augroup('nicecomp-auto-trigger', { clear = true }),
        callback = function()
            M.completion_auto_trigger()
            M.doc_win_hide() -- hide doc window
        end,
    })
end

---Get the current completion window ID.
---@return number|nil id Window ID of the completion popup, or nil if not open
function M.completion_win_id_get()
    return completion.win.id
end

---Set the current completion window ID.
---@return nil
function M.completion_win_id_set(id)
    completion.win.id = id
end

---Get the current width of the completion window.
---@return number width Width in columns
function M.completion_width_get()
    return completion.win.opts.width
end

---Set the width of the completion window.
---@param width number Width in columns
---@return nil
function M.completion_width_set(width)
    completion.win.opts.width = width
end

---Get the current height of the completion window.
---@return number height Height in rows
function M.completion_height_get()
    return completion.win.opts.height
end

---Set the height of the completion window.
---@param height number Height in rows
---@return nil
function M.completion_height_set(height)
    completion.win.opts.height = height
end

---Get the row of the completion window.
---@return number row Row
function M.completion_row_get()
    return completion.win.opts.row
end

---Set the row of the completion window.
---@param row number Row
---@return nil
function M.completion_row_set(row)
    completion.win.opts.row = row
end

---Get the col of the completion window.
---@return number col Col
function M.completion_col_get()
    return completion.win.opts.col
end

---Set the col of the completion window.
---@param col number Col
---@return nil
function M.completion_col_set(col)
    completion.win.opts.col = col
end

---Get completion items for a specific source.
---@param source string One of "lsp", "buffer", "snippet"
---@return table items List of completion items for the source
function M.completion_items_get(source)
    return completion.items[source] or {}
end

---Set completion items for a specific source.
---@param source string One of "lsp", "buffer", "snippet"
---@param items table List of completion items to set
---@return nil
function M.completion_items_set(source, items)
    completion.items[source] = items
end

---Get the index of the currently selected completion item.
---@return number selected 1-based index of the selected item (0 if none)
function M.completion_selected_item_get()
    return completion.selected_item or 0
end

---Set the index of the currently selected completion item.
---@param idx number 1-based index to set as selected
---@return nil
function M.completion_selected_item_set(idx)
    completion.selected_item = idx
end

---Check if any item in the completion list is selected
---@return boolean True if an item is selected
function M.completion_has_selected_item()
    return M.completion_selected_item_get() ~= 0 or false
end

---Create a debounced version of a function.
---@param func function The function to debounce.
---@param ms number The debounce delay in milliseconds.
---@return function function New function that delays calling func until ms milliseconds
function M.debounce(func, ms)
    local timer = vim.loop.new_timer()
    return function(...)
        local args = { ... }
        if timer then
            timer:stop()
            timer:start(ms, 0, vim.schedule_wrap(function()
                func(unpack(args))
            end))
        end
    end
end

function M.highlight_line(buf, line_idx, col_start, col_finish, ns_id, hl_group)
    vim.hl.range(buf, ns_id, hl_group, { line_idx, col_start }, { line_idx, col_finish })
end

---Highlight the currently selected completion item in the buffer.
---@return nil
function M.completion_selected_item_highlight()
    if not M.completion_win_is_open() then return end
    local selected_item = M.completion_selected_item_get()
    if not M.completion_has_selected_item() then return end

    local ns_id = vim.api.nvim_create_namespace('NiceComp')
    local hl_group = 'PmenuSel'

    -- vim.api.nvim_buf_clear_namespace(completion.buf, ns_id, 0, -1)
    M.highlight_line(completion.buf, selected_item - 1, 0, -1, ns_id, hl_group)
end

---Extract the main display parts of a completion item.
---@param item table Completion item with kind and label fields.
---@return table parts Table containing:
--- - icon string Icon representing the kind
--- - label string The completion text
--- - name string Human-readable kind name
function M.completion_item_parts_get(item)
    return {
        icon = M.completion_item_kind_icon_get(item.kind),
        label = item.label or "",
        name = M.completion_item_kind_name_get(item.kind),
    }
end

---Get the prefix string for a completion item based on selection state.
---@param selected boolean Whether the item is currently selected.
---@return string prefix Prefix to display for the item.
function M.completion_item_prefix_get(selected)
    if selected then
        return M.opts.formatting.selected_item_prefix
    else
        return " "
    end
end

---Calculate the display width of a list of completion items.
---This is used to determine the width of the completion popup window.
---@param items table List of completion items
---@return number max_width Maximum width in display cells
function M.completion_width_calc(items)
    local width = 0
    for i in ipairs(items) do
        local parts = M.completion_item_parts_get(items[i])

        -- Create a formatted string for the item including prefix, icon, label, and name
        local dummy = string.format("%s %s %s %s",
            M.completion_item_prefix_get(false),
            parts.icon,
            parts.label,
            parts.name
        )

        -- Measure display width and keep track of the maximum
        width = math.max(width, vim.fn.strdisplaywidth(dummy))
    end

    return width
end

---Format a single completion item line.
---@param idx number Item index
---@param selected boolean If the item is currently selected
---@param width number Target width for alignment
---@return string line Formatted display line
function M.format_item_line(idx, selected, width)
    local items = M.completion_items_get('lsp')
    if not items or not items[idx] then return "" end

    local parts = M.completion_item_parts_get(items[idx])
    local prefix = M.completion_item_prefix_get(selected)

    local base = string.format("%s %s %s", prefix, parts.icon, parts.label)
    local used_w = vim.fn.strdisplaywidth(base)
    local name_w = vim.fn.strdisplaywidth(parts.name)

    local padding = width - (used_w + name_w)
    if padding < 1 then padding = 1 end

    return string.format("%s%s%s", base, string.rep(" ", padding), parts.name)
end

---Compute formatted lines for all completion items.
---@param items table List of completion items
---@return table lines Formatted lines ready for display
function M.get_formated_lines(items)
    if not items or #items == 0 then return {} end

    -- compute width
    local width = M.completion_width_calc(items)

    -- update window width
    M.completion_width_set(width)

    -- format each line with final width
    local lines = {}
    for i in ipairs(items) do
        local selected = i == M.completion_selected_item_get()
        lines[i] = M.format_item_line(i, selected, width)
    end

    return lines
end

---Redraw completion buffer lines to reflect selection change.
---
---Replaces the previously selected item (`prev`) with its normal
---rendering and the newly selected item (`new`) with its selected
---rendering using `M.format_item_line`.
---@param prev number Index of the previously selected item
---@param new number Index of the newly selected item
---@return nil
function M.completion_item_selection_update(prev, new)
    local width = M.completion_width_get()

    if prev ~= 0 then
        vim.api.nvim_buf_set_lines(
            completion.buf,
            prev - 1,
            prev,
            false,
            { M.format_item_line(prev, false, width) } -- unselect previous line
        )
    end

    if new ~= 0 then
        vim.api.nvim_buf_set_lines(
            completion.buf,
            new - 1,
            new,
            false,
            { M.format_item_line(new, true, width) } -- select new line
        )
    end
end

function M.completion_item_update(idx, selected)
    local width = M.completion_width()

    vim.api.nvim_buf_set_lines(
        completion.buf,
        idx - 1,
        idx,
        false,
        { M.format_item_line(idx, selected, width) }
    )
end

---Calculate the row position for the completion window relative to the cursor.
---@return number row The row offset where the completion window should appear.
function M.completion_row_calc()
    local cursor_row_in_window = vim.fn.winline()               -- Cursor row relative to the window
    local total_window_rows    = vim.api.nvim_win_get_height(0) -- Total number of rows in the current window
    local completion_height    = M.completion_height_get()      -- Height of the completion popup

    -- If the popup would overflow past the bottom of the window, show it above the cursor
    if cursor_row_in_window + completion_height >= total_window_rows then
        return -completion_height - 2
    else
        return 1
    end
end

---Get the icon for a given completion kind.
---@param kind number The numeric kind value from the LSP completion item.
---@return string icon Icon representing the kind, or a default if not found.
function M.completion_item_kind_icon_get(kind)
    return M.opts.formatting.kind_icons[kind] or ''
end

---Get the human-readable name for a given completion kind.
---@param kind number The numeric kind value from the LSP completion item.
---@return string name Name of the completion kind, or "Unknown" if not found.
function M.completion_item_kind_name_get(kind)
    return vim.lsp.protocol.CompletionItemKind[kind] or "Unknown"
end

---Check if a table has any entries.
---@param t table Any table to check.
---@return boolean True if the table contains at least one key.
function M.has_entries(t)
    for _ in pairs(t) do
        return true
    end
    return false
end

---Clear all entries from a table.
---@param t table Any table to clear.
---@return nil
function M.clear_table(t)
    if M.has_entries(t) then
        for k in pairs(t) do
            t[k] = nil
        end
    end
end

---Check if the completion window is currently open and valid.
---@return boolean True if the completion window exists and is valid.
function M.completion_win_is_open()
    local win_id = M.completion_win_id_get()
    return win_id ~= nil and vim.api.nvim_win_is_valid(win_id)
end

---Check if the completion buffer is valid.
---@return boolean True if the completion buffer exists and is valid.
function M.completion_buf_is_valid()
    return completion.buf and vim.api.nvim_buf_is_valid(completion.buf)
end

---Fetch completion items from the language server via LSP for the current buffer
---@return nil
function M.completion_items_fetch_lsp()
    if M.completion_win_is_open() then return end

    local clients = vim.lsp.get_clients({ bufnr = 0 })
    local method = 'textDocument/completion'

    for _, client in ipairs(clients) do
        if client.supports_method(client, method) then
            local params = vim.lsp.util.make_position_params(0, 'utf-16')
            vim.lsp.buf_request(0, method, params, function(_, result)
                if not result then return end

                local items = result.items or result

                M.completion_items_set('lsp', items)

                local lines = M.get_formated_lines(items)
                M.completion_win_show(lines)
            end)
        end
    end
end

function M._get_namespace()
    return vim.api.nvim_create_namespace('NiceComp')
end

-- show completion
function M.completion_win_show(lines)
    if not lines or #lines == 0 then return end

    -- Reset selected item
    M.completion_selected_item_set(0)

    -- Set buffer lines
    vim.api.nvim_buf_set_lines(completion.buf, 0, -1, false, lines)

    -- calculate completion row
    local new_row = M.completion_row_calc()
    M.completion_row_set(new_row)

    -- Open completion if not open, otherwise just update it's position
    if not M.completion_win_is_open() then
        local win_id = vim.api.nvim_open_win(completion.buf, false, completion.win.opts)
        M.completion_win_id_set(win_id)
    else
        local win_id = M.completion_win_id_get()
        ---@diagnostic disable-next-line: param-type-mismatch
        vim.api.nvim_win_set_config(win_id, completion.win.opts)
    end

    -- reset cursor position
    M.completion_win_cursor_move()
end

-- hide completion
function M.completion_win_hide()
    if M.completion_win_is_open() then
        local win_id = M.completion_win_id_get()
        ---@diagnostic disable-next-line: param-type-mismatch
        vim.api.nvim_win_close(win_id, true)
        M.completion_win_id_set(nil)
        M.completion_selected_item_set(0)
    end
end

function M.completion_auto_trigger()
    if vim.fn.mode() ~= 'i' then return end -- only show in insert mode

    local col = vim.fn.col('.') - 1
    if col <= 0 then
        vim.cmd('NiceComp hide')
        return
    end

    local char = vim.api.nvim_get_current_line():sub(col, col)
    if char:match('%w') then
        vim.cmd('NiceComp show')
    else
        vim.cmd('NiceComp hide')
    end
end

---Change the currently selected completion item.
---Moves the selection forward or backward in the list,
---wrapping around at the boundaries.
---@param direction number +1 to select the next item, -1 to select the previous
---@return nil
function M.completion_item_select(direction)
    local items = M.completion_items_get('lsp')
    if not items or #items == 0 then return end

    local selected_item = M.completion_selected_item_get()
    local prev = selected_item
    local new

    -- calculate new index with wrap-around
    if not M.completion_has_selected_item() and direction == -1 then
        new = #items
    else
        new = ((selected_item - 1 + direction) % #items) + 1
    end

    -- update the internal selected item index
    M.completion_selected_item_set(new)

    -- update affected lines and highlight
    M.completion_item_selection_update(prev, new)
    M.completion_selected_item_highlight()
    M.completion_win_cursor_move()

    -- hide the doc window if it was open
    M.doc_win_hide()
end

function M.process_snippet_placeholders(lines)
    for i, l in ipairs(lines) do
        l = l:gsub("%${%d+:([^}]-)}", "%1")
        l = l:gsub("%$%d+", "")
        lines[i] = l
    end
    return lines
end

function M.completion_item_confirm()
    local selected = M.completion_selected_item_get()
    if not selected or selected == 0 then return end

    local item = M.completion_items_get('lsp')[selected]
    if not item then return end

    local row, col = unpack(vim.api.nvim_win_get_cursor(0))
    local line = vim.api.nvim_get_current_line()

    local start_col = col
    while start_col > 0 and line:sub(start_col, start_col):match("[%w_]") do
        start_col = start_col - 1
    end
    start_col = start_col + 1

    local before = line:sub(1, start_col - 1)
    local after = line:sub(col + 1)
    local text = item.insertText or item.label

    local lines = vim.split(text, "\n", { plain = true })
    lines = M.process_snippet_placeholders(lines)

    lines[1] = before .. lines[1]
    lines[#lines] = lines[#lines] .. after

    vim.api.nvim_buf_set_lines(0, row - 1, row, false, lines)

    local cursor_row, cursor_col

    if #lines > 1 then
        cursor_row = row + 1
        cursor_col = #lines[2]:match("^%s*")
    else
        cursor_row = row
        cursor_col = #lines[1]
    end

    vim.api.nvim_win_set_cursor(0, { cursor_row, cursor_col })
    M.completion_win_hide()
end

function M.completion_win_cursor_move()
    if M.completion_win_is_open() then
        local win_id = M.completion_win_id_get()
        local selected = M.completion_selected_item_get()

        -- if nothing is selected then just move the cursor to the first line
        local row = M.completion_has_selected_item() and selected or 1

        ---@diagnostic disable-next-line: param-type-mismatch
        vim.api.nvim_win_set_cursor(win_id, { row, 0 }) -- row is 1-based
    end
end

---Check if the doc window is open
---@return boolean True if the doc window is open, false otherwise
function M.doc_win_is_open()
    return doc.win.id ~= nil or false
end

function M.doc_get_lines(result)
    local res_doc = result.documentation
    local lines = {}

    if res_doc then
        local type = type(res_doc)
        if type == 'string' then
            lines = vim.split(res_doc, '\n')
        elseif type == 'table' and res_doc.value then
            lines = vim.split(res_doc.value, '\n')
        end
    end

    return lines
end

function M.doc_fetch_lines()
    if
        not M.completion_has_selected_item()
        or M.doc_win_is_open()
    then
        return -- return if no item is selected or if the doc window is already open
    end

    -- get the selected item
    local item = M.completion_items_get('lsp')[M.completion_selected_item_get()]

    -- send request and fetch
    vim.lsp.buf_request(0, 'completionItem/resolve', item, function(_, result)
        -- extract doc lines
        local lines = M.doc_get_lines(result)

        -- pass lines and show or update doc window
        M.doc_win_show(lines)
    end)
end

function M.doc_win_adjust()
    if not M.completion_win_is_open() then return end
    if not (doc and doc.buf and vim.api.nvim_buf_is_valid(doc.buf)) then return end

    -- completion window id and geometry
    local comp_win_id   = M.completion_win_id_get()
    ---@diagnostic disable-next-line: param-type-mismatch
    local comp_pos      = vim.api.nvim_win_get_position(comp_win_id) -- {row, col}
    ---@diagnostic disable-next-line: param-type-mismatch
    local comp_width    = vim.api.nvim_win_get_width(comp_win_id)
    ---@diagnostic disable-next-line: param-type-mismatch
    local comp_height   = vim.api.nvim_win_get_height(comp_win_id)

    -- editor dimensions
    local editor_width  = vim.o.columns
    local editor_height = vim.o.lines

    -- doc buffer lines
    local lines         = vim.api.nvim_buf_get_lines(doc.buf, 0, -1, false)
    if not lines or #lines == 0 then return end

    -- natural doc size from content
    local natural_width  = math.max(unpack(vim.tbl_map(vim.fn.strdisplaywidth, lines)))
    local natural_height = #lines

    local width, height, row, col

    -- try placing on top
    local top_space      = comp_pos[1] - 2
    if top_space > 0 then
        height = math.min(natural_height, top_space)
        width  = math.min(natural_width, editor_width)
        row    = comp_pos[1] - height - 2
        col    = math.min(comp_pos[2], math.max(0, editor_width - width))
        return M._set_doc_opts(row, col, width, height)
    end

    -- try placing on bottom
    local bottom_space = editor_height - (comp_pos[1] + comp_height) - 2
    if bottom_space > 0 then
        height = math.min(natural_height, bottom_space)
        width  = math.min(natural_width, editor_width)
        row    = comp_pos[1] + comp_height + 2
        col    = math.min(comp_pos[2], math.max(0, editor_width - width))
        return M._set_doc_opts(row, col, width, height)
    end

    -- fallback: left/right
    local left_space  = comp_pos[2] - 2
    local right_space = editor_width - (comp_pos[2] + comp_width) - 2
    if right_space >= left_space then
        width  = math.min(natural_width, right_space)
        height = math.min(natural_height, editor_height)
        col    = comp_pos[2] + comp_width + 2
        row    = math.max(0, math.min(editor_height - height, comp_pos[1]))
    else
        width  = math.min(natural_width, left_space)
        height = math.min(natural_height, editor_height)
        col    = math.max(0, comp_pos[2] - width - 2)
        row    = math.max(0, math.min(editor_height - height, comp_pos[1]))
    end

    M._set_doc_opts(row, col, width, height)
end

-- helper to set opts
function M._set_doc_opts(row, col, width, height)
    doc.win.opts = {
        relative = 'editor',
        row = row,
        col = col,
        width = width,
        height = height,
        style = 'minimal',
        border = 'rounded',
    }
end

function M.doc_win_show(lines)
    -- set doc buffer lines
    vim.api.nvim_buf_set_lines(doc.buf, 0, -1, false, lines)

    -- enable syntax highlighting
    vim.api.nvim_buf_set_option(doc.buf, "filetype", "markdown")

    -- adjust window pos and size
    M.doc_win_adjust()

    -- show or update doc window
    if not M.doc_win_is_open() then
        doc.win.id = vim.api.nvim_open_win(doc.buf, false, doc.win.opts)
    else
        vim.api.nvim_win_set_config(doc.win.id, doc.win.opts)
    end
end

function M.doc_win_hide()
    if M.doc_win_is_open() then
        vim.api.nvim_win_close(doc.win.id, true)
        doc.win.id = nil
    end
end

return M

