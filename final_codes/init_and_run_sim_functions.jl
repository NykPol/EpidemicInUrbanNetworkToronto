### Run Simulation ###
function initialize_sim_and_run(;m::MapData
				, routes_path::OrderedDict{Symbol, OrderedDict{Int64,Int64}}
				, routes_distances::OrderedDict{Symbol, OrderedDict{Int64,Float64}}
				, routes_types_both_dir::Dict{Symbol,Symbol}
				, orig_map_nodes_num::Int
				, when_to_run_people::Float64 = sim_params.when_to_run_people
				, when_to_run_wagons::Float64 = sim_params.when_to_run_wagons
				, TTC_freq::Union{Int, Float64} = sim_params.TTC_car_freq
				, max_load_subway::Int = sim_params.max_load_subway
				, max_load_streetcar::Int = sim_params.max_load_streetcar
				, max_load_gov_restr::Float64 =  sim_params.max_load_gov_restr
				, N_agents::Int =  sim_params.N_agents
				, sim_run_time_in_secs::Int = sim_params.sim_run_time_in_secs
				, serialize_finished_sim_object::Bool = false
				, p0::Float64 =  sim_params.p0
				, parset_id::Int64 = 1
				, prepared_agents::Vector{Commuter}  = Commuter[]
				, max_interactions_TTC::Int = sim_params.max_interactions_TTC
				, max_interactions_street::Int = sim_params.max_interactions_street)
	"""
	Description:
		Initialization of the simulation with a given parameters. Next the simulation will be running for the specified number of seconds.
	Returns:
		Simulation objects with the results.
	"""	
	
	println("By default parameters from `sim_params` object will be used")
	println("--------------------")
	simul = Simulation(m
						, orig_map_nodes_num
						, routes_path
						, routes_distances
						, routes_types_both_dir
						, N_agents
						, sim_run_time_in_secs
						, TTC_freq
						, max_load_subway
						, max_load_streetcar
						, max_load_gov_restr
						, p0
				        , prepared_agents
						, max_interactions_TTC
						, max_interactions_street)
	
	println("when_to_run_people: ",when_to_run_people)
	println("when_to_run_wagons: ",when_to_run_wagons)
	enqueue!.(Ref(simul.events), simul.agents, tuple.(when_to_run_people,rand(length(simul.agents))))
	enqueue!.(Ref(simul.events), simul.wagons, tuple.(when_to_run_wagons,rand(length(simul.wagons))))
	enqueue!(simul.events, simul.artificial_agent_stats, tuple(when_to_run_people, rand()))
	


    
	println("--------------------")
	println("Final simul object before run: \n", simul)
	println("--------------------")
	current_time = 0
	
	while sim_run_time_in_secs > current_time && length(simul.events) > 0
		event, t = dequeue_pair!(simul.events)
		step!(simul,  t,  event, orig_map_nodes_num)
		current_time = deepcopy(t[1])
		if simul.infected_agents_count[end] >= 0.95*N_agents
			println("Simulation has ended ealier, because 95% of agents are already infected. Current time: ",current_time) 
			break
		end
	end

	if serialize_finished_sim_object == true
		path_simul = "./data_output/simulation_finished_parset_id_$parset_id.bin"
		serialize(path_simul, simul)
		println("Simulation object with results was saved in: ", path_simul)
	end
	
	println("Simulation has already ended. You can check the results.")
    return simul
