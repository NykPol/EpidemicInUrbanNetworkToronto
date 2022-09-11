#####################
function read_results(
    results_path::String;
    control_vars::Array = [],
    control_val_equal::Array = [],
    vars_to_check::Array = [])

    """
	Description:
		read results from path & save to dict. returns dict and filtered list of parametrizations.
	"""

# reading files
    params_sets = CSV.read("$results_path/sim_params_comb_df.csv", DataFrame)

    if length(control_vars) > 0
        # filtering params:
        for (cond, val) in zip(control_vars, control_val_equal)
            params_sets = params_sets[params_sets[:,cond] .== val, :]
        end
        if length(vars_to_check) > 0
                @assert size(unique(params_sets[!, Symbol.(vars_to_check)]))[1] == size(params_sets)[1] "Incorrect filtering conditions specified. Multiple or none scenarios found."
        end
    end

    full_output = Dict()
    file_list = glob("simul_res_parset_id_*.json", results_path)
    for id in params_sets[:,:parset_id]
        if string(results_path,"/simul_res_parset_id_",id,".json") ∈ file_list
            full_output[id] = JSON.parsefile(string(results_path,"/simul_res_parset_id_",id,".json"))
            params = filter(r -> in(r.parset_id, [id]), params_sets)
            for col in names(params)
                full_output[id][col] = params[1,col]
            end
        else
            filter!(r -> !in(r.parset_id, [id]), params_sets)
        end
    end
    return full_output, params_sets
end



function develplot_by_var(response_var::String, variable::String, results::Dict;
    total_indic::Union{String, Nothing} = nothing,
    div::Union{Float64, Int} = 1,
    var_unit::String = "",
    max_it::Union{Int, Nothing} = nothing,
    min_it::Int = 1,
    x_lab::String = "iteration",
    y_lab::Union{String, Nothing} = nothing,
    title::Union{String, Nothing} = nothing,
    with_std::Bool = false,
    out_name::String="develplot",
    with_export::Bool = true)

    """
	Description:
		Plots line series with or without std
	"""
    full_output = deepcopy(results)
    #pyplot()
    #gathering a df
    df = DataFrame()
    stds = DataFrame()
    var_vals = []
    for (key, value) in full_output
        symb = value[variable]/div
        if !isnothing(total_indic) && length(value[total_indic])>1
            value[total_indic] = value[total_indic][1]
            if total_indic == "prct_of_agents_used_TTC"
                value[total_indic] = value[total_indic]/value["N_agents"]
            end
        end
        push!(var_vals, symb)
        if response_var in ["total_infected", "TTC_infected", "street_infected"]
            df[:,Symbol(symb)] = value[response_var][1]./(isnothing(total_indic) ? 1 : 0.01*value[total_indic])
            stds[:,Symbol(symb)] = value[response_var][2]./(isnothing(total_indic) ? 1 : value[total_indic])
            println(symb, ": ", value[total_indic])
        else
            df[:,Symbol(symb)] = value[response_var]./(isnothing(total_indic) ? 1 : value[total_indic])
        end  
    end

    var_vals = sort(collect(var_vals))

    pushfirst!(var_vals, rand())
    cs1 = ColorScheme(range(colorant"orange", colorant"purple", length = length(var_vals)))
    cs1 = Dict(zip(var_vals, cs1))
    var_vals = var_vals[2:end]
    max_it =  isnothing(max_it) ? size(df)[1] : max_it

    y_lab =  isnothing(y_lab) ? response_var : y_lab
    title =  isnothing(title) ? "$response_var with respect to $variable" : title

    gr(size = (800, 550))
    my_plot = Plots.plot()
    for i in var_vals
        rounding = Int(round(i, digits = 0))
        plot!(df[min_it:max_it, Symbol(i)], linewidth = 2.5, 
        #legend = false, 
        grid = false,
        legend = :topleft, lab = "$rounding $var_unit", 
            linecolor = cs1[i]#, annotations = ([max_it + 240], [df[max_it, Symbol(i)]],
                    #Plots.text("$rounding", "Courier", :purple, 8))
                    )
        if with_std == true
            plot!((df[min_it:max_it, Symbol(i)] + stds[min_it:max_it, Symbol(i)]), linewidth = 2.5, 
            legend = false,  linestyle = :dot, linecolor = cs1[i])
                
            plot!((df[min_it:max_it, Symbol(i)] - stds[min_it:max_it, Symbol(i)]), linewidth = 2.5,
            legend = false,  linestyle = :dot, linecolor = cs1[i])
        end
    end
    xlabel!(x_lab)
    ylabel!(y_lab)
    #title!(title)
    if with_export == true
        #n = now()
        Plots.savefig(my_plot,"./viz/$out_name.pdf")
    end
    #my_plot
end

