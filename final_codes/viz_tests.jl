using Base: Float64
using Dates: string
println("---> START <---")
# Set up environment
using Pkg
Pkg.activate(".")
using JSON
using Glob
using CSV
using Random
using DataFrames

using Statistics
using StatsBase

using Distributions
using DataStructures
using Parameters

using Plots
using Colors
using ColorSchemes
using Dates
using Plotly

include("post_simulation_plots_functions.jl")

gr()

folder_name = "res7"
outputs_path = "SOME_PATH"
#outputs_path = "SOME_PATH"
vars = ["N_agents", "agents_speed_in_sec_per_m", "p0"] # what has to be constant 
vars_heatmap = ["N_agents", "p0"] # what has to be constant
points_in_time = [[1*24*3600, 2*24*3600, 3*24*3600]]
points_in_time_sing = [0.25*24*3600, 0.5*24*3600, 0.75*24*3600]
orig_map_nodes_num = 770

for i in 1:5
    # SETUP
    folder_name = "res$i"
    outputs_path = "SOME_PATH"
    #outputs_path = "SOME_PATH"
    vars = ["N_agents", "agents_speed_in_sec_per_m", "p0"] # what has to be constant 
    vars_heatmap = ["N_agents", "p0"] # what has to be constant
    points_in_time = [[1*24*3600, 2*24*3600, 3*24*3600]]
    points_in_time_sing = [0.25*24*3600, 0.5*24*3600, 0.75*24*3600]
    orig_map_nodes_num = 770

    # reading possible parameter values
    params_to_plot = CSV.read("$outputs_path/sim_params_comb_df.csv", DataFrame)

    values_to_loop = Dict()
    for var in vars
        values_to_loop[var] = unique(params_to_plot[:,var])
    end

    # NODE EXAMINATION
    full_output, params_sets = read_results(outputs_path,
    control_vars = vars,
    control_val_equal = [2000, 0.8, 0.001],
    vars_to_check = ["TTC_car_freq"]);

    for (key,value) in full_output
        res = value["nodes_agents_maxes"];
        freq_t = Int(round(value["TTC_car_freq"]/60))
        res_df = DataFrame(res);
        cols_no = size(res_df)[2];
        res_df[!, :TTC] .= 0;
        res_df[orig_map_nodes_num+1:end, :TTC] .= 1;
        res_df[!, :node_mean] = map(mean, eachrow(res_df[!, Symbol.(1:cols_no)]));
        res_df[!, :node_std] = map(std, eachrow(res_df[!, Symbol.(1:cols_no)]));
        res_df[!, :node_min] = map(minimum, eachrow(res_df[!, Symbol.(1:cols_no)]));
        res_df[!, :node_max] = map(maximum, eachrow(res_df[!, Symbol.(1:cols_no)]));
        res_df;
        # "raw" data
        CSV.write("viz/$folder_name/node_data_$freq_t.csv", res_df)

        # plots
        Plots.histogram(res_df[res_df.TTC .== 0, :node_mean], title="node mean of agents no. in TTC")
        Plots.savefig("viz/$folder_name/TTC_mean_$freq_t.pdf")
        Plots.histogram(res_df[res_df.TTC .== 1, :node_mean], title="node mean of agents no. in the street")
        Plots.savefig("viz/$folder_name/street_mean_$freq_t.pdf")
        Plots.histogram(res_df[res_df.TTC .== 0, :node_max], title="node max of agents no. in TTC")
        Plots.savefig("viz/$folder_name/TTC_max_$freq_t.pdf")
        Plots.histogram(res_df[res_df.TTC .== 1, :node_max], title="node max of agents no. in the street")
        Plots.savefig("viz/$folder_name/street_max_$freq_t.pdf")
        Plots.histogram(res_df[res_df.TTC .== 0, :node_std], title="node std of agents no. in TTC")
        Plots.savefig("viz/$folder_name/TTC_std_$freq_t.pdf")
        Plots.histogram(res_df[res_df.TTC .== 1, :node_std], title="node std of agents no. in the street")
        Plots.savefig("viz/$folder_name/street_std_$freq_t.pdf")

        # top 10 tables
        tab_ttc = res_df[(res_df.TTC .== 1) .& (res_df.node_mean .> sort(res_df[res_df.TTC .== 1, :node_mean], rev=true)[51]),["node_mean", "node_min", "node_max", "node_std"]]
        tab_street = res_df[(res_df.TTC .== 0) .& (res_df.node_mean .> sort(res_df[res_df.TTC .== 0, :node_mean], rev=true)[51]),["node_mean", "node_min", "node_max", "node_std"]]
        CSV.write("viz/$folder_name/top50_ttc_$freq_t.csv", sort(tab_ttc, :node_mean, rev=true))
        CSV.write("viz/$folder_name/top50_street_$freq_t.csv", sort(tab_street, :node_mean, rev=true))

        ### NON-NODE STUFF
        # 1) infections & max people in TTC
        other_data = DataFrame("total_infected" => value["total_infected"][1][end],
        "TTC_infected" => value["TTC_infected"][1][end],
        "street_infected" => value["street_infected"][1][end],
        "total_infected_std" => value["total_infected"][2][end],
        "TTC_infected_std" => value["TTC_infected"][2][end],
        "street_infected_std" => value["street_infected"][2][end],
        "max_pass_per_wagon_subway_mean" => value["max_pass_per_wagon_subway"][1][1],
        "max_pass_per_wagon_streetcars_mean" => value["max_pass_per_wagon_streetcars"][1][1],
        "max_pass_per_wagon_subway_max" => value["max_pass_per_wagon_subway"][2][3],
        "max_pass_per_wagon_streetcars_max" => value["max_pass_per_wagon_streetcars"][2][3]
        )
        CSV.write("viz/$folder_name/infection&max_passengers_data_$freq_t.csv", stack(other_data))
    ###########
    end

    for n_ag in values_to_loop[vars[1]], #  THIS HAS TO BE CHANGED IF VAR NUMBER IS NOT 3
        speed in values_to_loop[vars[2]],
        p0 in values_to_loop[vars[3]]
    
        full_output, params_sets = read_results(outputs_path,
            control_vars = vars,
            control_val_equal = [n_ag, speed, p0],
            vars_to_check = ["TTC_car_freq"])
        
        gr()
        for (index, value) in enumerate(points_in_time_sing)
            ind = value/3600/24
            point_in_time_by_var(["total_infected", "TTC_infected", "street_infected"],
            "TTC_car_freq", full_output, 
            points_in_time = [value], 
            total_indic = "N_agents",
            div = 60,
            time_div = 3600, 
            time_unit = "h",
            x_lab = "public transport frequency (min)",
            y_lab = "% infected",
            #title = "Odsetek zarażonych vs. częstotliwość kursowania TTC, EOD $index", #COSMETIC
            out_name = "$folder_name/multiple_variables/ag_$n_ag&_sp_$speed&_p0_$p0&_EOD$ind", #COSMETIC
            with_export = true)
    
            plot_XY("prct_of_agents_used_TTC", "total_infected", full_output, 
                point_in_time = value, 
                total_indic = "N_agents",
                x_lab = "public transport users",
                y_lab = "% infected",
                #title = "Odsetek zarażonych vs. odsetek osób korzystających z TTC, EOD $index", #COSMETIC
                out_name = "$folder_name/XY_plots/ag_$n_ag&_sp_$speed&_p0_$p0&_EOD$ind", #COSMETIC
                with_export = true)
    
            plot_XYY("prct_of_agents_used_TTC", "total_infected", "TTC_car_freq", full_output, 
                    point_in_time = value,
                    divx = 60,
                    total_indic = "N_agents",
                    x_lab = "public transport frequency (min)",
                    y1_lab = "% public transport users",
                    y2_lab = "% infected",
                    #title = "Infected population & TTC usage by TTC frequency, EOD $index",
                    out_name = "$folder_name/XYY_plots/ag_$n_ag&_sp_$speed&_p0_$p0&_EOD$ind",
                    with_export = true)
        end
        println("parameters $n_ag agents, $speed speed, $p0 probability - finished" ) #COSMETIC
    end  
    println("plotting $folder_name finished")
