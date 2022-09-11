# Auxiliary functions for location processing
function get_ENU(node::Int, model::Simulation)
	"Get ENU coordinates of a specific node in the Simulation"
    model.m.nodes[m.n[node]]
end

function get_coordinates(agent::Commuter, model::Simulation)
	"Get XY coordinates of a specific node in the Simulation"
    pos = get_ENU(agent.pos, model)
    (getX(pos),
     getY(pos))
end

# Auxiliary functions for colors
agentcolor(agent) = agent.infected ? :red : :black
agentsize(agent) = agent.infected ? 6 : 5

# Plot simulation state
function plot_simstate(model::Simulation, background=Plots.current())
	"""
	Description:
		Plots simulation state on specific moment in time (after run).
	Example:
		plotmap(s.m, width=500, height=500)
		plot_simstate(s)
	"""
	# Plots black/red(if infected) agents routes
    for agent in model.agents
        path = [agent.pos]
        while path[end] in keys(agent.path)
            push!(path, agent.path[path[end]])
        end
        length(path) < 2 && continue 
        a_x, a_y = get_coordinates(agent, model)
        enu_coords = get_ENU.(path[2:end], Ref(model))
        

        a_x2, a_y2 = (getX(enu_coords[1]), getY(enu_coords[1]))
        
        !(a_x == a_x2 && a_y == a_y2) &&  plot!(
                background, [a_x, a_x2], [a_y, a_y2], 
                color=agentcolor(agent), arrow =arrow(:open)) 

        length(enu_coords) > 2 &&  plot!(
                background, getX.(enu_coords),  getY.(enu_coords),
                color=agentcolor(agent), arrow =arrow(:closed))
    end
    
	# Plots black wagons routes
    for wagon in model.wagons
        path = [wagon.pos]
        while path[end] in keys(wagon.path)
            push!(path, wagon.path[path[end]])
        end
        length(path) < 2 && continue 
        a_x, a_y = get_coordinates(wagon, model)
        enu_coords = get_ENU.(path[2:end], Ref(model))


        a_x2, a_y2 = (getX(enu_coords[1]), getY(enu_coords[1]))
        
        !(a_x == a_x2 && a_y == a_y2) &&  plot!(
                background, [a_x, a_x2], [a_y, a_y2], 
                color=:black, arrow =arrow(:open), linewidth = 3) 

        length(enu_coords) > 2 &&  plot!(
                background, getX.(enu_coords),  getY.(enu_coords),
                color=:black, arrow =arrow(:closed), linewidth = 3) 
    end
    
	# Define simulation objects appearance
    colors = vcat([agentcolor(agent) for agent in s.agents], [:yellow for wagon in s.wagons])
    sizes = vcat([agentsize(agent) for agent in model.agents], [10 for wagon in model.wagons])
    markers = vcat([:circle for i in 1:length(model.agents)], [:square for i in 1:length(model.wagons)])
    pos_agents = [get_coordinates(agent, model) for agent in model.agents]
    pos_wagons = [get_coordinates(wagon, model) for wagon in model.wagons]
    pos = vcat(pos_agents, pos_wagons)
    
	# Plot scatter
    scatter!(background,
        pos;
        markercolor = colors,
        markersize = sizes,
        markershapes = markers,
        label = "",
        markerstrokewidth = 0.5,
        markerstrokecolor = :black,
        markeralpha = 0.9
    )
    
    # Annotate how many agents are inside a TTC car.
    pos_wagons_x = [w[1] for w in pos_wagons]
    pos_wagons_y = [w[2] for w in pos_wagons]
    annot_text = [text(string(length(wagon.passengers)),8,:black) for wagon in model.wagons]
    annotate!(background, pos_wagons_x, pos_wagons_y, annot_text)
    
end