#####################
function point_in_time_by_var(response_vars::Array, variable::String, results::Dict; 
    points_in_time::Array{} = [],
    total_indic::Union{String, Nothing} = nothing,
    div::Union{Float64, Int} = 1,
    time_div::Union{Float64, Int} = 1,
    time_unit::String = "",
    x_lab::Union{String, Nothing} = nothing,
    y_lab::Union{String, Nothing} = nothing,
    title::Union{String, Nothing} = nothing,
    out_name::String = "point_in_time",
    with_export::Bool = true)

    """
	Description:
		Line plots for a numerical parameter shot at a given point(or points) of time
	"""
    @assert min(length(response_vars),length(points_in_time)) ==  1 "Only one array longer than 1 allowed"

    pyplot()

    full_output = deepcopy(results)

    #gathering a df
    df = Dict()
    for (key, value) in full_output
        symb = value[variable]/div
        if !isnothing(total_indic) && length(value[total_indic])>1
            value[total_indic] = value[total_indic][1]
            if total_indic == "prct_of_agents_used_TTC"
                value[total_indic] = value[total_indic]*value["N_agents"]/100
            end
        end
        for response_var in response_vars
            if response_var ∉ keys(df)
                df[response_var] = DataFrame()
            end
            if response_var in ["total_infected", "TTC_infected", "street_infected"]
                df[response_var][:,Symbol(symb)] = value[response_var][1]./(isnothing(total_indic) ? 1 : 0.01 * value[total_indic])
            else
                df[response_var][:,Symbol(symb)] = value[response_var]./(isnothing(total_indic) ? 1 : value[total_indic])
            end  
        end
    end

    points_in_time = length(points_in_time) > 0 ? points_in_time : [size(df[response_vars][1])[1]]
    points_in_time = sort(points_in_time)
    points_in_time = trunc.(Int, points_in_time)

    results = Dict()
    for response_var in response_vars
        results[response_var] = df[response_var][points_in_time, :]
        results[response_var] = DataFrame([[names(results[response_var])]; collect.(eachrow(results[response_var]))], [Symbol(variable); Symbol.("ITER_", points_in_time)])
        results[response_var][!,variable] = parse.(Float64, results[response_var][!,variable])
        sort!(results[response_var], Symbol(variable))
    end

    first_var = response_vars[1]
    x_lab =  isnothing(x_lab) ? variable : x_lab
    y_lab =  isnothing(y_lab) ? "infected" : y_lab
    #title =  isnothing(title) ? "$first_var with respect to $variable" : title

    if length(points_in_time) >= length(response_vars)
        pushfirst!(points_in_time, -1)
        cs1 = ColorScheme(range(colorant"orange", colorant"purple", length = length(points_in_time)))
        cs1 = Dict(zip(points_in_time, cs1))
        points_in_time = points_in_time[2:end]
    else
        pushfirst!(response_vars, "aaa")
        cs1 = ColorScheme(range(colorant"orange", colorant"purple", length = length(response_vars)))
        cs1 = Dict(zip(response_vars, cs1))
        response_vars = response_vars[2:end]
    end

    #gr(size = (800, 600))
    my_plot = Plots.plot()

    labels = Dict("total_infected"=>"% infected", "TTC_infected" => "infected in TTC", "street_infected" => "infected outside")

    for var in response_vars
        for i in points_in_time
            key_name = length(points_in_time) >= length(response_vars) ? i : var
            rounding = trunc(Int, i/time_div)
            lab = length(points_in_time) >= length(response_vars) ? "$rounding $time_unit" : labels[var]
            plot!(results[var][:, Symbol(variable)], results[var][!, Symbol("ITER_", i)], linewidth = 2.5, 
            legend = :topleft, lab = lab, 
            #legend = false,
            grid=false,
            linecolor = cs1[key_name])
        end
    end

    xlabel!(x_lab)
    ylabel!(y_lab)
    #title!(title)
    if with_export == true
        #n = now()
        Plots.savefig(my_plot,"./viz/$out_name.pdf")
    end
    #my_plot
end


function make_heatmap(response_var::String, variable1::String,
    variable2::String, results::Dict, params_sets::DataFrame;
    total_indic::Union{String, Nothing} = nothing,
    div1::Union{Float64, Int} = 1,
    div2::Union{Float64, Int} = 1,
    out_name::String="heatmap",
    with_export::Bool = true)

    """
	Description:
		Plots a heatmap
	"""
    full_output = deepcopy(results)

    #gathering a matrix
    var1 = []
    var2 = []
    resp_var = Array{Union{Float64, Int, Missing}}(missing,
    length(unique(params_sets[!, Symbol(variable1)])), length(unique(params_sets[!, Symbol(variable2)])))

    for (key, value) in full_output
        if (length(findall(x -> x == value[variable1]/div1, var1 )) == 0)
            push!(var1, value[variable1]/div1)
        end
        if (length(findall(x -> x == value[variable2]/div2, var2)) == 0)
            push!(var2, value[variable2]/div2)
        end
    end
    sort!(var1)
    sort!(var2)

    for (key, value) in full_output
        
        row_pos = findall(x -> x == value[variable1]/div1, var1)[1]
        col_pos = findall(x -> x == value[variable2]/div2, var2)[1]

        val = value[response_var][1]/(isnothing(total_indic) ? 1 : value[total_indic])
        resp_var[row_pos, col_pos] = val
    end

    #backend(:plotly)
    #plotly_js()
    my_plot = Plots.heatmap(var2,var1,resp_var)
    xlabel!(variable2)
    ylabel!(variable1)
    #title!(response_var)

    if with_export == true
        Plots.savefig(my_plot,"./viz/$out_name.pdf")
    end
