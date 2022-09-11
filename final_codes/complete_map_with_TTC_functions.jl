function add_point_to_map!(m::MapData, point::Tuple{Float64,Float64}, external_id::Int64 = -999, verbose::Bool = false)
    """
    Description:
        Converts a pair Latitude-Longitude of coordinates `point` to a node on a map `m`. 
    Returns:
        It updates m.n and m.nodes and m.v.
    """
    point_LLA = OpenStreetMapX.LLA(point[1],point[2])
    add_point_to_map!(m, point_LLA, external_id, verbose)
end

function add_point_to_map!(m::MapData, point::OpenStreetMapX.LLA, external_id::Int64 = -999, verbose::Bool = false)
    """
    Description:
        Converts a pair Latitude-Longitude of coordinates `point` to a node on a map `m`. 
    Returns:
        It updates m.n and m.nodes and m.v.
    """
    point_ENU = OpenStreetMapX.ENU(point, m.bounds)
    
    # generate node id for the point
    unq = false
    new_node_id = 0
    while unq == false
        new_node_id = -abs(rand(Int32))
        unq = ifelse(new_node_id ∉  m.n, true, false)
    end
    
    # Add to nodes
    push!(m.n, new_node_id)
    m.nodes[new_node_id] = point_ENU
    
    # Add to vertices
    m.v[new_node_id] = m.v.count + 1
    
    # Add to graph
    add_vertex!(m.g)
    
    if verbose == true
        println("New node and vertice created.")
        println("Node id: ", new_node_id)
        println("Vertice id: ", m.v.count)
    end
    
    if external_id != -999
        return new_node_id => external_id
    end
end



function find_route_id_by_stop_id(stop_id::Int64)
    """
    Description:
        Gives route_id to which stop_id is assigned.
    Returns:
        route_id which is associated with given stop_id.
    """
    for (nr,route) in enumerate(keys.(values(routes_dict)))
        if stop_id in route
           return collect(keys(routes_dict))[nr]
        end
    end
end



function describe_node(node_id::Int)
	"""
	Takes node_id from the final graph and if this node is a TTC node the description will be given.
	"""
    stop_my_id = m.v[node_id] - orig_map_nodes_num;
    stop_org_id = trip_longest_df[coalesce.(trip_longest_df[!, "my_stop_id"] .== stop_my_id, false),:][!, "stop_id"][1]
    stop_name = stops[coalesce.(stops[!, "stop_id"] .== stop_org_id, false),:][!, "stop_name"][1]
    route_id = find_route_id_by_stop_id(stop_my_id)
    route_name = routes_filtered[coalesce.(routes_filtered[!, "route_id"] .== parse(Int64,split(route_id,"_")[1]), false),:][!, "route_long_name"][1]
    route_number = routes_filtered[coalesce.(routes_filtered[!, "route_id"] .== parse(Int64,split(route_id,"_")[1]), false),:][!, "route_short_name"][1]
    println("It is stop '$stop_name' on the route '$route_name ($route_number) [$route_id]'.")
end




function nearest_1_node_allowed_list(nodes::Dict{Int,T}, loc::T, node_list::Array{Int64,1}, max_dist::Float64) where T<:(Union{OpenStreetMapX.ENU,OpenStreetMapX.ECEF})
	"""
	Find the nearest one node to a given location `loc`.
	"""
    ind_dist = OrderedDict{Int64, Float64}()

    for ind in node_list
        dist = OpenStreetMapX.distance(nodes[ind], loc)
        if dist <= max_dist
            ind_dist[ind] = dist
        end
    end
    
    dict_sorted_by_distance = sort(ind_dist; byvalue=true)
    keys_sorted_dict_by_distance = collect(keys(dict_sorted_by_distance))
    
    selected_ind = Dict{Int64,Float64}()
    
	@assert length(dict_sorted_by_distance) > 0 "There is no even one point!"
    selected_ind[keys_sorted_dict_by_distance[1]] = dict_sorted_by_distance[keys_sorted_dict_by_distance[1]]
  
    
    return selected_ind
end



function nearest_n_nodes_allowed_list(nodes::Dict{Int,T}, loc::T, node_list::Array{Int64,1}, n_nearest::Int64, max_dist::Float64) where T<:(Union{OpenStreetMapX.ENU,OpenStreetMapX.ECEF})
    """
	Find the nearest N nodes to a given location `loc`
	"""
	ind_dist = OrderedDict{Int64, Float64}()

    for ind in node_list
        dist = OpenStreetMapX.distance(nodes[ind], loc)
        if dist <= max_dist
            ind_dist[ind] = dist
        end
    end
    
    keys_sorted_dict_by_distance = collect(keys(sort(ind_dist; byvalue=true)))
    selected_ind = Int64[]
    @assert length(keys_sorted_dict_by_distance) > 0 "There is no even one point!"
	k = 0
	while k < n_nearest
	   push!(selected_ind,keys_sorted_dict_by_distance[k+1]) 
	   k += 1
	end
 
    
    return selected_ind
end