end
### Run Simulation N times###
function initialize_sim_and_run_N_times_and_gather_results(;m::MapData
				, routes_path::OrderedDict{Symbol, OrderedDict{Int64,Int64}}
				, routes_distances::OrderedDict{Symbol, OrderedDict{Int64,Float64}}
				, routes_types_both_dir::Dict{Symbol,Symbol}
				, orig_map_nodes_num::Int
				, when_to_run_people::Float64 = sim_params.when_to_run_people
				, when_to_run_wagons::Float64 = sim_params.when_to_run_wagons
				, TTC_freq::Union{Int,Float64} = sim_params.TTC_car_freq
				, max_load_subway::Int = sim_params.max_load_subway
				, max_load_streetcar::Int = sim_params.max_load_streetcar
				, max_load_gov_restr::Float64 =  sim_params.max_load_gov_restr
				, N_agents::Int =  sim_params.N_agents
				, sim_run_time_in_secs::Int = sim_params.sim_run_time_in_secs
				, serialize_finished_sim_object::Bool = false
				, parset_id::Int64 = 1
				, p0::Float64 =  sim_params.p0
				, prepared_agents::Vector{Commuter}  = Commuter[]
				, max_interactions_TTC::Int = sim_params.max_interactions_TTC
				, max_interactions_street::Int = sim_params.max_interactions_street
				, N_times_to_run::Int64 = 30)
	"""
	Description:
		Run the simulation with specified parameters N times and then gather related results into dict.
	Returns:
		Dict object with mean results of N runs.
	"""	
	vv = size(m.g)[1]

	res_gathering = Dict{String,Any}()
	total_cnt = Vector{Int}[]
	ttc_cnt = Vector{Int}[]
	street_cnt = Vector{Int}[] 
	
	prct_ag_used_TTC = Float64[]
	mean_time_spent_in_TTC = Float64[]
	
	max_load_achieved_streetcars = Float64[]
	max_load_achieved_subway = Float64[]
	
	all_TTC_trips_count_streetcars = Float64[]
	all_TTC_trips_count_subway = Float64[]
	
	# max_pass_per_wagon_subway = Vector{Float64}[] 
	# max_pass_per_wagon_streetcars = Vector{Float64}[]

	# nodes_agents_maxes = Dict{Int,Vector}()

	nodes_visits_res = Dict{Int,Vector}()
	for ver in 1:vv
		nodes_visits_res[ver] = Vector()
	end

	# num_interactions_vec_street_all_sim = Dict{Int,Vector{Int}}()
	# num_interactions_vec_TTC_all_sim = Dict{Int,Vector{Int}}()

	avg_no_of_trips = Vector{Float64}()
	
	println("Your simulation will be run ", N_times_to_run, " times")
	for i in 1:N_times_to_run	
	
		println("Is is a run number $i for parameters set number $parset_id.")
		@time s = initialize_sim_and_run(m = m
						, routes_path = routes_path
						, routes_distances = routes_distances
						, routes_types_both_dir = routes_types_both_dir
						, orig_map_nodes_num = orig_map_nodes_num
						, when_to_run_people = when_to_run_people
						, when_to_run_wagons = when_to_run_wagons
						, TTC_freq = TTC_freq
						, max_load_subway = max_load_subway
						, max_load_streetcar = max_load_streetcar 
						, max_load_gov_restr = max_load_gov_restr
						, N_agents = N_agents
						, sim_run_time_in_secs = sim_run_time_in_secs
						, serialize_finished_sim_object = serialize_finished_sim_object
						, p0 = p0
						, parset_id = parset_id
						, prepared_agents = prepared_agents
						, max_interactions_TTC = max_interactions_TTC
						, max_interactions_street = max_interactions_street)
		println("run $i done")	
		push!(total_cnt, s.infected_agents_count)
		push!(ttc_cnt, s.infected_agents_wagon)
		push!(street_cnt, s.infected_agents_street)
		
		# time_spend_in_TTC, TTC_types_used, time_spend_in_TTC_comp_to_total_path_time = TTC_usage_by_agents(s,orig_map_nodes_num);
		# push!(prct_ag_used_TTC, round((sum([1 for i in time_spend_in_TTC if i > 0]) / N_agents)*100))
		# push!(mean_time_spent_in_TTC, mean([i for i in time_spend_in_TTC if i > 0]))
		
		# loop_max_load_achieved_streetcar = [1 for (k,v) in s.max_passengers_per_TTC_car if (routes_types_both_dir[k[2]] == :streetcar) & (v >= max_load_streetcar)]
		# loop_max_load_achieved_subway = [1 for (k,v) in s.max_passengers_per_TTC_car if (routes_types_both_dir[k[2]] == :subway) & (v >= max_load_subway)]
		# push!(max_load_achieved_streetcars,sum(loop_max_load_achieved_streetcar))
		# push!(max_load_achieved_subway,sum(loop_max_load_achieved_subway))
		
		# loop_all_TTC_trips_count_streetcars = [1 for (k,v) in s.max_passengers_per_TTC_car if (routes_types_both_dir[k[2]] == :streetcar)]
		# loop_all_TTC_trips_count_subway = [1 for (k,v) in s.max_passengers_per_TTC_car if (routes_types_both_dir[k[2]] == :subway)]
		# push!(all_TTC_trips_count_streetcars,sum(loop_all_TTC_trips_count_streetcars))
		# push!(all_TTC_trips_count_subway,sum(loop_all_TTC_trips_count_subway))
		
		# loop_max_pass_per_wagon_streetcars = [v for (k,v) in s.max_passengers_per_TTC_car if (routes_types_both_dir[k[2]] == :streetcar)]
		# loop_max_pass_per_wagon_subway = [v for (k,v) in s.max_passengers_per_TTC_car if (routes_types_both_dir[k[2]] == :subway)]
		# # push!(max_pass_per_wagon_streetcars, [mean(loop_max_pass_per_wagon_streetcars),std(loop_max_pass_per_wagon_streetcars),maximum(loop_max_pass_per_wagon_streetcars)])
		# push!(max_pass_per_wagon_subway, [mean(loop_max_pass_per_wagon_subway),std(loop_max_pass_per_wagon_subway),maximum(loop_max_pass_per_wagon_subway)])

		# nodes_agents_maxes[i] = deepcopy(s.nodes_agents_max)

		# for vis_k in keys(s.nodes_visits)
		# 	push!(nodes_visits_res[vis_k], s.nodes_visits[vis_k])
		# end

		# num_interactions_vec_street_all_sim[i] = deepcopy(s.num_interactions_vec_street)
		# num_interactions_vec_TTC_all_sim[i] = deepcopy(s.num_interactions_vec_TTC)

		tmp_trips = Vector{Float64}()
		for ag in s.agents
			push!(tmp_trips, ag.no_of_trips)
		end
		push!(avg_no_of_trips, mean(tmp_trips))
		tmp_trips = Vector{Float64}()
	end	
	
	res_gathering["total_infected"] = (ceil.(mean(total_cnt)), ceil.(std(total_cnt)))
	res_gathering["TTC_infected"] = (ceil.(mean(ttc_cnt)), ceil.(std(ttc_cnt)))
	res_gathering["street_infected"] = (ceil.(mean(street_cnt)), ceil.(std(street_cnt)))
	
	res_gathering["prct_of_agents_used_TTC"] = (ceil.(mean(prct_ag_used_TTC)), ceil.(std(prct_ag_used_TTC)))
	res_gathering["mean_sec_spent_in_TTC_by_those_who_used"] = (ceil.(mean(mean_time_spent_in_TTC)), ceil.(std(mean_time_spent_in_TTC)))
	
	res_gathering["times_max_load_achieved_streetcars"] = (ceil.(mean(max_load_achieved_streetcars)), ceil.(std(max_load_achieved_streetcars)))
	res_gathering["times_max_load_achieved_subway"] = (ceil.(mean(max_load_achieved_subway)), ceil.(std(max_load_achieved_subway)))
	
	res_gathering["all_TTC_trips_count_streetcars"] = (ceil.(mean(all_TTC_trips_count_streetcars)),ceil.(std(all_TTC_trips_count_streetcars)))
	res_gathering["all_TTC_trips_count_subway"] = (ceil.(mean(all_TTC_trips_count_subway)),ceil.(std(all_TTC_trips_count_subway)))
	
	# res_gathering["max_pass_per_wagon_subway"] = (ceil.(mean(max_pass_per_wagon_subway)),ceil.(maximum(max_pass_per_wagon_subway)))
	# res_gathering["max_pass_per_wagon_streetcars"] = (ceil.(mean(max_pass_per_wagon_streetcars)),ceil.(maximum(max_pass_per_wagon_streetcars)))

	# res_gathering["agents_in_nodes_max"] = (ceil.(mean(total_cnt)), ceil.(std(total_cnt)))

	# res_gathering["nodes_agents_maxes"] = nodes_agents_maxes # we might need both dimensions

	# nodes_visits_mean = Dict{Int,Float64}()
	# for res_k in keys(nodes_visits_res)
	# 	nodes_visits_mean[res_k] = ceil(mean(nodes_visits_res[res_k]))
	# end

	# res_gathering["nodes_visits_mean"] = nodes_visits_mean

	# res_gathering["num_interactions_vec_street"] = num_interactions_vec_street_all_sim
	# res_gathering["num_interactions_vec_TTC"] = num_interactions_vec_TTC_all_sim

	res_gathering["avg_num_of_trips"] = (mean(avg_no_of_trips), std(avg_no_of_trips))

	println("All runs completed!")
	return res_gathering
