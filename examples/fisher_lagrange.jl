include("fisher.jl")
include("../src/lagrange.jl")

Logging.configure(level=DEBUG)

_lagrangesolve(graph)
