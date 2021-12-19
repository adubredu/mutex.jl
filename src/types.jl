mutable struct Graph 
    num_levels::Int64
    acts
    μacts 
    props 
    μprops 
    states
    leveled
    
    function Graph() 
        new(0, Dict(0=>[]), Dict(0=>[]),  Dict(0=>[]), Dict(0=>[]), Dict(), false)
    end
end

mutable struct NoOp 
    state 
    preconditions 
    effects
    is_noOp 

    function NoOp(state)
        new(state, state, state, true)
    end
end

mutable struct Action 
    name
    args
    pos_prec 
    neg_prec 
    pos_eff 
    neg_eff  
    
    function Action(name)
        new(name, [], [], [], [], [])
    end
end