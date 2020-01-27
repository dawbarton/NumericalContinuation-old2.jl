# TODO: need a way of closing the functions when initialisation is done

#--- Continuation variables

struct Vars
    names::Vector{String}
    lookup::Dict{String, Int64}
    dims::Vector{Int64}
    indices::Vector{UnitRange{Int64}}
    u0::Vector{Any}
    t0::Vector{Any}
end

Vars() = Vars(String["all"], Dict{String, Int64}("all"=>1), Int64[0], UnitRange{Int64}[1:0], Any[()], Any[()])

# Functions operating on individual variables

get_name(vars::Vars, vidx::Int64) = vars.names[vidx]
get_dim(vars::Vars, vidx::Int64) = vars.dims[vidx]
get_indices(vars::Vars, vidx::Int64) = vars.indices[vidx]
get_initial_u(vars::Vars, vidx::Int64) = vars.u0[vidx]
get_initial_t(vars::Vars, vidx::Int64) = vars.t0[vidx]
Base.nameof(vars::Vars, vidx::Int64) = get_name(vars, vidx)
Base.getindex(vars::Vars, name::String) = vars.lookup[name]
has_var(vars::Vars, name::String) = haskey(vars.lookup, name)
has_var(vars::Vars, idx::Integer) = (idx > 0) && (idx <= length(vars))

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
        throw(ArgumentError("Cannot set the dimension of the all variable"))
    elseif vidx == 2
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

set_initial_u!(vars::Vars, vidx::Int64, u0) = vars.u0[vidx] = u0
set_initial_t!(vars::Vars, vidx::Int64, t0) = vars.t0[vidx] = t0

# Functions operating on the collection of variables

Base.iterate(vars::Vars, args...) = iterate(vars.names, args...)
get_dim(vars::Vars) = vars.indices[end].stop
Base.length(vars::Vars) = length(vars.names)

function get_initial_u(T::Type{<: Number}, vars::Vars)
    u0 = Vector{T}()
    for vidx in 2:length(vars.u0)
        if vars.dims[vidx] != 0
            if vars.u0[vidx] === nothing
                append!(u0, zeros(T, vars.dims[vidx]))
            elseif length(vars.u0[vidx]) == vars.dims[vidx]
                append!(u0, convert(Vector{T}, vars.u0[vidx]))
            else
                throw(ErrorException("Initial data for variable $(vars.names[vidx]) does not have the correct number of dimensions ($(vars.dims[vidx]))"))
            end
        end
    end
    return u0
end

function get_initial_t(T::Type{<: Number}, vars::Vars)
    t0 = Vector{T}()
    for vidx in 2:length(vars.t0)
        if vars.dims[vidx] != 0
            if vars.t0[vidx] === nothing
                append!(t0, zeros(T, vars.dims[vidx]))
            elseif length(vars.t0[vidx]) == vars.dims[vidx]
                append!(t0, convert(Vector{T}, vars.t0[vidx]))
            else
                throw(ArgumentError("Initial data for variable $(vars.names[vidx]) does not have the correct number of dimensions ($(vars.dims[vidx]))"))
            end
        end
    end
    return t0
end

function Base.show(io::IO, mime::MIME"text/plain", vars::Vars)
    println(io, "Vars ($(length(vars)) variables):")
    for i in eachindex(vars.names)
        name = vars.names[i]
        dims = vars.dims[i] == 1 ? "1 dim" : "$(vars.dims[i]) dims"
        println(io, "  → $name ($dims)")
    end
    return nothing
end

#--- Continuation data

struct Data
    names::Vector{String}
    lookup::Dict{String, Int64}
    data::Vector{Any}
end

Data() = Data(String[], Dict{String, Int64}(), Any[])

# Functions operating on individual continuation data

function add_data!(data::Data, name::String, newdata=nothing)
    if haskey(data.lookup, name)
        throw(ArgumentError("Continuation data already exists: $name"))
    end
    push!(data.names, name)
    push!(data.data, newdata)
    return data.lookup[name] = length(data.names)
