### Specify simulation parameters ###
@with_kw mutable struct Simulation_Parameters
    TTC_car_freq::Int64 
    max_load_gov_restr::Float64 # 1.0 means there is no restrictions, because TTC car can take 1.0*max_load.
    when_to_run_people::Float64 
    when_to_run_wagons::Float64 
	sim_run_time_in_secs::Int
	N_agents::Int
	agents_speed_in_sec_per_m::Float64 # 0.8 means 0.8s per 1m of distance. The average, healthy human walks at a pace of 100m in 80 sec. Here we assume 100m=80s, so 1m = 0.8s.
    max_load_subway::Int64
    max_load_streetcar::Int64
	p0::Float64
    max_interactions_TTC::Int
    max_interactions_street::Int
end


### Agent definition ###
@with_kw mutable struct Commuter
    id::Int    
    pos::Int64
    work_loc::Int64
    home_loc::Int64
    direction::Symbol = :work_to_home # It will be changed to home --> work in a first step
    
    infected::Bool = false
    infected_in::Symbol = :not_infected
    
    path::Dict{Int,Int} = Dict{Int,Int}()
    path_distances::Dict{Int,Float64} = Dict{Int,Float64}()
    paths_home_work::Dict{Int, Dict} = Dict{Int, Dict}()
    distances_home_work::Dict{Int,Dict} = Dict{Int,Dict}()
    paths_work_home::Dict{Int, Dict} = Dict{Int, Dict}()
    distances_work_home::Dict{Int,Dict} = Dict{Int,Dict}()
    no_of_trips::Int = 0

    wagon_id::Int64 = -999
	met_infected_in_wagon::Set{Int} = Set{Int}()
	
end

Commuter(id, pos, home_loc, work_loc) = Commuter(id = id, pos = pos, home_loc = home_loc, work_loc = work_loc)

### Articial agents definition ###
@with_kw mutable struct Artificial_Commuter_Stats
    id::Int = 999
	enter_every_sec::Int = 60
end

### Wagon definition ###
@with_kw mutable struct Wagon
    id::Int
    pos::Int64
    line::Symbol
    type::Symbol
    
    
    path::OrderedDict{Int,Int} = OrderedDict{Int,Int}() #seqence of nodes
    path_distances::OrderedDict{Int,Float64} = OrderedDict{Int,Float64}() # distance from each node in the sequence 
    
    passengers::Set{Commuter} = Set{Commuter}()

    max_load::Union{Int, Float64}
    run_every::Int64 #sec
     
    time_start::Float64 = 0.0
    next_wagon_requested::Bool = false
    
    max_passengers_ever::Int64 = 0
end

### Simulation definiton ###
# EventTime represents time when event occurs. the second value in tuple is for sort ordering when 2 or more events are scheduled for the same point in time.
const EventTime = Tuple{Float64,Float64}

@with_kw mutable struct Simulation
    m::OpenStreetMapX.MapData
	
    agents::Vector{Commuter} 
    wagons::Vector{Wagon}
    artificial_agent_stats::Artificial_Commuter_Stats
	
    recent_wagon::Int = -9999
    nodes_agents::Vector{Set{Int}}
    nodes_wagons::Vector{Set{Int}}
    nodes_agents_max::Vector{Int}
    nodes_visits::Dict{Int,Int}
    
	infected_agents_count_current::Int
	infected_agents_wagon_current::Int
	infected_agents_street_current::Int
	
    infected_agents_count::Vector{Int}
    infected_agents_wagon::Vector{Int}
    infected_agents_street::Vector{Int}
    
    events = PriorityQueue{Union{Commuter,Wagon,Artificial_Commuter_Stats}, EventTime}()
    
    p0::Float64 # = 0.01
	
    max_load_subway::Int # = 15
    max_load_streetcar::Int # = 15 
    max_load_gov_restr::Float64 # 1.0 means there is no restrictions, because TTC car can take 1.0*max_load.
    
    max_passengers_per_TTC_car::Dict{Tuple,Int64} = Dict{Tuple,Int64}() # [string(wagon.id,"|") * wagon.line * string("|",t[1])] = wagon.max_passengers_ever

    max_interactions_TTC::Int
    max_interactions_street::Int

    inf_no_per_node::Dict{Int, Dict{Int, Int}}
    poss_interact_per_node::Dict{Int, Dict{Int, Int}}
    inf_no_per_line_TTC::Dict{Symbol, Dict{Int, Int}}
    
end

