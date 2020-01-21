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
    NC.mfunc_initialize!(Float64, mfuncs, prob=nothing)
    @test NC.get_data(data, data["mfunc_data"]) == [-1, 0.5]
    @test NC.get_u0(vars, vars["mfunc1"]) == [-1]
    @test NC.get_u0(vars, vars["mfunc2"]) == [0.5]
    @test NC.get_u0(vars) == [0, 0, 0, 0, -1]
    mfunc_data = NC.get_data(data)
    NC.mfunc_update_data!(mfunc_data, mfuncs, [0, 0, 0, 0, 2.5])
    NC.set_active!(mfuncs, mfuncs["mfunc2"], true)
    @test NC.get_u0(vars) == [0, 0, 0, 0, -1, 0.5]
    io = IOBuffer()
    show(io, MIME("text/plain"), mfuncs)
    @test !isempty(take!(io))
    @test NC.get_func(mfuncs) isa NC.Functions
    NC.set_active!(mfuncs, mfuncs["mfunc1"], false)
    out = zeros(2)
    NC.eval_func!(out, funcs, NC.get_funcs(funcs, :mfunc), zeros(5), data=mfunc_data, prob=nothing)
    @test out == [-3.5, 0.5]    
end
