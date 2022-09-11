### SIMULATION STEP ###

# Agent
function step!(model::Simulation, t::EventTime, agent::Commuter, orig_map_nodes_num::Int)
	if agent.pos > orig_map_nodes_num
		# An agent can interact maximum with max_interactions_TTC agents on TTC station.
		max_inter_num = deepcopy(model.max_interactions_TTC)
	else
		# An agent can interact maximum with max_interactions_street agents on a street.
		max_inter_num = deepcopy(model.max_interactions_street)
	end

    # infections
    if agent.infected == false # if healthy -> look at infected agents already in the node
        inf_no = sum([model.agents[ag].infected for ag in model.nodes_agents[agent.pos]])
		 # all infections have their own separate realizations of probabilities.
		if inf_no >= 1
			p = 1 - (1-model.p0)^min(inf_no,max_inter_num)
			agent.infected = (p > rand())
			if agent.infected == true
				agent.infected_in = :street
				model.infected_agents_count_current += 1
				model.infected_agents_street_current += 1
			end
            push!(model.num_interactions_vec_street,inf_no)
		end
    else # for agents that are infected -> possibly infect healthy agents standing at the intersection
		num_of_interactions = 0 # an agent can interact maximum with max_interactions_street agents
        for i in model.nodes_agents[agent.pos]
            if !model.agents[i].infected
                p = model.p0  # just from that one agent!
                model.agents[i].infected = (p > rand())
                if model.agents[i].infected == true
                    model.agents[i].infected_in = :street
					model.infected_agents_count_current += 1
					model.infected_agents_street_current += 1
                end
            end
			
			num_of_interactions += 1
			if num_of_interactions >= max_inter_num
				break
			end
        end
        if num_of_interactions >= 1
            push!(model.num_interactions_vec_street,num_of_interactions) 
        end
    end
    # after the infections from previous position are handled, we can move the agent
    move_agent!(agent, model, orig_map_nodes_num) 
    # println("S1! ","AGENT: ", agent.id," POS: ", agent.pos, " DIRECTION: ", agent.direction," TIME: ", t[1], " HOME:WORK: ", agent.home_loc,":",agent.work_loc)
    # If the current position is not in agent`s path it means that this node is the last one and we need to generate a new path.
    if agent.pos ∉ keys(agent.path)
        if agent.direction == :home_to_work
            working_day = 1 #rand(Normal(8,0.5),1)[1]*60*60
            queue_key = tuple(t[1] + working_day,rand()) 
            enqueue!(model.events, agent, queue_key)
            # println("I am at work. I will be here for ", working_day/60/60, " hours.")
        else
            time_to_rest_at_home = 1 # rand(Normal(16,0.5),1)[1] * 60 * 60
            queue_key = tuple(t[1] + time_to_rest_at_home, rand())
            enqueue!(model.events, agent, queue_key)
            # println("I am at home. I will take ", time_to_rest_at_home/60/60, " hours of rest.")
        end
    else
        # If an agent is not inside a TTC car we add next movement for him/her.
        if (agent.pos <= orig_map_nodes_num)
            queue_key = tuple(t[1] + agent.path_distances[agent.pos], rand())
            enqueue!(model.events, agent, queue_key)
         
        # If an agent is inside a TTC infrastucture, but the next node is outside the infrastructure we also add next movement.
        # For example, underpass.
        elseif (agent.pos > orig_map_nodes_num) && (agent.path[agent.pos] <= orig_map_nodes_num)
            queue_key = tuple(t[1] + agent.path_distances[agent.pos],rand())
            enqueue!(model.events, agent, queue_key)

        end
        # If an agent is inside a TTC car we don`t care because the TTC car will manage the queue.
    end
end

# TTC car
function step!(model::Simulation, t::EventTime, wagon::Wagon, orig_map_nodes_num::Int)
    # If it is the very beginning we just take passengers. TTC car will move only during the second step.
    if t[1] > 0.0 
        move_agent!(wagon, model, t)
    end
	
    # If the current node is the last one on this route we will remove this TTC car.
    if wagon.pos == collect(values(wagon.path))[end]
        leave_passengers!(model,t,wagon)
        update_passengers_pos!(model,wagon, orig_map_nodes_num)
        model.max_passengers_per_TTC_car[(wagon.id, wagon.line, t[1])] = wagon.max_passengers_ever
        #This wagon have arrived to the last stop on the route, so it will die.
        filter!(e->e≠wagon,model.wagons)
    else
        # A wagon continues its path to the last node on the route.
        leave_passengers!(model,t,wagon)
        take_passengers!(model,t,wagon)
        update_passengers_pos!(model,wagon,orig_map_nodes_num)
        count_passengers_and_update_max_passengers_ever!(model,wagon)
        queue_key = tuple(t[1] + wagon.path_distances[wagon.pos],rand())
        enqueue!(model.events, wagon, queue_key)
    end
    
    # if it is time to run the next TTC car on this route we will run one.
    if (wagon.next_wagon_requested == false) && (t[1] >= (wagon.time_start + wagon.run_every))
       add_new_wagon!(model, wagon, orig_map_nodes_num) 
    end
    
