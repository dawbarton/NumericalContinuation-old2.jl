#--- Monitor Functions

struct MonitorFunctionWrapper{F}
    idx::Int64
    func::F
end

function (mfunc::MonitorFunctionWrapper)(output, um, u...; var"%mfunc", kwargs...)
    mu = isempty(um) ? (var"%mfunc")[mfunc.idx] : um[1]
    output[1] = mfunc.func(u...; kwargs...) - mu
    return nothing
end

struct MonitorFunctions
    funcs::Functions
    names::Vector{String}
    lookup::Dict{String, Int64}
    didx::Int64
    fidx::Vector{Int64}
    muidx::Vector{Int64}
end

function MonitorFunctions(funcs::Functions)
    didx = add_data!(funcs, "mfunc_data", nothing)
    return MonitorFunctions(funcs, String[], Dict{String, Int64}(), didx, Int64[], Int64[])
end

Base.length(mfunc::MonitorFunctions) = length(mfunc.names)
Base.getindex(mfunc::MonitorFunctions, name::String) = mfunc.lookup[name]
has_mfunc(mfunc::MonitorFunctions, name::String) = haskey(mfunc.lookup, name)

function add_mfunc!(mfunc::MonitorFunctions, name::String, func, vars; data=(), prob=false, active::Bool=true, initial_value=nothing)
    if has_mfunc(mfunc, name)
        throw(ArgumentError("Monitor function already exists: $name"))
    end
    if has_var(mfunc.funcs, name)
        throw(ArgumentError("Continuation variable already exists: $name"))
    end
    midx = length(mfunc.names)+1
    fidx = add_func!(mfunc.funcs, name, 1, MonitorFunctionWrapper(midx, func), vars, [:embedded, :mfunc], data=data, prob=prob)
    # Do things in this order to ensure that user errors (e.g., with vars) bail out before corrupting internal structures
    muidx = add_var!(mfunc.funcs, name, active ? 1 : 0, u0=(initial_value isa Number ? [initial_value] : initial_value))
    set_vardeps!(mfunc.funcs, fidx, pushfirst!(get_vardeps(mfunc.funcs, fidx), muidx))
    set_datadeps!(mfunc.funcs, fidx, pushfirst!(get_datadeps(mfunc.funcs, fidx), Symbol("%mfunc")=>mfunc.didx))
    push!(mfunc.names, name)
    mfunc.lookup[name] = midx
    push!(mfunc.fidx, fidx)
    push!(mfunc.muidx, muidx)
    return midx
end

function add_par!(mfunc::MonitorFunctions, name::String, var::Union{String, Int64}; index::Int64=1, active::Bool=false)
    let index=index
        add_mfunc!(mfunc, name, u -> getindex(u, index), var, active=active)
    end
end

function add_pars!(mfunc::MonitorFunctions, names, var::Union{String, Int64}; active::Bool=false)
    vars = get_vars(mfunc.funcs)
    u_dim = get_dim(vars, var isa String ? vars[var] : var)
    p_dim = length(names)
    if u_dim != p_dim
        throw(ArgumentError("Number of parameters ($p_dim) does not match the dimension of the variable ($u_dim)"))
    end
    idx = 1
    p_idx = zeros(Int64, p_dim)
    for name in names
        p_idx[idx] = add_par!(mfunc, name, var, index=idx, active=active)
        idx += 1
    end
    return p_idx
end

set_active!(mfunc::MonitorFunctions, midx::Int64, active) = set_dim!(get_vars(mfunc.funcs), mfunc.muidx[midx], active ? 1 : 0)
set_active!(mfunc::MonitorFunctions, name::String, active) = set_active!(mfunc, mfunc[name], active)

function mfunc_initialize!(T::Type{<:Number}, mfunc::MonitorFunctions; prob)
    vars = get_vars(mfunc.funcs)
    data = get_data(mfunc.funcs)
    mfunc_data = zeros(T, length(mfunc))
    set_data!(data, mfunc.didx, mfunc_data)
    output = zeros(T, 1)
    for i in eachindex(mfunc.muidx)
        mu = get_u0(vars, mfunc.muidx[i])
        if mu === nothing
            eval_func!(output, mfunc.funcs, [mfunc.fidx[i]], get_u0(T, vars), data=get_data(data), prob=prob)
            set_u0!(vars, mfunc.muidx[i], [output[1]])
            mfunc_data[i] = output[1]
        else
            mfunc_data[i] = mu[1]
        end
    end
    return mfunc
end

function mfunc_update_data!(data, mfunc::MonitorFunctions, u)
    vars = get_vars(mfunc.funcs)
    mfunc_data = data[mfunc.didx]
    for i in eachindex(mfunc.muidx)
        muidx = mfunc.muidx[i]
        if get_dim(vars, muidx) == 1
            mfunc_data[i] = u[get_indices(vars, muidx)[1]]
        end
    end
end

get_funcs(mfunc::MonitorFunctions) = mfunc.funcs

function Base.show(io::IO, mime::MIME"text/plain", mfuncs::MonitorFunctions)
    vars = get_vars(mfuncs.funcs)
    data = get_data(mfuncs.funcs)
    println(io, "MonitorFunctions:")
    for i in eachindex(mfuncs.names)
        name = mfuncs.names[i]
        active = get_dim(vars, mfuncs.muidx[i]) == 1 ? "active" : "inactive"
        vdeps = join([nameof(vars, dep) for dep in get_vardeps(mfuncs.funcs, mfuncs.fidx[i])], ", ")
        ddeps = join([nameof(data, last(dep)) for dep in get_datadeps(mfuncs.funcs, mfuncs.fidx[i])], ", ")
        println(io, "  → $name ($active) that depends on")
        !isempty(vdeps) && println(io, "    • variables: $vdeps")
        !isempty(ddeps) && println(io, "    • data: $ddeps")
    end
end
