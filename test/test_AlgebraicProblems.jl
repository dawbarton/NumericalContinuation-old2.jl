@testset "Algebraic problems" begin
    ALG = NC.AlgebraicProblems
    prob = ALG.add_algebraicproblem!(NC.ProblemStructure(), "cubic", (u, p) -> u^3 - p, 1.5, 1, pnames=["λ"])
    NC.initialize!(prob)
    func = NC.get_group_func(prob, :embedded)
    out = zeros(Float64, 2)
    u0 = NC.get_initial_u(Float64, NC.get_vars(prob))
    d0 = NC.get_initial_data(NC.get_data(prob))
    func(out, u0, data=d0, atlas=prob)
    @test out ≈ [1.5^3-1, 0]
    @test NC.has_var(NC.get_vars(prob), "λ")

    @test_throws ArgumentError ALG.add_algebraicproblem!(NC.ProblemStructure(), "cubic", (u, p) -> u^3 - p, 1.5, 1, pnames=["λ", "β"])

    prob = ALG.add_algebraicproblem!(NC.ProblemStructure(), "cubic/product", (out, u, p) -> (out[1] = u[1]^3 - p[1]; out[2] = u[1]*u[2] - p[2]), [1.5, 2.0], [1.0, 2.0])
    NC.initialize!(prob)
    func = NC.get_group_func(prob, :embedded)
    out = zeros(Float64, 4)
    u0 = NC.get_initial_u(Float64, NC.get_vars(prob))
    d0 = NC.get_initial_data(NC.get_data(prob))
    func(out, u0, data=d0, atlas=prob)
    @test out ≈ [1.5^3-1, 1.5*2-2, 0, 0]
end
