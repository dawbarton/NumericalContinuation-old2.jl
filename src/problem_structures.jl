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
get_u0(vars::Vars, vidx::Int64) = vars.u0[vidx]
get_t0(vars::Vars, vidx::Int64) = vars.t0[vidx]
Base.nameof(vars::Vars, vidx::Int64) = vars.names[vidx]
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

get_u0(vars::Vars) = get_u0(Float64, vars)

function get_t0(T::Type{<: Number}, vars::Vars)
    t0 = Vector{T}()
    for vidx in 2:length(vars.t0)
        if vars.dims[vidx] != 0
            if vars.t0[vidx] === nothing
                append!(t0, zeros(T, vars.dims[vidx]))
            elseif length(vars.t0[vidx]) == vars.dims[vidx]
                append!(t0, convert(Vector{T}, vars.t0[vidx]))
            else
                throw(ErrorException("Initial data for variable $(vars.names[vidx]) does not have the correct number of dimensions ($(vars.dims[vidx]))"))
            end
        end
    end
    return t0
end

get_t0(vars::Vars) = get_t0(Float64, vars)

function Base.show(io::IO, mime::MIME"text/plain", vars::Vars)
    println(io, "Variables:")
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

function add_data!(data::Data, name::String, newdata)
    if haskey(data.lookup, name)
        throw(ArgumentError("Continuation data already exists: $name"))
    end
    push!(data.names, name)
    push!(data.data, newdata)
    return data.lookup[name] = length(data.names)
end

get_data(data::Data, didx::Int64) = data.data[didx]
set_data!(data::Data, didx::Int64, newdata) = data.data[didx] = newdata

Base.nameof(data::Data, didx::Int64) = data.names[didx]
Base.getindex(data::Data, name::String) = data.lookup[name]

# Functions operating on the collection of continuation data

get_data(data::Data) = (data.data...,)
has_data(data::Data, name::String) = haskey(data.lookup, name)

Base.length(data::Data) = length(data.names)

function Base.show(io::IO, mime::MIME"text/plain", data::Data)
    println(io, "Data:")
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
    vardeps::Vector{NTuple{<:Any, Int64}}
    datadeps::Vector{NTuple{<:Any, Int64}}
    probdep::Vector{Bool}
    memberof::Vector{NTuple{<:Any, Symbol}}
    groups::Dict{Symbol, Vector{Int64}}
    group_func::Dict{Symbol, Any}
end

Functions(vars::Vars, data::Data) = Functions(vars, data, String[], Dict{String, Int64}(), Int64[], Any[], NTuple{<:Any, Int64}[], NTuple{<:Any, Int64}[], Bool[], NTuple{<:Any, Symbol}[], Dict{Symbol, Vector{Int64}}(), Dict{Symbol, Any}())
Functions() = Functions(Vars(), Data())

# Functions operating on individual continuation functions

get_name(funcs::Functions, fidx::Int64) = funcs.names[fidx]
get_dim(funcs::Functions, fidx::Int64) = funcs.dims[fidx]
get_func(funcs::Functions, fidx::Int64) = funcs.funcs[fidx]
get_vardeps(funcs::Functions, fidx::Int64) = funcs.vardeps[fidx]
get_datadeps(funcs::Functions, fidx::Int64) = funcs.datadeps[fidx]
get_probdep(funcs::Functions, fidx::Int64) = funcs.probdep[fidx]
get_groups(funcs::Functions, fidx::Int64) = funcs.memberof[fidx]
Base.nameof(funcs::Functions, fidx::Int64) = funcs.names[fidx]
Base.getindex(funcs::Functions, name::String) = funcs.lookup[name]
has_func(funcs::Functions, name::String) = haskey(funcs.lookup, name)
has_group(funcs::Functions, name::String) = haskey(funcs.groups, name)

function add_func!(funcs::Functions, name::String, dim::Integer, func, vardeps::NTuple{<:Any, Int64}, datadeps::NTuple{<:Any, Int64}, probdep::Bool, memberof::NTuple{<:Any, Symbol})
    if has_func(funcs, name)
        throw(ArgumentError("Continuation function already exists: $name"))
    end
    push!(funcs.names, name)
    push!(funcs.dims, dim)
    push!(funcs.funcs, func)
    push!(funcs.vardeps, vardeps)
    push!(funcs.datadeps, datadeps)
    push!(funcs.probdep, probdep)
    push!(funcs.memberof, memberof)
    fidx = funcs.lookup[name] = length(funcs.names)
    for grp in memberof
        if haskey(funcs.groups, grp)
            push!(funcs.groups[grp], fidx)
        else
            funcs.groups[grp] = [fidx]
        end
        funcs.group_func[grp] = nothing
    end
    return fidx
end

