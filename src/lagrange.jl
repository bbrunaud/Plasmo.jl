using Logging

# Parallel model solve function, returns an array of objective values with dimension equal to of elements in the collection for which pmap was applied
@everywhere function psolve(m::JuMP.Model)
  JuMP.solve(m)
  return JuMP.getobjectivevalue(m)
end

function _lagrangesolve(graph::PlasmoGraph;update_method=:subgradient)
  # 1. Check for dynamic structure. If not error

  # 2. Generate model for heuristic
  mflat = create_flat_graph_model(graph)
  mflat.solver = graph.solver

  # 2. Generate master problem
  ## Number of multipliers
  links = getlinkconstraints(graph)
  nmult = length(links)

  # Initial Multipliers
  λ0 = [0.0 for i in 1:nmult]

  ## Master Model
  ms = Model(solver=graph.solver)
  @variable(ms, η)
  @variable(ms, λ[1:nmult])
  @objective(ms, Min, η)

  # Equality constraint the multiplier is unbounded in sign. For <= or >= need to set the lower or upper bound at 0

  # 3. Generate subproblem array
  # Assuming nodes are created in order
  SP = [graph.nodes[i].attributes[:model] for i in 1:length(graph.nodes)]
  for sp in SP
    JuMP.setsolver(sp,graph.solver)
  end
  SPObjectives = [graph.nodes[i].attributes[:model].obj for i in 1:length(graph.nodes)]
  sense = SP[1].objSense
  # To update the multiplier in the suproblem, call @objective again

  # 4. Initialize
  # TODO Revise
  MaxIter = 20
  ϵ = 0.124999999999
  λk = [0 for j in 1:nmult]
  UB = +1000
  LB = -1000
  α = 2
  i = 0

  # 5. Solve subproblems
  # TODO Begin iterations here
  for iter in 1:MaxIter
  spobjs = pmap(psolve,SP)
  Zk = sum(spobjs)
  debug("Zk = $Zk")

  # 7. Solve Lagrange heuristic
  mflat.colVal = vcat([SP[j].colVal for j in keys(getnodes(graph))]...)
  println("mf val = $(mflat.colVal)")
  println("S1 val = $(SP[1].colVal)")
  for j in 1:2
    mflat.colUpper[j] = mflat.colVal[j]
    mflat.colLower[j] = mflat.colVal[j]
  end
  solve(mflat)
  Hk = getobjectivevalue(mflat)
  # While mflat switches from Max to Min
  Hk *= sense==:Min ? 1 : -1
  debug("Hk = $Hk")

  # 8. Update bounds and check bounds convergence
  # Minimization problem
  debug("sense = $sense")
  if sense == :Min
    LB = max(Zk,LB)
    UB = min(Hk,UB)
    graph.objVal = UB
  else
    LB = max(Hk,LB)
    UB = min(Zk,UB)
    graph.objVal = LB
  end
  UB - LB < ϵ &&  break

  # 9. Update λ
  λprev = λk

  # 9. Multipliers Update
  lval = [getvalue(links[j].terms) for j in 1:nmult]
  step = α*(UB-LB)/norm(lval)^2
  debug("Step = $step")

  # update multiplier bounds (Bundle method)
  if update_method == :bundle
    for j in 1:nmult
      setupperbound(λ[j], λprev[j] + step*abs(getvalue(links[j].terms)))
      setlowerbound(λ[j], λprev[j] - step*abs(getvalue(links[j].terms)))
    end
  end
  # Cutting planes or Bundle
  if update_method in (:cuttingplanes,:bundle)
    @constraint(ms, η >= Zk + sum(λ[j]*lval[j] for j in 1:nmult))
    debug("Last cut = $(ms.linconstr[end])")
    solve(ms)
    λk = getvalue(λ)
  end
  # Subgradient
  if update_method == :subgradient
    λk = λprev - step*lval
  end

  debug("λ = $λk")
  # sqrt(sum( (λ-λprev).^2 )) < ϵ && break

  # 10. Update objectives
  # Restore initial objective
  for (j,sp) in enumerate(SP)
    sp.obj = SPObjectives[j]
  end
  # add dualized part
  for l in 1:nmult
    for j in 1:length(links[l].terms.vars)
      var = links[l].terms.vars[j]
      coeff = links[l].terms.coeffs[j]
      var.m.obj += λk[l]*coeff*var
    end
  end
  debug("SP1 objective = $(SP[1].obj)")
  debug("SP2 objective = $(SP[2].obj)")
  debug("UB = $UB")
  debug("LB = $LB")
  end
end
