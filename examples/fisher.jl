using Plasmo
using JuMP
using Gurobi

graph = PlasmoGraph()
graph.solver = GurobiSolver()

m1 = Model(solver=GurobiSolver())
@variable(m1,x[1:2], Bin)
@constraint(m1, x[1] + x[2] <= 1)
@objective(m1, Max, 16x[1] + 10x[2])
n1 = add_node!(graph)
setmodel(n1,m1)

m2 = Model(solver=GurobiSolver())
@variable(m2, x[1:2], Bin)
@variable(m2, y[3:4], Bin)
@constraint(m2, sum(y[i] for i in 3:4) <= 1)
@constraint(m2, 8x[1] + 2x[2] + y[3] + 4y[4] <= 10)
@objective(m2, Max, 4y[4])
n2 = add_node!(graph)
setmodel(n2,m2)

@linkconstraint(graph, [i in 1:2], n1[:x][i] == n2[:x][i])

#Get all of the link constraints in a graph
links = Plasmo.getlinkconstraints(graph)
for link in links
    println(link)
end