end

# Artificial agent
function step!(model::Simulation, t::EventTime, agent::Artificial_Commuter_Stats, orig_map_nodes_num::Int)
	model.infected_agents_count[floor(Int,t[1])+1:end] .= model.infected_agents_count_current
	model.infected_agents_wagon[floor(Int,t[1])+1:end] .= model.infected_agents_wagon_current
	model.infected_agents_street[floor(Int,t[1])+1:end] .= model.infected_agents_street_current
	queue_key = tuple(t[1] + agent.enter_every_sec, rand())
	enqueue!(model.events, agent, queue_key)	
end

### Movement of an agent ###
function move_agent!(agent::Commuter, model::Simulation, orig_map_nodes_num::Int)
    # If an agent is inside a TTC the pos for agent will be the same as for the TTC. 
        if agent.wagon_id != -999
            pos = filter(wag->wag.id==agent.wagon_id,model.wagons)[1].pos
        else
            #If an agent reached the last node a new travel destination will be selected.
            if !(agent.pos in keys(agent.path)) 
                if agent.direction == :home_to_work
                    ind = sample(1:length(keys(agent.paths_work_home)), ProbabilityWeights(agent.probs_work_home))
                    agent.path = agent.paths_work_home[ind]
                    agent.path_distances = agent.distances_work_home[ind]
                    agent.direction = :work_to_home
                else
                    ind = sample(1:length(keys(agent.paths_home_work)), ProbabilityWeights(agent.probs_home_work))
                    agent.path = agent.paths_home_work[ind]
                    agent.path_distances = agent.distances_home_work[ind]
                    agent.direction = :home_to_work
                end
                agent.no_of_trips += 1
                #println("agent ", agent.id, " walking ", agent.direction, ", route: ", agent.path)
                pos = agent.pos
            else
                # If an agent will use TTC and not only an underpass. We should not assign a new node for him, because
                # It will be assigned thanks to a TTC car.
                if (agent.pos > orig_map_nodes_num) && (agent.path[agent.pos] > orig_map_nodes_num)
                    # If agent changes line (transfer), so we need to change his pos
                    if find_route_id_by_stop_id(agent.pos - orig_map_nodes_num) != find_route_id_by_stop_id(agent.path[agent.pos] - orig_map_nodes_num) 
                        node2 = agent.path[agent.pos]
                    else
                        node2 = agent.pos
                    end
                else
                    node2 = agent.path[agent.pos]
                end
                pos = deepcopy(node2)                
        end
    end

    # Remove an agent from previous location and add to a new one.
    delete!(model.nodes_agents[agent.pos], agent.id)
    push!(model.nodes_agents[pos], agent.id)
    # Calc statistics
    model.nodes_agents_max[pos] = max(length(model.nodes_agents[pos]), model.nodes_agents_max[pos])
    model.nodes_visits[pos] += 1

    agent.pos = pos
end



### TTC CARS DYNAMIC ###

# Movement of a TTC car
function move_agent!(wagon::Wagon, model::Simulation, t::EventTime) 
    # A wagon moves from one node to another on the route and disappear at the end.
	pos = wagon.path[wagon.pos] 
    # Delete this wagon from the previous position and add to a new one.
    delete!(model.nodes_wagons[wagon.pos], wagon.id)
    push!(model.nodes_wagons[pos], wagon.id)
    wagon.pos = pos
end

# Request new wagons
function add_new_wagon!(model::Simulation, wagon::Wagon, orig_map_nodes_num)
    # New wagon definition

    new_wagon = Wagon(id = model.recent_wagon + 1
        ,pos = collect(keys(wagon.path))[1]
        ,line = wagon.line
        ,type = wagon.type
        ,path = wagon.path
        ,path_distances = wagon.path_distances
        ,time_start = wagon.time_start + wagon.run_every
		,run_every = wagon.run_every
        ,max_load = wagon.max_load)
    # Adding to the simulation
    push!(model.wagons, new_wagon)
    model.recent_wagon = new_wagon.id
    
    # Our old wagon requsted a new one.
    wagon.next_wagon_requested = true
    
    # New wagon gather all people which are on the first station
    time_new_wagon_starts = tuple(new_wagon.time_start,rand())
    leave_passengers!(model,time_new_wagon_starts,new_wagon)
    take_passengers!(model,time_new_wagon_starts,new_wagon)
    update_passengers_pos!(model,new_wagon, orig_map_nodes_num)
    # We create a new event for the wagon for the second station
    queue_key = tuple(time_new_wagon_starts[1]+new_wagon.path_distances[new_wagon.pos],rand())
    enqueue!(model.events, new_wagon, queue_key)
end

