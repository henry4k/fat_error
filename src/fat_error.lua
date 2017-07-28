local Error = require 'fat_error.Error'


local function message_handler(e)
    if not Error.is_instance(e) then
        e = Error(e)
    end
    e:trace_back(3)
    return e
end

local function protected_call(fn, ...)
    return xpcall(fn, message_handler, ...)
end

local function handle_error(ok, ...)
    if ok then
        return ...
    else
        local err = ...
        error(err, 0)
    end
end

local function create_coroutine_with_error_handler(fn)
    return coroutine.create(function(...)
        return handle_error(protected_call(fn, ...))
    end)
end

local function propagate_error(ok, ...)
    if ok then
        return ...
    else
        local err = ...
        error(Error('coroutine error', err), 0)
    end
end

local function resume_coroutine_and_propagate_error(coro, ...)
    return propagate_error(coroutine.resume(coro, ...))
end

return {message_handler = message_handler,
        pcall = protected_call,
        create_coroutine_with_error_handler = create_coroutine_with_error_handler,
        resume_coroutine_and_propagate_error = resume_coroutine_and_propagate_error}
