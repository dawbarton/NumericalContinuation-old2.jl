module SimpleCoverings

using Base: RefValue, @kwdef
using LinearAlgebra: norm, dot
using ..NumericalContinuation: NumericalContinuation
using ..NumericalContinuation: ProblemStructure, Vars, Functions
using ..NumericalContinuation: get_numtype, get_vars, get_data, get_funcs,
    get_mfuncs, get_options, add_data!, add_mfunc!, add_projection!,
    update_projection!, get_dim, get_initial_u, get_initial_t, get_initial_data,
    update_data!, initialize!, get_mfunc_func, get_indices

using NLsolve: NLsolve
using ForwardDiff: ForwardDiff

using Infiltrator

# TODO: u indices change when mfuncs are active/inactive - how is that dealt
# with during covering? Might need to adjust the setactive function to update
# u & TS at the same time.

# TODO: how to deal with storing variable indices? They might change during continuation...

# TODO: events

# TODO: pass prob or atlas or both? (embed prob in atlas)

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
    midx = add_mfunc!(prob, "pseudo-arclength", pseudo, "all", data=didx, active=false, initial_value=0)
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

NumericalContinuation.get_chart_label(chart::Chart) = chart.pt
NumericalContinuation.get_chart_type(chart::Chart) = chart.pt_type
NumericalContinuation.get_chart_u(chart::Chart) = chart.u
NumericalContinuation.get_chart_t(chart::Chart) = chart.t
NumericalContinuation.get_chart_data(chart::Chart) = chart.data

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

#--- Atlas1D

struct Atlas1D{T, D, J}
    prob::ProblemStructure{T}
    vars::Vars
    funcs::Functions
    projection::J
    projection_idx::Int64
    current_chart::RefValue{Chart{T, D}}
    current_curve::Vector{Chart{T, D}}
    charts::Vector{Chart{T, D}}
    options::Atlas1DOptions{T}
end

function Atlas1D(prob, projection)
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
    (projection, projection_idx) = add_projection!(prob, projection)
    # Options
    options = Atlas1DOptions(prob)
    # Initialise the problem structure (must be done after adding all the required functions but before getting chart data)
    initialize!(prob)
    # Initial chart data
    u0 = get_initial_u(T, vars)
    t0 = get_initial_t(T, vars)  # assumption is that the active continuation variable has a non-zero value for t
    data = get_initial_data(get_data(prob))
    status = options.correct_initial ? :predicted : :corrected
    current_chart = Chart(pt=0, pt_type=:IP, u=u0, TS=t0, t=options.initial_direction.*t0./norm(t0), 
        data=data, R=options.initial_step, s=options.initial_direction, status=status)
    # Construct!
    D = typeof(data)
    C = typeof(current_chart)
    J = typeof(projection)
    return Atlas1D{T, D, J}(prob, vars, funcs, projection, projection_idx, 
        Ref(current_chart), C[], C[], options)
end

NumericalContinuation.get_prob(atlas::Atlas1D) = atlas.prob
NumericalContinuation.get_charts(atlas::Atlas1D) = atlas.charts
NumericalContinuation.get_current_chart(atlas::Atlas1D) = atlas.current_chart[]
NumericalContinuation.get_numtype(atlas::Atlas1D{T}) where T = T

#--- Covering

function covering(prob; dim)
    if dim == 1
        projection = get(prob[], "cont.projection", PseudoArclength)
        return Atlas1D(prob, projection)
    else
        throw(ArgumentError("Only able to compute 1D coverings at the moment"))
    end
end

#--- State machine

function NumericalContinuation.cover!(atlas::Atlas1D)
    state::Any = init_covering!
    while state !== nothing
        state = state(atlas)
        # println(nameof(state))
    end 
    return atlas
end

#--- States of the state machine

"""
    init_covering!(atlas)

# Outline

1. Determine the real entry point into the finite state machine based on the
   current chart status.

# Next state

* [`Coverings.correct!`](@ref) if chart status is `:predicted`,
* [`Coverings.add_chart!`](@ref) if chart status is `:corrected`,
* otherwise error.
"""
function init_covering!(atlas::Atlas1D)
    # Choose the next state
    if atlas.current_chart[].status === :predicted
        return correct!
    elseif atlas.current_chart[].status === :corrected
        return add_chart!
    else
        throw(ErrorException("current_chart has an invalid initial status"))
    end
end

"""
    correct!(atlas)

Correct the (predicted) solution in the current chart with the projection
condition as previously specified.

# Outline

1. Solve the zero-problem with the current chart as the starting guess.
2. Determine whether the solver converged;
    * if converged, set the chart status to `:corrected`, otherwise
    * if not converged, set the chart status to `:rejected`.

# Next state

* [`SimpleCoverings.add_chart!`](@ref) if the chart status is `:corrected`; otherwise
* [`SimpleCoverings.refine!`](@ref).
"""
function correct!(atlas::Atlas1D)
    # Function barrier
    # TODO: turn this into a structure rather than a closure and use the OnceDifferentiable wrapper to set up caching?
    @noinline function solve!(funcs, u0; data, prob)
        NLsolve.nlsolve((res, u) -> funcs(res, u, data=data, prob=prob), u0)
    end
    # Current chart
    chart = atlas.current_chart[]
    # Set up the projection condition
    update_projection!(atlas.projection, chart.u, chart.TS, data=chart.data, prob=atlas.prob)
    # Solve zero problem
    sol = solve!(atlas.funcs[:embedded], chart.u, data=chart.data, prob=atlas.prob)
    if NLsolve.converged(sol)
        chart.u .= sol.zero
        chart.status = :corrected
        return add_chart!
    else
        chart.status = :rejected
        return refine!
    end