end

get_name(data::Data, didx::Int64) = data.names[didx]
get_initial_data(data::Data, didx::Int64) = data.data[didx]
set_initial_data!(data::Data, didx::Int64, newdata) = data.data[didx] = newdata

Base.nameof(data::Data, didx::Int64) = get_name(data, didx)
Base.getindex(data::Data, name::String) = data.lookup[name]

# Functions operating on the collection of continuation data

Base.iterate(data::Data, args...) = iterate(data.names, args...)
get_initial_data(data::Data) = (data.data...,)
has_data(data::Data, name::String) = haskey(data.lookup, name)
has_data(data::Data, idx::Integer) = (idx > 0) && (idx <= length(data))

Base.length(data::Data) = length(data.names)

function Base.show(io::IO, mime::MIME"text/plain", data::Data)
    println(io, "Data ($(length(data)) data):")
    for i in eachindex(data.names)
        name = data.names[i]
        println(io, "  → $name")
    end
    return nothing
end

#--- Continuation functions

struct Functions
    vars::Vars
    data::Data
    names::Vector{String}
    lookup::Dict{String, Int64}
    dims::Vector{Int64}
    funcs::Vector{Any}
    vardeps::Vector{Vector{Int64}}
    datadeps::Vector{Vector{Pair{Symbol, Int64}}}
    probdep::Vector{Bool}
    memberof::Vector{Vector{Symbol}}
    groups::Dict{Symbol, Vector{Int64}}
    group_func::Dict{Symbol, Any}
end

Functions(vars::Vars, data::Data) = Functions(vars, data, String[], Dict{String, Int64}(), Int64[], Any[], Vector{Int64}[], Vector{Pair{Symbol, Int64}}[], Bool[], Vector{Symbol}[], Dict{Symbol, Vector{Int64}}(), Dict{Symbol, Any}())
Functions() = Functions(Vars(), Data())

# Functions operating on individual continuation functions

get_name(funcs::Functions, fidx::Int64) = funcs.names[fidx]
get_dim(funcs::Functions, fidx::Int64) = funcs.dims[fidx]
get_func(funcs::Functions, fidx::Int64) = funcs.funcs[fidx]
get_vardeps(funcs::Functions, fidx::Int64) = funcs.vardeps[fidx]
get_datadeps(funcs::Functions, fidx::Int64) = funcs.datadeps[fidx]
get_probdep(funcs::Functions, fidx::Int64) = funcs.probdep[fidx]
get_groups(funcs::Functions, fidx::Int64) = funcs.memberof[fidx]
Base.nameof(funcs::Functions, fidx::Int64) = get_name(funcs, fidx)
Base.getindex(funcs::Functions, name::String) = funcs.lookup[name]
has_func(funcs::Functions, name::String) = haskey(funcs.lookup, name)
has_func(funcs::Functions, idx::Integer) = (idx > 0) && (idx <= length(funcs))

function add_func_to_group(funcs::Functions, fidx::Int64, name::Symbol)
    if haskey(funcs.groups, name)
        groups = funcs.groups[name]
        _idx = findfirst(==(fidx), groups)
        if _idx === nothing
            push!(funcs.memberof[fidx], name)
            push!(groups, fidx)
            idx = length(groups)
            funcs.group_func[name] = nothing
        else
            idx = _idx
        end
    else
        push!(funcs.memberof[fidx], name)
        funcs.groups[name] = [fidx]
        idx = 1
        funcs.group_func[name] = nothing
    end
    return idx
end

function _invalidate_groups(funcs::Functions, fidx::Int64)
    for grp in funcs.memberof[fidx]
        funcs.group_func[grp] = nothing
    end
end

function set_vardeps!(funcs::Functions, fidx::Int64, vars::Vector{Int64})
    funcs.vardeps[fidx] = vars
    _invalidate_groups(funcs, fidx)
    return funcs
end

function set_datadeps!(funcs::Functions, fidx::Int64, data::Vector{Pair{Symbol, Int64}})
    funcs.datadeps[fidx] = data
    _invalidate_groups(funcs, fidx)
    return funcs
