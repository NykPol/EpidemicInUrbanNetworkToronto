using Pkg
using Plots
using DataFrames
pyplot()

### functions for simulations

function calc_new_state(y::AbstractArray,
    a::Dict,
    b::Dict,
    l::Dict;
    from::Float64=0.01)
    """ adds another value to a time-series vector of rates of infected population in time.
    calculating new state based on the last value in the vector y, contagion probabilities (l),
    interaction frequencies (b) and probabilities of walking & taking subway (a) stemming from times of travel (s).
    a is calculated outside the function (it is calculated in simul func instead for performance reasons).
    parameter "from" is a start infection rate of an epidemic.
    """
    if length(y)==0
        y = [from]
    end
    y[end]+(1-y[end])*(a["walk"]*(1-exp(-b["walk"]*l["walk"]*a["walk"]*y[end]))+a["TTC"]*(1-exp(-b["TTC"]*l["TTC"]*a["TTC"]*y[end])))
end

function simul(s::Dict,
               b::Dict,
               l::Dict;
               to_perc::Bool=true,
               from::Float64=0.01,
               to::Union{Float64, Int}=0.99,
               new_infections::Bool=false,
               approx_value::Bool=false)
               """
               simulation of consecutive days of a pandemic using the calc_new_state function.
                used parameters:
                s - times of travel
                b - interaction frequencies
                l - contagion probabilities
                to_perc - simulate till reaching a certain % of infected population if True;
                if set to False - parameter "to" sets number of iterations (days) to simulate
                from - stating % of infected population
                to - max % of infected population to be reached (if to_perc==True), or no of days otherwise
                new_infections - whether to return numbef of  new agents infected (True) or the total number (False)
                approx_value - whether to use an approximated formula
               
               """

                # initial calculations
                e1 = (exp(-(s["walk"])/min(s["walk"], s["TTC"])))
                e2 = (exp(-(s["TTC"])/min(s["walk"], s["TTC"])))
                a = Dict("walk" => e1/sum([e1,e2]), "TTC" => e2/sum([e1,e2])) # walk/ttc path probability
                print(a)

                # simulation loop
                y = [] # number of agents infected
                ay = [] # number of agents infected (approximation)

                z = [] # number of new agents infected
                az = [] # number of new agents infected (approximation)

                append!(y, from)
                append!(ay, from)

                if to_perc # loop till the % of infected equals "to"
                    while y[end] <= to
                        append!(y, calc_new_state(y,a,b,l))
                        append!(z, y[end]-y[end-1])
                    end
                else # loop till the number of iterations (days) reaches "to"
                    for i in 1:to
                        append!(y, calc_new_state(y,a,b,l))
                        append!(z, y[end]-y[end-1])

                        ca = a["walk"]*a["walk"]*b["walk"]*l["walk"]+a["TTC"]*a["TTC"]*b["TTC"]*l["TTC"]
                        append!(az, (1-ay[end])*ay[end]*ca)
                        append!(ay, 1/(1+exp(-ca*i)*(1/from-1)))
                    end
                end
                if new_infections
                    if approx_value
                        return az
                    else
                        return z
                    end
                else
                    if approx_value
                        return ay
                    else
                        return y
                    end
                end
end

#####################################
### scenario 1:
s = Dict("walk" => 15, "TTC" => 10) # time of travel
l = Dict("walk" => 0.01, "TTC" => 0.02) # contagion
b = Dict("walk" => 5, "TTC" => 5) # interaction frequency

x1 = simul(s,b,l)
z1 = simul(s,b,l,new_infections=true)
length(x1) - 1

# PLOT1
Plots.plot(1:length(x1), x1, linecolor="purple", lw = 2, legend=false, grid=false)
ylabel!("% infected")
xlabel!("# of iterations")
savefig("plot1.eps")

# PLOT1' (new infections)
Plots.plot(1:length(z1), z1, linecolor="purple", lw = 2, legend=false, grid=false)
ylabel!("% of new infections")
xlabel!("# of iterations")
savefig("plot1b.eps")

#####################################
### scenario 2:
s = Dict("walk" => 15, "TTC" => 15) # time of travel
l = Dict("walk" => 0.01, "TTC" => 0.02) # contagion
b = Dict("walk" => 5, "TTC" => 5) # interaction frequency

x2 = simul(s,b,l)
z2 = simul(s,b,l,new_infections=true)
length(x2) - 1

#####################################
### scenario 3:
s = Dict("walk" => 15, "TTC" => 10) # time of travel
l = Dict("walk" => 0.01, "TTC" => 0.02) # contagion
b = Dict("walk" => 5, "TTC" => 3) # interaction frequency

x3 = simul(s,b,l)
z3 = simul(s,b,l,new_infections=true)
length(x3) - 1

