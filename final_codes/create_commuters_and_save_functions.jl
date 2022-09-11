function create_commuters_to_save(m::OpenStreetMapX.MapData
					, orig_map_nodes_num::Int
					, N_agents::Int
                    , TTC_freq_flag::Int)
	
    vv = size(m.g)[1] # number of vertices
	
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
    serialize("./data_output/agents_set_SPEED_08_AGENTS_$N_agents...TTC_FREQ_$TTC_freq_flag.bin", agents)
end


