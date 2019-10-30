module ProblemStructures

#--- Thoughts

# Should toolboxes exist as objects in their own right, or should they simply
# set up the continuation problem and rely on the continuation functions having
# sufficient hooks into the continuation algorithm?

# Continuation functions might maintain their own data structure, but anything
# that might change from chart to chart should be stored in the chart data. (It
# might be that the same data is shared across multiple charts - this requires a
# custom copyfuncdata function to avoid making unnecessary copies.)

#--- Continuation variables

struct Vars
    names::Vector{String}
    dims::Vector{Int64}
    indices::Vector{UnitRange{Int64}}
    u0::Vector{Any}
    t0::Vector{Any}
    lookup::Dict{String, Int64}
end

Vars() = Vars(String[], Int64[], UnitRange{Int64}[], Any[], Any[], Dict{String, Int64}())

# Functions operating on individual variables

getname(vars::Vars, vidx::Int64) = vars.names[vidx]
getdim(vars::Vars, vidx::Int64) = vars.dims[vidx]
getindices(vars::Vars, vidx::Int64) = vars.indices[vidx]
getu0(vars::Vars, vidx::Int64) = vars.u0[vidx]
gett0(vars::Vars, vidx::Int64) = vars.t0[vidx]
Base.getindex(vars::Vars, name::String) = vars.lookup[name]
hasvar(vars::Vars, name::String) = haskey(vars.lookup, name)

function addvar!(vars::Vars, name::String, dim::Integer; u0=nothing, t0=nothing)
    if haskey(vars.lookup, name)
        throw(ArgumentError("Continuation variable already exists: $name"))
    end
    push!(vars.names, name)
    push!(vars.dims, 0)
    push!(vars.indices, 0:0)
    push!(vars.u0, u0)
    push!(vars.t0, t0)
    vidx = length(vars.names)
    vars.lookup[name] = vidx
    setdim!(vars, vidx, dim)
    return vidx
end

function setdim!(vars::Vars, vidx::Int64, dim::Integer)
    if vidx == 1
        last = 0
    else
        last = vars.indices[vidx-1].stop
    end
    vars.dims[vidx] = dim
    for i in vidx:length(vars.indices)
        vars.indices[i] = (last + 1):(last + vars.dims[i])
        last += vars.dims[i]
    end
    return vars
end

setu0!(vars::Vars, vidx::Int64, u0) = vars.u0[vidx] = u0
sett0!(vars::Vars, vidx::Int64, t0) = vars.t0[vidx] = t0

# Functions operating on the collection of variables

getdim(vars::Vars) = vars.indices[end].stop
Base.length(vars::Vars) = length(vars.names)

function getu0(T::Type{<: Number}, vars::Vars)
    u0 = Vector{Vector{T}}()
    for vidx in eachindex(vars.u0)
        if vars.dims[vidx] != 0
            if vars.u0[vidx] === nothing
                push!(u0, zeros(T, vars.dims[vidx]))
            elseif length(vars.u0[vidx]) == vars.dims[vidx]
                push!(u0, convert(Vector{T}, vars.u0[vidx]))
            else
                throw(ErrorException("Initial data for variable $(vars.names[vidx]) does not have the correct number of dimensions ($(vars.dims[vidx]))"))
            end
        end
    end
    reduce(vcat, u0)
end

getu0(vars::Vars) = getu0(Float64, vars)

function gett0(T::Type{<: Number}, vars::Vars)
    t0 = Vector{Vector{T}}()
    for vidx in eachindex(vars.t0)
        if vars.dims[vidx] != 0
            if vars.t0[vidx] === nothing
                push!(t0, zeros(T, vars.dims[vidx]))
            elseif length(vars.t0[vidx]) == vars.dims[vidx]
                push!(t0, convert(Vector{T}, vars.t0[vidx]))
            else
                throw(ErrorException("Initial data for variable $(vars.names[vidx]) does not have the correct number of dimensions ($(vars.dims[vidx]))"))
            end
        end
    end
    reduce(vcat, t0)
end

gett0(vars::Vars) = gett0(Float64, vars)

#--- Traits for continuation functions

passdata(func) = false
passproblem(func) = false

#--- Continuation functions (embedded or non-embedded)

struct Functions
    names::Vector{String}
    dims::Vector{Int64}
    indices::Vector{UnitRange{Int64}}
    funcs::Vector{Any}
    deps::Vector{Any}
    funcdata::Vector{Any}
    kind::Vector{Symbol}
    lookup::Dict{String, Int64}
    vars::Vars
