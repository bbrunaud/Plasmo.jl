# Parallel model solve function, returns an array of objective values with dimension equal to of elements in the collection for which pmap was applied
@everywhere function psolve(m::JuMP.Model)
  JuMP.solve(m)
  return JuMP.getobjectivevalue(m)
end

function _lagrangesolve(graph::PlasmoGraph)
  # 1. Check for dynamic structure. If not error

  # 2. Generate model for heuristic
  mflat = create_flat_graph_model(graph)

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
  @objective(ms, Max, η)

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
  MaxI = 50
  ϵ = 0.124999999999
  λk = [0 for j in 1:nmult]
  Z_ub = +1000
  Z_lb = -1000
  α = 2
  i = 0

  # 5. Solve subproblems
  # TODO Begin iterations here
  spobjs = pmap(psolve,SP)
  Zk = sum(spobjs)

  # 7. Solve Lagrange heuristic
  for j in 1:mflat.numCols
    if mflat.colCat[j] == :Bin || mflat.colCat[j] == :Int
      mflat.colUpper = mflat.colVal
      mflat.colLower = mflat.colVal
    end
  end
  solve(mflat)
  Hk = getobjectivevalue(mflat)

  # 8. Update bounds and check bounds convergence
  # Minimization problem
  if sense == :Min
    LB = max(Zk,LB)
    UB = min(Hk,UB)
    graph.objVal = UB
  else
    LB = max(Zk,LB)
    UB = min(Hk,UB)
    graph.objVal = LB
  end
  #UB - LB < ϵ &&  break

  # 9. Update λ
  λprev = λk
  # add cut
  lval = [getvalue(links[j].terms) for j in 1:nmult]
  @constraint(ms, η >= Zk + sum(λ[j]*lval[j] for j in 1:nmult))
  # update multiplier bounds (Bundle method)

  step = α*(UB-LB)/norm(lval)^2
  for j in 1:nmult
    setupperbound(λ[j], λprev[j] + step*abs(getvalue(links[j].terms)))
    setlowerbound(λ[j], λprev[j] - step*abs(getvalue(links[j].terms)))
  end
  solve(ms)
  λk = getvalue(λ)
  # sqrt(sum( (λ-λprev).^2 )) < ϵ && break

  # 10. Update objectives
  # Restore initial objective
  for (j,sp) in enumerate(SP)
    sp.obj = SPObjective[j]
  end
  # add dualized part
  for l in 1:nmult
    for j in 1:lenght(l.terms.vars)
      var = links[l].terms.vars[j]
      coeff = links[l].terms.coeffs[j]
      var.m.obj += λk[l]*coeff*var
    end
  end


end
