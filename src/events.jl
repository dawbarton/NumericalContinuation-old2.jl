#--- Event handling

struct Events
    signals::Signals
    funcs::Functions
    mfuncs::MonitorFunctions
    didx::Int64
    names::Vector{String}
    lookup::Dict{String, Int64}
    idx::Vector{Int64}  # index to the corresponding monitor function (for embedded events) or the function (for non-embedded events)
    grpidx::Vector{Int64}  # index into the event group of functions
    values::Vector{Any}  # the values to trigger the event on
    kind::Vector{Symbol}  # :SP (special point), :EP (boundary point), or :MX (abnormal termination)
    func_type::Vector{Symbol}  # :embedded, :regular, :singular
    signal_names::Vector{Symbol}
end

function Events(signals::Signals, mfuncs::MonitorFunctions)
    funcs = get_funcs(mfuncs)
    data = get_data(funcs)
    didx = add_data!(data, "event_data")
    Events(signals, funcs, mfuncs, didx,
        String[], Dict{String, Int64}(), Int64[], Int64[], Any[], Symbol[], Symbol[], Symbol[])
end

get_kind(events::Events, eidx::Integer) = events.kind[eidx]
get_func_type(events::Events, eidx::Integer) = events.func_type[eidx]
get_signal_name(events::Events, eidx::Integer) = events.signal_names[eidx]
Base.length(events::Events) = length(events.names)
Base.getindex(events::Events, name::String) = events.lookup[name]
Base.nameof(events::Events, eidx::Integer) = events.names[eidx]

has_event(events::Events, name::String) = haskey(events.lookup, name)

function add_event!(events::Events, name::String, mu_func::Union{String, Integer}, values=0; kind::Symbol=:SP, func_type::Symbol=:embedded)
    if has_event(events, name)
        throw(ArgumentError("Event already exists: $name"))
    end
    if !(kind in (:SP, :EP, :MX))
        throw(ArgumentError("Event kind must be one of :SP, :EP, or :MX; specified kind is $kind"))
    end
    if !(func_type in (:embedded, :regular, :singular))
        throw(ArgumentError("Function type must be one of :embedded, :regular, or :singular; specified type is $func_type"))
    end
    signal_name = Symbol("event_$name")
    if has_signal(events.signals, signal_name)
        throw(ArgumentError("Event signal already exists: $signal_name"))
    end
    if func_type === :embedded
        if !has_mfunc(events.mfuncs, mu_func)
            throw(ArgumentError("Unknown monitor function: $mu_func"))
        end
        idx = mu_func isa String ? events.mfuncs[mu_func] : mu_func
        grpidx = 0
    else
        if !has_func(events.funcs, mu_func)
            throw(ArgumentError("Unknown function: $mu_func"))
        end
        idx = mu_func isa String ? events.funcs[mu_func] : mu_func
        if get_dim(events.funcs, idx) != 1
            throw(ArgumentError("Function is not one dimensional: $mu_func")) 
        end
        grpidx = add_func_to_group(events.funcs, idx, :events)
    end
    # All checking done, now modify internal structures
    add_signal!(events.signals, signal_name, :((event::String, chart, prob)))
    evidx = lastindex(events.names)+1
    push!(events.names, name)
    events.lookup[name] = evidx
    push!(events.idx, idx)
    push!(events.grpidx, grpidx)
    push!(events.values, values)
    push!(events.kind, kind)
    push!(events.func_type, func_type)
    push!(events.signal_names, signal_name)
    return evidx
end

function initialize!(events::Events, prob)
    T = get_numtype(prob)
    data = get_data(events.funcs)
    set_initial_data!(data, events.didx, zeros(T, sum(events.func_type .!== :embedded))) # storage for non-embedded function output
    return events
end

function update_data!(events::Events, u; data, atlas)
    if !isempty(data[events.didx])
        events.funcs[:events](data[events.didx], u, data=data, atlas=atlas)
    end
    return
end

@noinline function check_event!(events::Events, evlist::Vector{<:Pair}, eidx::Integer, cmplist, v1::T, v2::T) where T
    for cmp in cmplist
        if xor(v1 < cmp, v2 < cmp) || xor(v1 == cmp, v2 == cmp) # ignore constant event functions
            push!(evlist, eidx=>cmp)
        end
    end
end

function check_events(events::Events, data1, data2)
    T = eltype(data1[events.didx])
    evlist = Pair{Int64, T}[]
    for eidx in eachindex(events.names)
        if events.grpidx[eidx] == 0
            v1 = get_mfunc_value(events.mfuncs, events.idx[eidx], data1)
            v2 = get_mfunc_value(events.mfuncs, events.idx[eidx], data2)
        else
            i = events.grpidx[eidx]
            v1 = data1[events.didx][i]
            v2 = data2[events.didx][i]
        end
        check_event!(events, evlist, eidx, events.values[eidx], v1, v2)
    end
    return evlist
end

function Base.show(io::IO, mime::MIME"text/plain", events::Events)
    println(io, "Events ($(length(events)) events):")
    for eidx in eachindex(events.names)
        name = nameof(events, eidx)
        kind = events.kind[eidx]
        func_type = events.func_type[eidx]
        if func_type === :embedded
            depname = "mfunc="*nameof(events.mfuncs, events.idx[eidx])
        else
            depname = "func="*nameof(events.funcs, events.idx[eidx])
        end
        value = events.values[eidx]
        println(io, "  → $name ($kind, $func_type, $depname)")
        println(io, "    • Trigger at: $value")
    end
end