function add_func!(funcs::Functions, name::String, dim::Integer, func, vardeps::Any, datadeps::Any, probdep::Bool, memberof::Any)
    # Convenience function to put all dependencies into the required format
    _vardeps = Int64[]
    if typeof(vardeps) === String
        push!(_vardeps, funcs.vars[vardeps])
    else
        for vdep in vardeps
            if typeof(vdep) === String
                push!(_vardeps, funcs.vars[vdep])
            else
                push!(_vardeps, vdep)
            end
        end
    end
    _datadeps = Int64[]
    if typeof(datadeps) === String
        push!(_datadeps, funcs.data[datadeps])
    else
        for ddep in datadeps
            if typeof(ddep) === String
                push!(_datadeps, funcs.data[ddep])
            else
                push!(_datadeps, ddep)
            end
        end
    end
    _memberof = typeof(memberof) === Symbol ? [memberof] : memberof
    add_func!(funcs, name, dim, func, (_vardeps...,), (_datadeps...,), probdep, (_memberof...,))
end

# Functions operating on the collection of functions

get_groups(funcs::Functions) = keys(funcs.groups)
get_vars(funcs::Functions) = funcs.vars
get_data(funcs::Functions) = funcs.data

Base.length(funcs::Functions) = length(funcs.names)

function Base.getindex(funcs::Functions, name::Symbol)
    if !haskey(funcs.groups, name)
        throw(ErrorException("Function group does not exist: $name"))
    else
        group_func = funcs.group_func[name]
        if group_func === nothing
            return generate_func!(funcs, name)
        else
            return group_func
        end
    end
end

function generate_func_expr(funcs::Functions, name::Symbol)
    func = :(function (output, funcs, prob, data, u) vars = funcs.vars end)
    func_body = func.args[2]
    # Get all dependent continuation variables
    fidx = funcs.groups[name]
    vidx = unique([vdep for vdeps in funcs.vardeps[fidx] for vdep in vdeps])
    # Generate symbols for each continuation variable
    vdict = Dict([vi=>gensym() for vi in vidx])
    # Generate views for each variable (indices can change during continuation so can't interpolate them here)
    for (vi, vsym) in vdict
        push!(func_body.args, :($vsym = view(u, vars.indices[$vi])))
    end
    # Iterate over all the functions
    push!(func_body.args, :(next = 1))
    for fi in fidx
        func_call = :($(funcs.funcs[fi])(view(output, next:next+funcs.dims[$fi])))
        if funcs.probdep[fi]
            push!(func_call.args, :prob)
        end
        for di in funcs.datadeps[fi]
            push!(func_call.args, :(data[di]))
        end
        for vi in funcs.vardeps[fi]
            push!(func_call.args, vdict[vi])
        end
        push!(func_body.args, func_call)
        push!(func_body.args, :(next = next + funcs.dims[$fi]))
    end
    push!(func_body.args, :(return nothing))
    return func
end

function generate_func!(funcs::Functions, name::Symbol)
    let funcs = funcs
        grpfunc = eval(generate_func_expr(funcs, name))
        return funcs.group_func[name] = (output, prob, data, u) -> grpfunc(output, funcs, prob, data, u)
    end
end

function Base.show(io::IO, mime::MIME"text/plain", funcs::Functions)
    println(io, "Functions structure with $(length(funcs.vars)) variables, $(length(funcs.data)) data, $(length(funcs.names)) functions, and $(length(keys(funcs.groups))) functions groups")
    show(io, mime, funcs.vars)
    show(io, mime, funcs.data)
    println(io, "Functions:")
    for i in eachindex(funcs.names)
        name = funcs.names[i]
        dims = funcs.dims[i] == 1 ? "1 dim" : "$(funcs.dims[i]) dims"
        vdeps = join([nameof(funcs.vars, dep) for dep in funcs.vardeps[i]], ", ")
        ddeps = join([nameof(funcs.data, dep) for dep in funcs.datadeps[i]], ", ")
        println(io, "  → $name ($dims) that depends on")
        !isempty(vdeps) && println(io, "    • variables: $vdeps")
        !isempty(ddeps) && println(io, "    • data: $ddeps")
    end
    println(io, "Function groups:")
    for name in keys(funcs.groups)
        fcount = length(funcs.groups[name]) == 1 ? "1 function" : "$(length(funcs.groups[name])) functions"
        flist = join([funcs.names[dep] for dep in funcs.groups[name]], ", ")
        println(io, "  → $name ($fcount; includes $flist)")
    end
    return nothing
end

# Function forwarding
add_var!(funcs::Functions, args...; kwargs...) = add_var!(funcs.vars, args...; kwargs...)
add_data!(funcs::Functions, args...; kwargs...) = add_data!(funcs.data, args...; kwargs...)

