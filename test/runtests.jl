using NautyGraphs, Graphs
using NautyGraphs: Graphset
using Test
using Random, LinearAlgebra

@testset verbose=true "NautyGraphs" begin
    include("densenautygraph.jl")
    include("nauty.jl")
    include("graphset.jl")
end
