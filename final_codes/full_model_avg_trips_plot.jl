println("---> START <---")
# Working directory to /final_codes/
cd("SOME_PATH")
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






df = DataFrame("freq" => [], "avg_trips" => [], "std_trips" => [])
freqs = [i for i in 60:60:60*20]
for i in 1:20
    freq_to_check = freqs[i];
    # Load json to Julia
    my_json=join(readlines("SOME_PATH/avg_trips_full/simul_res_parset_id_$i.json"));
    my_json_dict=JSON.parse(my_json);
    tmp = my_json_dict["avg_num_of_trips"]
    push!(df, [freq_to_check,tmp[1],tmp[2]])
end

CSV.write("SOME_PATH/avg_trips_full/toy_model_trips_df.csv", df)