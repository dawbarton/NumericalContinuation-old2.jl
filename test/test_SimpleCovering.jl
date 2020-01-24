using NumericalContinuation
using NumericalContinuation.AlgebraicProblems

@testset "SimpleCovering" begin
    prob = ProblemStructure()
    add_algebraicproblem!(prob, "cubic", (u, p) -> u^3 - u - p, 1.5, 1, pnames=["p"])
    bifn = continuation(prob, "p"=>[-2,2])
end
