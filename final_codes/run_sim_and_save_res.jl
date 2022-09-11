println("---> START <---")
# Working directory to /final_codes/
cd("SOME_PATH/COVID_Simulator_Toronto/final_codes")
println("Your current directory: ", pwd())

if split(pwd(),"/")[end] != "final_codes"
    throw("Your working directory should be in: COVID_Simulator_Toronto/final_codes")
end
# Set up environment
using Pkg
Pkg.activate(".")

using JSON
using CSV
using Random
using DataFrames
using Conda
using PyCall
using Serialization
using SparseArrays

using Statistics
using StatsBase


using Distributions
using DataStructures
using Parameters


using Geodesy
using SimpleWeightedGraphs
using OpenStreetMapX
using LightGraphs


println("---> PACKAGES DONE <---")

# Include codes
include("TTC_data_read_and_prep_functions.jl")
include("graph_from_TTC_data_functions.jl")
include("read_and_prep_osm_map_functions.jl")
include("complete_map_with_TTC_functions.jl")
include("create_simulation_objects_functions.jl")
include("simulation_dynamic_functions.jl")
include("init_and_run_sim_functions.jl")
include("gather_statistics_from_sim_functions.jl")
println("---> INCLUDES DONE <---")

# Read TTC data and create needed structures
gg,secs_between_stops,routes_dict,route_types,routes_filtered,routes_types_both_dir = read_and_prep_TTC_data(data_folder = "./data_input/");

# Define simulation parameters
sim_params_comb_df = create_df_with_sim_params(TTC_car_freq = 3*60
                            , max_load_gov_restr = 1.0
                            , when_to_run_people = 60.0*60.0*1.0
                            , when_to_run_wagons = 0.0
                            , sim_run_time_in_secs = 3*24*60*60
                            , N_agents = 100
                            , agents_speed_in_sec_per_m = 0.8
                            , max_load_subway = 100
                            , max_load_streetcar = 100
                            , p0 = 1/1000
                            , max_interactions_TTC = 10
                            , max_interactions_street = 3);
CSV.write("./data_output/sim_params_comb_df.csv",sim_params_comb_df);


# Run one time
sim_params = Simulation_Parameters(copy(sim_params_comb_df[1,2:end])...);
freq_to_check = deepcopy(sim_params.TTC_car_freq)
speed_to_check = deepcopy(sim_params.agents_speed_in_sec_per_m)
if isfile("./data_output/map_prepared_$freq_to_check.....$speed_to_check.bin") == false
    m, orig_map_nodes_num, routes_path, routes_distances  = read_and_prep_osm_map(map_path = "./data_input/central_toronto.osm"
                                                                                    , routes_dict = routes_dict
                                                                                    , secs_between_stops = secs_between_stops
                                                                                    , parset_id = 1
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
    println("Already existing agents will be used.")
    prepared_agents = deserialize("./data_output/agents_set_SPEED_08_AGENTS_150000...TTC_FREQ_$freq_to_check.bin");
end

@time simul_res = initialize_sim_and_run(m = m
        , routes_path = routes_path
        , routes_distances = routes_distances
        , routes_types_both_dir = routes_types_both_dir
        , orig_map_nodes_num = orig_map_nodes_num
        , serialize_finished_sim_object = false
        , parset_id = 1

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

simul_res











# Select just one parset
sim_params = Simulation_Parameters(copy(sim_params_comb_df[1,2:end])...);
println("Simulation parameters selected:\n", sim_params)
freq_to_check = deepcopy(sim_params.TTC_car_freq)
speed_to_check = deepcopy(sim_params.agents_speed_in_sec_per_m)
# Create map and add TTC
if isfile("./data_output/map_prepared_$freq_to_check.....$speed_to_check.bin") == false
    m, orig_map_nodes_num, routes_path, routes_distances  = read_and_prep_osm_map(map_path = "./data_input/central_toronto.osm"
                                                                                    , routes_dict = routes_dict
                                                                                    , secs_between_stops = secs_between_stops
                                                                                    , parset_id = 1
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
        , parset_id = 1
        , N_times_to_run = 3

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



simul_res





# Loop through parset
for par_set_id in 1:nrow(sim_params_comb_df)
    println("CURRENT PARSET ID: ", par_set_id)
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
            , N_times_to_run = 3

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
    open("./data_output/simul_res_parset_id_$par_set_id.json", "w") do f
            write(f, simul_res_to_json)
         end
end

