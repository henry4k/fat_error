local function indent(depth, o)
    if depth >= 1 then
        return o.write(string.rep(o.indentation, depth))
    end
end

local function is_safe_string_key(value)
    return type(value) == 'string' and value:match('^[%a_][%w%d_]*$')
end

local function compare_keys(pair_a, pair_b)
    return pair_a.key < pair_b.key
end

local function ordered_pairs(map)
    local list = {}
    for key, value in pairs(map) do
        list[#list+1] = {key=key, value=value}
    end
    table.sort(list, compare_keys)

    local i = 1
    return function()
        local pair = list[i]
        if pair then
            i = i+1
            return pair.key, pair.value
        end
    end
end

local pretty_print_recursive

local unsafe_char_pattern = '[^%g%s]'

local specially_escaped_chars =
{
    ['\a'] = '\\a',
    ['\b'] = '\\b',
    ['\f'] = '\\f',
    ['\n'] = '\\n',
    ['\r'] = '\\r',
    ['\t'] = '\\t',
    ['\v'] = '\\v',
    ['\z'] = '\\z'
}

local function escape_char(c)
    return specially_escaped_chars[c] or '\\'..string.byte(c)
end

local type_handlers =
{
    ['nil'] = function(_, o)
        o.write('nil')
    end,

    ['boolean'] = function(value, o)
        if value then
            o.write('true')
        else
            o.write('false')
        end
    end,

    ['number'] = function(value, o)
        o.write(tostring(value))
    end,

    ['string'] = function(value, o)
        value = string.gsub(value, unsafe_char_pattern, escape_char)
        o.write("'", string.gsub(value, "'", "\\'"), "'")
    end,

    ['function'] = function(value, o)
        -- TODO: Enhance this
        o.write(tostring(value))
    end,

    ['thread'] = function(value, o)
        o.write(tostring(value))
    end,

    ['userdata'] = function(value, o)
        o.write(tostring(value))
    end,

    ['table'] = function(value, o, depth)
        if depth+1 > o.max_depth then
            if not next(value) then
                o.write(o.table_start, o.table_end)
            else
                o.write(o.table_start, o.ellipsis, o.table_end)
            end
            return
        end

        local length = #value
        local first = true
        local write = o.write
        local newline = o.newline

        write(o.table_start, newline)

        for i, v in ipairs(value) do
            if first then
                first = false
            else
                write(o.separator, newline)
            end

            indent(depth+1, o)
            pretty_print_recursive(v, o, depth+1, false)
        end

        for k, v in ordered_pairs(value) do
            -- ignore list part:
            if not (type(k) == 'number' and k >= 1 and k <= length) then
                if first then
                    first = false
                else
                    write(o.separator, newline)
                end

                indent(depth+1, o)
                if is_safe_string_key(k) then
                    o.before(k, true)
                    write(k)
                    o.after(k, true)
                else
                    write(o.table_index_start)
                    pretty_print_recursive(k, o, depth+1, true)
                    write(o.table_index_end)
                end
                o.write(o.assignment)
                pretty_print_recursive(v, o, depth+1, false)
            end
        end

        --write(newline)
        --indent(depth, o)
        write(o.table_end)
    end
}

pretty_print_recursive = function(value, o, depth, is_key)
    o.before(value, is_key)
    type_handlers[type(value)](value, o, depth)
    o.after(value, is_key)
end

local option_mt =
{
    __index =
    {
        max_depth = 1,
        before = function() end,
        after = function() end,
        newline = '\n',
        indentation = '\t',
        table_start = '{',
        table_end   = '}',
        table_index_start = '[',
        table_index_end   = ']',
        separator = ', ',
        assignment = ' = ',
        ellipsis = '...'
    }
}

---
-- Options:
--
-- - `write(...)`: Mandatory! A function, which shall behave like file:write().
-- - `max_depth`: Defaults to 1.
-- - `before(value, is_key)`: A function that is called before writing the given value.
-- - `after(value, is_key)`: A function that is called after writing the given value.
-- - `newline`: Defaults to '\n'.
-- - `indent`: Defaults to '\t'.
--
local function pretty_print(value, options)
    assert(options.write, 'No write function given.')
    setmetatable(options, option_mt)
    pretty_print_recursive(value, options, 0, false)
end

return pretty_print
