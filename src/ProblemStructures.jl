module ProblemStructures

#--- Thoughts

# Should toolboxes exist as objects in their own right, or should they simply
# set up the continuation problem and rely on the continuation functions having
# sufficient hooks into the continuation algorithm?

# Continuation functions might maintain their own data structure, but anything
# that might change from chart to chart should be stored in the chart data. (It
# might be that the same data is shared across multiple charts - this requires a
# custom copy_funcdata function to avoid making unnecessary copies.)

#--- Continuation variables

struct Vars
    names::Vector{String}
    dims::Vector{Int64}
    indices::Vector{UnitRange{Int64}}
    u0::Vector{Any}
    t0::Vector{Any}
    lookup::Dict{String, Int64}
end

Vars() = Vars(String["all"], Int64[0], UnitRange{Int64}[1:0], Any[()], Any[()], Dict{String, Int64}("all"=>1))

# Functions operating on individual variables

get_name(vars::Vars, vidx::Int64) = vars.names[vidx]
get_dim(vars::Vars, vidx::Int64) = vars.dims[vidx]
get_indices(vars::Vars, vidx::Int64) = vars.indices[vidx]
get_u0(vars::Vars, vidx::Int64) = vars.u0[vidx]
get_t0(vars::Vars, vidx::Int64) = vars.t0[vidx]
Base.getindex(vars::Vars, name::String) = vars.lookup[name]
has_var(vars::Vars, name::String) = haskey(vars.lookup, name)

function add_var!(vars::Vars, name::String, dim::Integer; u0=nothing, t0=nothing)
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
    set_dim!(vars, vidx, dim)
    return vidx
end

function set_dim!(vars::Vars, vidx::Int64, dim::Integer)
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
    vars.dims[1] = last
    vars.indices[1] = 1:last
    return vars
end

set_u0!(vars::Vars, vidx::Int64, u0) = vars.u0[vidx] = u0
set_t0!(vars::Vars, vidx::Int64, t0) = vars.t0[vidx] = t0

# Functions operating on the collection of variables

get_dim(vars::Vars) = vars.indices[end].stop
Base.length(vars::Vars) = length(vars.names)

function get_u0(T::Type{<: Number}, vars::Vars)
    u0 = Vector{Vector{T}}()
    for vidx in 2:length(vars.u0)
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

get_u0(vars::Vars) = get_u0(Float64, vars)

function get_t0(T::Type{<: Number}, vars::Vars)
    t0 = Vector{Vector{T}}()
    for vidx in 2:length(vars.t0)
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

get_t0(vars::Vars) = get_t0(Float64, vars)

#--- Traits for continuation functions

pass_data(func) = false
pass_problem(func) = false

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

get_name(funcs::Functions, fidx::Int64) = funcs.names[fidx]
get_dim(funcs::Functions, fidx::Int64) = funcs.dims[fidx]
get_indices(funcs::Functions, fidx::Int64) = funcs.indices[fidx]
get_func(funcs::Functions, fidx::Int64) = funcs.funcs[fidx]
get_deps(funcs::Functions, fidx::Int64) = funcs.deps[fidx]
get_funcdata(funcs::Functions, fidx::Int64) = funcs.funcdata[fidx]
Base.getindex(funcs::Functions, name::String) = funcs.lookup[name]
has_func(funcs::Functions, name::String) = haskey(funcs.lookup, name)

function add_func!(funcs::Functions, name::String, func, deps::NTuple{N, Int64} where N, dim::Integer; data=nothing, kind=:none)
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
    set_dim!(funcs, fidx, dim)
    return fidx
end

function set_dim!(funcs::Functions, fidx::Int64, dim::Int64)
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

set_funcdata!(funcs::Functions, fidx::Int64, data) = funcs.funcdata[fidx] = data

# Functions operating on the collection of functions

Base.length(funcs::Functions) = length(funcs.names)

function evaluate!(res, funcs::Functions, u, prob=nothing, data=nothing)
    uv = [view(u, idx) for idx in funcs.vars.indices]
    for i in eachindex(funcs.funcs)
        args = Any[view(res, funcs.indices[i])]
        if pass_problem(typeof(funcs.funcs[i]))
            push!(args, prob)
        end
        if pass_data(typeof(funcs.funcs[i]))
            push!(args, data[i])
        end
        for dep in funcs.deps[i]
            push!(args, uv[dep])
        end
        funcs.funcs[i](args...)
    end
    return res
end

get_initial_funcdata(funcs::Functions) = funcs.funcdata

function copy_funcdata(funcs::Functions, data::Tuple)
    return ((copy_funcdata(funcs.funcs[i], data[i]) for i in eachindex(data))...,)
end

copy_funcdata(func, data) = deepcopy(data)

#--- Specialisations for speed of evaluation of continuation functions

# Replace with a CFunction? Still needs the tuple of functions but dependencies could be done away with
# julia> let f = (x)->x * x
#            ptr = @cfunction $f Cdouble (Cdouble,)
#            GC.@preserve ptr ccall(Base.unsafe_convert(Ptr{Cvoid}, ptr), Cdouble, (Cdouble,), 2.0)
#        end

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
        if pass_problem(F.parameters[i])
            push!(expr.args, :prob)
        end
        if pass_data(F.parameters[i])
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

get_initial_funcdata(funcs::SpecialisedFunctions) = (funcs.wrapped.funcdata...,)
copy_funcdata(funcs::SpecialisedFunctions, data::Tuple) = copy_funcdata(funcs.wrapped, data)  # TODO: write as a generated function?

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