# Take passengers waiting on the station
function take_passengers!(model::Simulation, t::EventTime, wagon::Wagon)
    # A wagon takes passengers only when it has free places.
    # A wagon checks all passengers who are on the station.
    # It take only those passengers for whom the next node on the route is the same as for this wagon.
    for pass in model.nodes_agents[wagon.pos]
        if length(wagon.passengers) < ceil(wagon.max_load*model.max_load_gov_restr)
            ag = filter(ag->ag.id==pass,model.agents)[1]
            if (wagon.path[wagon.pos] == ag.path[wagon.pos]) && (ag.wagon_id == -999)
				# Tell anyone inside that this agent is infected
				if ag.infected == true
					for copass in wagon.passengers
						if copass.infected == false
							push!(copass.met_infected_in_wagon,ag.id)
						end
					end
				end
                # Update of co-riders
                push!(wagon.passengers,ag)
                # For each passenger we update in which wagon he/she is.
                ag.wagon_id = wagon.id
            end
        end   
    end
end

# Leave passengers who need to leave a TTC car on specific point in time.
function leave_passengers!(model::Simulation, t::EventTime, wagon::Wagon)
    # If it is the last station everyone will be asked to leave a TTC car.
    if wagon.pos == collect(values(wagon.path))[end]
        current_passengers = copy(wagon.passengers) # copy because if there is no copy we will iterate through and modify the same array, so the loop will stop after the first change.
        # We remove all passengers and schedule next events for them.
        for pass in current_passengers
			if !pass.infected
				inf_no = length(pass.met_infected_in_wagon)
				if inf_no >= 1
					p0_TTC = model.p0 * 19
					# An agent can interact maximum with max_interactions_TTC agents in the TTC.
					p = 1 - (1-p0_TTC)^min(inf_no,model.max_interactions_TTC)
					pass.infected = (min(1, p) > rand())
					if pass.infected == true
						pass.infected_in = :wagon
						model.infected_agents_count_current += 1
						model.infected_agents_wagon_current += 1
					end
					pass.met_infected_in_wagon = Set{Int}()
                    push!(model.num_interactions_vec_TTC,inf_no) 
				end
			end
			# Delete passengers who left a TTC car and add them new events.
            delete!(model.nodes_agents[pass.pos], pass.id)
            filter!(e->e!=pass,wagon.passengers)
            pass.wagon_id = -999

            pass.pos = deepcopy(wagon.pos)

            push!(model.nodes_agents[pass.pos], pass.id)
            model.nodes_agents_max[pass.pos] = max(length(model.nodes_agents[pass.pos]), model.nodes_agents_max[pass.pos])
            model.nodes_visits[pass.pos] += 1
			
            queue_key = tuple(t[1] + pass.path_distances[pass.pos],rand())
            enqueue!(model.events, pass, queue_key)
        end  
    else
        # If it is not the last station we check for each agent if this station is one to leave a TTC car.
        # If a next station for TTC is not included in an agent path it means that the current station is the last one.
        # If it is so we schedule a new event.
        current_passengers = copy(wagon.passengers) # copy because if there is no copy we will iterate through and modify the same array, so the loop will stop after the first change.
        for pass in current_passengers
           if wagon.path[wagon.pos] ∉ keys(pass.path)
                # Caculation of infection p and infection assgiment right after exiting a TTC car.
                if !pass.infected
					inf_no = length(pass.met_infected_in_wagon)
                    if inf_no >= 1
						p0_TTC = model.p0 * 19
						# An agent can interact maximum with max_interactions_TTC agents in the TTC.
						p = 1 - (1-p0_TTC)^min(inf_no,model.max_interactions_TTC)
                        pass.infected = (min(1, p) > rand())
                        if pass.infected == true
                            pass.infected_in = :wagon
							model.infected_agents_count_current += 1
							model.infected_agents_wagon_current += 1
                        end
						pass.met_infected_in_wagon = Set{Int}()
                        push!(model.num_interactions_vec_TTC,inf_no) 
                    end
                end
				
                # Delete passengers who left a TTC car and add them new events.
				delete!(model.nodes_agents[pass.pos], pass.id)
                filter!(e->e!=pass,wagon.passengers)
                pass.wagon_id = -999
  
                pass.pos = deepcopy(wagon.pos)
				
                push!(model.nodes_agents[pass.pos], pass.id)
                model.nodes_agents_max[pass.pos] = max(length(model.nodes_agents[pass.pos]), model.nodes_agents_max[pass.pos])
                model.nodes_visits[pass.pos] += 1
                queue_key = tuple(t[1] + pass.path_distances[pass.pos], rand())
                enqueue!(model.events, pass, queue_key)
            end
        end

    end
end

# For agents who are inside a TTC car. The TTC car updates their positions on each station.
function update_passengers_pos!(model::Simulation, wagon::Wagon, orig_map_nodes_num)
    # We update positions of all passengers according to the TTC car they are inside.
    current_passengers = copy(wagon.passengers) # copy because if there is no copy we will iterate through and modify the same array, so the loop will stop after the first change.
    move_agent!.(current_passengers, Ref(model), orig_map_nodes_num)
end

# Count passengers inside a TTC car on each station. Thanks to this we can check if there was a max_load issue.
function count_passengers_and_update_max_passengers_ever!(model::Simulation, wagon::Wagon)
    wagon.max_passengers_ever = max(wagon.max_passengers_ever,length(wagon.passengers))
end

println("Simulation dynamic functions were read")