@testset "Monitor functions" begin
    vars = NC.Vars()
    data = NC.Data()
    funcs = NC.Functions(vars, data)
    mfuncs = NC.MonitorFunctions(funcs)
    @test_throws ArgumentError NC.MonitorFunctions(funcs)
    NC.add_var!(funcs, "v1", 4)
    NC.add_mfunc!(mfuncs, "mfunc1", u -> u[1]-1, "v1")
    @test_throws ArgumentError NC.add_mfunc!(mfuncs, "mfunc1", u -> u[1]-1, "v1")
    @test_throws ArgumentError NC.add_mfunc!(mfuncs, "v1", u -> u[1]-1, "v1")
    @test NC.get_indices(vars, vars["mfunc1"]) == 5:5
    @test NC.get_dim(vars) == 5
    @test length(mfuncs) == 1
    NC.add_mfunc!(mfuncs, "mfunc2", u -> u[2]+0.5, "v1", initial_value=0.5, active=false)
    NC.initialize!(mfuncs, Float64)
    @test NC.get_initial_data(data, data["mfunc_data"]) == [-1, 0.5]
    @test NC.get_initial_u(vars, vars["mfunc1"]) == [-1]
    @test NC.get_initial_u(vars, vars["mfunc2"]) == [0.5]
    @test NC.get_initial_u(Float64, vars) == [0, 0, 0, 0, -1]
    mfunc_data = NC.get_initial_data(data)
    NC.update_data!(mfuncs, [0, 0, 0, 0, 2.5], data=mfunc_data)
    @test NC.get_mfunc_value(mfuncs, mfuncs["mfunc2"], mfunc_data) == 0.5
    NC.set_active!(mfuncs, mfuncs["mfunc2"], true)
    @test NC.get_initial_u(Float64, vars) == [0, 0, 0, 0, -1, 0.5]
    io = IOBuffer()
    show(io, MIME("text/plain"), mfuncs)
    @test !isempty(take!(io))
    @test NC.get_funcs(mfuncs) isa NC.Functions
    NC.set_active!(mfuncs, "mfunc1", false)
    out = zeros(2)
    NC.eval_func!(out, funcs, NC.get_funcs(funcs, :mfunc), zeros(5), data=mfunc_data, atlas=nothing)
    @test out == [-3.5, 0.5]    
    @test NC.has_mfunc(mfuncs, "mfunc1")
    @test NC.has_mfunc(mfuncs, mfuncs["mfunc1"])
    @test !NC.has_mfunc(mfuncs, length(mfuncs)+1)
    
    vars = NC.Vars()
    data = NC.Data()
    funcs = NC.Functions(vars, data)
    mfuncs = NC.MonitorFunctions(funcs)
    NC.add_var!(funcs, "v1", 4, u0=1:4)
    @test_throws ArgumentError NC.add_pars!(mfuncs, ["p1", "p2", "p3", "p4", "p5"], "v1")
    NC.add_pars!(mfuncs, ["p1", "p2", "p3", "p4"], "v1")
    @test length(funcs) == 4
    NC.initialize!(mfuncs, Float64)
    @test NC.get_initial_data(data, data["mfunc_data"]) == 1:4
    @test NC.get_dim(vars) == 4
    @test NC.get_dim(funcs, :mfunc) == 4
end
