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
outputs_path = "SOME_PATH"
vars = ["p0"] # what has to be constant

# reading possible parameter values
params_to_plot = CSV.read("$outputs_path/sim_params_comb_df.csv", DataFrame)

# file_list = glob("simul_res_parset_id_*.json", outputs_path)
#     for id in params_to_plot[:,:parset_id]
#         if string(outputs_path,"/simul_res_parset_id_",id,".json") ∉ file_list
#             filter!(r -> !in(r.parset_id, [id]), params_to_plot)
#         end
#     end
# CSV.write("$outputs_path/sim_params_comb_df.csv", params_to_plot)

values_to_loop = Dict()
for var in vars
    values_to_loop[var] = unique(params_to_plot[:,var])
end

# what to get
total_indic = "N_agents"
response_var = "total_infected"
variable = "TTC_car_freq"
div = 60

#what to plot
points_in_time = Int(3*24*3600)


df = Dict()
full_output = Dict()
for p0 in values_to_loop["p0"]
    full_output[p0], params_sets = read_results(outputs_path,
        control_vars = vars,
        control_val_equal = [p0],
        vars_to_check = ["TTC_car_freq"])
    
    println("$p0 read to dict")

    for (key, value) in full_output[p0]
        symb = value[variable]/div
        if !isnothing(total_indic) && length(value[total_indic])>1
            value[total_indic] = value[total_indic][1]
            if total_indic == "prct_of_agents_used_TTC"
                value[total_indic] = value[total_indic]*value["N_agents"]/100
            end
        end
        if p0 ∉ keys(df)
            df[p0] = DataFrame()
        end
        if response_var in ["total_infected", "TTC_infected", "street_infected"]
            df[p0][:,Symbol(symb)] = 100value[response_var][1]./(isnothing(total_indic) ? 1 : value[total_indic])
        else
            df[p0][:,Symbol(symb)] = value[response_var]./(isnothing(total_indic) ? 1 : value[total_indic])
        end  
    end
    println("$p0 read to df")
end


out_df = DataFrame()
for p0 in values_to_loop["p0"]
    results = Dict()
    results[response_var] = df[p0][points_in_time, :]
    results[response_var] = DataFrame([[names(results[response_var])]; collect.(eachrow(DataFrame(results[response_var])))], [Symbol(variable); Symbol.("ITER_", points_in_time)])
    results[response_var][!,variable] = parse.(Float64, results[response_var][!,variable])
    sort!(results[response_var], Symbol(variable))

    min_row = DataFrame(sort!(results[response_var], Symbol("ITER_", points_in_time), rev=false)[1,:])
    p = DataFrame(p = p0)
    min_row = hcat(min_row,p)
    append!(out_df, min_row)
end

sort!(out_df, :p)
#out_df2 = out_df[1:9, :]
pyplot()
Plots.plot(out_df[!, :p], out_df[!, :TTC_car_freq], linewidth = 2.5, 
legend = false,
linecolor = "purple")

xlabel!("base probability of infection")
ylabel!("optimal TTC frequency")
Plots.savefig("EOD_3_mins.eps")