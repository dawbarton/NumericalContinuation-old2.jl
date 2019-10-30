"""
    AlgebraicProblems

This module implements basic functionality to continue algebraic problems of the
form

```math
    0 = f(u, p)
```
"""
module AlgebraicProblems

using ..ProblemStructures:ProblemStructure, addvar!, addfunc!, addpars!

struct AlgebraicProblem{U, P, F}
    f!::F
end

_convertto(T, val) = val
_convertto(::Type{<:Number}, val) = val[1]

(ap::AlgebraicProblem{U, P})(res, u, p) where {U, P} = ap.f!(res, _convertto(U, u), _convertto(P, p))

function addalgebraicproblem!(prob::ProblemStructure, name::String, f, u0, p0; pnames=nothing)
    # Determine whether f is in-place or not
    if any(method.nargs == 4 for method in methods(f))
        f! = f
    else
        f! = (res, u, p) -> res .= f(u, p)
    end
    # Check for parameter names
    _pnames = pnames !== nothing ? pnames : ["$(name).p$i" for i in 1:length(p0)]
    if length(_pnames) != length(p0)
        throw(ArgumentError("Length of parameter vector does not match number of parameter names"))
    end
    # Give the user-provided function the input expected
    U = u0 isa Number ? Number : Vector 
    P = p0 isa Number ? Number : Vector
    alg = AlgebraicProblem{U, P, typeof(f!)}(f!)
    # Create the necessary continuation variables and add the function
    uidx = addvar!(prob, "$(name).u", length(u0), u0=(U === Number ? [u0] : u0))
    pidx = addvar!(prob, "$(name).p", length(p0), u0=(P === Number ? [p0] : p0))
    fidx = addfunc!(prob, name, alg, (uidx, pidx), length(u0), kind=:embedded)
    addpars!(prob, _pnames, pidx, active=false)
    return fidx
end

end # module
