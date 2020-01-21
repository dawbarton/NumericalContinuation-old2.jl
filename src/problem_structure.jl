#--- Main problem structure for continuation

export ProblemStructure

export get_options, get_signals, get_vars, get_data, get_funcs, get_mfuncs
export add_signal!, connect_signal!, emit_signal
export add_var!, add_data!
export add_func!, get_func
export add_mfunc!, add_par!, add_pars!

abstract type AbstractProblemStructure{T} end

struct ProblemStructure{T<:Number} <: AbstractProblemStructure{T}
    options::Options
    signals::Signals
    vars::Vars
    data::Data
    funcs::Functions
    mfuncs::MonitorFunctions
end

function ProblemStructure(T::Type{<:Number}=Float64)
    options = Options()
    signals = Signals()
    vars = Vars()
    data = Data()
    funcs = Functions(vars, data)
    mfuncs = MonitorFunctions(funcs)
    # Default options (see default_options.jl)
    for (key, value) in DEFAULT_OPTIONS
        options[key] = value
    end
    # Standard signals
    for signal in SIGNALS
        add_signal!(signals, signal, (:(prob,)))
    end
    return ProblemStructure{T}(options, signals, vars, data, funcs, mfuncs)
end

const SIGNALS = [:pre_initialization, :post_initialization]

#--- Pretty printing

function Base.show(io::IO, mime::MIME"text/plain", prob::ProblemStructure{T}) where T
    println(io, "ProblemStructure{$T}:")
    println(io, "  → $(length(prob.options)) options set")
    println(io, "  → $(length(prob.signals)) signals")
    println(io, "  → $(length(prob.vars)) variables")
    println(io, "  → $(length(prob.data)) data")
    println(io, "  → $(length(prob.funcs)) functions")
    println(io, "  → $(length(prob.mfuncs)) monitor functions")
end

#--- Accessors

get_options(prob::ProblemStructure) = prob.options
get_signals(prob::ProblemStructure) = prob.signals
get_vars(prob::ProblemStructure) = prob.vars
get_data(prob::ProblemStructure) = prob.data
get_funcs(prob::ProblemStructure) = prob.funcs
get_mfuncs(prob::ProblemStructure) = prob.mfuncs

Base.getindex(prob::ProblemStructure) = prob.options
Base.getindex(prob::ProblemStructure, key) = getindex(prob.options, key)
Base.setindex!(prob::ProblemStructure, key, value) = setindex!(prob.options, key, value)

get_numtype(prob::ProblemStructure{T}) where T = T

#--- Function forwarding

add_signal!(prob::ProblemStructure, args...; kwargs...) = add_signal!(prob.signals, args...; kwargs...)
connect_signal!(prob::ProblemStructure, args...; kwargs...) = connect_signal!(prob.signals, args...; kwargs...)
emit_signal(prob::ProblemStructure, args...; kwargs...) = emit_signal(prob.signals, args...; kwargs...)
add_var!(prob::ProblemStructure, args...; kwargs...) = add_var!(prob.vars, args...; kwargs...)
add_data!(prob::ProblemStructure, args...; kwargs...) = add_data!(prob.data, args...; kwargs...)
add_func!(prob::ProblemStructure, args...; kwargs...) = add_func!(prob.funcs, args...; kwargs...)
get_func(prob::ProblemStructure, args...; kwargs...) = get_func(prob.funcs, args...; kwargs...)
add_mfunc!(prob::ProblemStructure, args...; kwargs...) = add_mfunc!(prob.mfuncs, args...; kwargs...)
add_par!(prob::ProblemStructure, args...; kwargs...) = add_par!(prob.mfuncs, args...; kwargs...)
add_pars!(prob::ProblemStructure, args...; kwargs...) = add_pars!(prob.mfuncs, args...; kwargs...)

#--- Initialization

function initialize!(prob::ProblemStructure{T}, args...) where T
    emit_signal(prob, :pre_initialization, prob)
    mfunc_initialize!(T, prob.mfuncs, prob=prob)
    emit_signal(prob, :post_initialization, prob)
end
