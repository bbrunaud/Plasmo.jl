include("fisher.jl")
include("../src/lagrange.jl")

Logging.configure(level=DEBUG)

lagrangesolve(graph,update_method=:bundle)
