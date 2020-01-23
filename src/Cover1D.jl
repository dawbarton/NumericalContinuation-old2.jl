module Cover1D

using Base: RefValue, @kwdef
using LinearAlgebra: norm
using ..NumericalContinuation: NumericalContinuation, Vars, Functions
using ..NumericalContinuation: get_numtype, get_vars, get_funcs, get_options, 
    add_data!, add_mfunc!, add_projection!, update_projection!, get_dim,
    get_initial_u, get_initial_t, get_initial_data


# TODO: u indices change when mfuncs are active/inactive - how is that dealt
# with during covering? Might need to adjust the setactive function to update
# u & TS at the same time.

# TODO: how to deal with storing variable indices? They might change during continuation...

#--- Pseudo-arclength equation

struct PseudoArclength
    didx::Int64
end

function (pseudo::PseudoArclength)(u; data)
    res = zero(eltype(u))
    for i in eachindex(data.u)
        res += data.TS[i]*(u[i] - data.u[i])
    end
    return res
end

function NumericalContinuation.add_projection!(prob, ::Type{PseudoArclength})
    T = get_numtype(prob)
    didx = add_data!(prob, "pseudo-arclength", (u=T[], TS=T[]))
    pseudo = PseudoArclength(didx)
    midx = add_mfunc!(prob, "pseudo-arclength", pseudo, "all", active=false)
    return (pseudo, midx)
end

function NumericalContinuation.update_projection!(pseudo::PseudoArclength, u, TS; data, prob)
    d = data[pseudo.didx]
    if length(d.u) != length(u)
        resize!(d.u, length(u))
        resize!(d.TS, length(TS))
    end
    d.u .= u
    d.TS .= TS
    return
end

#--- Charts

@kwdef mutable struct Chart{T, D}
    pt::Int64
    pt_type::Symbol = :unknown  # e.g., :SP, :EP, :MX, ...
    ep_flag::Bool = false  # end point flag
    status::Symbol = :new  # e.g., :corrected, :saved, ... (TODO: what statuses are there?)
    u::Vector{T}  # solution vector
    TS::Vector{T}  # tangent space (not normalized)
    t::Vector{T}  # normalized tangent vector
    s::Int64  # direction indicator
    R::T  # step size
    data::D 
end

#--- Atlas1DOptions - continuation options

struct Atlas1DOptions{T <: Number}
    correct_initial::Bool
    initial_step::T
    initial_direction::Int64
    step_min::T
    step_max::T
    step_decrease::T
    step_increase::T
    α_max::T
    ga::T
    max_steps::Tuple{Int64, Int64}
end

function Atlas1DOptions(prob)
    T = get_numtype(prob)
    opts = get_options(prob)
    correct_initial   = get(opts, "cont.correct_initial",   true)::Bool
    initial_step      = get(opts, "cont.initial_step",      T(1/2^6))::T
    initial_direction = get(opts, "cont.initial_direction", 1)::Int64
    step_min          = get(opts, "cont.step_min",          T(1/2^20))::T
    step_max          = get(opts, "cont.step_max",          T(1))::T
    step_decrease     = get(opts, "cont.step_decrease",     T(1/2))::T
    step_increase     = get(opts, "cont.step_increase",     T(1.125))::T
    α_max             = get(opts, "cont.α_max", get(opts, "cont.alpha_max", T(0.125)))::T
    ga                = get(opts, "cont.ga",                T(0.95))::T
    max_steps         = get(opts, "cont.max_steps",         (100,100))::Tuple{Int64, Int64}
    return Atlas1DOptions{T}(correct_initial, initial_step, initial_direction, 
        step_min, step_max, step_decrease, step_increase, α_max, ga, max_steps)
end

#--- Atlas

struct Atlas1D{T, D, P}
    vars::Vars
    funcs::Functions
    projection::P
    projection_idx::Int64
    current_chart::RefValue{Chart{T, D}}
    current_curve::Vector{Chart{T, D}}
    charts::Vector{Chart{T, D}}
    options::Atlas1DOptions{T}
end

function Atlas1D(prob)
    T = get_numtype(prob)
    # Check dimensionality; should have a 1D deficit
    vars = get_vars(prob)
    funcs = get_funcs(prob)
    udim = get_dim(vars)
    fdim = get_dim(funcs, :embedded)
    if udim != (fdim + 1)
        throw(ErrorException("Problem is not suitable for 1D continuation; $udim variables != $fdim+1 functions"))
    end
    # Projection condition (typically PseudoArclength)
    (projection, projection_idx) = add_projection!(prob, get(prob[], "cont.projection", PseudoArclength))
    # Options
    options = Atlas1DOptions(prob)
    # Initial chart data
    u0 = get_initial_u(vars)
    t0 = get_initial_t(vars)  # assumption is that the active continuation variable has a non-zero value for t
    data = get_initial_data(get_data(prob))
    current_chart = Chart(pt=0, pt_type=:IP, u=u0, TS=t0, t=options.initial_direction.*t0./norm(t0), 
        data=data, R=options.initial_step, s=options.initial_direction)
    # Construct!
    D = typeof(data)
    C = typeof(current_chart)
    P = typeof(projection)
    return Atlas1D{T, D, P}(vars, funcs, projection, projection_idx, 
        Ref(current_chart), Vector{C}(), Vector{C}(), options)
end


end # module
