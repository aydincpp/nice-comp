# NiceComp - Totally Serious Completion Plugin

**IT'S SO GOOD THAT YOU WILL REGRET USING IT!**  

Yes, you read that right. This is my **first Neovim plugin** ever, so proceed with caution. Or don't. Your call.

---

## License Agreement

By using this plugin, you agree to:

1. Bow to the code. Seriously, bow. 🙏
2. Never question why things work… or why they don’t.
3. Accept that bugs are actually *features in disguise*.
4. Send money to the author if it breaks. I’m poor 😢

**WARN:** Use at your own risk.

---

## Demo

Check out this totally real demo GIF (not staged):

![NiceComp Demo](demo.gif)

---

## Installation

Use your favorite plugin manager:

```lua
-- Packer
use 'aydincpp/nicecomp'

-- Lazy.nvim
{ 'aydincpp/nicecomp' }
```

### Keymaps

NiceComp comes with some pre-configured keymaps.  
**Seriously, do not touch them.**  

Default keymaps:

| Action        | Mode | Key        |
|---------------|------|------------|
| Show Window   | i    | `<C-Space>`|
| Confirm Item  | i    | `<C-y>`    |
| Next Item     | i    | `<C-n>`    |
| Previous Item | i    | `<C-p>`    |
| Show Doc      | i    | `<C-Space>`|

> Recommended: leave them as is and live a happy life.

## Default Config Example

For those brave enough to configure NiceComp, here’s a starter template.  
Remember: width and height are sacred and chosen by me. Don’t complain.  

```lua
return {
    "aydincpp/nicecomp",
    config = function()
        require("nicecomp").setup({
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
                    rhs = 'NiceComp confirm', -- doesn’t really work, you’ve been warned
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
        })
    end
}
```


