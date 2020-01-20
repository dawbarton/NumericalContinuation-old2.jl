#--- Main problem structure for continuation

struct ProblemStructure
    signals::Signals
    vars::Vars
    data::Data
    funcs::Functions
    mfuncs::MonitorFunctions
end

function ProblemStructure()
    signals = Signals()
    vars = Vars()
    data = Data()
    funcs = Functions(vars, data)
    mfuncs = MonitorFunctions(funcs)
    return ProblemStructure(signals, vars, data, funcs, mfuncs)
end

#--- Pretty printing

function Base.show(io::IO, mime::MIME"text/plain", prob::ProblemStructure)
    println(io, "ProblemStructure:")
    println(io, "  → $(length(prob.signals)) signals")
    println(io, "  → $(length(prob.vars)) variables")
    println(io, "  → $(length(prob.data)) data")
    println(io, "  → $(length(prob.funcs)) functions")
    println(io, "  → $(length(prob.mfuncs)) monitor functions")
end

#--- Accessors

get_signals(prob::ProblemStructure) = prob.signals
get_vars(prob::ProblemStructure) = prob.vars
get_data(prob::ProblemStructure) = prob.data
get_funcs(prob::ProblemStructure) = prob.funcs
get_mfuncs(prob::ProblemStructure) = prob.mfuncs

#--- Function forwarding

add_signal!(prob::ProblemStructure, args...; kwargs...) = add_signal!(prob.signals, args...; kwargs...)
connect_signal!(prob::ProblemStructure, args...; kwargs...) = connect_signal!(prob.signals, args...; kwargs...)
emit_signal!(prob::ProblemStructure, args...; kwargs...) = emit_signal!(prob.signals, args...; kwargs...)
add_var!(prob::ProblemStructure, args...; kwargs...) = add_var!(prob.vars, args...; kwargs...)
add_data!(prob::ProblemStructure, args...; kwargs...) = add_data!(prob.data, args...; kwargs...)
add_func!(prob::ProblemStructure, args...; kwargs...) = add_func!(prob.funcs, args...; kwargs...)
add_mfunc!(prob::ProblemStructure, args...; kwargs...) = add_mfunc!(prob.mfuncs, args...; kwargs...)