end


function plot_XY(variable1::String, variable2::String, results::Dict; 
    point_in_time::Union{Float64, Int, Nothing} = nothing,
    total_indic::Union{String, Nothing} = nothing,
    x_lab::Union{String, Nothing} = nothing,
    y_lab::Union{String, Nothing} = nothing,
    title::Union{String, Nothing} = nothing,
    out_name::String = "XY",
    with_export::Bool = true)

    full_output = deepcopy(results)

    #pyplot()

    #gathering a df
    df = DataFrame([variable1, variable2] .=> 1.1)
    delete!(df, 1)
    for (key, value) in full_output
        val = deepcopy(value)
        for var in [variable1, variable2]
            if length(val[var]) > 1
                val[var] = val[var][1]
            end
            if var in ["total_infected", "TTC_infected", "street_infected"]
                val[var] = isnothing(point_in_time) ? val[var][end] : val[var][Int(round(point_in_time))]
                val[var] = val[var]/(isnothing(total_indic) ? 1 : 0.01 * value[total_indic])
            end
            if var == "prct_of_agents_used_TTC"
                val[var] = val[var]/100
            end
        end
        push!(df, Dict(variable1 => val[variable1], variable2 => val[variable2]))
    end
    sort!(df, variable1)

    #gr(size = (800, 600))
    x_lab =  isnothing(x_lab) ? variable1 : x_lab
    y_lab =  isnothing(y_lab) ? variable2 : y_lab
    title =  isnothing(title) ? "$variable2 with respect to $variable2" : title

    my_plot = Plots.plot(df[!, variable1], df[!, variable2], linewidth = 2.5, legend = false,
    linecolor="purple", grid = false)
    xlabel!(x_lab)
    ylabel!(y_lab)
    #title!(title)

    if with_export == true
        Plots.savefig(my_plot,"./viz/$out_name.pdf")
    end
    #my_plot
end


function plot_XYY(variable1::String, variable2::String, x_var::String,  results::Dict; 
    point_in_time::Union{Float64, Int, Nothing} = nothing,
    divx::Union{Float64, Int} = 1,
    total_indic::Union{String, Nothing} = nothing,
    x_lab::Union{String, Nothing} = nothing,
    y1_lab::Union{String, Nothing} = nothing,
    y2_lab::Union{String, Nothing} = nothing,
    title::Union{String, Nothing} = nothing,
    out_name::String = "XYY",
    with_export::Bool = true)

    #pyplot()

    full_output = deepcopy(results)
    #gathering a df
    df = DataFrame([variable1, variable2, x_var] .=> 1.1)
    delete!(df, 1)
    for (key, value) in full_output
        val = deepcopy(value)
        val[x_var] = val[x_var]/divx
        for var in [variable1, variable2]
            if length(val[var]) > 1
                val[var] = val[var][1]
            end
            if var in ["total_infected", "TTC_infected", "street_infected"]
                val[var] = isnothing(point_in_time) ? val[var][end] : val[var][Int(round(point_in_time))]
                val[var] = val[var]/(isnothing(total_indic) ? 1 : 0.01*value[total_indic])
            end
            if var == "prct_of_agents_used_TTC"
                val[var] = val[var]#/100
            end
        end
        push!(df, Dict(variable1 => val[variable1], variable2 => val[variable2], x_var => val[x_var]))
    end
    sort!(df, x_var)

    #gr(size = (800, 600))
    x_lab =  isnothing(x_lab) ? x_var : x_lab
    y1_lab =  isnothing(y1_lab) ? variable1 : y1_lab
    y2_lab =  isnothing(y2_lab) ? variable2 : y2_lab
    title =  isnothing(title) ? "$variable1 & $variable2 with respect to $x_var" : title


    my_plot = Plots.plot(df[!, x_var], df[!, variable1], linewidth = 2.5, linecolor="purple",
    label=y1_lab,legend=:bottomleft, xlabel=x_lab, grid=true)
    plot!(twinx(), df[!, x_var], df[!, variable2], xticks=:none, linecolor="black", grid=true, linewidth = 2.5, label=y2_lab, legend=:topright)

    #title!(title)

    if with_export == true
        Plots.savefig(my_plot,"./viz/$out_name.pdf")
    end
    #my_plot
end