end

"""
    add_chart!(atlas)

Add a corrected chart to the list of charts that defines the current curve and
update any calculated properties (e.g., tangent vector).

# Outline

1. Determine whether the chart is an end point (e.g., the maximum number of
   iterations has been reached).
2. Update the tangent vector of the chart.
3. Check whether the chart provides an adequate representation of the current
   curve (e.g., whether the angle between the tangent vectors is sufficiently
   small).

# Next state

* [`SimpleCoverings.flush!`](@ref).

# To do

1. Update monitor functions.
2. Locate events.
"""
function add_chart!(atlas::Atlas1D)
    @noinline function jacobian(funcs, u0; data, prob)
        # TODO: sort out the jacobian calculation...
        ForwardDiff.jacobian((res, u) -> funcs(res, u, data=data, prob=prob), similar(u0), u0)
    end
    T = get_numtype(atlas)
    chart = atlas.current_chart[]
    @assert (chart.status === :corrected) "Chart has not been corrected before adding"
    if chart.pt >= atlas.options.max_steps[1] # TODO: fix this! Start with just doing a continuation in one direction
        chart.pt_type = :EP
        chart.ep_flag = true
    end
    # Update the tangent vector
    dfdu = jacobian(atlas.funcs[:embedded], chart.u, data=chart.data, prob=atlas.prob)
    dfdp = zeros(T, length(chart.u))
    dfdp[end] = 1  # TODO: fix this! should get the indices associated with the projection condition
    chart.TS .= dfdu \ dfdp
    chart.t .= chart.s.*chart.TS./norm(chart.TS)
    opt = atlas.options
    # Check the angle
    if !isempty(atlas.current_curve)
        chart0 = atlas.current_curve[end]
        β = acos(clamp(dot(chart.t, chart0.t), -1, 1))
        if β > opt.α_max*opt.step_increase
            # Angle is too large, attempt to adjust step size
            if chart0.R > opt.step_min
                chart.status = :rejected
                chart0.R = clamp(chart0.R*opt.step_decrease, opt.step_min, opt.step_max)
                return predict!
            else
                @warn "Minimum step size reached but angle constraints not met" chart
            end
        end
        if opt.step_increase^2*β < opt.α_max
            mult = opt.step_increase
        else
            mult = clamp(opt.α_max / (sqrt(opt.step_increase)*β), opt.step_decrease, opt.step_increase)
        end
        chart.R = clamp(opt.ga*mult*chart.R, opt.step_min, opt.step_max)
    end
    # Update data
    update_data!(atlas.prob, chart.u, data=chart.data)
    # Store
    push!(atlas.current_curve, chart)
    return flush!
end

"""
    refine!(atlas)

Update the continuation strategy to attempt to progress the continuation after
a failed correction step.

# Outline

1. If the step size is greater than the minimum, reduce the step size to the
   larger of the minimum step size and the current step size multiplied by the
   step decrease factor.

# Next state

* [`SimpleCoverings.predict!`](@ref) if the continuation strategy was updated,
  otherwise
* [`SimpleCoverings.flush!`](@ref).
"""
function refine!(atlas::Atlas1D)
    if isempty(atlas.current_curve)
        return flush!
    else
        chart = first(atlas.current_curve)
        if chart.R > atlas.options.step_min
            chart.R = max(chart.R*atlas.options.step_decrease, atlas.options.step_min)
            return predict!
        else
            return flush!
        end
    end
end

"""
    flush!(atlas)

Given a representation of a curve in the form of a list of charts, add all
corrected charts to the atlas, and update the current curve.

# Outline

1. Add all corrected charts to the atlas.
2. If charts were added to the atlas, set the current curve to be a single
   chart at the boundary of the atlas.
   
# Next state

* [`SimpleCoverings.predict!`](@ref) if charts were added to the atlas, otherwise
* `nothing` to terminate the state machine.
"""
function flush!(atlas::Atlas1D)
    added = false
    ep_flag = false
    for chart in atlas.current_curve
        # Flush any corrected points
        # TODO: check for end points?
        if chart.status === :corrected
            chart.status = :flushed
            push!(atlas.charts, chart)
            added = true
            if chart.ep_flag
                ep_flag = true
                continue
            end
        end
    end
    if added
        # Set the new base point to be the last point flushed
        resize!(atlas.current_curve, 1)
        atlas.current_curve[1] = last(atlas.charts)
        if ep_flag
            return nothing
        else
            return predict!
        end
    else
        # Nothing was added so the continuation failed
        # TODO: indicate the type of failure?
        return nothing
    end
end

"""
    predict!(atlas)

Make a deep copy of the (single) chart in the current curve and generate a
prediction for the next chart along the curve.

# Outline

1. `deepcopy` the chart in the current curve.
2. Generate a predicted value for the solution.
3. Set the current chart equal to the predicted value.
4. Update the projection condition with the new prediction and tangent vector.

# Next state

* [`SimpleCoverings.correct!`](@ref).
"""
function predict!(atlas::Atlas1D)
    @assert length(atlas.current_curve) == 1 "Multiple charts in atlas.current_curve"
    # Copy the existing chart along with toolbox data
    predicted = deepcopy(first(atlas.current_curve))
    # Predict
    predicted.pt += 1
    predicted.u .+= predicted.R*predicted.TS*predicted.s
    predicted.status = :predicted
    atlas.current_chart[] = predicted
    return correct!
end

end # module
