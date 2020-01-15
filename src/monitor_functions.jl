#--- Monitor Functions

struct MonitorFunctionWrapper{F}
    idx::Int64
    func::F
end

function (mfunc::MonitorFunctionWrapper)(output, um, u...; mfunc_data, kwargs...)
    mu = isempty(um) ? mfunc_data[mfunc.idx] : um[1]
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

Base.getindex(mfunc::MonitorFunctions, name::String) = mfunc.lookup[name]
has_mfunc(mfunc::MonitorFunctions, name::String) = haskey(mfunc.lookup, name)

_prepend_deps(dep, deps::String) = (dep, deps)
_prepend_deps(dep, deps) = (dep, deps...)

function add_mfunc!(mfunc::MonitorFunctions, name::String, func, vars; data=(), prob=false, active=:true, initial_value=nothing)
    if has_mfunc(mfunc, name)
        throw(ArgumentError("Monitor function already exists: $name"))
    end
    push!(mfunc.names, name)
    midx = length(name)
    mfunc.lookup[name] = midx
    muidx = add_var!(mfunc.funcs, name, active ? 1 : 0, u0=initialvalue)
    fidx = add_func!(mfunc.funcs, name, 1, MonitorFunctionWrapper(midx, func), _prepend_deps(muidx, vars), :mfunc, data=_prepend_deps(mfunc.didx, data), prob=prob)
    push!(mfunc.fidx, fidx)
    push!(mfunc.muidx, muidx)
    return midx
end

set_active!(mfunc::MonitorFunctions, midx::Int64, active) = set_dim!(get_vars(mfunc.funcs), mfunc.muidx[midx], active ? 1 : 0)
set_active!(mfunc::MonitorFunctions, name::String, active) = set_active!(mfunc, mfunc[name], active)

function update_mfunc_data!(mfunc::MonitorFunctions, u, data)
    vars = get_vars(mfunc.funcs)
    mfunc_data = data[mfunc.didx]
    for i in eachindex(mfunc.muidx)
        muidx = mfunc.muidx[i]
        if get_dim(vars, muidx) == 1
            mfunc_data[i] = u[get_indicies(vars, muidx)[1]]
        end
    end
end
