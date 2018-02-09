local Frame = require 'fat_error.Frame'


local Error = {}
Error.__index = Error

function Error:__index(key)
    if key == 'message' then
        return tostring(self.description)
    end
    return Error[key]
end

function Error:__tostring()
    local short_msg = string.gsub(self.message, "'", "\\'")
    if #short_msg > 32 then
        short_msg = string.sub(short_msg, 1, 32)..'...'
    end
    return 'Error\''..short_msg..'\''
end

function Error:trace_back(level)
    assert(not self.frames, 'Has already a stack trace.')
    local ok, frames = pcall(Frame.trace, coroutine.running(), level+1)
    if not ok then
        io.stderr:write('INTERNAL ERROR: ', frames, '\n')
    end
    self.frames = frames
end

local function is_error(value)
    return getmetatable(value) == Error
end

local function new_error(description, parent)
    -- To be able to rethrow regular error messages:
    if parent and not is_error(parent) then
        parent = new_error(parent)
    end

    local self = setmetatable({}, Error)
    self.description = description
    self.parent = parent
    return self
end

return setmetatable({is_instance = is_error},
                    {__call = function(_, ...) return new_error(...) end})
