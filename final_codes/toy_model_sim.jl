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
Pkg.instantiate()

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

using OpenStreetMapXPlot

#Pkg.add("GraphPlot")
#using GraphPlot

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



################### Loop through parsets #####################

function make_toy_graph(secs_between_stops_const;m_path="./data_input/central_toronto.osm", walking_edge::Float64=120.0)
    m = OpenStreetMapX.get_map_data(m_path, use_cache=false, trim_to_connected_graph=true);
    gg = SimpleDiGraph(12)
    orig_map_nodes_num = 4 # It means that only 4 out of 12 vertices are STREET
    route_types = Dict(1:orig_map_nodes_num .=> zeros(orig_map_nodes_num))
    merge!(route_types, Dict((orig_map_nodes_num+1):12 .=> ones(12-orig_map_nodes_num)))

    #City route: A->B
    As = [1,2,3,2,3,4,5,6,7,1,7,9,10,11,4,11]
    Bs = [2,3,4,1,2,3,6,7,8,6,4,10,11,12,10,1]

    for i in 1:length(As)
        add_edge!(gg, As[i], Bs[i])
    end

    #gplot(gg, nodelabel = 1:12, layout=spectral_layout, nodelabeldist=1.5)
    ### CREATE MAP STRUCTURE ###
    my_w = SparseArrays.sparse(As, Bs,[walking_edge for i in 1:length(As)], 12, 12)

    my_w[5,6] = secs_between_stops_const
    my_w[6,7] = secs_between_stops_const
    my_w[7,8] = secs_between_stops_const
    my_w[9,10] = secs_between_stops_const
    my_w[10,11] = secs_between_stops_const
    my_w[11,12] = secs_between_stops_const

    m.g = gg
    m.w = my_w

    ### Create helper objects for TTC ###
    secs_between_stops =  Dict{Tuple{Int64, Int64}, Int64}()
    secs_between_stops[(5,6)] = secs_between_stops_const
    secs_between_stops[(6,7)] = secs_between_stops_const
    secs_between_stops[(7,8)] = secs_between_stops_const
    secs_between_stops[(9,10)] = secs_between_stops_const
    secs_between_stops[(10,11)] = secs_between_stops_const
    secs_between_stops[(11,12)] = secs_between_stops_const

    routes_path = OrderedDict{Symbol, OrderedDict{Int64, Int64}}()
    routes_path[Symbol("99999_a")] = OrderedDict(5=>6, 6=>7, 7=>8)
    routes_path[Symbol("99999_b")] = OrderedDict(9=>10, 10=>11, 11=>12)

    routes_types_both_dir = Dict{Symbol, Symbol}()
    routes_types_both_dir[Symbol("99999_a")] = :subway
    routes_types_both_dir[Symbol("99999_b")] = :subway

    routes_distances = OrderedDict{Symbol, OrderedDict{Int64, Float64}}()
    routes_distances[Symbol("99999_a")] = OrderedDict(5 => secs_between_stops_const, 6 => secs_between_stops_const, 7 => secs_between_stops_const)
    routes_distances[Symbol("99999_b")] = OrderedDict(9 => secs_between_stops_const, 10 => secs_between_stops_const, 11 => secs_between_stops_const)
    return m, routes_path, routes_distances, orig_map_nodes_num, routes_types_both_dir, route_types, secs_between_stops
end

N_agents = 500 # no max load, no max interactions
sim_params_comb_df = create_df_with_sim_params(TTC_car_freq = [i for i in 30:30:600]
                                            , max_load_gov_restr = 1.0
                                            , when_to_run_people = 60.0*60.0*1.0
                                            , when_to_run_wagons = 0.0
                                            , sim_run_time_in_secs = 3*24*60*60
                                            , N_agents = N_agents
                                            , agents_speed_in_sec_per_m = 0.8
                                            , max_load_subway = N_agents
                                            , max_load_streetcar = N_agents
                                            , p0 = 1/1000
                                            , max_interactions_TTC = N_agents
                                            , max_interactions_street = N_agents);
#CSV.write("./data_output/toy_model3/sim_params_comb_df.csv",sim_params_comb_df);


#####
# JUST ONE RUN WITH ONE SET
####

sim_params = Simulation_Parameters(copy(sim_params_comb_df[1,2:end])...);
println("Simulation parameters selected:\n", sim_params)
freq_to_check = deepcopy(sim_params.TTC_car_freq)
# Prepare map
m, routes_path, routes_distances, orig_map_nodes_num, routes_types_both_dir, route_types, secs_between_stops = make_toy_graph(freq_to_check);
# Run simulation
simul_res = initialize_sim_and_run(m = m
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
        , prepared_agents = Commuter[]
        , max_interactions_TTC = sim_params.max_interactions_TTC
        , max_interactions_street = sim_params.max_interactions_street);



