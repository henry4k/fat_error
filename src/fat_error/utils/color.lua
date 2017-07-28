local is_terminal
local has_stdio,  stdio  = pcall(require, 'posix.stdio')
local has_unistd, unistd = pcall(require, 'posix.unistd')
if has_stdio and has_unistd then
    is_terminal = function(file)
        assert(io.type(file) == 'file', 'Not an open file.')
        local fd = assert(stdio.fileno(file))
        return unistd.isatty(fd) == 1
    end
else
    is_terminal = function() return false end
end

local function has_color_support(file)
    if not is_terminal(file) then
        return false
    end

    if os.getenv('COLORTERM') then
        return true
    end

    if os.getenv('TERM'):match('color') then
        return true
    end

    return false
end


local attributes = -- stolen from https://github.com/kikito/ansicolors.lua
{
    -- reset
    reset =      0,

    -- misc
    bright     = 1,
    dim        = 2,
    underline  = 4,
    blink      = 5,
    reverse    = 7,
    hidden     = 8,

    -- foreground colors
    black     = 30,
    red       = 31,
    green     = 32,
    yellow    = 33,
    blue      = 34,
    magenta   = 35,
    cyan      = 36,
    white     = 37,

    -- background colors
    blackbg   = 40,
    redbg     = 41,
    greenbg   = 42,
    yellowbg  = 43,
    bluebg    = 44,
    magentabg = 45,
    cyanbg    = 46,
    whitebg   = 47
}

local function escape_code(...)
    local a = {...}
    if #a > 0 then
        for i = 1, #a do
            a[i] = assert(attributes[a[i]], 'Unknown attribute name.')
        end
        return string.char(27)..'['..table.concat(a, ';')..'m'
    else
        return ''
    end
end

return {has_color_support = has_color_support,
        escape_code = escape_code}