end

# gathering results into aggregated files
infection_max_passengers_data = DataFrame()
top50_street = DataFrame()
top50_ttc = DataFrame()
for i in 1:5
    foldr = "res$i"
    for num in 1:20
        temp = CSV.read("viz/$foldr/infection&max_passengers_data_$num.csv", DataFrame)
        temp[!,"freq"] .= num
        temp[!,"res"] .= i
        append!(infection_max_passengers_data, temp)
        temp = CSV.read("viz/$foldr/top50_street_$num.csv", DataFrame)
        temp[!,"freq"] .= num
        temp[!,"res"] .= i
        append!(top50_street, temp)
        temp = CSV.read("viz/$foldr/top50_ttc_$num.csv", DataFrame)
        temp[!,"freq"] .= num
        temp[!,"res"] .= i
        append!(top50_ttc, temp)
    end
end
CSV.write("viz/infection_max_passengers_data.csv", infection_max_passengers_data)
CSV.write("viz/top50_ttc.csv", top50_ttc)
CSV.write("viz/top50_street.csv", top50_street)

# NODE EXAMINATION
full_output, params_sets = read_results(outputs_path,
control_vars = vars,
control_val_equal = [2000, 0.8, 0.003],
vars_to_check = ["TTC_car_freq"]);

for (key,value) in full_output
    res0 = value["nodes_visits_mean"];
    res = zeros(length(keys(res0)))
    for (key,value) in res0
        res[parse(Int,key)] = Int(value)
    end
    res = Dict("node_mean" => res)
    freq_t = Int(round(value["TTC_car_freq"]/60))
    res_df = DataFrame(res);
    cols_no = size(res_df)[2];
    res_df[!, :TTC] .= 0;
    res_df[orig_map_nodes_num+1:end, :TTC] .= 1;
    res_df;
    # "raw" data
    CSV.write("viz/$folder_name/node_data_$freq_t.csv", res_df)
end ###########