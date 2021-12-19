using PDDL
using Revise
using plan_graph

domain = load_domain("test/pddl/domain.pddl")
problem = load_problem("test/pddl/problem.pddl")

graph = create_graph(domain, problem)
# acts = get_all_actions(domain, problem)
