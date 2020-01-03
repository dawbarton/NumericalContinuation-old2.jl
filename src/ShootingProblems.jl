"""
    ShootingProblems

This module implements a basic single shooting method for use with ordinary
differential equations (ODEs). The solvers are provided by OrdinaryDiffEq.jl.

This assumes that the ODE takes a `Vector` or `SVector` input and produces a
corresponding output. For small ODEs (i.e., fewer than around 20 dimensions)
`SVector` inputs are often significantly faster.

See [`add_shootingproblem!`](@ref) for details.
"""
module ShootingProblems

using DocStringExtensions
using ..ProblemStructures: ProblemStructure, add_var!, add_func!, add_pars!
using OrdinaryDiffEq: solve, remake, ODEProblem, Tsit5

export add_shootingproblem!

struct ShootingProblem{T, S, C}
    odeprob::T
    solver::S
    container::C
end

function (shoot::ShootingProblem)(res, u, p, tspan)
    sol = solve(remake(shoot.odeprob, u0=shoot.container(u), p=p, tspan=(tspan[1], tspan[2])), shoot.solver, save_everystep=false, save_start=false)
    res .= u .- sol[end]
end

function add_shootingproblem!(prob::ProblemStructure, name::String, f, u0, p0, tspan; pnames=nothing, solver=Tsit5())
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
    uidx = add_var!(prob, "$(name).u", length(u0), u0=u0)
    pidx = add_var!(prob, "$(name).p", length(p0), u0=p0)
    tidx = add_var!(prob, "$(name).tspan", 2, u0=_tspan)
    fidx = add_func!(prob, name, alg, (uidx, pidx, tidx), length(u0), kind=:embedded)
    add_pars!(prob, _pnames, pidx, active=false)
    add_pars!(prob, ("$(name).t0", "$(name).t1"), tidx, active=false)
    return fidx
end

end # module