function Simulation(m::OpenStreetMapX.MapData
					, orig_map_nodes_num::Int
					, routes_path::OrderedDict{Symbol, OrderedDict{Int64,Int64}}
					, routes_distances::OrderedDict{Symbol, OrderedDict{Int64,Float64}}
					, routes_types_both_dir::Dict{Symbol,Symbol}
					, N_agents::Int
					, sim_run_time_in_secs::Int
					, TTC_freq::Int64
                    , max_load_subway::Int64
                    , max_load_streetcar::Int64
					, max_load_gov_restr::Float64
					, p0::Float64
                    , prepared_agents::Vector{Commuter}
                    , max_interactions_TTC::Int
                    , max_interactions_street::Int)
					
	println("TTC_freq: ",TTC_freq)
    println("max_load_subway: ",max_load_subway)
	println("max_load_streetcar: ",max_load_streetcar)
	println("max_load_gov_restr: ",max_load_gov_restr)
	println("N_agents: ",N_agents)
	println("sim_run_time_in_secs: ",sim_run_time_in_secs)	
	println("p0: ", p0)	
    println("max_interactions_TTC: ", max_interactions_TTC)
    println("max_interactions_street: ", max_interactions_street)
	
    vv = size(m.g)[1] # number of vertices
	if length(prepared_agents) == 0
        println("Agents are being created from scratch.")
        ### Agents creation ###
        home_loc = rand(1:orig_map_nodes_num,N_agents)
        work_loc = rand(1:orig_map_nodes_num,N_agents)
        agents = Commuter.(1:N_agents, home_loc, home_loc, work_loc)
        for ag in agents
            while ag.home_loc == ag.work_loc
                    ag.work_loc = rand(1:orig_map_nodes_num)
            end
        end
        # Routes from home to work and inverse
        for agent in agents
            # Home to work
            ys = yen_k_shortest_paths(m.g, agent.home_loc, agent.work_loc, m.w, 3, maxdist=100_000)
            for (index, nodes) in enumerate(ys.paths)
                agent.paths_home_work[index] = Dict()
                agent.distances_home_work[index] = Dict()
                setindex!.(Ref(agent.paths_home_work[index]), nodes[2:end], nodes[1:end-1])
                for i in 1:(length(nodes)-1)
                    agent.distances_home_work[index][nodes[i]] = m.w[nodes[i], nodes[i+1]]
                end
            end
            
            # Work to home
            ys = yen_k_shortest_paths(m.g, agent.work_loc, agent.home_loc, m.w, 3, maxdist=100_000)
            for (index, nodes) in enumerate(ys.paths)
                agent.paths_work_home[index] = Dict()
                agent.distances_work_home[index] = Dict()
                setindex!.(Ref(agent.paths_work_home[index]), nodes[2:end], nodes[1:end-1])
                for i in 1:(length(nodes)-1)
                    agent.distances_work_home[index][nodes[i]] = m.w[nodes[i], nodes[i+1]]
                end
            end        
            # Current path: home --> work 
            # !!! We should not assign it here, because it will negatively influence timing. 
            # It will be 1-step delayed comparing to the reality. 
            # That is why it is mentioned here, but commented!
            # agent.path = deepcopy(agent.path_home_work)
            # agent.path_distances = deepcopy(agent.path_distances_home_work)

        end
    else
        println("Agents will be taken from a file. Next N_agents will be randomly selected.")
        agents = deepcopy(StatsBase.sample(prepared_agents, N_agents, replace = false));
        nr = 1
        for ag in agents
            ag.id = nr
            nr += 1
        end
	end

    # Structure to gather statistics
    nodes_agents = [Set{Int}() for _ in 1:vv]
    nodes_agents_max = [0 for _ in 1:vv]
    nodes_wagons = [Set{Int}() for _ in 1:vv] 
    nodes_visits = Dict(zip([i for i in 1:vv], zeros(vv)))
    ### Wagons creation ###
    wagons = Wagon[]
    wagon_id = 1
    for r in collect(keys(routes_path))
        push!(wagons, Wagon(id = wagon_id
                ,pos = collect(keys(routes_path[r]))[1]
                ,line = r
                ,type = routes_types_both_dir[r]
                ,path = routes_path[r]
                ,path_distances = routes_distances[r]
                ,run_every = TTC_freq
                ,max_load = routes_types_both_dir[r] == :subway ? max_load_subway : max_load_streetcar
                ))
        wagon_id += 1
    end

	# Add agents and wagons current positions.
    for agent in agents
        push!(nodes_agents[agent.pos], agent.id)
        nodes_agents_max[agent.pos] += 1
        nodes_visits[agent.pos] += 1
    end
    
    for wagon in wagons
        push!(nodes_wagons[wagon.pos], wagon.id)
    end
	# Identify patient zero and ensure that his/her trip is long enough, so we are sure that the only infected agent is not locked at home.
	target_n_of_patients_zero = N_agents*0.01
	n_of_patients_zero = 0
	while n_of_patients_zero < target_n_of_patients_zero
		patient_zero = rand(agents)
		if patient_zero.infected == false
			patient_zero.infected = true
			n_of_patients_zero += 1
		end
	end
    println("Number of patients zero: ", n_of_patients_zero)
    Simulation(agents = agents, wagons = wagons, recent_wagon = length(collect(keys(routes_path))), m = m, artificial_agent_stats = Artificial_Commuter_Stats(),
        nodes_agents = nodes_agents, nodes_wagons = nodes_wagons, nodes_agents_max = nodes_agents_max, nodes_visits = nodes_visits,
		infected_agents_count_current = n_of_patients_zero, infected_agents_wagon_current = 0, infected_agents_street_current = 0,
        infected_agents_count = fill(n_of_patients_zero, sim_run_time_in_secs + 1), infected_agents_wagon = zeros(Int, sim_run_time_in_secs + 1),
        infected_agents_street = zeros(Int, sim_run_time_in_secs + 1), max_load_subway = max_load_subway,
        max_load_streetcar = max_load_streetcar, max_load_gov_restr = max_load_gov_restr, p0 = p0, max_interactions_street = max_interactions_street, max_interactions_TTC = max_interactions_TTC, 
        inf_no_per_node = Dict{Int, Dict{Int, Int}}(),  poss_interact_per_node = Dict{Int, Dict{Int, Int}}(), inf_no_per_line_TTC = Dict{Symbol, Dict{Int, Int}}()) 
end


println("Simulations objects were created")