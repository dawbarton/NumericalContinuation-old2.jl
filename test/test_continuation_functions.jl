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
    @test NC.get_u0(v, v1) === nothing
    @test NC.get_u0(v, v2) == [1.25, 2.5]
    @test NC.get_u0(v, v3) == 1:2
    @test NC.get_u0(v, v3) isa UnitRange
    @test NC.get_t0(v, v1) === nothing
    @test NC.get_t0(v, v2) === nothing
    @test NC.get_t0(v, v3) == 3:4
    @test NC.get_t0(v, v3) isa UnitRange
    @test NC.get_u0(Int64, v) == [0, 1, 2]
    @test NC.get_u0(Int64, v) isa Vector{Int64}
    @test NC.get_u0(v) == [0.0, 1.0, 2.0]
    @test NC.get_u0(v) isa Vector{Float64}
    @test NC.get_t0(Int64, v) == [0, 3, 4]
    @test NC.get_t0(Int64, v) isa Vector{Int64}
    @test NC.get_t0(v) == [0.0, 3.0, 4.0]
    @test NC.get_t0(v) isa Vector{Float64}
    @test NC.get_indices(v, v1) == 1:1
    @test length(NC.get_indices(v, v2)) == 0
    @test NC.get_indices(v, v3) == 2:3
    @test nameof(v, v1) == "v1"
    @test NC.has_var(v, "v1")
    NC.set_u0!(v, v1, [1])
    NC.set_t0!(v, v1, [2])
    @test NC.get_u0(v) == [1, 1, 2]
    @test NC.get_t0(v) == [2, 3, 4]
    @test_throws ArgumentError NC.set_dim!(v, 1, 5)
    NC.set_dim!(v, v1, 2)
    @test NC.get_indices(v, v1) == 1:2
    @test_throws ErrorException NC.get_u0(v)  
    io = IOBuffer()
    show(io, MIME("text/plain"), v)
    @test !isempty(take!(io))
end

@testset "Continuation data" begin
    data = NC.Data()
    d1 = NC.add_data!(data, "d1", nothing)
    d2 = NC.add_data!(data, "d2", 1:1000)
    @test_throws ArgumentError NC.add_data!(data, "d1", nothing)
    @test NC.get_data(data, data["d1"]) === nothing
    @test NC.get_data(data, d2) == 1:1000
    NC.set_data!(data, d1, (1, 2, 3))
    @test NC.get_data(data, data["d1"]) == (1, 2, 3)
    @test nameof(data, d2) == "d2"
    @test NC.get_data(data) == ((1, 2, 3), 1:1000)
    @test NC.has_data(data, "d1")
    @test length(data) == 2
    io = IOBuffer()
    show(io, MIME("text/plain"), data)
    @test !isempty(take!(io))    
end

@testset "Continuation functions" begin
    f1 = (out, x...; data=0) -> out[1] = sum(reduce(vcat, x)) + data
    f2 = (out, x...; dta) -> (out[1] = sum(reduce(vcat, x)) + dta; out[2] = x[2][1])
    f3 = (out, x...; prob) -> out[1] = sum(reduce(vcat, x)) + prob
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
    NC.add_func!(func, "f1d", 1, f1, "v1", data="d1")
    NC.add_func!(func, "f1e", 1, f1, "v1", data=d1)
    NC.add_func!(func, "f3", 1, f3, ("v1", "v2"), prob=true)
    @test length(func) == 8
    @test NC.get_vars(func) isa NC.Vars
    @test NC.get_data(func) isa NC.Data
    @test collect(NC.get_groups(func)) == [:embedded, :monitor]
    @test_throws ArgumentError func[:random]
    @test nameof(func, func["f1"]) == "f1"
    @test NC.get_dim(func, func["f2"]) == 2
    @test NC.get_func(func, func["f1"]) === f1
    @test NC.get_vardeps(func, func["f1a"]) == [v1, v2]
    @test NC.get_datadeps(func, func["f2"]) == [:dta=>d1]
    @test NC.get_probdep(func, func["f1"]) == false
    @test NC.get_groups(func, func["f2"]) == [:embedded, :monitor]
    @test NC.has_func(func, "f1")
    @test NC.has_group(func, :monitor)
    @test NC.has_var(func, "v1")
    @test NC.has_data(func, "d1")
    @test NC.get_dim(func, :embedded) == 9
    @test NC.get_dim(func, :monitor) == 2
    u = [2.5, 4.0]
    d = (8.5,)
    prob = 3.25
    out = zeros(Float64, NC.get_dim(func, :embedded))
    func[:embedded](out, u, data=d, prob=prob)
    @test out == [u[1], sum(u[1:2])+d[1], u[2], sum(u[1:2])+d[1], u[1]+d[1], u[2]+d[1], u[1]+d[1], u[1]+d[1], sum(u[1:2])+prob]
    g1 = (out, u1, u2) -> out[1] = u1[1]+u2[1]
    g2 = (out, u1; dta) -> out[1] = u1[1]+dta
    g3 = (out, u1; prob) -> out[1] = u1[1]+prob
    out2 = zeros(Float64, 1)
    func = NC.Functions()
    v1 = NC.add_var!(func, "v1", 1)
    v2 = NC.add_var!(func, "v2", 1)
    NC.add_func!(func, "func", 1, g1, "v1")
    @test_throws MethodError func[:embedded](out2, u, data=nothing, prob=nothing)
    NC.set_vardeps!(func, func["func"], [v1, v2])
    func[:embedded](out2, u, data=nothing, prob=nothing)
    @test out2 == [u[1]+u[2]]
    func = NC.Functions()
    v1 = NC.add_var!(func, "v1", 1)
    d1 = NC.add_data!(func, "d1")
    NC.add_func!(func, "func", 1, g2, "v1")
    @test_throws UndefKeywordError func[:embedded](out2, u, data=d, prob=nothing)
    NC.set_datadeps!(func, func["func"], [:dta=>d1])
    func[:embedded](out2, u, data=d, prob=nothing)
    @test out2 == [u[1]+d[1]]
    func = NC.Functions()
    v1 = NC.add_var!(func, "v1", 1)
    NC.add_func!(func, "func", 1, g3, "v1", prob=false)
    @test_throws UndefKeywordError func[:embedded](out2, u, data=nothing, prob=prob)
    NC.set_probdep!(func, func["func"], true)
    func[:embedded](out2, u, data=nothing, prob=prob)
    @test out2 == [u[1]+prob]
end
