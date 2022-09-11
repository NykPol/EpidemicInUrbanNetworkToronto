- [Title](#title)
- [Abstract](#abstract)
- [Visual Summary](#visual-summary)
  * [Introductory graphics](#introductory-graphics)
    + [Map of Toronto used in the experiment](#map-of-toronto-used-in-the-experiment)
    + [A live simulation example for 10 agents on a small fragment of the map](#a-live-simulation-example-for-10-agents-on-a-small-fragment-of-the-map)
    + [An example of one day simulation dynamic for an agent](#an-example-of-one-day-simulation-dynamic-for-an-agent)
      - [A live simulation example of a trip of an agent](#a-live-simulation-example-of-a-trip-of-an-agent)
    + [An example of one day simulation dynamic for a TTC car](#an-example-of-one-day-simulation-dynamic-for-a-ttc-car)
  * [Result plots](#result-plots)
    + [Individual nodes visits depending on TTC frequency on a small fragment of the map](#individual-nodes-visits-depending-on-ttc-frequency-on-a-small-fragment-of-the-map)
    + [Percentage of TTC users and infected agents at a fixed iteration depending on TTC frequency](#percentage-of-ttc-users-and-infected-agents-at-a-fixed-iteration-depending-on-ttc-frequency)
- [TTC Data](#ttc-data)

# Title
Optimizing transport frequency in multi-layered urban transportation networks for pandemic prevention


# Abstract
In this paper, we show how transport policy decisions can affect the pandemic dynamics in urban populations. Specifically, we develop a multi-agent simulation framework to model infection dynamics in complex networks. Our agents periodically commute between home and work via a combination of walking routes and public transit, and make decisions intelligently based upon their location, available routes, and expectations of public transport arrival times. Our infection scheme allows for different contagiousness levels, as a function of the virus's strain and where the agents interact (i.e., inside or outside). The results show that the pandemic's scale is heavily impacted by the network's structure, and the decision making of the agents. In particular, the progression of the pandemic greatly differs when agents primarily infect each other in a crowded urban transportation system, opposed to while walking. Additionally, the results show that local subgraph characteristics, including topology, structure, and statistics such as its degree distribution and density, affect the viruses' transmission rates. We also assess the effect of modifying the public transport's running frequency on the spread of two different virus strains (with different levels of contagiousness). In particular, lowering the running frequency can discourage agents from taking public transportation too often, especially for shorter distances. On the other hand, the low frequency contributes to more crowded streetcars or subway cars if the policy is not designed correctly, which is why such an analysis may prove valuable for finding "sweet spots" that optimize the system. The proposed approach has been validated on real world data, and a model of the transportation network of downtown Toronto. The framework used is flexible and can be easily adjusted to model other urban environments, and additional forms of transportation (such as carpooling, ride-share and more). This general approach can be used modeling of contiguous disease spread in an urban environments including influenza or various COVID-19 variants.


# Visual Summary

## Introductory graphics
### Map of Toronto used in the experiment
![Fig1](https://github.com/NykPol/EpidemicInUrbanNetworkToronto/blob/main/graphics/Toronto_TTC_map.png)

### A live simulation example for 10 agents on a small fragment of the map
![Fig2](https://github.com/NykPol/EpidemicInUrbanNetworkToronto/blob/main/graphics/simulation_env_10_agents.gif)

### An example of one day simulation dynamic for an agent
![Fig3](https://github.com/NykPol/EpidemicInUrbanNetworkToronto/blob/main/graphics/Agent_sim_process.png)

#### A live simulation example of a trip of an agent 
![Fig4](https://github.com/NykPol/EpidemicInUrbanNetworkToronto/blob/main/graphics/simulation_env_1_agent_trip_example.gif)

### An example of one day simulation dynamic for a TTC car
![Fig5](https://github.com/NykPol/EpidemicInUrbanNetworkToronto/blob/main/graphics/TTC_sim_process.png)

## Result plots
### Individual nodes visits depending on TTC frequency on a small fragment of the map
![Fig6](https://github.com/NykPol/EpidemicInUrbanNetworkToronto/blob/main/graphics/Map_freq3_vs_20.png)

### Percentage of TTC users and infected agents at a fixed iteration depending on TTC frequency
![Fig7](https://github.com/NykPol/EpidemicInUrbanNetworkToronto/blob/main/graphics/TTCfreq_vs_TTCuser_vs_infected.png)


# TTC Data
https://open.toronto.ca/dataset/ttc-routes-and-schedules/ [access: 01 November 2020]


