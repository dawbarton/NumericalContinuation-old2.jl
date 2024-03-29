#--- Signals and slots

#--- Individual signals

struct Signal
    name::Symbol
    signature::Expr
    slots::Vector{Any}
end

Signal(name::Symbol, signature::Expr) = Signal(name, signature, Any[])

(signal::Signal)(args...; kwargs...) = emit_signal(signal, args...; kwargs...)

function emit_signal(signal::Signal, args...; kwargs...)
    for slot in signal.slots
        slot(args...; kwargs...)
    end
    return
end

function connect_signal!(signal::Signal, slot)
    if slot in signal.slots
        throw(ArgumentError("Slot already connected to signal $(signal.name): $slot"))
    end
    push!(signal.slots, slot)
    return signal
end

Base.length(signal::Signal) = length(signal.slots)

#--- Collection of signals

struct Signals
    signals::Dict{Symbol, Signal}
end

Signals() = Signals(Dict{Symbol, Signal}())

Base.length(signals::Signals) = length(signals.signals)

function add_signal!(signals::Signals, name::Symbol, signature::Expr)
    if name in keys(signals.signals)
        throw(ArgumentError("Signal already exists: $name"))
    end
    return signals.signals[name] = Signal(name, signature)
end

has_signal(signals::Signals, name::Symbol) = haskey(signals.signals, name)

function connect_signal!(signals::Signals, name::Symbol, slot)
    if !haskey(signals.signals, name)
        throw(ArgumentError("Signal does not exist: $name"))
    end
    connect_signal!(signals.signals[name], slot)
    return signals
end

Base.getindex(signals::Signals, name::Symbol) = signals.signals[name]

emit_signal(signals::Signals, name::Symbol, args...; kwargs...) = emit_signal(signals.signals[name], args...; kwargs...)

#--- Pretty printing

function Base.show(io::IO, mime::MIME"text/plain", signals::Signals)
    println(io, "Signals ($(length(signals)) signals):")
    for (name, signal) in signals.signals
        println(io, "  → $name ($(length(signal)) slot functions)")
    end
end
