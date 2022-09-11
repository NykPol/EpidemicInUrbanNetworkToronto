println("---> START <---")
# Working directory to /final_codes/
if split(pwd(),"/")[end] != "final_codes"
    throw("Your working directory should be in: COVID_Simulator_Toronto/final_codes")
end


# Set up environment
using Pkg
using Distributed
@everywhere using Pkg
@everywhere using Distributed
@everywhere Pkg.activate(".")

@everywhere using JSON
@everywhere using Glob
@everywhere using CSV
@everywhere using Random
@everywhere using DataFrames
@everywhere using Conda
@everywhere using PyCall
@everywhere using Serialization
@everywhere using SparseArrays

@everywhere using Statistics
@everywhere using StatsBase


@everywhere using Distributions
@everywhere using DataStructures
@everywhere using Parameters


@everywhere using Geodesy
@everywhere using SimpleWeightedGraphs
@everywhere using OpenStreetMapX
@everywhere using LightGraphs

@everywhere using AWSS3
@everywhere using AWS

println("---> PACKAGES DONE <---")

# Include codes
@everywhere include("TTC_data_read_and_prep_functions.jl")
@everywhere include("graph_from_TTC_data_functions.jl")
@everywhere include("read_and_prep_osm_map_functions.jl")
@everywhere include("complete_map_with_TTC_functions.jl")
@everywhere include("create_simulation_objects_functions.jl")
@everywhere include("simulation_dynamic_functions.jl")
@everywhere include("init_and_run_sim_functions.jl")
@everywhere include("gather_statistics_from_sim_functions.jl")
println("---> INCLUDES DONE <---")

# Read TTC data and create needed structures
@everywhere gg,secs_between_stops,routes_dict,route_types,routes_filtered,routes_types_both_dir = read_and_prep_TTC_data(data_folder = "./data_input/");

# Define simulation parameters
#
@everywhere sim_params_comb_df = create_df_with_sim_params(TTC_car_freq = [i for i in 60:60:60*20]
                                                            , max_load_gov_restr = 1.0
                                                            , when_to_run_people = 60.0*60.0*1.0
                                                            , when_to_run_wagons = 0.0
                                                            , sim_run_time_in_secs = 3*24*60*60
                                                            , N_agents = 2000
                                                            , agents_speed_in_sec_per_m = 0.8
                                                            , max_load_subway = 100
                                                            , max_load_streetcar = 100
                                                            , p0 = 1/1000
                                                            , max_interactions_TTC = 10
                                                            , max_interactions_street = 3);
CSV.write("./data_output/sim_params_comb_df.csv",sim_params_comb_df);

# AWS ENV
@everywhere AWS_ACCESS_KEY_ID = "SOME_AWS_ACCESS_KEY_ID"
@everywhere AWS_SECRET_ACCESS_KEY = "SOME_AWS_SECRET_ACCESS_KEY"
@everywhere aws = AWSConfig()

# AWS PATH
@everywhere aws_path = "dynamic_wait_time/soscip_res"
@everywhere aws_s3_name = "covidsimjulia"
@everywhere aws_full_path = aws_s3_name * "/" * aws_path


# Write params to AWS
if s3_exists(aws,aws_s3_name,aws_path * "/sim_params_comb_df.csv")
	println("SIM PARAMS COMB DF EXISTS ALREADY!")
else
	b = IOBuffer()
	CSV.write(b,sim_params_comb_df)
	s3_put(aws,aws_full_path,"sim_params_comb_df.csv",take!(b))
	println("sim_params_comb_df.csv was saved in S3")
end

# Select one parameters set
@sync @distributed for par_set_id in 1:nrow(sim_params_comb_df)
    println("CURRENT PARSET ID: ", par_set_id)
	if s3_exists(aws,aws_s3_name,aws_path * "/simul_res_parset_id_$par_set_id.json")
		println("CURRENT PARSET ID: ", par_set_id," already exists in AWS. Julia will continue")
		continue
	end
    sim_params = Simulation_Parameters(copy(sim_params_comb_df[par_set_id,2:end])...);
    println("Simulation parameters selected:\n", sim_params)


    freq_to_check = deepcopy(sim_params.TTC_car_freq)
    speed_to_check = deepcopy(sim_params.agents_speed_in_sec_per_m)


    # Create map and add TTC
    if isfile("./data_output/map_prepared_$freq_to_check.....$speed_to_check.bin") == false
        m, orig_map_nodes_num, routes_path, routes_distances  = read_and_prep_osm_map(map_path = "./data_input/central_toronto.osm"
                                                                                        , routes_dict = routes_dict
                                                                                        , secs_between_stops = secs_between_stops
                                                                                        , parset_id = par_set_id
                                                                                        , serialize_results = true
                                                                                        , TTC_car_freq = freq_to_check
								                                                        , agents_speed_in_sec_per_m = speed_to_check)
    else
        println("Objects with suffix $freq_to_check.....$speed_to_check.bin already exist and will be used.")
        m = deserialize("./data_output/map_prepared_$freq_to_check.....$speed_to_check.bin")
        orig_map_nodes_num = deserialize("./data_output/orig_map_nodes_num_prepared_$freq_to_check.....$speed_to_check.bin")
        routes_path = deserialize("./data_output/routes_path_prepared_$freq_to_check.....$speed_to_check.bin")
        routes_distances = deserialize("./data_output/routes_distances_prepared_$freq_to_check.....$speed_to_check.bin")
    end

    # Prepared agents
    if isfile("./data_output/agents_set_SPEED_08_AGENTS_150000...TTC_FREQ_$freq_to_check.bin") == false
        println("Agents will be created during simulation.")
        prepared_agents = Commuter[]
    else
        println("Already existing agents will be used. ---> ./data_output/agents_set_SPEED_08_AGENTS_150000...TTC_FREQ_$freq_to_check.bin")
        prepared_agents = deserialize("./data_output/agents_set_SPEED_08_AGENTS_150000...TTC_FREQ_$freq_to_check.bin");
    end
    
    # Run simulation
    simul_res = initialize_sim_and_run_N_times_and_gather_results(m = m
            , routes_path = routes_path
            , routes_distances = routes_distances
            , routes_types_both_dir = routes_types_both_dir
            , orig_map_nodes_num = orig_map_nodes_num
            , serialize_finished_sim_object = false
            , parset_id = par_set_id
            , N_times_to_run = 200

            , when_to_run_people = sim_params.when_to_run_people
            , when_to_run_wagons = sim_params.when_to_run_wagons
            , TTC_freq = freq_to_check
            , max_load_subway= sim_params.max_load_subway
            , max_load_streetcar = sim_params.max_load_streetcar
            , max_load_gov_restr=  sim_params.max_load_gov_restr
            , N_agents =  sim_params.N_agents
            , sim_run_time_in_secs = sim_params.sim_run_time_in_secs
            , p0 =  sim_params.p0
            , prepared_agents = prepared_agents
            , max_interactions_TTC = sim_params.max_interactions_TTC
            , max_interactions_street = sim_params.max_interactions_street);

    # Save results to JSON
    simul_res_to_json = JSON.json(simul_res)
    # open("./data_output/simul_res_parset_id_$par_set_id.json", "w") do f
            # write(f, simul_res_to_json)
         # end
    # Save results to AWS
    s3_put(aws,aws_full_path,"simul_res_parset_id_$par_set_id.json",simul_res_to_json)
    println("par_set_id: ", par_set_id, " finished at $(myid())")
end

