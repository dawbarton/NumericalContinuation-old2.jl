module Cover1D

using Base: RefValue
using ..NumericalContinuation: add_mfunc!

#--- Pseudo-arclength equation

struct PseudoArclength{T}
    u::Vector{T}
    TS::Vector{T}
end

function PrCond(prob)
    T = numtype(prob)
    n = udim(prob)
    return PrCond{T}(zeros(T, n), zeros(T, n))
end

function (prcond::PrCond{T})(u) where T
    res = zero(T)
    for i in eachindex(prcond.u)
        res += prcond.TS[i]*(u[i] - prcond.u[i])
    end
    return res
end

function initial_prcond!(prcond::PrCond{T}, chart::Chart, contvar::Var) where T
    prcond.u .= chart.u
    prcond.TS .= zero(T)
    prcond.TS[uidx(contvar)] .= one(T)
    return
end

function update_prcond!(prcond::PrCond, chart::Chart)
    prcond.u .= chart.u
    prcond.TS .= chart.TS
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


#--- Atlas

struct Atlas{T, D}
    vars::Vars
    prcond_idx::Int64
    current_chart::RefValue{Chart{T, D}}
    current_curve::Vector{Chart{T, D}}
    charts::Vector{Chart{T, D}}

end

end # module
