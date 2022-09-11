# Working directory to /final_codes/
cd("SOME_PATH")
println("Your current directory: ", pwd())

if split(pwd(),"/")[end] != "final_codes"
    throw("Your working directory should be in: COVID_Simulator_Toronto/final_codes")
end

using Pkg

Pkg.activate(".")
Pkg.add(PackageSpec(name="CSV", version="0.8.2"))
Pkg.add(PackageSpec(name="DataFrames", version="0.22.2"))
Pkg.add(PackageSpec(name="Distributions", version="0.24.13"))
Pkg.add(PackageSpec(name="JSON", version="0.21.1"))

Pkg.add(PackageSpec(name="Conda", version="1.5.0"))
Pkg.add(PackageSpec(name="PyCall", version="1.92.1"))
Pkg.add(PackageSpec(name="LightGraphs", version="1.3.4"))

Pkg.add(PackageSpec(name="OpenStreetMapX", version="0.2.3"))
Pkg.add(PackageSpec(name="Geodesy", version="1.0.0"))
Pkg.add(PackageSpec(name="DataStructures", version="0.17.20"))

Pkg.add(PackageSpec(name="SimpleWeightedGraphs", version="1.1.1"))

Pkg.add(PackageSpec(name="StatsBase", version="0.32.2"))
Pkg.add(PackageSpec(name="Parameters", version="0.12.1"))

#CLOUD
Pkg.add(PackageSpec(name="AWS", version="1.43.0"))
Pkg.add(PackageSpec(name="AWSS3", version="0.8.3"))

Pkg.build("Conda")