#####################################
### scenario 4:
s = Dict("walk" => 15, "TTC" => 10) # time of travel
l = Dict("walk" => 0.01, "TTC" => 0.02) # contagion
b = Dict("walk" => 3, "TTC" => 5) # interaction frequency

x4 = simul(s,b,l)
z4 = simul(s,b,l,new_infections=true)
length(x4) - 1

# PLOT2
Plots.plot(1:length(x2), x2, linecolor="purple", lw = 2, legend=false, grid=false)
ylabel!("% infected")
xlabel!("# of iterations")
savefig("plot2.eps")

#PLOT3
Plots.plot(1:length(x1), x1, linecolor="purple", label="Scenario 1", lw=2, grid = false, legend=:topleft)
Plots.plot!(1:length(x2), x2, linecolor="black", label="Scenario 2", lw=2 #linestyle = :dot, )
)
Plots.plot!(1:length(x3), x3, linecolor="red", label="Scenario 3", lw=2 #linestyle = :dot, )
)
Plots.plot!(1:length(x4), x4, linecolor="blue", label="Scenario 4", lw=2 #linestyle = :dot, )
)
ylabel!("% infected")
xlabel!("# of iterations")
savefig("plot3.eps")

#PLOT3 (new infections)
Plots.plot(1:length(z1), z1, linecolor="purple", label="Scenario 1", lw=2, grid = false, legend=:topleft)
Plots.plot!(1:length(z2), z2, linecolor="black", label="Scenario 2", lw=2 #linestyle = :dot, )
)
Plots.plot!(1:length(z3), z3, linecolor="red", label="Scenario 3", lw=2 #linestyle = :dot, )
)
Plots.plot!(1:length(z4), z4, linecolor="blue", label="Scenario 4", lw=2 #linestyle = :dot, )
)
ylabel!("% of new infections")
xlabel!("# of iterations")
savefig("plot3.eps")

################################
# PLOT 4
s = Dict("walk" => 15, "TTC" => 10) # time of travel
l = Dict("walk" => 0.01, "TTC" => 0.02) # contagion
b = Dict("walk" => 5, "TTC" => 5) # interaction frequency

results_full = Dict()
results_short = DataFrame()
for i in 1:50
    s["TTC"] = i
    results_full[i] = simul(s,b,l)
    append!(results_short, DataFrame(s_ttc = [i], days = [length(results_full[i])-1]))
end

results_short # ok

Plots.plot(results_short[!,:s_ttc], results_short[!,:days], linecolor="purple", lw = 2, legend=false, grid=false)
ylabel!("# of iterations")
xlabel!("expected travel time for subway")
savefig("plot4.eps")

#############################
# PLOT 4b
s = Dict("walk" => 15, "TTC" => 10) # time of travel
l = Dict("walk" => 0.01, "TTC" => 0.02) # contagion
b = Dict("walk" => 5, "TTC" => 5) # interaction frequency

results_full2 = Dict()
results_short2 = DataFrame()
for i in 1:50
    s["TTC"] = i
    results_full2[i] = simul(s,b,l, to_perc=false, to=101)
    append!(results_short2, DataFrame(s_ttc = [i], infected = results_full2[i][101]))
end

results_short2 # ok

Plots.plot(results_short2[!,:s_ttc], results_short2[!,:infected], linecolor="purple", lw = 2, legend=false, grid=false)
ylabel!("% infected after 100 days")
xlabel!("expected travel time for subway")
savefig("plot4b.eps")




#####################################
### Approximation
s = Dict("walk" => 15, "TTC" => 10) # time of travel
l = Dict("walk" => 0.01, "TTC" => 0.02) # contagion
b = Dict("walk" => 5, "TTC" => 5) # interaction frequency

ax6 = simul(s,b,l,to_perc=false, to=length(x1)-1, approx_value=true)
az6 = simul(s,b,l,to_perc=false, to=length(x1)-1, approx_value=true, new_infections=true)
length(x6) - 1

# PLOT5
Plots.plot(1:length(x1), x1, linecolor="purple", label="Actual", lw=2, grid = false, legend=:topleft)
Plots.plot!(1:length(x6), ax6, linecolor="black", label="Approximation", lw=2 #linestyle = :dot, )
)
ylabel!("% infected")
xlabel!("# of iterations")
savefig("plot5.eps")

# PLOT5b
Plots.plot(1:length(z1), z1, linecolor="purple", label="Actual", lw=2, grid = false, legend=:topleft)
Plots.plot!(1:length(az6), az6, linecolor="black", label="Approximation", lw=2 #linestyle = :dot, )
)
ylabel!("% of new infections")
xlabel!("# of iterations")
savefig("plot5b.eps")
