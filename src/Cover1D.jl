module Cover1D

using Base: RefValue
using ..NumericalContinuation: NumericalContinuation
using ..NumericalContinuation: get_numtype, get_options, add_data!, add_mfunc!

# TODO: u indices change when mfuncs are active/inactive - how is that dealt
# with during covering? Might need to adjust the setactive function to update
# u & TS at the same time.

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

function add_projection!(prob, ::Type{PseudoArclength})
    T = get_numtype(prob)
    didx = add_data!(prob, "pseudo-arclength", (u=T[], TS=T[]))
    pseudo = PseudoArclength(didx)
    midx = add_mfunc!(prob, "pseudo-arclength", pseudo, "all", active=false)
    return (pseudo, midx)
end

function update_projection!(pseudo::PseudoArclength, u, TS; data, prob)
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

mutable struct Chart{T, D}
    pt::Int64
    pt_type::Symbol
    ep_flag::Bool
    status::Symbol
    u::Vector{T}  # solution vector
    TS::Vector{T}  # tangent space (not normalized)
    t::Vector{T}  # normalized tangent vector
    s::Int64
    R::T
    data::D
end

#--- AtlasOptions - continuation options

struct AtlasOptions{T <: Number}
    correct_initial::Bool
    initial_step::T
    initial_direction::Int64
    step_min::T
    step_max::T
    step_decrease::T
    step_increase::T
    α_max::T
    ga::T
    max_steps::Int64
end

function AtlasOptions(prob)
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
    max_steps         = get(opts, "cont.max_steps",         100)::Int64
    return AtlasOptions{T}(correct_initial, initial_step, initial_direction, 
        step_min, step_max, step_decrease, step_increase, α_max, ga, max_steps)
end

#--- Atlas

struct Atlas{T, D, P}
    vars::Vars
    projection::P
    projection_idx::Int64
    current_chart::RefValue{Chart{T, D}}
    current_curve::Vector{Chart{T, D}}
    charts::Vector{Chart{T, D}}
    options::AtlasOptions{T}
end

end # module
