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
    u = [1.5,2,3,4,5]
    
end