end

function set_probdep!(funcs::Functions, fidx::Int64, prob::Bool)
    funcs.probdep[fidx] = prob
    _invalidate_groups(funcs, fidx)
    return funcs
end

_convert_vars(deps::Vector{Int64}, vars) = deps
_convert_vars(deps::Int64, vars) = [deps]
_convert_vars(deps::String, vars) = [vars[deps]]
function _convert_vars(deps, vars)
    _deps = Int64[]
    for dep in deps
        if typeof(dep) === String
            push!(_deps, vars[dep])
        elseif typeof(dep) === Int64
            push!(_deps, dep)
        else
            throw(ArgumentError("Variable dependencies are expected to be variable names (Strings) or variable indices (Int64)"))
        end
    end
    return _deps
end

_convert_data(deps::Vector{Pair{Symbol, Int64}}, data) = deps
_convert_data(deps::Pair{Symbol, Int64}, data) = [deps]
_convert_data(deps::Pair{Symbol, String}, data) = [first(deps)=>data[last(deps)]]
_convert_data(deps::Int64, data) = [:data=>deps]
_convert_data(deps::String, data) = [:data=>data[deps]]
function _convert_data(deps, data)
    _deps = Pair{Symbol, Int64}[]
    for dep in deps
        if typeof(dep) === Pair{Symbol, Int64}
            push!(_deps, dep)
        elseif typeof(dep) === Pair{Symbol, String}
            push!(_deps, first(dep)=>data[last(dep)])
        else
            throw(ArgumentError("Data dependencies are expected to be pair of the form `:data=>data_idx`"))
        end
    end
    return _deps
end

_convert_memberof(memberof::Vector{Symbol}) = memberof
_convert_memberof(memberof::Symbol) = [memberof]
_convert_memberof(memberof::Union{Nothing, Tuple{}}) = Symbol[]

function add_func!(funcs::Functions, name::String, dim::Integer, func, vars, memberof=:embedded; data=Pair{Symbol, Int64}[], prob::Bool=false)
    if has_func(funcs, name)
        throw(ArgumentError("Continuation function already exists: $name"))
    end
    _vars = _convert_vars(vars, funcs.vars)
    _data = _convert_data(data, funcs.data)
    _memberof = _convert_memberof(memberof)
    # All code that could error due to user inputs should be before push! to avoid data structure corruption
    push!(funcs.names, name)
    push!(funcs.dims, dim)
    push!(funcs.funcs, func)
    push!(funcs.vardeps, _vars)
    push!(funcs.datadeps, _data)
    push!(funcs.probdep, prob)
    push!(funcs.memberof, _memberof)
    fidx = funcs.lookup[name] = length(funcs.names)
    for grp in _memberof
        if haskey(funcs.groups, grp)
            push!(funcs.groups[grp], fidx)
        else
            funcs.groups[grp] = [fidx]
        end
        funcs.group_func[grp] = nothing
    end
    return fidx
end

# Functions operating on the collection of functions

Base.iterate(funcs::Functions, args...) = iterate(funcs.names, args...)
get_dim(funcs::Functions, group::Symbol) = sum(funcs.dims[funcs.groups[group]])
get_groups(funcs::Functions) = keys(funcs.groups)
get_vars(funcs::Functions) = funcs.vars
get_data(funcs::Functions) = funcs.data
has_group(funcs::Functions, name::Symbol) = haskey(funcs.groups, name)
get_funcs(funcs::Functions, name::Symbol) = funcs.groups[name]

Base.getindex(funcs::Functions, name::Symbol) = get_func(funcs, name)
Base.length(funcs::Functions) = length(funcs.names)

function get_func(funcs::Functions, name::Symbol)
    if !haskey(funcs.groups, name)
        throw(ArgumentError("Function group does not exist: $name"))
    else
        group_func = funcs.group_func[name]
        if group_func === nothing
            return generate_func!(funcs, name)
        else
            return group_func
        end
    end
