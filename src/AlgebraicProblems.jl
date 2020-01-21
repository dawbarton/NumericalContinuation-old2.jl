"""
    AlgebraicProblems

This module implements basic functionality to construct algebraic problems of
the form

```math
    0 = f(u, p)
```

where `u` and `p` are the state variables and parameters respectively. Both `u`
and `p` can be scalars or vectors.

See [`add_algebraicproblem!`](@ref) for details.
"""
module AlgebraicProblems

using DocStringExtensions
using ..NumericalContinuation: add_var!, add_func!, add_pars!

export add_algebraicproblem!

struct AlgebraicProblem{U, P, F}
    f!::F
end

_convert_to(T, val) = val
_convert_to(::Type{<:Number}, val) = val[1]

(ap::AlgebraicProblem{U, P})(res, u, p) where {U, P} = ap.f!(res, _convert_to(U, u), _convert_to(P, p))

"""
$SIGNATURES

Construct an algebraic zero problem of the form 

```math
    0 = f(u, p),
```

where `u` is the state and `p` is the parameter(s), and add it to the problem
structure. The function can operate on scalars or vectors, and be in-place or
not. It assumes that the function output is of the same dimension as `u`.

# Parameters

* `prob` : the underlying continuation problem.
* `name::String` : the name of the algebraic zero problem.
* `f` : the function to use for the zero problem. It takes either two arguments
  (`u` and `p`) or three arguments for an in-place version (`res`, `u`, and `p`).
* `u0` : the initial state value (either scalar- or vector-like).
* `p0` : the initial parameter value (either scalar- or vector-like).
* `pnames` : (keyword, optional) the names of the parameters. If not specified,
  auto-generated names will be used.

# Example

```
prob = ProblemStructure()
add_algebraicproblem!(prob, "cubic", (u, p) -> u^3 - p, 1.5, 1)  # u0 = 1.5, p0 = 1
```
"""
function add_algebraicproblem!(prob, name::String, f, u0, p0; pnames=nothing)
    # Determine whether f is in-place or not
    if any(method.nargs == 4 for method in methods(f))
        f! = f
    else
        f! = (res, u, p) -> res .= f(u, p)
    end
    # Check for parameter names
    _pnames = pnames !== nothing ? [string(pname) for pname in pnames] : ["$(name).p$i" for i in 1:length(p0)]
    if length(_pnames) != length(p0)
        throw(ArgumentError("Length of parameter vector does not match number of parameter names"))
    end
    # Give the user-provided function the input expected
    U = u0 isa Number ? Number : Vector 
    P = p0 isa Number ? Number : Vector
    alg = AlgebraicProblem{U, P, typeof(f!)}(f!)
    # Create the necessary continuation variables and add the function
    uidx = add_var!(prob, "$(name).u", length(u0), u0=(U === Number ? [u0] : u0))
    pidx = add_var!(prob, "$(name).p", length(p0), u0=(P === Number ? [p0] : p0))
    fidx = add_func!(prob, name, length(u0), alg, [uidx, pidx])
    add_pars!(prob, _pnames, pidx, active=false)
    return prob
end

end # module
