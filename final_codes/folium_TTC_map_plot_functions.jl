function get_map_bounds(routes_dict::OrderedDict{String,OrderedDict{Int64,Tuple{Float64,Float64}}})
    """
    Description:
        This function takes routes_dict and returns map_bounds for folium.
    Returns:
        (minimum(LAT),minimum(LOT)),(maximum(LAT),maximum(LOT))
    """
    lats = []
    lots = []

    for route in keys(routes_dict)
        [push!(lats,i[1]) for i in values(routes_dict[route])]
        [push!(lots,i[2]) for i in values(routes_dict[route])]  
    end
    
    return (minimum(lats),minimum(lots)),(maximum(lats),maximum(lots))
end


function plot_folium_map(routes_filtered::DataFrame, routes_dict::OrderedDict{String,OrderedDict{Int64,Tuple{Float64,Float64}}})
	"""
	Description:
		Plots TTC routes on the folium interactive Toronto map.
	Example:
		plot_folium_map(routes_filtered, routes_dict)
	"""
    m = flm.Map()
    for route in keys(routes_dict)
        #Get route info
        route_name = values(routes_filtered[routes_filtered[!, "route_id"] .== parse(Int64,split(route,"_")[1]),:][!, "route_long_name"])[1]
        route_type = values(routes_filtered[routes_filtered[!, "route_id"] .== parse(Int64,split(route,"_")[1]),:][!, "route_type"])[1]
		
        # Mark route type and assign differents colors 
        if route_type == 1
            route_type = "SUBWAY"
            color = "red"
        elseif route_type == 0
            route_type = "STREETCAR"
            color = "green"
        elseif route_type == 3
            route_type = "BUS"
            color = "gray"
        end
        
        # Drawing a route
        flm.PolyLine(        
        [values(sort(routes_dict[route]))],
        popup="Route id: $route Type: $route_type",
        tooltip="Route name: $route_name",
        color=color,
        weight = ifelse(route_type == "SUBWAY", 6, 4),
        opacity = 0.6
    ).add_to(m)
           
    end

	# Reduce vis to the map bounds and draw rectangle as a border.
    MAP_BOUNDS = get_map_bounds(routes_dict)
    flm.Rectangle(MAP_BOUNDS, color="black",weight=6).add_to(m)
    m.fit_bounds(MAP_BOUNDS)
    return m
end

println("Folium plotting functions were read.")