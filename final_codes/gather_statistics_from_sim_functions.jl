function calc_wagons_time_from_first_to_last(s::Simulation, know_which_route::Bool = false)
	"""
	Description:
		For each TTC route calculates how many seconds it takes to get from the first station to the last on the route.
	Returns:
		Array with unique values or Dictionary with value per route.
	"""
	if know_which_route == true
		wagons_time_from_first_to_last = Dict{String,Float64}()
		for wag in s.wagons
			if wag.line ∉ keys(wagons_time_from_first_to_last)
				wagons_time_from_first_to_last[wag.line] = sum(values(wag.path_distances))
			end
		end
	elseif know_which_route == false
		wagons_time_from_first_to_last = Float64[]
		for wag in s.wagons
		   push!(wagons_time_from_first_to_last,sum(values(wag.path_distances))) 
		end
	end
	
    return unique(wagons_time_from_first_to_last)
end


function calc_agents_time_to_work(s::Simulation)
	"""
	Description:
		For each agent calculates how many seconds it takes to get from home to work.
	Returns:
		Array with values per agent.
	"""
    agents_time_to_work = Float64[]
    for ag in s.agents
		sums = [sum(values(value)) for (key, value) in ag.distances_home_work]
		push!(agents_time_to_work, mean(sums))
    end
    return agents_time_to_work
end



function TTC_usage_by_agents(s::Simulation, orig_map_nodes_num::Int64)
	"""
	Description:
		For each agent calculates:
			1) how many seconds he/she spends in TTC on the way from home to work
			2) how many different TTC types he/she uses to get from home to work
			3) percent of time spent in TTC in relation to the total time from home to work
	Returns:
		time_spend_in_TTC, TTC_types_used, time_spend_in_TTC_comp_to_total_path_time
	"""
    time_spend_in_TTC = Float64[]
    TTC_types_used = Int64[]
    agents_time_to_work = calc_agents_time_to_work(s);
    
    for ag in s.agents
        ag_TTC_types_used = Int64[]
        ag_time_in_TTC = Dict()
		TTC_on_path = Dict()

		for (key, value) in ag.paths_home_work
			TTC_on_path[key] = [i for i in keys(value) if i > orig_map_nodes_num]
		end
        
		for (key, value) in TTC_on_path
			ag_time_in_TTC[key] = 0
			for ttc_node in value
            	ag_time_in_TTC[key] += ag.distances_home_work[key][ttc_node]
            	push!(ag_TTC_types_used, route_types[ttc_node-orig_map_nodes_num])
			end
        end
		ag_time_in_TTC = mean(values(ag_time_in_TTC))
        
        push!(time_spend_in_TTC, ag_time_in_TTC)
        push!(TTC_types_used, length(unique(ag_TTC_types_used)))
    end
    time_spend_in_TTC_comp_to_total_path_time  = time_spend_in_TTC ./ agents_time_to_work 
    return time_spend_in_TTC, TTC_types_used, time_spend_in_TTC_comp_to_total_path_time
end

println("Gather statistics functions were read")




### Examples ###
# maximum(values(s.max_passengers_per_TTC_car))

# agents_time_to_work = calc_agents_time_to_work(s);
# describe(agents_time_to_work ./ 60)

# wagons_time_from_first_to_last = calc_wagons_time_from_first_to_last(s);
# describe(wagons_time_from_first_to_last ./ 60)

# time_spend_in_TTC, TTC_types_used, time_spend_in_TTC_comp_to_total_path_time = TTC_usage_by_agents(s,orig_map_nodes_num);
# describe(time_spend_in_TTC ./ 60)
# describe(time_spend_in_TTC_comp_to_total_path_time)
# describe(TTC_types_used)