#####
# JUST ONE RUN WITH DIFFERENT SETS
####


avg_trips = Vector{Float64}()
for par_set_id in 1:nrow(sim_params_comb_df)

    sim_params = Simulation_Parameters(copy(sim_params_comb_df[par_set_id,2:end])...);
    println("Simulation parameters selected:\n", sim_params)
    freq_to_check = deepcopy(sim_params.TTC_car_freq)
    # Prepare map
    m, routes_path, routes_distances, orig_map_nodes_num, routes_types_both_dir, route_types, secs_between_stops = make_toy_graph(freq_to_check);
    # Run simulation
    simul_res = initialize_sim_and_run(m = m
            , routes_path = routes_path
            , routes_distances = routes_distances
            , routes_types_both_dir = routes_types_both_dir
            , orig_map_nodes_num = orig_map_nodes_num
            , serialize_finished_sim_object = false
            , parset_id = par_set_id
            , when_to_run_people = sim_params.when_to_run_people
            , when_to_run_wagons = sim_params.when_to_run_wagons
            , TTC_freq = freq_to_check
            , max_load_subway= sim_params.max_load_subway
            , max_load_streetcar = sim_params.max_load_streetcar
            , max_load_gov_restr=  sim_params.max_load_gov_restr
            , N_agents =  sim_params.N_agents
            , sim_run_time_in_secs = sim_params.sim_run_time_in_secs
            , p0 =  sim_params.p0
            , prepared_agents = Commuter[]
            , max_interactions_TTC = sim_params.max_interactions_TTC
            , max_interactions_street = sim_params.max_interactions_street);
    tmp = Vector{Int}()
    for ag in simul_res.agents
        push!(tmp,ag.no_of_trips)
    end
    push!(avg_trips, mean(tmp))
end

avg_trips
sim_params_comb_df.TTC_car_freq




#####
# MULTIPLE RUNS WITH MULTIPLE SETS
####
for par_set_id in 1:nrow(sim_params_comb_df)
    println("CURRENT PARSET ID: ", par_set_id)
    sim_params = Simulation_Parameters(copy(sim_params_comb_df[par_set_id,2:end])...);
    println("Simulation parameters selected:\n", sim_params)
    freq_to_check = deepcopy(sim_params.TTC_car_freq)
    # Prepare map
    m, routes_path, routes_distances, orig_map_nodes_num, routes_types_both_dir, route_types, secs_between_stops = make_toy_graph(freq_to_check);
    # Run simulation
    simul_res = initialize_sim_and_run_N_times_and_gather_results(m = m
            , routes_path = routes_path
            , routes_distances = routes_distances
            , routes_types_both_dir = routes_types_both_dir
            , orig_map_nodes_num = orig_map_nodes_num
            , serialize_finished_sim_object = false
            , parset_id = par_set_id
            , N_times_to_run = 10
            , when_to_run_people = sim_params.when_to_run_people
            , when_to_run_wagons = sim_params.when_to_run_wagons
            , TTC_freq = freq_to_check
            , max_load_subway= sim_params.max_load_subway
            , max_load_streetcar = sim_params.max_load_streetcar
            , max_load_gov_restr=  sim_params.max_load_gov_restr
            , N_agents =  sim_params.N_agents
            , sim_run_time_in_secs = sim_params.sim_run_time_in_secs
            , p0 =  sim_params.p0
            , prepared_agents = Commuter[]
            , max_interactions_TTC = sim_params.max_interactions_TTC
            , max_interactions_street = sim_params.max_interactions_street);

    # Save results to JSON
    simul_res_to_json = JSON.json(simul_res)
    open("./data_output/toy_model/simul_res_parset_id_$par_set_id.json", "w") do f
            write(f, simul_res_to_json)
         end
end




df = DataFrame("freq" => [], "avg_trips" => [], "std_trips" => [])
for i in 1:nrow(sim_params_comb_df)
    sim_params = Simulation_Parameters(copy(sim_params_comb_df[i,2:end])...);
    freq_to_check = deepcopy(sim_params.TTC_car_freq);
    # Load json to Julia
    my_json=join(readlines("./data_output/toy_model/simul_res_parset_id_$i.json"));
    my_json_dict=JSON.parse(my_json);
    tmp = my_json_dict["avg_num_of_trips"]
    push!(df, [freq_to_check,tmp[1],tmp[2]])
end

df
CSV.write("data_output/toy_model_trips_df.csv", df)