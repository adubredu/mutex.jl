#= 
Steps to build planning graph

1. Init level 0
2. Init s0 with propositions in init state
3. Get proposition mutexes pm₀ in s0 
4. Get all actions A₁ with prec in s0 and no pair of prec in pm₀
5. Create s1 as union of all effects of all actions in A₁
6. Get all mutexes of A₁, μA₁
7. Go to 3
=#

function get_effects(domain, action)
    action = PDDL.get_action(domain, action.name)
    pos, neg = [], []
    for eff in action.effect.args
        if eff.name == :not 
            push!(neg, eff)
        else 
            push!(pos, eff)
        end
    end
    return pos, neg
end

function get_preconditions(domain, action)
    action = PDDL.get_action(domain, action.name)
    pos, neg = [], []
    for pre in action.precond.args
        if pre.name == :not 
            push!(neg, pre)
        else 
            push!(pos, pre)
        end
    end
    return pos, neg
end


function goal_reached!(domain, problem, graph)
    goal_set = goalstate(domain, problem).facts
    index = graph.num_levels - 1
    props = graph.props[index]
    μprops = graph.μprops[index]
    goal_found = false
    if issubset(goal_set, props)
        goal_found = true
        for goal_pair in collect(permutations(goal_set, 2))
            if goal_pair in μprops
                goal_found = false
                break 
            end
        end
    elseif index > 0 && graph.props[index-1] == props 
        graph.leveled = true
    end 
    return goal_found
end


function is_mutex_acts(domain, act_pair, μprops)
    a = act_pair[1]
    b = act_pair[2]

    a_pos_eff, a_neg_eff = get_effects(domain, a)
    b_pos_eff, b_neg_eff = get_effects(domain, b)

    a_pos_pre, a_neg_pre = get_preconditions(domain, a)
    b_pos_pre, b_neg_pre = get_preconditions(domain, b)

    if isempty(intersect(a_neg_eff, union(b_pos_pre, b_pos_eff)))  || isempty(intersect(b_neg_eff, union(a_pos_pre, a_pos_eff)))
        return true
    end

    if !isempty(μpropos)
        for μ in μprops 
            p = μ[1]
            q = μ[2]
            if p in a_pos_pre && q in b_pos_pre
                return true
            end
        end
    end
    return false
end


function is_mutex_props(domain, prop_pair, action_list, μacts)
    p = prop_pair[1]
    q = prop_pair[2]

    for action in action_list
        a_pos_eff, _ = get_effects(domain, action)
        if p in a_pos_eff && q in a_pos_eff
            return false
        end
    end

    actions_with_p = Set()
    for action in action_list 
        a_pos_eff, _ = get_effects(domain, action)
        if p in a_pos_eff
            push!(actions_with_p, action)
        end
    end

    actions_with_q = Set()
    for action in action_list 
        a_pos_eff, _ = get_effects(domain, action)
        if q in a_pos_eff
            push!(actions_with_q, action)
        end
    end

    μall = true
    for p_action in actions_with_p 
        for q_action in actions_with_q
            if p_action == q_action
                return false
            end
            if !([p_action, q_action] in μacts)
                μall = false
                break 
            end
        end
        if !μall 
            break 
        end 
    end
    return μall
end


function expand!(domain, problem, graph)
    level = graph.num_levels

    #As
    states = graph.states[level]
    graph.states[level+1]=[]
    action_list = []
    for state in states
        for action in available(domain, state)
            push!(action_list, action)
        end
    end
    graph.acts[level] = action_list

    #Ps 
    proposition_list = Set()
    for state in states
        for action in action_list
            try
                ns = execute(domain, state, action)
                push!(proposition_list, ns.facts...)
                push!(graph.states[level+1], ns)
            catch
                nothing
            end
        end
    end
    graph.props[level] = collect(proposition_list)
    proposition_list = collect(proposition_list)

    #μA 
    action_μ_list = []
    for act_pair in collect(permutations(action_list, 2))
        if is_mutex_acts(domain, act_pair, graph.μprops[level-1])
            push!(action_μ_list, act_pair)
        end
    end
    graph.μacts[level] = action_μ_list

    #μP 
    proposition_μ_list = []
    for prop_pair in collect(permutations(proposition_list, 2))
        if is_mutex_props(domain, prop_pair, action_list, action_μ_list)
            if !(prop_pair in proposition_μ_list)
                swapped = [prop_pair[2], prop_pair[1]]
                if !(swapped in proposition_μ_list)
                    push!(proposition_μ_list, prop_pair)
                end
            end
        end
    end
    graph.μprops[level] = proposition_μ_list

    graph.num_levels = level + 1
    if graph.props[level-1] == proposition_list
        graph.leveled = true
    end

    return graph 
end


function create_graph(domain, problem; max_levels=10)
    graph = Graph()
    graph.num_levels = 1
    graph.states[1] = [initstate(domain, problem)]

    for _ = 1:max_levels
        expand!(domain, problem, graph)
        if goal_reached!(domain, problem, graph)
            break 
        end
    end
    graph.num_levels -=1
    return graph
end