end

function eval_func!(output, funcs::Functions, fidx::Vector{Int64}, u; prob, data)
    next = 1
    for fi in fidx  
        kwargs = [name=>data[idx] for (name, idx) in funcs.datadeps[fi]]
        funcs.funcs[fi](view(output, next:next+funcs.dims[fi]-1), 
            (view(u, get_indices(funcs.vars, ui)) for ui in funcs.vardeps[fi])...;
            (name=>data[idx] for (name, idx) in funcs.datadeps[fi])...,
            (if funcs.probdep[fi]; (:prob=>prob,) else () end)...)
        next = next + funcs.dims[fi]
    end
    return output
end

function generate_func(funcs::Functions, fidx::Vector{Int64})
    func = :(function (output, funcs, u; prob, data) vars = funcs.vars end)
    func_body = func.args[2]
    # Get all dependent continuation variables
    vidx = unique(reduce(vcat, funcs.vardeps[fidx]))
    # Generate symbols for each continuation variable
    vdict = Dict([vi=>gensym() for vi in vidx])
    # Generate views for each variable (indices can change during continuation so can't interpolate them here)
    for (vi, vsym) in vdict
        push!(func_body.args, :($vsym = view(u, vars.indices[$vi])))
    end
    # Iterate over all the functions
    push!(func_body.args, :(next = 1))
    for fi in fidx
        func_call = :($(funcs.funcs[fi])(view(output, next:next+funcs.dims[$fi]-1)))
        for vi in funcs.vardeps[fi]
            push!(func_call.args, vdict[vi])
        end
        if funcs.probdep[fi]
            push!(func_call.args, Expr(:kw, :prob, :prob))
        end
        for (dname, di) in funcs.datadeps[fi]
            push!(func_call.args, Expr(:kw, dname, :(data[$di])))
        end
        push!(func_body.args, func_call)
        push!(func_body.args, :(next = next + funcs.dims[$fi]))
    end
    push!(func_body.args, :(return output))
    return func
end

function generate_func!(funcs::Functions, name::Symbol)
    let funcs = funcs
        grpfunc = eval(generate_func(funcs, funcs.groups[name]))
        return funcs.group_func[name] = (output, u; prob, data) -> grpfunc(output, funcs, u, prob=prob, data=data)
    end
end

function initialize!(funcs::Functions, prob)
    for name in keys(funcs.groups)
        generate_func!(funcs, name)
    end
end

function Base.show(io::IO, mime::MIME"text/plain", funcs::Functions)
    println(io, "Functions ($(length(funcs)) functions):")
    for i in eachindex(funcs.names)
        name = funcs.names[i]
        dims = funcs.dims[i] == 1 ? "1 dim" : "$(funcs.dims[i]) dims"
        vdeps = join([nameof(funcs.vars, dep) for dep in funcs.vardeps[i]], ", ")
        ddeps = join([nameof(funcs.data, last(dep)) for dep in funcs.datadeps[i]], ", ")
        println(io, "  → $name ($dims) that depends on")
        !isempty(vdeps) && println(io, "    • variables: $vdeps")
        !isempty(ddeps) && println(io, "    • data: $ddeps")
    end
    !isempty(funcs.groups) && println(io, "With $(length(funcs.groups)) function groups:")
    for name in keys(funcs.groups)
        fcount = length(funcs.groups[name]) == 1 ? "1 function" : "$(length(funcs.groups[name])) functions"
        flist = join([funcs.names[dep] for dep in funcs.groups[name]], ", ")
        println(io, "  → $name ($fcount; includes $flist)")
    end
    return nothing
end

# Function forwarding
add_var!(funcs::Functions, args...; kwargs...) = add_var!(funcs.vars, args...; kwargs...)
has_var(funcs::Functions, name) = has_var(funcs.vars, name)
add_data!(funcs::Functions, args...; kwargs...) = add_data!(funcs.data, args...; kwargs...)
has_data(funcs::Functions, name) = has_data(funcs.data, name)
