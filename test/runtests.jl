using NumericalContinuation
using Test

const NC = NumericalContinuation

include("test_signals_slots.jl")
include("test_continuation_functions.jl")
include("test_monitor_functions.jl")
include("test_events.jl")
include("test_problem_structure.jl")

include("test_AlgebraicProblems.jl")
