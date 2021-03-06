function get_all_actions(domain, problem)
    actions = []
    obs = collect(PDDL.get_objects(problem))
    for act in values(PDDL.get_actions(domain))
        vars = act.args   
        for vs in collect(permutations(obs, length(vars)))
            a = Action(act.name)
            a.pos_prec, a.neg_prec = get_preconditions(domain, act, vs)
            a.pos_eff, a.neg_eff = get_effects(domain, act, vs) 
            a.args = vs
            push!(actions, a)
        end
    end
    return actions
end


function get_preconditions(domain, act, vars)
    action = PDDL.get_action(domain, act.name)
    vardict = Dict()
    [vardict[action.args[i]] = vars[i] for i=1:length(action.args)]
    pos, neg = [], []
    for pre in action.precond.args 
        if pre.name == :not 
            vs = []
            [push!(vs, vardict[arg]) for arg in pre.args[1].args]
            prop = fill_proposition(pre.args[1], vs)
            push!(neg, prop)
        else 
            vs = []
            [push!(vs, vardict[arg]) for arg in pre.args]
            prop = fill_proposition(pre, vs)
            push!(pos, prop)
        end
    end
    return pos, neg
end


function get_effects(domain, act, vars)
    action = PDDL.get_action(domain, act.name)
    vardict = Dict()
    [vardict[action.args[i]] = vars[i] for i=1:length(action.args)]
    pos, neg = [], []
    for eff in action.effect.args 
        if eff.name == :not 
            vs = []
            [push!(vs, vardict[arg]) for arg in eff.args[1].args]
            prop = fill_proposition(eff.args[1], vs)
            push!(neg, prop)
        else 
            vs = []
            [push!(vs, vardict[arg]) for arg in eff.args]
            prop = fill_proposition(eff, vs)
            push!(pos, prop)
        end
    end
    return pos, neg
end


function fill_proposition(proposition, objs) 
    if isempty(objs) objs=Term[] end
    prop = Compound(Symbol(proposition.name), objs)
    return prop
end


function goal_reached!(domain, problem, graph)
    goal_set = goalstate(domain, problem).facts
    goal_set = [goal_set...]
    index = graph.num_levels - 1
    props = graph.props[index]
    ??props = graph.??props[index]
    goal_found = false 
    if issubset(goal_set, props)
        goal_found = true
        for goal_pair in collect(permutations(goal_set, 2))
            if goal_pair in ??props 
                goal_found = false
                break 
            end
        end
    elseif index > 0 && graph.props[index-1] == props 
        graph.leveled = true
    end 
    return goal_found
end


function is_mutex_acts(act_pair, ??props)
    a = act_pair[1]
    b = act_pair[2]

    if !isempty(intersect(a.neg_eff, union(b.pos_prec, b.pos_eff))) ||
       !isempty(intersect(b.neg_eff, union(a.pos_prec, a.pos_eff)))
        return true
    end

    if !isempty(??props) 
        for ?? in ??props 
            p = ??[1]
            q = ??[2]
            if (p in a.pos_prec && q in b.pos_prec) 
                return true
            end
        end
    end
    return false
end
 

function is_mutex_props(prop_pair, action_list, ??acts)
    p = prop_pair[1]
    q = prop_pair[2]

    for a in action_list
        if p in a.pos_eff && q in a.pos_eff 
            return false
        end
    end

    actions_with_p = Set()
    for a in action_list 
        if p in a.pos_eff 
            push!(actions_with_p, a)
        end
    end

    actions_with_q = Set()
    for a in action_list 
        if q in a.pos_eff 
            push!(actions_with_q, a)
        end
    end

    ??all = true 
    for p_action in actions_with_p
        for q_action in actions_with_q 
            if p_action == q_action return false end 
            if !([p_action, q_action] in ??acts)
                ??all = false
                break 
            end
        end
        if !??all break end 
    end
    return ??all 
end


function action_is_applicable(action, props, ??props) 
    if issubset(action.pos_prec, props) && isdisjoint(action.neg_prec, props)
        app = true 
        if !isempty(??props)
            for precondition in collect(permutations(action.pos_prec, 2))
                if precondition in ??props
                    app = false
                    break 
                end
            end
        end
    else
        app = false
    end
    return app 
end


function expand!(domain, problem, graph)
    level = graph.num_levels 
    #As 
    action_list = []
    for action in get_all_actions(domain, problem)
        if action_is_applicable(action, graph.props[level-1], graph.??props[level-1]) 
            push!(action_list, action)
        end
    end
    for prop in graph.props[level-1]
        push!(action_list, NoOp(prop))
    end
    graph.acts[level] = action_list

    #Ps 
    proposition_list = Set()
    for action in action_list 
        for eff in action.pos_eff 
            push!(proposition_list, eff)
        end
    end
    graph.props[level] = collect(proposition_list)
    proposition_list = collect(proposition_list)

    #??A
    action_??_list = []
    for act_pair in collect(permutations(action_list, 2))
        if is_mutex_acts(act_pair, graph.??props[level-1])
            push!(action_??_list, act_pair)
        end
    end
    graph.??acts[level] = action_??_list

    #??P 
    proposition_??_list = []
    for prop_pair in collect(permutations(proposition_list, 2))
        if is_mutex_props(prop_pair, action_list,action_??_list)
            if !(prop_pair in proposition_??_list)
                swapped = [prop_pair[2], prop_pair[1]]
                if !(swapped in proposition_??_list)
                    push!(proposition_??_list, prop_pair)
                end
            end
        end
    end
    graph.??props[level] = proposition_??_list
    
    graph.num_levels = level + 1 
    if graph.props[level-1] == proposition_list
        graph.leveled = true
    end

    return graph 
end


function get_init_propositions(domain, problem)
    initprops=[]
    inits = collect(initstate(domain, problem).facts)
    for init in inits
        objs = init.args
        push!(initprops, fill_proposition(init, objs))
    end
    return initprops

end

function get_goal_propositions(domain, problem)
    goalprops=[]
    goals = collect(goalstate(domain, problem).facts)
    for goal in goals
        objs = goal.args
        push!(goalprops, fill_proposition(goal, objs))
    end
    return goalprops

end


function create_graph(domain, problem; max_levels=10)
    graph = Graph()
    graph.num_levels = 1 
    graph.props[0] =  get_init_propositions(domain, problem)

    for _ in 1:max_levels
        expand!(domain, problem, graph)
        if goal_reached!(domain, problem, graph) break end 
        if graph.leveled break end
    end
    graph.initprops = get_init_propositions(domain, problem)
    graph.goalprops = get_goal_propositions(domain, problem) 
    return graph  
end
            