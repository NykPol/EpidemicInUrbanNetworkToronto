function read_and_prep_osm_map(;map_path::String 
								, routes_dict::OrderedDict{Symbol, OrderedDict{Int,Tuple{Float64,Float64}}}
								, secs_between_stops::Dict{Tuple{Int,Int},Int64}
								, TTC_car_freq::Int = sim_params.TTC_car_freq
								, agents_speed_in_sec_per_m::Float64 = sim_params.agents_speed_in_sec_per_m
								, parset_id::Int64
								, serialize_results::Bool = false)
	"""
	Description:
		Reads the specified .osm map (e.g. central_toronto) with all related objects as nodes, graph etc.
		Next it will add TTC information (routes and stops as egdes and vertices) to the map.
		It will also generate structures which will be used in the simulation for routing (e.g. routes_path, routes_distances).
		Map, routes_path and routes_distances will be serialized and saved to the data_output folder.
		
		NOTE! Create data_output folder in your working directory.
	Returns:
		Map, number of nodes in the map before TTC info adding, routes_path, routes_distances
	"""
	
	println("By default TTC_car_freq will be used from object `sim_params`")
	println("TTC car freq specified: ", TTC_car_freq)
    m = OpenStreetMapX.get_map_data(map_path, use_cache=false, trim_to_connected_graph=true);
    orig_map_nodes_num = nv(m.g)
    node_id_stop_id_dict, stop_id_to_node_id_dict = adding_TTC_points_to_map!(routes_dict, m);
    routes_path, routes_distances = create_routes_dicts(routes_dict, secs_between_stops, orig_map_nodes_num);
	add_edges_and_weights_to_map!(m = m
									, TTC_graph = gg
									, stop_id_to_node_id_dict = stop_id_to_node_id_dict
									, node_id_stop_id_dict = node_id_stop_id_dict
									, wait_time = Int64(TTC_car_freq/2)
									, orig_map_nodes_num = orig_map_nodes_num
									, agents_speed_in_sec_per_m = agents_speed_in_sec_per_m);
	if serialize_results
		path_map = "./data_output/map_prepared_$TTC_car_freq.....$agents_speed_in_sec_per_m.bin"
		path_routes_path = "./data_output/routes_path_prepared_$TTC_car_freq.....$agents_speed_in_sec_per_m.bin"
		path_routes_distances = "./data_output/routes_distances_prepared_$TTC_car_freq.....$agents_speed_in_sec_per_m.bin"
		path_orig_map_nodes_num = "./data_output/orig_map_nodes_num_prepared_$TTC_car_freq.....$agents_speed_in_sec_per_m.bin"
		serialize(path_map, m)
		serialize(path_routes_path, routes_path)
		serialize(path_routes_distances, routes_distances)
		serialize(path_orig_map_nodes_num, orig_map_nodes_num)
		println("Map object `m` was saved in: ", path_map)
		println("Object `routes_path` was saved in: ", path_routes_path)
		println("Object `routes_distances` was saved in: ", path_routes_distances)
		println("Object `orig_map_nodes_num` was saved in: ", path_orig_map_nodes_num)
		println("OSM map prepared")
	end
    return m, orig_map_nodes_num, routes_path, routes_distances
end
println("Read and prepare OSM map functions were read.")