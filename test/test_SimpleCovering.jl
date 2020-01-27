using NumericalContinuation
using NumericalContinuation.AlgebraicProblems

@testset "SimpleCovering" begin
    prob = ProblemStructure()
    prob = add_algebraicproblem!(ProblemStructure(), "cubic", (u, p) -> u^3 - u - p, 1.5, 1, pnames=["p"])
    prob["cont.initial_direction"] = -1
    atlas = NumericalContinuation.continuation!(prob, "p"=>[-2,2])
    charts = NumericalContinuation.get_charts(atlas)
    u = Float64[]
    p = Float64[]
    for chart in charts
        c = NumericalContinuation.ChartInfo(prob, chart)
        push!(u, c.vars["cubic.u"][1])
        push!(p, c.vars["p"][1])
    end
end
