@testset "Events" begin
    signals = NC.Signals()
    vars = NC.Vars()
    data = NC.Data()
    funcs = NC.Functions(vars, data)
    mfuncs = NC.MonitorFunctions(funcs)
    events = NC.Events(signals, mfuncs)

    NC.add_var!(vars, "v1", 4, u0=1:4)
    NC.add_func!(funcs, "f1", 1, (out, u) -> out[1] = u[1]^2, "v1", nothing)
    NC.add_func!(funcs, "f2", 2, (out, u) -> (out[1] = u[1]*u[2]; out[2] = u[3]*u[4]), "v1", nothing)
    NC.add_mfunc!(mfuncs, "mf1", u -> u[1], "v1")

    NC.add_event!(events, "ev1", "mf1", 1.5)
    NC.add_event!(events, "ev2", "mf1", 1.5:5, kind=:EP)
    NC.add_event!(events, "ev3", "f1", 2.0, func_type=:regular)

    NC.add_signal!(signals, :event_ev5, :(()))

    @test_throws ArgumentError NC.add_event!(events, "ev1", "mf1", 1.5)
    @test_throws ArgumentError NC.add_event!(events, "ev4", "mf1", 1.5, kind=:random)
    @test_throws ArgumentError NC.add_event!(events, "ev4", "mf1", 1.5, func_type=:random)
    @test_throws ArgumentError NC.add_event!(events, "ev4", "random", 1.5)
    @test_throws ArgumentError NC.add_event!(events, "ev4", "f2", 1.5, func_type=:regular)
    @test_throws ArgumentError NC.add_event!(events, "ev4", "random", 1.5, func_type=:regular)
    @test_throws ArgumentError NC.add_event!(events, "ev5", "mf1", 1.5)

    @test NC.get_kind(events, events["ev1"]) == :SP
    @test NC.get_kind(events, events["ev2"]) == :EP
    @test NC.get_func_type(events, events["ev1"]) == :embedded
    @test NC.get_func_type(events, events["ev3"]) == :regular
    @test NC.get_signal_name(events, events["ev1"]) == :event_ev1
    @test length(events) == 3
    @test NC.has_event(events, "ev1")

    NC.initialize!(funcs, Float64)
    NC.initialize!(mfuncs, Float64)
    NC.initialize!(events, Float64)

    u0 = NC.get_initial_u(Float64, vars)
    d0 = NC.get_initial_data(data)
    NC.update_data!(mfuncs, u0, data=d0, atlas=nothing)
    NC.update_data!(events, u0, data=d0, atlas=nothing)
    ev0 = NC.check_events(events, d0, d0)
    @test isempty(ev0)

    u1 = u0 .+ 1
    d1 = deepcopy(d0)
    NC.update_data!(mfuncs, u1, data=d1, atlas=nothing)
    NC.update_data!(events, u1, data=d1, atlas=nothing)
    ev1 = NC.check_events(events, d0, d1)
    @test length(ev1) == 3
    @test (1=>1.5) in ev1
    @test (2=>1.5) in ev1
    @test (3=>2.0) in ev1

    u2 = u0 .+ 3
    d2 = deepcopy(d0)
    NC.update_data!(mfuncs, u2, data=d2, atlas=nothing)
    NC.update_data!(events, u2, data=d2, atlas=nothing)
    ev2 = NC.check_events(events, d0, d2)
    @test length(ev2) == 5
    @test (1=>1.5) in ev2
    @test (2=>1.5) in ev2
    @test (2=>2.5) in ev2
    @test (2=>3.5) in ev2
    @test (3=>2.0) in ev2

    io = IOBuffer()
    show(io, MIME("text/plain"), events)
    @test !isempty(take!(io))
end
