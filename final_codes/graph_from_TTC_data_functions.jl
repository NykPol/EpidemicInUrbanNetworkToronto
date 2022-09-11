function create_graph_from_TTC(routes_dict::OrderedDict{Symbol, OrderedDict{Int,Tuple{Float64,Float64}}}
								, n_stops::Int
								, secs_between_stops::Dict{Tuple{Int,Int},Int64}
								, plot_graph::Bool = false
								, write_to_pdf::Bool = false)
	"""
	Description:
		Takes into account real data regarding TTC routes, connections, and distances between stops and create Simple Weighted Directed Graph based on this information.
		Graph info: Vertices --> stops | Edges --> routes | Weights --> seconds between stops
	Returns:
		SimpleWeightedDiGraph with `n_stops` vertices.
	"""
    # basic graph with original routes
    gg = SimpleWeightedDiGraph(n_stops)
    for route in keys(routes_dict)
        for stop in 1:size(collect(keys(routes_dict[route])))[1]-1
            stop_time = secs_between_stops[(collect(keys(routes_dict[route]))[stop], collect(keys(routes_dict[route]))[stop+1])]
            stop_a = collect(keys(routes_dict[route]))[stop]
            stop_b = collect(keys(routes_dict[route]))[stop+1]
            add_edge!(gg, stop_a, stop_b, stop_time)
        end
    end
	
	# Check if stops on the routes were correctly connected.
	@assert adjacency_matrix(gg)[1,2] > 0.0  "SOMETHING WENT WRONG 1-->2 should have a non-zero weight!" 
    @assert adjacency_matrix(gg)[2,1] == 0.0 "SOMETHING WENT WRONG 2-->1 should have zero weight!"
    @assert adjacency_matrix(gg)[616,615] > 0.0 "SOMETHING WENT WRONG 616-->615 should have a non-zero weight!"
    @assert adjacency_matrix(gg)[615,616] == 0.0 "SOMETHING WENT WRONG 615-->616 should have zero weight!"

	
    ### Adding artificial edges between same location stops ###
	
    # dictionary mapping node => LLA
    node_id_LLA = Dict{Int,Tuple{Float64,Float64}}()
    for route in collect(values(routes_dict))
        for (stop_id, stop_LLA) in route
           push!(node_id_LLA, stop_id => stop_LLA)
        end 
    end

    # identifing same location nodes and assigning transfer times between them
    transfer_time_dict = Dict{Tuple{Int,Int},Int}()
    for (key, value) in node_id_LLA
        obj = [k for k in keys(node_id_LLA) if node_id_LLA[k] == value]
        obj = vec(collect(Iterators.product(obj, obj))) # array
        obj = filter(((xx, yy),)->xx!=yy, obj) # remove same node distances
        obj = Dict(zip(obj,repeat([120], length(obj))))
        merge!(transfer_time_dict, obj)
    end

    # adding fake edges to the graph 
    for (key, value) in transfer_time_dict
        add_edge!(gg, key[1], key[2], value)
    end

    # all of the times in 1 object
    merge!(secs_between_stops, transfer_time_dict);

	# PDF or plot graph if needed
    if write_to_pdf == true
        draw(PDF("stops_subway_streetcars_Toronto_graph.pdf", 16cm, 16cm), gplot(gg))
    else
        if plot_graph == true
            gplot(gg)
        end 
    end
	
    println("Graph from TTC data was made")
    return gg
end
println("Graph from TTC functions were read")