get_vars(prob::ProblemStructure) = prob.vars  # allow direct access to vars to avoid lots of delegation
add_var!(prob::ProblemStructure, args...; kwargs...) = add_var!(prob.vars, args...; kwargs...)

function Base.getindex(prob::ProblemStructure, name::String)
    if has_func(prob.embedded, name)
        return prob.embedded[name]
    elseif has_func(prob.nonembedded, name)
        return -prob.nonembedded[name]
    else
        throw(KeyError("Function \"$name\" not found"))
    end
end

# Allow direct access to the different functions to avoid lots of (potentially ambiguous) delegation
get_embeddedfuncs(prob::ProblemStructure) = prob.embedded
get_nonembeddedfuncs(prob::ProblemStructure) = prob.nonembedded

get_func(prob::ProblemStructure, fidx::Int64) = fidx > 0 ? get_func(prob.embedded, fidx) : get_func(prob.nonembedded, fidx)
has_func(prob::ProblemStructure, name::String) = has_func(prob.embedded, name) || has_func(prob.nonembedded, name)

function add_func!(prob::ProblemStructure, name::String, args...; kind::Symbol=:embedded, kwargs...)
    if !has_func(prob, name)
        if kind === :embedded
            fidx = add_func!(prob.embedded, name, args...; kind=kind, kwargs...)
        else
            fidx = -add_func!(prob.nonembedded, name, args...; kind=kind, kwargs...)
        end
        return fidx
    else
        throw(ArgumentError("Function \"$name\" already exists"))
    end
end

function Base.show(io::IO, ::MIME"text/plain", prob::ProblemStructure)
    println(io, "ProblemStructure with $(length(prob.vars.names)-1) variables, $(length(prob.embedded.names)) embedded functions, and $(length(prob.nonembedded.names)) non-embedded functions.")
    println(io, "\nVariables (total $(prob.vars.dims[1]) dims)")
    for i in 2:length(prob.vars.names)
        name = prob.vars.names[i]
        dims = prob.vars.dims[i] == 1 ? "1 dim" : "$(prob.vars.dims[i]) dims"
        println(io, "  → $name ($dims)")
    end
    println("\nEmbedded functions (total $(sum(prob.embedded.dims)) dims)")
    for i in Base.OneTo(length(prob.embedded.names))
        name = prob.embedded.names[i]
        dims = prob.embedded.dims[i] == 1 ? "1 dim" : "$(prob.embedded.dims[i]) dims"
        deps = join([prob.vars.names[dep] for dep in prob.embedded.deps[i]], ", ")
        println(io, "  → $name ($dims; depends on $deps)")
    end
    println("\nNon-embedded functions (total $(sum(prob.nonembedded.dims)) dims)")
    for i in Base.OneTo(length(prob.nonembedded.names))
        name = prob.nonembedded.names[i]
        dims = prob.nonembedded.dims[i] == 1 ? "1 dim" : "$(prob.nonembedded.dims[i]) dims"
        deps = join([prob.vars.names[dep] for dep in prob.nonembedded.deps[i]], ", ")
        println(io, "  → $name ($dims; depends on $deps)")
    end
    return nothing
end

#--- Monitor functions

struct MonitorFunction{F}
    func::F
    vidx::Int64
end

pass_problem(::Type{MonitorFunction{F}} where F) = true
pass_data(::Type{MonitorFunction{F}} where F) = true

function (mfunc::MonitorFunction)(res, prob, data, um, u...)
    mu = isempty(um) ? data[1][] : um[1]
    if pass_problem(typeof(mfunc.func))
        if pass_data(typeof(mfunc.func))
            res[1] = mfunc.func(prob, data, u...) - mu
        else
            res[1] = mfunc.func(prob, u...) - mu
        end
    else
        if pass_data(typeof(mfunc.func))
            res[1] = mfunc.func(data, u...) - mu
        else
            res[1] = mfunc.func(u...) - mu
        end
    end
    return res
end

set_active!(prob::ProblemStructure, mfunc::MonitorFunction, active::Bool) = set_dim!(get_vars(prob), mfunc.vidx, active ? 1 : 0)
set_active!(prob::ProblemStructure, fidx::Int64, active::Bool) = set_active!(prob, get_func(prob, fidx), active)

copy_funcdata(mfunc::MonitorFunction, data::Tuple) = (Ref(data[1][]), copy_funcdata(mfunc.func, data[2]))

function add_monitorfunc!(prob::ProblemStructure, name::String, func, deps::NTuple{N, Int64} where N; data=nothing, active=true, val=nothing)
    vars = get_vars(prob)
    _val = val === nothing ? func((get_u0(vars, dep) for dep in deps)...) : val
    vidx = add_var!(vars, name, active ? 1 : 0, u0=_val)
    mfunc = MonitorFunction(func, vidx)
    add_func!(prob, name, mfunc, (vidx, deps...), 1, data=(Ref(_val), data), kind=:embedded)
end

function add_par!(prob::ProblemStructure, name::String, vidx::Int64; active=true, offset=1)
    if get_dim(get_vars(prob), vidx) < offset
        throw(ArgumentError("Requested offset ($offset) is larger than the variable"))
    end
    let offset=offset
        add_monitorfunc!(prob, name, u->(@inbounds u[offset]), (vidx,), active=active) 
    end
end

function add_pars!(prob::ProblemStructure, names, vidx::Int64; active=true)
    return [add_par!(prob, name, vidx, active=active, offset=offset) for (name, offset) in zip(names, Base.OneTo(length(names)))]
end

end # module