end

Functions(vars::Vars) = Functions(String[], Int64[], UnitRange{Int64}[], Any[], Any[], Any[], Symbol[], Dict{String, Int64}(), vars)

# Functions operating on individual continuation functions

getname(funcs::Functions, fidx::Int64) = funcs.names[fidx]
getdim(funcs::Functions, fidx::Int64) = funcs.dims[fidx]
getindices(funcs::Functions, fidx::Int64) = funcs.indices[fidx]
getfunc(funcs::Functions, fidx::Int64) = funcs.funcs[fidx]
getdeps(funcs::Functions, fidx::Int64) = funcs.deps[fidx]
getfuncdata(funcs::Functions, fidx::Int64) = funcs.funcdata[fidx]
Base.getindex(funcs::Functions, name::String) = funcs.lookup[name]
hasfunc(funcs::Functions, name::String) = haskey(funcs.lookup, name)

function addfunc!(funcs::Functions, name::String, func, deps::NTuple{N, Int64} where N, dim::Integer; data=nothing, kind=:none)
    if haskey(funcs.lookup, name)
        throw(ArgumentError("Continuation function already exists: $name"))
    end
    push!(funcs.names, name)
    push!(funcs.dims, 0)
    push!(funcs.indices, 0:0)
    push!(funcs.funcs, func)
    push!(funcs.deps, deps)
    push!(funcs.funcdata, data)
    push!(funcs.kind, kind)
    fidx = length(funcs.names)
    funcs.lookup[name] = fidx
    setdim!(funcs, fidx, dim)
    return fidx
end

function setdim!(funcs::Functions, fidx::Int64, dim::Int64)
    if fidx == 1
        last = 0
    else
        last = funcs.indices[fidx-1].stop
    end
    funcs.dims[fidx] = dim
    for i in fidx:length(funcs.indices)
        funcs.indices[i] = (last + 1):(last + funcs.dims[i])
        last += funcs.dims[i]
    end
    return funcs
end

setfuncdata!(funcs::Functions, fidx::Int64, data) = funcs.funcdata[fidx] = data

# Functions operating on the collection of functions

Base.length(funcs::Functions) = length(funcs.names)

function evaluate!(res, funcs::Functions, u, prob=nothing, data=nothing)
    uv = [view(u, idx) for idx in funcs.vars.indices]
    for i in eachindex(funcs.funcs)
        args = Any[view(res, funcs.indices[i])]
        if passproblem(typeof(funcs.funcs[i]))
            push!(args, prob)
        end
        if passdata(typeof(funcs.funcs[i]))
            push!(args, data[i])
        end
        for dep in funcs.deps[i]
            push!(args, uv[dep])
        end
        funcs.funcs[i](args...)
    end
    return res
end

getinitialfuncdata(funcs::Functions) = funcs.funcdata

function copyfuncdata(funcs::Functions, data::Tuple)
    return ((copyfuncdata(funcs.funcs[i], data[i]) for i in eachindex(data))...,)
end

copyfuncdata(func, data) = deepcopy(data)

#--- Specialisations for speed of evaluation of continuation functions

struct SpecialisedFunctions{N, D, F}
    wrapped::Functions
    funcs::F
end

function SpecialisedFunctions(funcs::Functions)
    f = (funcs.funcs...,)
    deps = (funcs.deps...,)
    return SpecialisedFunctions{length(funcs.vars), deps, typeof(f)}(funcs, f)
end

function _evaluate_specialised(N, D, F)
    body = quote 
        uv = ($((:(view(u, funcs.wrapped.vars.indices[$i])) for i in Base.OneTo(N))...),)
    end
    # Call each of the problems
    for i in eachindex(D)
        expr = :(funcs.funcs[$i](view(res, funcs.wrapped.indices[$i])))
        if passproblem(F.parameters[i])
            push!(expr.args, :prob)
        end
        if passdata(F.parameters[i])
            push!(expr.args, :(data[$i]))
        end
        for j in eachindex(D[i])
            push!(expr.args, :(uv[$(D[i][j])]))
        end
        push!(body.args, expr)
    end
    # Return res
    push!(body.args, :res)
    body
end

@generated function evaluate!(res, funcs::SpecialisedFunctions{N, D, F}, u, prob=nothing, data=nothing) where {N, D, F}
    _evaluate_specialised(N, D, F)
end