end


### Create parameters grid ###
function create_df_with_sim_params(;TTC_car_freq::Union{Vector{Int64},Vector{Float64},Int64, Float64}
                                    , max_load_gov_restr::Union{Vector{Float64},Float64}
                                    , when_to_run_people::Union{Vector{Float64},Float64}
                                    , when_to_run_wagons::Union{Vector{Float64},Float64}
                                    , sim_run_time_in_secs::Union{Vector{Int64},Int64}
                                    , N_agents::Union{Vector{Int64},Int64}
									, agents_speed_in_sec_per_m::Union{Vector{Float64},Float64}
									, max_load_subway::Union{Vector{Int64},Int64}
									, max_load_streetcar::Union{Vector{Int64},Int64}
									, p0::Union{Vector{Float64},Float64}
									, max_interactions_TTC::Union{Vector{Int},Int}
									, max_interactions_street::Union{Vector{Int},Int})
	"""
	Description:
		Make all possible combinations of given values.
	Returns:
		DataFrame with all possible combinations of given parameters where one row means one set of parameters for Simulation.
	"""	
    df = DataFrame(Iterators.product(TTC_car_freq
                                        , max_load_gov_restr
                                        , when_to_run_people
                                        , when_to_run_wagons
                                        , sim_run_time_in_secs
                                        , N_agents
										, agents_speed_in_sec_per_m
										, max_load_subway
										, max_load_streetcar
										, p0
										, max_interactions_TTC
										, max_interactions_street))
    colnames = ["TTC_car_freq", "max_load_gov_restr", "when_to_run_people", "when_to_run_wagons", "sim_run_time_in_secs", "N_agents", "agents_speed_in_sec_per_m", "max_load_subway", "max_load_streetcar", "p0", "max_interactions_TTC", "max_interactions_street"]
    rename!(df,Symbol.(colnames))
	df[!,"parset_id"] = [i for i in 1:nrow(df)]
	df = df[:,["parset_id","TTC_car_freq", "max_load_gov_restr", "when_to_run_people", "when_to_run_wagons", "sim_run_time_in_secs", "N_agents", "agents_speed_in_sec_per_m", "max_load_subway", "max_load_streetcar", "p0", "max_interactions_TTC", "max_interactions_street"]]
    return df
end

println("Run sim functions were read")
