@testset "Problem structure" begin
    prob = NC.ProblemStructure()
    _slot = Ref(0)
    slotfnc = (u; data, prob) -> _slot[] += 1
    f = (out, u; data) -> out[1] = sum(u) - data
    mf = u -> sum(u.^2)
    NC.add_signal!(prob, :random_signal1, :((u; data, prob)))
    NC.connect_signal!(prob, :random_signal1, slotfnc)
    NC.add_var!(prob, "MyVar", 10, u0=1:10)
    NC.add_data!(prob, "MyData", 2.0)
    NC.add_func!(prob, "MyFunc", 1, f, "MyVar", data="MyData")
    NC.add_mfunc!(prob, "MyMfunc", mf, "MyVar")
    NC.add_event!(prob, "MyEvent", "MyMfunc", 400)

    options = NC.get_options(prob)
    @test options === prob[]
    signals = NC.get_signals(prob)
    @test NC.has_signal(signals, :random_signal1) == 1
    vars = NC.get_vars(prob)
    @test length(vars) == 3 # includes "all"
    data = NC.get_data(prob)
    @test length(data) == 3 # includes "mfunc_data" and "event_data"
    funcs = NC.get_funcs(prob)
    @test length(funcs) == 2
    mfuncs = NC.get_mfuncs(prob)
    @test length(mfuncs) == 1
    events = NC.get_events(prob)
    @test length(events) == 1

    prob["random.option.2"] = "Hello"
    @test prob["random.option.2"] == "Hello"

    NC.add_pars!(prob, ["p$i" for i in 1:10], "MyVar")
    @test NC.get_dim(funcs, :embedded) == 12
    @test NC.get_dim(vars) == 11
    @test_throws ArgumentError NC.add_par!(prob, "p1", "MyVar")

    T = NC.get_numtype(prob)
    NC.initialize!(prob)
    u0 = NC.get_initial_u(T, vars)
    d0 = NC.get_initial_data(data)
    NC.update_data!(prob, u0, data=d0, atlas=prob)
    u1 = u0 .+ 1
    u1[end] = sum(u1[1:10].^2)  # manually fix up the monitor function rather than using a nonlinear solve
    d1 = deepcopy(d0)
    NC.update_data!(prob, u1, data=d1, atlas=prob)
    @test length(NC.check_events(prob, d0, d1)) == 1

    NC.emit_signal(prob, :random_signal1, u0, data=d0, prob=prob)
    @test _slot[] == 1
    embedded = NC.get_group_func(funcs, :embedded)
    out = zeros(T, NC.get_dim(funcs, :embedded))
    embedded(out, u0, data=d0, atlas=prob)
    @test out == [sum(1:10) - d0[data["MyData"]]; 0.0; zeros(10)]

    io = IOBuffer()
    show(io, MIME("text/plain"), prob)
    @test !isempty(take!(io))

    prob2 = NC.ProblemStructure(Float32)
    @test NC.get_numtype(prob2) === Float32
end

