local api = vim.api

local function makeTerm()
    return vim.cmd('e term://zsh')
end

Terminals = {numTerms = 0, bufs = {}, recent=nil, toggled = false}

function Terminals:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self
    return o
end

function Terminals:createTerm()
    self.numTerms = self.numTerms + 1
    local newBuf = api.nvim_create_buf(false, false)
    local name = 'Terminal ' .. self.numTerms
    api.nvim_buf_call(newBuf, makeTerm)
    api.nvim_buf_set_option(newBuf, "filetype", "Terminal")
    api.nvim_buf_set_option(newBuf, 'buflisted', false)
    api.nvim_buf_set_name(newBuf, name)
    self.bufs[self.numTerms] = {focused = false,
                                name = name,
                                bufNr = newBuf,
                                index = self.numTerms}
end

function Terminals:termWin()
    local bufNr
    for index, buf in pairs(self.bufs) do
        for _, win in pairs(api.nvim_list_wins()) do
            bufNr = api.nvim_win_get_buf(win)
            if bufNr == buf.bufNr then
                return win
            end
        end
    end
    return nil
end


function Terminals:focus()
    for index, buf in pairs(self.bufs) do
        if self:isAttached(index) then
            buf.focused = true
        end
    end
end

function Terminals:setCurrent()
    local thisBuf = api.nvim_get_current_buf()
    local found
    for index, buf in pairs(self.bufs) do
        if buf.bufNr == thisBuf then
            self.recent = index
        end

        found = false
        for _, bufNr in pairs(api.nvim_list_bufs()) do
            if bufNr == buf.bufNr then
                found = true
            end
        end
        if not found then
            self:delete(index)
        end
    end
end

function Terminals:delete(termIndex)
    termIndex = termIndex or self.recent
    self.bufs[termIndex] = nil
    self.numTerms = self.numTerms - 1
    for index, buf in pairs(self.bufs) do
        if index > termIndex then
            if buf.name == 'Terminal ' .. index then
                local newName = 'Terminal ' .. index - 1
                buf.name = newName
                api.nvim_buf_set_name(buf.bufNr, newName)
            end
            buf.index = buf.index - 1
            self.bufs[index - 1] = buf
        end
        if index == self.numTerms + 1 then
            self.bufs[index] = nil
        end
    end

end

function Terminals:isAttached(termIndex)
    local bufNr
    local buf = self.bufs[termIndex]
    for _, win in pairs(api.nvim_list_wins()) do
        bufNr = api.nvim_win_get_buf(win)
        if bufNr == buf.bufNr then
            return true
        end
    end
    return false
end

function Terminals:newTerm()
    self:createTerm()
    self:attach(self.numTerms)
end

function Terminals:attach(termIndex)
    self.toggled = true
    termIndex = termIndex or self.recent
    if self:isAttached(termIndex) then
        for _, win in pairs(api.nvim_list_wins()) do
            local buf = api.nvim_win_get_buf(win)
            if buf == self.bufs[termIndex].bufNr then
                api.nvim_set_current_win(win)
            end
        end
        return
    end
    local termWin = self:termWin()
    if termWin then
        api.nvim_set_current_win(termWin)
        vim.cmd('vsplit')
    else
        vim.cmd('topleft split')
        local lines = vim.o.lines
        local toResize = .25 * lines
        vim.cmd('resize ' .. toResize)
    end
    self.bufs[termIndex].focused = true
    api.nvim_win_set_buf(0, self.bufs[termIndex].bufNr)
    self.recent = termIndex
    vim.cmd('goto 99999999')
end

function Terminals:nextTerm()
   local thisBuf = api.nvim_get_current_buf()
   for index, buf in pairs(self.bufs) do
       if buf.bufNr == thisBuf then
           local newIndex = index + 1
           if newIndex > self.numTerms then
               newIndex = 1
           end
           -- self.recent = newIndex
           api.nvim_win_set_buf(0, self.bufs[newIndex].bufNr)
           break
       end
   end
   self:setCurrent()
end

function Terminals:prevTerm()
   local thisBuf = api.nvim_get_current_buf()
   for index, buf in pairs(self.bufs) do
       if buf.bufNr == thisBuf then
           local newIndex = index - 1
           if newIndex == 0 then
               newIndex = self.numTerms
           end
           -- self.recent = newIndex
           api.nvim_win_set_buf(0, self.bufs[newIndex].bufNr)
           break
       end
   end
   self:setCurrent()
end

function Terminals:toggle()
    self:setCurrent()
    if self.numTerms == 0 then
        self:newTerm()
        self.toggled = true
        return
    end
    -- toggle on
    if not self.toggled then
        local found = false
        self.toggled = true
        for index, buf in pairs(self.bufs) do
            if buf.focused then
                found = true
                self:attach(index)
            end
        end
        if not found then
            self:attach()
        end

    else
    -- toggle off
        self.toggled = false
        local attachedBuf, ft
        local found
        for index, buf in pairs(self.bufs) do
            found = false
            for _, win in pairs(api.nvim_list_wins()) do
                attachedBuf = api.nvim_win_get_buf(win)
                ft = api.nvim_buf_get_option(attachedBuf, 'filetype')
                if buf.bufNr == attachedBuf then
                    found = true
                end
            end
            buf.focused = found
        end
        for _, win in pairs(api.nvim_list_wins()) do
            attachedBuf = api.nvim_win_get_buf(win)
            ft = api.nvim_buf_get_option(attachedBuf, 'filetype')
            if ft == 'Terminal' then
                api.nvim_win_close(win, {force=true})
            end
        end
    end
    -- self.toggled = not self.toggled
end

function Terminals:renameTerm(termIndex)
    termIndex = termIndex or self.recent
    local newName = vim.fn.input('New name for ' .. self.bufs[termIndex].name .. ': ')
    api.nvim_buf_set_name(self.bufs[termIndex].bufNr, newName)
    self.bufs[termIndex].name = newName
end

function Terminals:show()
    print(vim.inspect(self.bufs))
end

T = Terminals:new()
return {
    terminals = T
}