function nodes_within_range_with_allowed_list(nodes::Dict{Int,T}, loc::T, node_list::Array{Int64,1}, range::Float64 = 100.0) where T<:(Union{OpenStreetMapX.ENU,OpenStreetMapX.ECEF})
    """
	Find nodes within some range to a given location. Only nodes in the `node_list` will be checked.
	"""
	if range == Inf
        return node_list
    end
    indices = Int[]
    for ind in node_list
        dist = OpenStreetMapX.distance(nodes[ind], loc)
        if dist < range
            push!(indices, ind)
        end
    end
    return indices
end

## Examples ##
# nodes_within_range_with_allowed_list(m.nodes, m.nodes[394502528], m.n,  10.0)
# nearest_n_nodes_allowed_list(m.nodes, m.nodes[394502528], [i for i in m.n if i ∉ collect(keys(node_id_stop_id_dict))], 1, Inf )
# nearest_1_node_allowed_list(m.nodes, m.nodes[394502528], [i for i in m.n if i ∉ collect(keys(node_id_stop_id_dict))], Inf )

function add_edges_and_weights_to_map!(;m::MapData
        , TTC_graph::SimpleWeightedDiGraph{Int64,Float64}
        , stop_id_to_node_id_dict::Dict{Int64,Int32}
        , node_id_stop_id_dict::Dict{Int32,Int64}
        , wait_time::Int64
        , orig_map_nodes_num::Int64
		, agents_speed_in_sec_per_m::Float64)
    """
    Description:
        Adds information from the TTC graph to the main city graph (e.g. central_toronto).
		Edges are connections between stops.
		Weights are numbers of seconds between two stops.
		
		NOTE! Assumption: Healthy human walks at a pace of 100m in 80 sec.
		NOTE! Assumption: Each TTC node must be connected at least with one city node.In general each TTC node is connected with all city nodes within 100m range.
		NOTE! Assumption: Each agent assume that expected waiting time is half of TTC frequency. For example, if for a TTC car A it takes 10m to get from stop X to stop Y an agent will assume that he/she will wait for 5m at stop Y.
    Returns:
        It modifies the map m.
    """
	
    edges = adjacency_matrix(TTC_graph)
    
    matrix_rows = [i[1] for i in findall(!iszero, m.w)];
    matrix_cols = [i[2] for i in findall(!iszero, m.w)];
    matrix_weights = [i * agents_speed_in_sec_per_m for i in m.w.nzval]; # The average, healthy human walks at a pace of 100m in 80 sec. Here we assume 100m=80s, so 1m = 0.8s.
    
    n_added = 0
    
    for edge in findall(!iszero, edges) # only non-zero edges
        egde_node_a = stop_id_to_node_id_dict[edge[1]]
        edge_node_b = stop_id_to_node_id_dict[edge[2]]
         
        # NOTE! edges contain also reversed nodes ==> e.g. (a --> b) and (b --> a) with the same weights.
        # That us why we do push only once. Our TTC_graph already contains reversed connections.
        
        # add new edges to m.e
        push!(m.e, (egde_node_a, edge_node_b)) # m.e is an object without any weights
        
        # add new edges to m.w
        push!(matrix_rows, m.v[egde_node_a])
        push!(matrix_cols, m.v[edge_node_b])
        
        # add new weights to m.w 
        push!(matrix_weights, edges[(edge[1],edge[2])])
        
        # add edges to m.g
        add_edge!(m.g, (m.v[egde_node_a],m.v[edge_node_b]))
        
        # add classes to m.class
        push!(m.class, 6)
        
        n_added += 1
    end
    
    # Integrating TTC and map
    # In purpose to integrate TTC map and OpenStreetMap we decided to connect TTC nodes with all not TTC nodes, which
    # are in 100m range. If there is no nodes in 100m, we then connect TTC node to the nearest city node.
    
    for ttc_node in  collect(keys(node_id_stop_id_dict))
        # [i for i in m.n if i > 0] --> it helps us to select only non-TTC node keys.
        ttc_neigbours_nodes = nodes_within_range_with_allowed_list(m.nodes, m.nodes[ttc_node], [i for i in m.n if i ∉ collect(keys(node_id_stop_id_dict))],  100.0)
        time_from_ttc = agents_speed_in_sec_per_m * 100 #80 sec to go 100m.
        if length(ttc_neigbours_nodes) == 0
            # if there is no nodes in a range of 100m, then we connect TTC node to the nearest one city node (both directions!).
            node_dist = nearest_1_node_allowed_list(m.nodes, m.nodes[ttc_node], [i for i in m.n if i ∉ collect(keys(node_id_stop_id_dict))], Inf) 
            ttc_neigbours_nodes = collect(keys(node_dist))[1]
            time_from_ttc = collect(values(node_dist))[1] * agents_speed_in_sec_per_m
        end
        for neigbour_node in ttc_neigbours_nodes
            # NOTE! Here we need to make connections for both sides ==> (a --> b) and (b --> a). That us why we push two times.
            
            # add new edges to m.e
            push!(m.e, (ttc_node, neigbour_node))
            push!(m.e, (neigbour_node, ttc_node))
            
            
            # add new edges to m.w
            push!(matrix_rows, m.v[ttc_node])
            push!(matrix_cols, m.v[neigbour_node])
            
            push!(matrix_rows, m.v[neigbour_node])
            push!(matrix_cols, m.v[ttc_node])
            
            # add new weights to m.w 
            push!(matrix_weights, time_from_ttc)
            push!(matrix_weights, (time_from_ttc + wait_time)) # To every arrow from city to TTC we need to add WAIT_TIME as time of waiting for TTC.
            
            # add edges to m.g
            add_edge!(m.g, (m.v[ttc_node], m.v[neigbour_node]))
            add_edge!(m.g, (m.v[neigbour_node], m.v[ttc_node]))

            # add classes to m.class
            push!(m.class, 6)
            push!(m.class, 6)
            
            n_added += 2

        end
    end
    
    # New weights structure for the map
    m.w = SparseArrays.sparse(matrix_rows, matrix_cols, matrix_weights, m.v.count, m.v.count)
    
    # check_correctness_of_map_udpate
	@assert adjacency_matrix(m.g)[1+orig_map_nodes_num,2+orig_map_nodes_num] > 0.0 "SOMETHING WENT WRONG 1+orig_map_nodes_num-->2+orig_map_nodes_num should have a non-zero weight!"
	@assert adjacency_matrix(m.g)[2+orig_map_nodes_num,1+orig_map_nodes_num] == 0.0 "SOMETHING WENT WRONG 2+orig_map_nodes_num-->1+orig_map_nodes_num should have zero weight!"
	@assert adjacency_matrix(m.g)[616+orig_map_nodes_num,615+orig_map_nodes_num] > 0.0 "SOMETHING WENT WRONG 616+orig_map_nodes_num-->615+orig_map_nodes_num should have a non-zero weight!"
    @assert adjacency_matrix(m.g)[615+orig_map_nodes_num,616+orig_map_nodes_num] == 0.0 "SOMETHING WENT WRONG 615+orig_map_nodes_num-->616+orig_map_nodes_num should have zero weight!"

	println("Expected TTC car waiting time: ", wait_time, " sec")
	println("Assumed agent`s speend in seconds per m: ", agents_speed_in_sec_per_m, "sec/meter")
    println("TTC info was added to the map.Total of $n_added edges and weights added to the map")
