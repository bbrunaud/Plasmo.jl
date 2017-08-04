include("fisher.jl")
include("../src/lagrange.jl")

Logging.configure(level=DEBUG)

r = lagrangesolve(graph,update_method=:subgradient,max_iterations=10)
println(r)
