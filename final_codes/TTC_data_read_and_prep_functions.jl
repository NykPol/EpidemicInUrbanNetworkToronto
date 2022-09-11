  
function read_data(data_folder::String = "./data_input/")
	"""
	Read data from https://open.toronto.ca/dataset/ttc-routes-and-schedules/.
	Based on these files TTC routes and graph will be created.
	"""
    trips =  DataFrame(CSV.File(data_folder * "trips.txt"));
    routes = DataFrame(CSV.File(data_folder * "routes.txt"));
    stop_times = DataFrame(CSV.File(data_folder * "stop_times.txt"));
    shapes = DataFrame(CSV.File(data_folder * "shapes.txt"));
    stops = DataFrame(CSV.File(data_folder * "stops.txt"));
    return trips, routes, stop_times, shapes, stops
end


function get_longest_trip_data(stop_times::DataFrame, trips_filtered::DataFrame, stops::DataFrame)
    """
    Description:
        It takes the data and then find the longest trip per each route and leave only this trip in the dataset.
    Returns:
        Dataframe, where each route is associated with the longest trip only.
    """
    # Find stops for each trip
    routes_stops = innerjoin(stop_times, trips_filtered, on=:trip_id)[:,[:route_id,:trip_id,:stop_id,:stop_sequence,:arrival_time,:departure_time]]
    # Find the longest trip for each route
    routes_max_trip = combine(find_max_index -> find_max_index[argmax(find_max_index[!,"stop_sequence"]), [:trip_id]], groupby(routes_stops, :route_id))
    # Leave only those trips, which are the longest one.
    routes_stops_longest = innerjoin(routes_stops, routes_max_trip, on=:trip_id, makeunique=true)
    # Join stop LLA info
    route_stops_geo = innerjoin(routes_stops_longest, stops, on = :stop_id)[:,[:route_id,:stop_id,:stop_sequence,:stop_lat,:stop_lon,:arrival_time,:departure_time]]

    # Direction A->B
    route_stops_geo_dir_A = deepcopy(route_stops_geo)
    route_stops_geo_dir_A[!,"route_id"] = Symbol.(string.(route_stops_geo_dir_A[!, "route_id"])  .* "_a")
    
    # Direction B->A
    route_stops_geo_dir_B = deepcopy(route_stops_geo)
    new_stop_sequence = Int64[]
    for r in unique(route_stops_geo_dir_B[!,"route_id"])
        stops_reversed = sort(route_stops_geo_dir_B[route_stops_geo_dir_B.route_id .== r, :stop_sequence],rev=true)
        for i in stops_reversed
           push!(new_stop_sequence,i) 
        end
    end
    route_stops_geo_dir_B[!,"stop_sequence"] = new_stop_sequence
    route_stops_geo_dir_B[!,"route_id"] = Symbol.(string.(route_stops_geo_dir_B[!, "route_id"]) .* "_b")
    
    # UNION
    both_direction_routes = vcat(route_stops_geo_dir_A,route_stops_geo_dir_B)
    
    # Global id for each stop, to ensure that even two identical points will have different ids.
    both_direction_routes[!,"my_stop_id"] = [i for i in 1:nrow(both_direction_routes)]
    
    return both_direction_routes
end



function get_routes_dict(data::DataFrame)
    """
    Description:
        Creates structure to represent route as a dictionary of stops, which are located on the map.
    Returns:
        1) Dict(route_id => Dict(stop_id => (lat,lon), stop_id => (lat,lon), ...))
        2) Number_of_stops::Int64
    """
    # Initialize final dictionary
    routes_d = OrderedDict{Symbol, OrderedDict{Int,Tuple{Float64,Float64}}}()
    # For each shape we find stops in sequence and give each stop unique id.
    # Once we have all stops gathered we can assign them to a particular route.
    for r in unique(data[!,"route_id"])
        stops_selected = sort(data[data.route_id .== r, :], :stop_sequence)
        route_points = OrderedDict{Int,Tuple{Float64,Float64}}()
        for srow in eachrow(stops_selected)
            geo_stop_point = (srow.stop_lat, srow.stop_lon)
            route_points[srow.my_stop_id] = geo_stop_point 
        end
        routes_d[r] = route_points
    end

    routes_d, maximum(data[!,"my_stop_id"])
end



