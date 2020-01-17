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
    f2 = (out, x...; dta) -> (out[1] = sum(reduce(vcat, x)) + dta; out[2] = x[2])
    f3 = (out, x...; prob) -> out[1] = sum(reduce(vcat, x)) + prob
    func = NC.Functions()
    v1 = NC.add_var!(func, "v1", 1)
    v2 = NC.add_var!(func, "v2", 1)
    d1 = NC.add_data!(func, "d1", 1.25)
    NC.add_func!(func, "f1", 1, f1, "v1")
    @test_throws ArgumentError NC.add_func!(func, "f1", 1, f1, "v1")
    NC.add_func!(func, "f2", 2, f2, v1, [:embedded, :monitor], data=:dta=>d1)
    @test_throws ArgumentError NC.add_func!(func, "_f2", 2, f2, ["v1", v2, :v2])
    @test_throws ArgumentError NC.add_func!(func, "_f2", 2, f2, [v1, v2], data=[:dta=>d1, :data=>"d1", "data"=>"d1"])
    NC.add_func!(func, "f1a", 1, f1, "v1", data="d1")
    NC.add_func!(func, "f1b", 1, f1, "v1", data=d1)
    NC.add_func!(func, "f1c", 1, f1, "v1", data=:data=>"d1")
end
