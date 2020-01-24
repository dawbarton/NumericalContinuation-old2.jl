module NumericalContinuation

using Infiltrator

include("default_options.jl")

include("options.jl")
include("signals_slots.jl")
include("continuation_functions.jl")
include("monitor_functions.jl")
include("events.jl")
include("problem_structure.jl")
include("covering.jl")

include("SimpleCoverings.jl")

include("AlgebraicProblems.jl")
include("ODE.jl")

end # module
