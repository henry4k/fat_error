local Frame = require 'fat_error.Frame'

describe('A frame', function()
    it('uses the correct stack level', function()
        local bar_frame
        local foo_frame
        local function bar()
            bar_frame = Frame(coroutine.running(), 1)
            foo_frame = Frame(coroutine.running(), 2)
        end
        local function foo()
            bar()
        end
        foo()
        assert.are.equals(bar, bar_frame.func)
        assert.are.equals(foo, foo_frame.func)
    end)

    it('collects parameters', function()
        local frame
        local function foo(bar, baz, ...)
            frame = Frame(coroutine.running(), 1)
        end
        foo('BAR', 'BAZ', 'BOO', 'MOO')
        local params = frame:get_parameters()
        assert.are.equal(#params, 4)
        assert.are.same({name = 'bar',
                         value = 'BAR',
                         parameter_index = 1}, params[1])
        assert.are.same({name = 'baz',
                         value = 'BAZ',
                         parameter_index = 2}, params[2])
        assert.are.same({value = 'BOO',
                         parameter_index = 3}, params[3])
        assert.are.same({value = 'MOO',
                         parameter_index = 4}, params[4])
    end)

    it('collects locals', function()
        local frame
        local function foo()
            local bar = 'BAR'
            local baz = 'BAZ'
            frame = Frame(coroutine.running(), 1)
        end
        foo()
        local locals = frame:get_locals()
        assert.are.same({name = 'bar',
                         value = 'BAR'}, locals.bar)
        assert.are.same({name = 'baz',
                         value = 'BAZ'}, locals.baz)
    end)

    it('collects upvalues', function()
        local frame
        local function foo()
            local baz = 'BAZ'
            local boo = 'BOO'
            local function bar()
                frame = Frame(coroutine.running(), 1)
                return baz..boo
            end
            bar()
        end
        foo()
        local upvalues = frame:get_upvalues()
        assert.are.same({name = 'baz',
                         value = 'BAZ',
                         is_upvalue = true}, upvalues.baz)
        assert.are.same({name = 'boo',
                         value = 'BOO',
                         is_upvalue = true}, upvalues.boo)
    end)

    it('finds origin of variables', function()
        local frames
        local function foo()
            local moo = {}
            local function bar(boo_param)
                local moo_local = moo
                frames = Frame.trace(coroutine.running(), 1, 2)
            end
            local boo = {}
            bar(boo)
        end
        foo()
        assert.are.equal(#frames, 2)
        local vars = frames[1]:get_named_variables()
        assert.are.same({name = 'boo_param',
                         origin = 'boo',
                         value = {},
                         parameter_index = 1}, vars.boo_param)
        assert.are.same({name = 'moo_local',
                         origin = 'moo',
                         value = {}}, vars.moo_local)
    end)
end)
