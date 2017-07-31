function _lagrangesolve(graph::PlasmoGraph)
  # 1. Check for dynamic structure. If not error

  # 2. Generate master problem
  ## Number of multipliers
  links = getlinkconstraints(graph)
  nmult = length(links)

  # 3. Initial Multipliers
  λ0 = [0.0 for i in 1:nmult]

  ## Model
  ms = Model(solver=graph.solver)
  @variable(ms, η)
  @variable(ms, λ[1:nmult])
  @objective(ms, Max, η)

  # Equality constraint the multiplier is unbounded in sign. For <= or >= need to set the lower or upper bound at 0

  # 3. Generate subproblem array
  # Assuming nodes are created in order
  SP = [graph.nodes[i].attributes[:model] for i in 1:length(graph.nodes)]

  # To update the multiplier in the suproblem, call @objective again

end
