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
            prop = fill_proposition(pre, vars; neg=true)
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
            prop = fill_proposition(eff, vars; neg=true)
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


function fill_proposition(proposition, objs; neg=false)
    if !neg 
        prop = Compound(Symbol(proposition.name), objs)
    else
        prop = Compound(Symbol(proposition.name), [Compound(Symbol(proposition.args[1].name), objs)])
    end
    return prop
end