getinitialdata(funcs::SpecialisedFunctions) = (funcs.wrapped.funcdata...,)
copyfuncdata(funcs::SpecialisedFunctions, data::Tuple) = copyfuncdata(funcs.wrapped, data)  # TODO: write as a generated function?

#--- Problem structure (embedded and non-embedded functions)

struct ProblemStructure
    vars::Vars
    embedded::Functions
    nonembedded::Functions
end

function ProblemStructure()
    vars = Vars()
    return ProblemStructure(vars, Functions(vars), Functions(vars))
end

getvars(prob::ProblemStructure) = prob.vars  # allow direct access to vars to avoid lots of delegation
addvar!(prob::ProblemStructure, args...; kwargs...) = addvar!(prob.vars, args...; kwargs...)

function Base.getindex(prob::ProblemStructure, name::String)
    if hasfunc(prob.embedded, name)
        return prob.embedded[name]
    elseif hasfunc(prob.nonembedded, name)
        return -prob.nonembedded[name]
    else
        throw(KeyError("Function \"$name\" not found"))
    end
end

# Allow direct access to the different functions to avoid lots of (potentially ambiguous) delegation
getembeddedfuncs(prob::ProblemStructure) = prob.embedded
getnonembeddedfuncs(prob::ProblemStructure) = prob.nonembedded

getfunc(prob::ProblemStructure, fidx::Int64) = fidx > 0 ? getfunc(prob.embedded, fidx) : getfunc(prob.nonembedded, fidx)
hasfunc(prob::ProblemStructure, name::String) = hasfunc(prob.embedded, name) || hasfunc(prob.nonembedded, name)

function addfunc!(prob::ProblemStructure, name::String, args...; kind::Symbol=:embedded, kwargs...)
    if !hasfunc(prob, name)
        if kind === :embedded
            fidx = addfunc!(prob.embedded, name, args...; kind=kind, kwargs...)
        else
            fidx = -addfunc!(prob.nonembedded, name, args...; kind=kind, kwargs...)
        end
        return fidx
    else
        throw(ArgumentError("Function \"$name\" already exists"))
    end
end

#--- Monitor functions

struct MonitorFunction{F}
    func::F
    vidx::Int64
end

passproblem(::Type{MonitorFunction}) = true
passdata(::Type{MonitorFunction}) = true

function (mfunc::MonitorFunction)(res, prob, data, um, u...)
    mu = isempty(um) ? data[1][] : um[1]
    if passproblem(typeof(mfunc.func))
        if passdata(typeof(mfunc.func))
            res[1] = mfunc.func(prob, data, u...) - mu
        else
            res[1] = mfunc.func(prob, u...) - mu
        end
    else
        if passdata(typeof(mfunc.func))
            res[1] = mfunc.func(data, u...) - mu
        else
            res[1] = mfunc.func(u...) - mu
        end
    end
    return res
end

setactive!(prob::ProblemStructure, mfunc::MonitorFunction, active::Bool) = setdim!(getvars(prob), mfunc.vidx, active ? 1 : 0)
setactive!(prob::ProblemStructure, fidx::Int64, active::Bool) = setactive!(prob, getfunc(prob, fidx), active)

copyfuncdata(mfunc::MonitorFunction, data::Tuple) = (Ref(data[1][]), copyfuncdata(mfunc.func, data[2]))

function addmonitorfunc!(prob::ProblemStructure, name::String, func, deps::NTuple{N, Int64} where N; data=nothing, active=true, val=nothing)
    vars = getvars(prob)
    _val = val === nothing ? func((getu0(vars, dep) for dep in deps)...) : val
    vidx = addvar!(vars, name, active ? 1 : 0, u0=_val)
    mfunc = MonitorFunction(func, vidx)
    addfunc!(prob, name, mfunc, (vidx, deps...), 1, data=(Ref(_val), data), kind=:embedded)
end

function addpar!(prob::ProblemStructure, name::String, vidx::Int64; active=true, offset=1)
    if getdim(getvars(prob), vidx) < offset
        throw(ArgumentError("Requested offset ($offset) is larger than the variable"))
    end
    let offset=offset
        addmonitorfunc!(prob, name, u->(@inbounds u[offset]), (vidx,), active=active) 
    end
end

function addpars!(prob::ProblemStructure, names, vidx::Int64; active=true)
    return [addpar!(prob, name, vidx, active=active, offset=offset) for (name, offset) in zip(names, Base.OneTo(length(names)))]
end

end # module
