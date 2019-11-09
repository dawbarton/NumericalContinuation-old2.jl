"""
    ShootingProblems

This module implements a basic single shooting method for use with ordinary
differential equations (ODEs). The solvers are provided by OrdinaryDiffEq.jl.

This assumes that the ODE takes a `Vector` or `SVector` input and produces a
corresponding output. For small ODEs (i.e., fewer than around 20 dimensions)
`SVector` inputs are often significantly faster.

See [`addshootingproblem!`](@ref) for details.
"""
module ShootingProblems

using DocStringExtensions
using ..ProblemStructures: ProblemStructure, addvar!, addfunc!, addpars!
using OrdinaryDiffEq: solve, remake, ODEProblem, Tsit5

export addshootingproblem!

struct ShootingProblem{T, S, C}
    odeprob::T
    solver::S
    container::C
end

function (shoot::ShootingProblem)(res, u, p, tspan)
    sol = solve(remake(shoot.odeprob, u0=shoot.container(u), p=p, tspan=(tspan[1], tspan[2])), shoot.solver, save_everystep=false, save_start=false)
    res .= u .- sol[end]
end

function addshootingproblem!(prob::ProblemStructure, name::String, f, u0, p0, tspan; pnames=nothing, solver=Tsit5())
    _tspan = length(tspan) == 1 ? [zero(tspan[1]), tspan[1]] : [tspan[1], tspan[2]]
    odeprob = ODEProblem(f, u0, (_tspan[1], _tspan[2]), p0)
    container = typeof(u0)
    shooting = ShootingProblem(odeprob, solver, container)
    # Check for parameter names
    _pnames = pnames !== nothing ? pnames : ["$(name).p$i" for i in 1:length(p0)]
    if length(_pnames) != length(p0)
        throw(ArgumentError("Length of parameter vector does not match number of parameter names"))
    end
    # Create the necessary continuation variables and add the function
    uidx = addvar!(prob, "$(name).u", length(u0), u0=u0)
    pidx = addvar!(prob, "$(name).p", length(p0), u0=p0)
    tidx = addvar!(prob, "$(name).tspan", 2, u0=_tspan)
    fidx = addfunc!(prob, name, alg, (uidx, pidx, tidx), length(u0), kind=:embedded)
    addpars!(prob, _pnames, pidx, active=false)
    addpars!(prob, ("$(name).t0", "$(name).t1"), tidx, active=false)
    return fidx
end

end # module
