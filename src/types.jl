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