end


function adding_TTC_points_to_map!(routes_dict::OrderedDict{Symbol, OrderedDict{Int,Tuple{Float64,Float64}}}, m::MapData)
	"""
	Description:
		Adds TTC stops as vertices to the map graph (e.g. central_toronto.osm). 
		It also keeps the information about added points in the dictionaries.
	Returns:
		1) Modifies the map
		2) node_id --> stop_id and stop_id --> node_id dictionaries
	"""
    node_id_stop_id_dict = Dict{Int32, Int64}()
    for route in collect(values(routes_dict))
        for (stop_id, stop_LLA) in sort(route)
           new_point_dict = add_point_to_map!(m, stop_LLA, stop_id, false) 
           push!(node_id_stop_id_dict, new_point_dict)
        end 
    end
    # reversing the dict so we map previous node keys to map node keys
    stop_id_to_node_id_dict= Dict(value => key for (key, value) in node_id_stop_id_dict);
    println("TTC POINTS WERE ADDED TO THE MAP")
    return node_id_stop_id_dict, stop_id_to_node_id_dict
end


function create_routes_dicts(routes_dict, secs_between_stops, orig_map_nodes_num)
	"""
	Description:
		Stops on every route which was added to the main map (e.g. central_toronto.osm) and seconds it takes to travel between two stops on the route.
		orig_map_nodes - number of nodes in the original graph (e.g. central_toronto.osm).
		NOTE! TTC nodes are added directly after original nodes, so that is why we need (stop_id + orig_map_nodes_num).
	Returns:
		Two dictionaries, where one shows all stops on each route and another one shows the time it takes to get from one stop to another on each route.
	"""
    # All points on a road
    routes_path = OrderedDict{Symbol, OrderedDict{Int64,Int64}}()
    routes_distances = OrderedDict{Symbol, OrderedDict{Int64,Float64}}()
    for route in keys(routes_dict)
        stops_sel = OrderedDict{Int64,Int64}()
        distances  = OrderedDict{Int64,Float64}()
        for stop in 1:size(collect(keys(routes_dict[route])))[1]-1
            stop_a = collect(keys(routes_dict[route]))[stop]
            stop_b = collect(keys(routes_dict[route]))[stop+1]
            stops_sel[stop_a+orig_map_nodes_num] = stop_b+orig_map_nodes_num
            distances[stop_a+orig_map_nodes_num] = secs_between_stops[(stop_a,stop_b)]
        end
        routes_path[route] = stops_sel
        routes_distances[route] = distances
    end
    return routes_path, routes_distances
end

println("Complete map with TTC functions were read.")