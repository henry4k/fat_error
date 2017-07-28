local pretty_print = require 'fat_error.utils.pretty_print'
local color = require 'fat_error.utils.color'
local code = color.escape_code

local colors =
{
    reset         = code('reset'),
    message       = code('bright'),
    unimportant   = code('dim', 'white'),
    location      = code(),
    key           = code('green'),
    nil_type      = code('red'),
    boolean_type  = code('magenta'),
    number_type   = code('cyan'),
    string_type   = code('yellow'),
    table_type    = code(),
    function_type = code(),
    thread_type   = code(),
    userdata_type = code()
}
local no_colors = setmetatable({}, {__index = function() return '' end})

local function autodetect_color_support(file)
    if io.type(file) == 'file' then
        return color.has_color_support(file)
    else
        return false
    end
end

--- Creates a new error writer instance.
--
-- @tparam[opt=io.stderr] destination
-- Either a file or a callback. The callback should behave like the `write`
-- method of file objects.
--
-- @tparam[bool,opt] use_color
-- Whether to use ANSI escape codes to colorize the output.
--
-- @tparam[string,opt='bottom'] head_location
-- By default the deepest frame is printed first and the error message is at
-- the bottom.
--
-- @tparam[string,opt] frame_prefix
--
-- @tparam[string,opt] aux_line_prefix
--
-- @tparam[string,opt='parameters'] show_variables
-- - `none` or ``: No variables are shown.
-- - `parameters`: Show only values of function parameters.
-- - `all`: Show all variable values.
--
-- @tparam[bool,opt=true] show_origin
-- Print the origin variable of values if available.
--
local function Writer(o)
    local destination      = o.destination or io.stderr
    local use_color        = o.use_color or autodetect_color_support(destination)
    local head_location    = o.head_location or 'bottom'
    local frame_prefix     = o.frame_prefix
    local aux_line_prefix  = o.aux_line_prefix
    local show_variables   = o.show_variables or 'parameters'
    local show_origin      = o.show_origin or true

    if not frame_prefix then
        if head_location == 'bottom' then
            frame_prefix = '    ↱ '
        else
            frame_prefix = '    ↳ '
        end
    end

    if not aux_line_prefix then
        aux_line_prefix = frame_prefix:gsub('.', ' ')
    end

    local write
    if (type(destination) == 'table' or getmetatable(destination)) and
       destination.write then
        write = function(...)
            return destination:write(...)
        end
    else
        write = destination
    end

    local c
    if use_color then
        c = colors
    else
        c = no_colors
    end
    local reset = c.reset

    local write_exception
    local write_frame

    local function write_head(e)
        write(c.message, e.message, reset, '\n')
    end

    local function write_tail(e)
        if e.parent then
            write_exception(e.parent)
        end
    end

    if head_location == 'bottom' then
        write_exception = function(e)
            write_tail(e)
            for i = #e.frames, 1, -1 do
                write_frame(e.frames[i])
            end
            write_head(e)
        end
    else
        write_exception = function(e)
            write_head(e)
            for i = 1, #e.frames do
                write_frame(e.frames[i])
            end
            write_tail(e)
        end
    end

    local function write_location(f)
        if f.what ~= 'C' then
            write(c.unimportant, 'at ', reset)
            write(c.location, f.short_src)
            if f.currentline ~= -1 then
                write(':', tostring(f.currentline))
            end
            write(reset, ' ')
        end
    end

    local function write_tail_calls(f)
        if f.istailcall then
            write(c.unimportant, frame_prefix, '... tail call(s) ...', reset, '\n')
        end
    end

    local function before_writing_value(v, is_key)
        if is_key then
            write(c.key)
        else
            write(c[type(v)..'_type'])
        end
    end

    local function after_writing_value(v, is_key)
        write(reset)
    end

    local pretty_print_options = {write = write,
                                  newline = '',
                                  indentation = '',
                                  before = before_writing_value,
                                  after = after_writing_value,
                                  assignment = c.unimportant..'='..reset,
                                  separator = c.unimportant..', '..reset,
                                  ellipsis = c.unimportant..'…'..reset}

    local function write_value(v)
        pretty_print(v, pretty_print_options)
    end

    local function write_function_name(f)
        write(c.unimportant, 'in ')
        if f.what == 'main' then
            write('main chunk')
        else
            if f.namewhat ~= '' then
                write(f.namewhat, ' ')
            end

            if f.name then
                write(reset, c.function_type, f.name)
            else
                write('?')
            end
        end
        write(reset)
    end

    local function write_variable(var)
        if var.name then
            write(c.key, var.name, reset)
            write(c.unimportant, '=', reset)
        end

        local t = type(var.value)
        if show_origin and
            var.origin and
            (t == 'function' or t == 'userdata' or t == 'table') then
            write(c.unimportant, t, ' ', reset)
            write(c.key, var.origin, reset)
        else
            write_value(var.value)
        end
    end

    local function write_function_parameters(f)
        write(c.unimportant, '(', reset)
        for i, param in ipairs(f:get_parameters()) do
            if i > 1 then
                write(c.unimportant, ', ', reset)
            end
            write_variable(param)
        end
        write(c.unimportant, ')', reset)
    end

    local function write_other_variables(f)
        for name, var in pairs(f:get_named_variables()) do
            if not var.parameter_index and not name:match'^_' then
                write(aux_line_prefix)
                write_variable(var)
                write('\n')
            end
        end
    end

    write_frame = function(f)
        if head_location ~= 'bottom' then
            write_tail_calls(f)
        end

        write(c.unimportant, frame_prefix, reset)

        write_location(f)

        write_function_name(f)
        if show_variables == 'parameters' or
           show_variables == 'all' then
            write_function_parameters(f)
        end

        write('\n')

        if show_variables == 'all' then
            write_other_variables(f)
        end

        if head_location == 'bottom' then
            write_tail_calls(f)
        end
    end

    local function write_exceptions(e)
        if head_location == 'bottom' then
            write(c.unimportant, 'Traceback (most recent call last):', reset, '\n')
        else
            write(c.unimportant, 'Traceback:', reset, '\n')
        end
        write_exception(e)
    end
    return write_exceptions
end

return Writer
