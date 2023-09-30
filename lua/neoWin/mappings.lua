local map = vim.api.nvim_set_keymap
local opts = {noremap = true, silent = true}
-- Recommended default mappings
local MAPPINGS = {
    NewTerm = '<Leader>tt',
    NextTerm = '<Leader>tn',
    PrevTerm = '<Leader>tp',
    RenameTerm = '<Leader>tr',
    Terminals = '<Leader>T',
    ShowTerms = '<Leader>ts',
    ToggleTerm = '<C-t>'
}

local function setup(mappings)
    for command, mapping in pairs(MAPPINGS) do
        if mappings[command] == nil then
            map('n', mapping, ':' .. command .. '<CR>', opts)
            -- map('t', mapping, '<C-w>:' .. command .. '<CR>', opts)
        end
    end
end

return {setup=setup}
