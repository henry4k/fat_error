local Frame = {}
Frame.__index = Frame

--- Returns function parameters as a list.
-- Variables without names are variadic arguments.
function Frame:get_parameters()
    return self._parameters
end

--- Returns all internal local variables by name.
-- This includes the parameters, except for the variadic ones.
function Frame:get_locals()
    return self._locals
end

--- Returns all external local variables by name.
function Frame:get_upvalues()
    return self._upvalues
end

--- Returns all visible variables by name.
function Frame:get_named_variables()
    return self._named_variables
end

--- Returns all variables as a list.
function Frame:get_all_variables()
    return self._variables
end

---
-- @tparam name
-- @tparam value
-- @tparam parameterIndex
-- @tparam isUpvalue
local function add_variable(frame, v)
    table.insert(frame._variables, v)

    if v.parameter_index then
        assert(not frame._parameters[v.parameter_index])
        frame._parameters[v.parameter_index] = v
    end

    if v.name then
        if v.is_upvalue then
            frame._upvalues[v.name] = v
        else
            frame._locals[v.name] = v
        end
        frame._named_variables[v.name] = v
    end
end

local function add_locals(frame, thread, level)
    local parameter_count = assert(frame.nparams)
    local i = 1
    while true do
        local name, value = debug.getlocal(thread, level+1, i)
        if not name then break end

        local parameter_index
        if i <= parameter_count then
            parameter_index = i
        end

        if not string.match(name, '^%(') then -- internal locals start with (
            add_variable(frame, {name = name,
                                 value = value,
                                 parameter_index = parameter_index})
        end
        i = i + 1
    end
end

local function add_var_args(frame, thread, level)
    local parameter_count = assert(frame.nparams)
    local i = 1
    while true do
        local name, value = debug.getlocal(thread, level+1, -i)
        if not name then break end

        add_variable(frame, {value = value,
                             parameter_index = parameter_count + i})

        i = i + 1
    end
end

local function add_upvalues(frame)
    local fn = assert(frame.func)
    local i = 1
    while true do
        local name, value = debug.getupvalue(fn, i)
        if not name then break end

        add_variable(frame, {name = name,
                             value = value,
                             is_upvalue = true})

        i = i + 1
    end
end

local function new_frame(thread, level)
    local frame = debug.getinfo(thread, level+1, 'nSltufL')
    if not frame then return end

    frame._parameters = {}
    frame._locals = {}
    frame._upvalues = {}
    frame._named_variables = {}
    frame._variables = {}

    -- sort by ascending priority:
    add_upvalues(frame)
    add_locals(frame, thread, level+1)
    add_var_args(frame, thread, level+1)

    return setmetatable(frame, Frame)
end

local function find_value_origin(value, frame, excluded_variable)
    for var_name, var in pairs(frame._named_variables) do
        if var ~= excluded_variable then
            if var.value == value then
                return var_name
            end

            local mt = getmetatable(var.value)
            if mt and mt.__call and mt.__call == value then
                return var_name
            end
        end
    end

    local env_var = frame._named_variables._ENV
    if env_var then
        for slot_name, slot_value in pairs(env_var.value) do
            if slot_value == value then
                return slot_name
            end

            local mt = getmetatable(slot_value)
            if mt and mt.__call and mt.__call == value then
                return slot_name
            end
        end
    end
end

local function gather_value_origins(frames)
    for i, frame in ipairs(frames) do
        -- resolve parameter names (using the next frame):
        for _, variable in ipairs(frame._parameters) do
            local next_frame = frames[i+1]
            if next_frame then
                variable.origin = find_value_origin(variable.value, next_frame)
            end
        end

        -- resolve other variable names:
        for _, variable in ipairs(frame._variables) do
            if not variable.origin then
                variable.origin = find_value_origin(variable.value, frame, variable)
            end
        end
    end
end

local function trace_frames(thread, level, max_level)
    max_level = max_level or math.huge
    local frames = {}
    local i = 1
    while i <= max_level do
        local frame = new_frame(thread, level+i)
        if not frame then break end
        frames[i] = frame
        i = i + 1
    end
    gather_value_origins(frames)
    return frames
end

return setmetatable({new = new_frame,
                     trace = trace_frames},
                    {__call = function(_, ...)
                         return new_frame(...)
                     end})
