#--- Continuation functions

@testset "Continuation variables" begin
    v = NC.Vars()
    v1 = NC.add_var!(v, "v1", 1)
    v2 = NC.add_var!(v, "v2", 0, u0=[1.25, 2.5])
    v3 = NC.add_var!(v, "v3", 2, u0=1:2, t0=3:4)
    v4 = NC.add_var!(v, "v4", 0)
    @test_throws ArgumentError NC.add_var!(v, "v1", 1)
    vall = v["all"]
    @test vall == 1
    @test NC.get_dim(v, vall) == 3
    @test NC.get_dim(v) == 3
    @test length(v) == 5
    @test NC.get_initial_u(v, v1) === nothing
    @test NC.get_initial_u(v, v2) == [1.25, 2.5]
    @test NC.get_initial_u(v, v3) == 1:2
    @test NC.get_initial_u(v, v3) isa UnitRange
    @test NC.get_initial_t(v, v1) === nothing
    @test NC.get_initial_t(v, v2) === nothing
    @test NC.get_initial_t(v, v3) == 3:4
    @test NC.get_initial_t(v, v3) isa UnitRange
    @test NC.get_initial_u(Int64, v) == [0, 1, 2]
    @test NC.get_initial_u(Int64, v) isa Vector{Int64}
    @test NC.get_initial_u(Float64, v) == [0.0, 1.0, 2.0]
    @test NC.get_initial_u(Float64, v) isa Vector{Float64}
    @test NC.get_initial_t(Int64, v) == [0, 3, 4]
    @test NC.get_initial_t(Int64, v) isa Vector{Int64}
    @test NC.get_initial_t(Float64, v) == [0.0, 3.0, 4.0]
    @test NC.get_initial_t(Float64, v) isa Vector{Float64}
    @test NC.get_indices(v, v1) == 1:1
    @test length(NC.get_indices(v, v2)) == 0
    @test NC.get_indices(v, v3) == 2:3
    @test nameof(v, v1) == "v1"
    @test NC.has_var(v, "v1")
    @test NC.has_var(v, v["v1"])
    NC.set_initial_u!(v, v1, [1])
    NC.set_initial_t!(v, v1, [2])
    @test NC.get_initial_u(Float64, v) == [1, 1, 2]
    @test NC.get_initial_t(Float64, v) == [2, 3, 4]
    @test_throws ArgumentError NC.set_dim!(v, 1, 5)
    NC.set_dim!(v, v1, 2)
    @test NC.get_indices(v, v1) == 1:2
    @test_throws ErrorException NC.get_initial_u(Float64, v)  
    io = IOBuffer()
    show(io, MIME("text/plain"), v)
    @test !isempty(take!(io))
end

@testset "Continuation data" begin
    data = NC.Data()
    d1 = NC.add_data!(data, "d1", nothing)
    d2 = NC.add_data!(data, "d2", 1:1000)
    @test_throws ArgumentError NC.add_data!(data, "d1", nothing)
    @test NC.get_initial_data(data, data["d1"]) === nothing
    @test NC.get_initial_data(data, d2) == 1:1000
    NC.set_initial_data!(data, d1, (1, 2, 3))
    @test NC.get_initial_data(data, data["d1"]) == (1, 2, 3)
    @test nameof(data, d2) == "d2"
    @test NC.get_initial_data(data) == ((1, 2, 3), 1:1000)
    @test NC.has_data(data, "d1")
    @test NC.has_data(data, data["d1"])
    @test length(data) == 2
    io = IOBuffer()
    show(io, MIME("text/plain"), data)
    @test !isempty(take!(io))    
end