function convert_my_date(str_time::String)
    """
    Description:
        Takes string time like 22:55:33 and calculate number of seconds from a day start.
        This function is used instead of date - date, because there are times like 26:58:03 in the dataset.
    Returns:
        Number of seconds from a day start.
    """
    hours = parse(Int64,split(str_time,":")[1])
    minutes = parse(Int64,split(str_time,":")[2])
    seconds = parse(Int64,split(str_time,":")[3])
    sum_sec = hours*60*60 + minutes*60 + seconds
    return sum_sec
end

function trips_time(data::DataFrame)
    """
    Description:
        Takes arrival time and departure time for stops in the data and calculate number of seconds between two stops on the route.
    Returns:
        Dictionary, where keys are (stop_origin, stop_destination) and values are seconds between stops.
    """
    mydata = deepcopy(data)
    mydata[!, "arrival_time"] = map(x -> convert_my_date(x),mydata[!,"arrival_time"])
    mydata[!, "departure_time"] = map(x -> convert_my_date(x),mydata[!,"departure_time"])
    stops_time = Dict{Tuple{Int,Int},Int64}()
    unq_routes = unique(mydata[!,"route_id"])
    for route in unq_routes
       per_route = mydata[mydata[!,"route_id"].==route,:]
       for i in 2:nrow(per_route)
            stop_a, dep_a = per_route[i-1,:my_stop_id], per_route[i-1,:departure_time]
            stop_b, arr_b = per_route[i,:my_stop_id], per_route[i,:arrival_time]
            stops_time[(stop_a,stop_b)] = (arr_b - dep_a)
            stops_time[(stop_b,stop_a)] = (arr_b - dep_a)
       end
    end
    return stops_time
end



function assign_route_type_to_route(routes_dict::OrderedDict{Symbol, OrderedDict{Int,Tuple{Float64,Float64}}}, routes_filtered::DataFrame)
	"""
	Description:
		Assigns route type for each node on the route.
	Returns:
		Route type of each node.
	"""
    route_types = Dict{Int,Int}()
    for route in keys(routes_dict)
        
        if length(routes_filtered[routes_filtered[!,"route_id"] .== parse(Int64,split(string(route),"_")[1]),:][!,"route_type"]) > 1
            println("More than 1 route type")
            break
        end
        
        temp = Dict(zip(keys(routes_dict[route]),
                repeat(routes_filtered[routes_filtered[!,"route_id"] .== parse(Int64,split(string(route),"_")[1]),:][!,"route_type"],
                    length(keys(routes_dict[route])))))
        merge!(route_types, temp)
    end # each node has a type of route attached to it - may be useful in simulations
    return route_types
end


function routes_types_both_dir_func(routes_filtered::DataFrame)
	route_both_dir_type = Dict{Symbol,Symbol}()
	for i in eachrow(routes_filtered)
		for dire in ["a","b"]
			dir_key = string(i.route_id,"_",dire)
			route_both_dir_type[Symbol(dir_key)] = i.route_type == 1 ? :subway : :streetcar
		end
	end
	return route_both_dir_type
end	



function read_and_prep_TTC_data(;data_folder::String = "./data_input/")
	"""
	Description:
		Gather all functions which should be used to prepare TTC data into a single function.
	Returns:
		TTC graph, number of seconds between stops, Dictionary with each route types and associated stops, and the DataFrame with filtered routes to be used in TTC routes visualization.
	"""
    trips, routes, stop_times, shapes, stops = read_data(data_folder);
    route_ids_without_buses = routes[coalesce.(routes.route_type .!= 3, false), :][!,"route_id"];
    routes_filtered = routes[in.(routes[!,"route_id"], [route_ids_without_buses]), :];
    trips_filtered = trips[in.(trips[!,"route_id"], [route_ids_without_buses]), :];
    trip_longest_df = get_longest_trip_data(stop_times, trips_filtered, stops);
    routes_dict, n_stops = get_routes_dict(trip_longest_df);
    secs_between_stops = trips_time(trip_longest_df);
    route_types = assign_route_type_to_route(routes_dict, routes_filtered);
	routes_types_both_dir = routes_types_both_dir_func(routes_filtered);
    gg = create_graph_from_TTC(routes_dict,n_stops,secs_between_stops); 
    println("TTC data was read")
    return gg,secs_between_stops,routes_dict,route_types,routes_filtered,routes_types_both_dir
end
println("Read and prep TTC functions were read")