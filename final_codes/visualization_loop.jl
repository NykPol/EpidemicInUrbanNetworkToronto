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

# SETUP
folder_name = "toy_model3"
outputs_path = "SOME_PATH/COVID_Simulator_Toronto/final_codes/data_output/$folder_name"
vars = ["N_agents", "agents_speed_in_sec_per_m", "p0"] # what has to be constant 
#vars_heatmap = ["N_agents", "p0"] # what has to be constant
#points_in_time = [[1*24*3600, 2*24*3600, 3*24*3600]]
points_in_time_sing = [0.5*3600, 1*3600, 1.5*3600, 1.75*3600]#[0.25*24*3600, 0.5*24*3600, 0.75*24*3600, 1*24*3600, 2*24*3600, 3*24*3600]
#orig_map_nodes_num = 770

# reading possible parameter values
params_to_plot = CSV.read("$outputs_path/sim_params_comb_df.csv", DataFrame)

file_list = glob("simul_res_parset_id_*.json", outputs_path)
    for id in params_to_plot[:,:parset_id]
        if string(outputs_path,"/simul_res_parset_id_",id,".json") ∉ file_list
            filter!(r -> !in(r.parset_id, [id]), params_to_plot)
        end
    end
CSV.write("$outputs_path/sim_params_comb_df.csv", params_to_plot)

values_to_loop = Dict()
for var in vars
    values_to_loop[var] = unique(params_to_plot[:,var])
end

