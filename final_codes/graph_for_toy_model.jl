println("---> START <---")
# Working directory to /final_codes/
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

using OpenStreetMapXPlot

Pkg.add("GraphPlot")
using GraphPlot

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

# COSTANT
secs_between_stops_const = 10
### CREATE TOY GRAPH ###
gg = SimpleDiGraph(12)
orig_map_nodes_num = 4 # It means that only 4 out of 12 vertices are STREET

#City route: A->B
As = [1,2,3,2,3,4,5,6,7,1,7,9,10,11,4,11]
Bs = [2,3,4,1,2,3,6,7,8,6,4,10,11,12,10,1]

for i in 1:length(As)
    add_edge!(gg, As[i], Bs[i])
end

#gplot(gg, nodelabel = 1:12, layout=spectral_layout, nodelabeldist=1.5)
### CREATE MAP STRUCTURE ###
my_w = SparseArrays.sparse(As, Bs,[100.0 for i in 1:length(As)], 12, 12)
m = OpenStreetMapX.get_map_data("./data_input/central_toronto.osm", use_cache=false, trim_to_connected_graph=true);

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
### Test - 1 - shortest route ###

# HOME -> WORK
home = 1
work = 4
agent = Commuter(2, home, home, work)

num_paths = 2
ys = yen_k_shortest_paths(m.g, home, work, m.w, num_paths, maxdist=100_000)
agent.probs_home_work = zeros(num_paths)
for (index, nodes) in enumerate(ys.paths)
    agent.paths_home_work[index] = Dict()
    agent.distances_home_work[index] = Dict()
    setindex!.(Ref(agent.paths_home_work[index]), nodes[2:end], nodes[1:end-1])
    for i in 1:(length(nodes)-1)
        agent.distances_home_work[index][nodes[i]] = m.w[nodes[i], nodes[i+1]]
    end
    agent.probs_home_work[index] = (exp(-(ys.dists[index])/minimum(ys.dists)))
end
agent.probs_home_work = agent.probs_home_work./sum(agent.probs_home_work)
#ok

### RUN SIMULATION EXAMPLE ###


simul_res = initialize_sim_and_run(m = m
        , routes_path = routes_path
        , routes_distances = routes_distances
        , routes_types_both_dir = routes_types_both_dir
        , orig_map_nodes_num = orig_map_nodes_num
        , serialize_finished_sim_object = false
        , parset_id = 1
        , when_to_run_people = 0.0
        , when_to_run_wagons = 100.0
        , TTC_freq = secs_between_stops_const
        , max_load_subway = 10000
        , max_load_streetcar = 10000
        , max_load_gov_restr =  1.0
        , N_agents =  1000
        , sim_run_time_in_secs = 1000
        , p0 =  0.001
        , prepared_agents = Commuter[]
        , max_interactions_TTC = 10
        , max_interactions_street = 3)

simul_res.agents[1]
simul_res.agents[1].paths_home_work

TTC_usage_by_agents(simul_res, orig_map_nodes_num)