@testset "Continuation functions" begin
    f1 = (out, x...; data=0) -> out[1] = sum(reduce(vcat, x)) + data
    f2 = (out, x...; dta) -> (out[1] = sum(reduce(vcat, x)) + dta; out[2] = x[2][1])
    f3 = (out, x...; atlas) -> out[1] = sum(reduce(vcat, x)) + atlas
    func = NC.Functions()
    v1 = NC.add_var!(func, "v1", 1)
    v2 = NC.add_var!(func, "v2", 1)
    d1 = NC.add_data!(func, "d1", 1.25)
    NC.add_func!(func, "f1", 1, f1, "v1")
    @test_throws ArgumentError NC.add_func!(func, "f1", 1, f1, v1)
    NC.add_func!(func, "f2", 2, f2, [v1, v2], [:embedded, :monitor], data=:dta=>d1)
    @test_throws ArgumentError NC.add_func!(func, "_f2", 2, f2, ["v1", v2, :v2])
    @test_throws ArgumentError NC.add_func!(func, "_f2", 2, f2, [v1, v2], data=[:dta=>d1, :data=>"d1", "data"=>"d1"])
    NC.add_func!(func, "f1a", 1, f1, ("v1", v2), data=(:data=>"d1",))
    NC.add_func!(func, "f1b", 1, f1, "v1", data=(:data=>d1,))
    NC.add_func!(func, "f1c", 1, f1, "v2", data=:data=>"d1")
    NC.add_func!(func, "f1d", 1, f1, v1, data="d1")
    NC.add_func!(func, "f1e", 1, f1, "v1", data=d1)
    NC.add_func!(func, "f1f", 1, f1, "v1", nothing, data=d1)
    NC.add_func!(func, "f3", 1, f3, ("v1", "v2"), atlas=true)
    @test length(func) == 9
    @test NC.get_vars(func) isa NC.Vars
    @test NC.get_data(func) isa NC.Data
    @test collect(NC.get_groups(func)) == [:embedded, :monitor]
    @test_throws KeyError func[:random]
    @test nameof(func, func["f1"]) == "f1"
    @test NC.get_dim(func, func["f2"]) == 2
    @test NC.get_func(func, func["f1"]) === f1
    @test NC.get_vardeps(func, func["f1a"]) == [v1, v2]
    @test NC.get_datadeps(func, func["f2"]) == [:dta=>d1]
    @test NC.get_atlasdep(func, func["f1"]) == false
    @test NC.get_memberof(func, func["f2"]) == [:embedded, :monitor]
    NC.add_func_to_group(func, func["f2"], :monitor)
    @test NC.get_memberof(func, func["f2"]) == [:embedded, :monitor]
    @test NC.get_memberof(func, func["f1"]) == [:embedded]
    NC.add_func_to_group(func, func["f1"], :monitor)
    @test NC.get_memberof(func, func["f1"]) == [:embedded, :monitor]
    @test NC.has_func(func, "f1")
    @test NC.has_func(func, func["f1"])
    @test NC.has_group(func, :monitor)
    @test NC.has_var(func, "v1")
    @test NC.has_data(func, "d1")
    @test NC.get_dim(func, :embedded) == 9
    @test NC.get_dim(func, :monitor) == 3
    u = [2.5, 4.0]
    d = (8.5,)
    atlas = 3.25
    out = zeros(Float64, NC.get_dim(func, :embedded))
    NC.close_group!(func, :embedded)
    func[:embedded](out, u, data=d, atlas=atlas)
    @test out == [u[1], sum(u[1:2])+d[1], u[2], sum(u[1:2])+d[1], u[1]+d[1], u[2]+d[1], u[1]+d[1], u[1]+d[1], sum(u[1:2])+atlas]
    out .= 0
    NC.eval_func!(out, func, NC.get_group(func, :embedded), u, data=d, atlas=atlas)
    @test out == [u[1], sum(u[1:2])+d[1], u[2], sum(u[1:2])+d[1], u[1]+d[1], u[2]+d[1], u[1]+d[1], u[1]+d[1], sum(u[1:2])+atlas]
    g1 = (out, u1, u2) -> out[1] = u1[1]+u2[1]
    g2 = (out, u1; dta) -> out[1] = u1[1]+dta
    g3 = (out, u1; atlas) -> out[1] = u1[1]+atlas
    out2 = zeros(Float64, 1)

    func = NC.Functions()
    v1 = NC.add_var!(func, "v1", 1)
    v2 = NC.add_var!(func, "v2", 1)
    NC.add_func!(func, "func", 1, g1, "v1")
    @test_throws MethodError NC.eval_func!(out2, func, NC.get_group(func, :embedded), u, data=nothing, atlas=nothing)
    NC.set_vardeps!(func, func["func"], [v1, v2])
    NC.eval_func!(out2, func, NC.get_group(func, :embedded), u, data=nothing, atlas=nothing)
    @test out2 == [u[1]+u[2]]

    func = NC.Functions()
    v1 = NC.add_var!(func, "v1", 1)
    d1 = NC.add_data!(func, "d1")
    NC.add_func!(func, "func", 1, g2, "v1")
    @test_throws UndefKeywordError NC.eval_func!(out2, func, NC.get_group(func, :embedded), u, data=d, atlas=nothing)
    NC.set_datadeps!(func, func["func"], [:dta=>d1])
    NC.eval_func!(out2, func, NC.get_group(func, :embedded), u, data=d, atlas=nothing)
    @test out2 == [u[1]+d[1]]
    io = IOBuffer()
    show(io, MIME("text/plain"), func)
    @test !isempty(take!(io))    

    func = NC.Functions()
    v1 = NC.add_var!(func, "v1", 1)
    NC.add_func!(func, "func", 1, g3, "v1", atlas=false)
    @test_throws UndefKeywordError NC.eval_func!(out2, func, NC.get_group(func, :embedded), u, data=nothing, atlas=atlas)
    NC.set_atlasdep!(func, func["func"], true)
    NC.eval_func!(out2, func, NC.get_group(func, :embedded), u, data=nothing, atlas=atlas)
    @test out2 == [u[1]+atlas]

    @test_throws KeyError func[:test]
    NC.add_func_to_group(func, func["func"], :test)
    NC.close_group!(func, :test)
    out2 .= 0
    func[:test](out2, u, data=nothing, atlas=atlas)
    @test out2 == [u[1]+atlas]
end
