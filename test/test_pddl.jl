using PDDL
using Revise
using mutex

domain = load_domain("test/pddl/domain.pddl")
problem = load_problem("test/pddl/hard_problem.pddl")

graph = create_graph(domain, problem; max_levels=1000);
# acts = get_all_actions(domain, problem) 
1