# actual loop
for n_ag in values_to_loop[vars[1]],
    speed in values_to_loop[vars[2]],
    p0 in values_to_loop[vars[3]]

    full_output, params_sets = read_results(outputs_path,
        control_vars = vars,
        control_val_equal = [n_ag, speed, p0],
        vars_to_check = ["TTC_car_freq"])

    # develplot_by_var("total_infected", "TTC_car_freq", full_output,
    # with_std = false,
    # total_indic = "N_agents",
    # div = 60,
    # var_unit = "min", 
    # max_it = nothing,
    # x_lab = "iteration",
    # y_lab = "% infected",
    # title = "% infected vs freq when ag = $n_ag, speed = $speed, p0 = $p0", #COSMETIC
    # out_name = "total_infected_S/ag_$n_ag&_sp_$speed&_p0_$p0", #COSMETIC
    # with_export = true)

    # develplot_by_var("TTC_infected", "TTC_car_freq", full_output,
    # with_std = false,
    # div = 60,
    # var_unit = "min", 
    # max_it = nothing,
    # x_lab = "iteration",
    # y_lab = "people infected",
    # title = "TTC infected vs freq when ag = $n_ag, speed = $speed, p0 = $p0", #COSMETIC
    # out_name = "TTC_infected_S/ag_$n_ag&_sp_$speed&_p0_$p0", #COSMETIC
    # with_export = true)

    # develplot_by_var("TTC_infected", "TTC_car_freq", full_output,
    # with_std = false,
    # div = 60,
    # var_unit = "min", 
    # max_it = nothing,
    # x_lab = "iteration",
    # y_lab = "people infected",
    # total_indic = "prct_of_agents_used_TTC",
    # title = "% TTC infected vs freq when ag = $n_ag, speed = $speed, p0 = $p0", #COSMETIC
    # out_name = "perc_used/ag_$n_ag&_sp_$speed&_p0_$p0", #COSMETIC
    # with_export = true)

    # for (index, value) in enumerate(points_in_time)
        
    #     # point_in_time_by_var(["total_infected"], "TTC_car_freq", full_output, 
    #     #     points_in_time = value, 
    #     #     total_indic = "N_agents",
    #     #     div = 60,
    #     #     time_div = 3600, 
    #     #     time_unit = "h",
    #     #     x_lab = "Public Transport Frequency",
    #     #     y_lab = "% infected",
    #     #     #title = "Optimal Public Transport Frequency = 9 min", #COSMETIC
    #     #     out_name = "do_networks", #COSMETIC
    #     #     with_export = true)
    #     point_in_time_by_var(["total_infected"], "TTC_car_freq", full_output, 
    #         points_in_time = value, 
    #         total_indic = "N_agents",
    #         div = 60,
    #         time_div = 3600, 
    #         time_unit = "h",
    #         x_lab = "public transport frequency",
    #         y_lab = "% infected",
    #         #title = "%infected when ag = $n_ag, speed = $speed, p0 = $p0", #COSMETIC
    #         out_name = "points_in_time/ag_$n_ag&_sp_$speed&_p0_$p0&_$index", #COSMETIC
    #         with_export = true)

    #     point_in_time_by_var(["TTC_infected"], "TTC_car_freq", full_output, 
    #         points_in_time = value, 
    #         total_indic = "N_agents",
    #         div = 60,
    #         time_div = 3600, 
    #         time_unit = "h",
    #         x_lab = "public transport frequency",
    #         y_lab = "% infected",
    #         #title = "%infected when ag = $n_ag, speed = $speed, p0 = $p0", #COSMETIC
    #         out_name = "TTC_points_in_time/ag_$n_ag&_sp_$speed&_p0_$p0&_$index", #COSMETIC
    #         with_export = true)

    #     point_in_time_by_var(["TTC_infected"], "TTC_car_freq", full_output, 
    #         points_in_time = value, 
    #         total_indic = "prct_of_agents_used_TTC",
    #         div = 60,
    #         time_div = 3600, 
    #         time_unit = "h",
    #         x_lab = "public transport frequency",
    #         y_lab = "% infected",
    #         #title = "%infected when ag = $n_ag, speed = $speed, p0 = $p0", #COSMETIC
    #         out_name = "perc_used/ag_$n_ag&_sp_$speed&_p0_$p0&_$index", #COSMETIC
    #         with_export = true)
    # end

    for (index, value) in enumerate(points_in_time_sing)
        gr()
        ind = value/3600
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
        out_name = "$folder_name/multiple_variables/ag_$n_ag&_sp_$speed&_p0_$p0&_$ind&h", #COSMETIC
        with_export = true)
        gr()
        # plot_XY("prct_of_agents_used_TTC", "total_infected", full_output, 
        #     point_in_time = value, 
        #     total_indic = "N_agents",
        #     x_lab = "public transport users",
        #     y_lab = "% infected",
        #     #title = "Odsetek zarażonych vs. odsetek osób korzystających z TTC, EOD $index", #COSMETIC
        #     out_name = "$folder_name/XY_plots/ag_$n_ag&_sp_$speed&_p0_$p0&_EOD$ind", #COSMETIC
        #     with_export = true)
        # gr()
        # plot_XYY("prct_of_agents_used_TTC", "total_infected", "TTC_car_freq", full_output, 
        #         point_in_time = value,
        #         divx = 1,
        #         total_indic = "N_agents",
        #         x_lab = "public transport frequency (min)",
        #         y1_lab = "% public transport users",
        #         y2_lab = "% infected",
        #         #title = "Infected population & TTC usage by TTC frequency, EOD $index",
        #         out_name = "$folder_name/XYY_plots/ag_$n_ag&_sp_$speed&_p0_$p0&_EOD$ind",
        #         with_export = true)
    end
        
    # full_output, params_sets = read_results(outputs_path,
    #     control_vars = vars_heatmap,
    #     control_val_equal = [n_ag, p0],
    #     vars_to_check = ["TTC_car_freq", "agents_speed_in_sec_per_m"])

    # make_heatmap("prct_of_agents_used_TTC", "TTC_car_freq",
    #     "agents_speed_in_sec_per_m", full_output, params_sets,
    #     div1 = 60,
    #     div2 = 1,
    #     out_name = "heatmaps/ag_$n_ag&_p0_$p0",
    #     with_export = true)    

    println("parameters $n_ag agents, $speed speed, $p0 probability - finished" ) #COSMETIC
end

println("plotting finished")