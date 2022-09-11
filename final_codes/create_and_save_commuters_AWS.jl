println("---> START <---")
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
@everywhere include("create_commuters_and_save_functions.jl")
println("---> INCLUDES DONE <---")

# Read TTC data and create needed structures
@everywhere gg,secs_between_stops,routes_dict,route_types,routes_filtered,routes_types_both_dir = read_and_prep_TTC_data(data_folder = "./data_input/");

# Define simulation parameters
#
@everywhere sim_params_comb_df = create_df_with_sim_params(TTC_car_freq = [i for i in 60:60:60*25]
                            , max_load_gov_restr = 1.0
                            , when_to_run_people = 60.0*60.0*1.0
                            , when_to_run_wagons = 0.0
                            , sim_run_time_in_secs = 5*24*60*60
                            , N_agents = [150000]
                            , agents_speed_in_sec_per_m = 0.8 
                            , max_load_subway = 100
                            , max_load_streetcar = 100
                            , p0 = 1/1000);

@sync @distributed for par_set_id in 1:nrow(sim_params_comb_df)
    sim_params = Simulation_Parameters(copy(sim_params_comb_df[par_set_id,2:end])...);
    println("Simulation parameters selected:\n", sim_params)
    freq_to_check = deepcopy(sim_params.TTC_car_freq)
    speed_to_check = deepcopy(sim_params.agents_speed_in_sec_per_m)
    # Create map and add TTC
        m, orig_map_nodes_num, routes_path, routes_distances  = read_and_prep_osm_map(map_path = "./data_input/central_toronto.osm"
                                                                                        , routes_dict = routes_dict
                                                                                        , secs_between_stops = secs_between_stops
                                                                                        , parset_id = par_set_id
                                                                                        , serialize_results = true
                                                                                        , TTC_car_freq = sim_params.TTC_car_freq
								                        , agents_speed_in_sec_per_m = sim_params.agents_speed_in_sec_per_m)
create_commuters_to_save(m, orig_map_nodes_num, sim_params.N_agents, sim_params.TTC_car_freq)	
end

