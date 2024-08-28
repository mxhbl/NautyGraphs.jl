using Test
using Random
using Graphs
using NautyGraphs


@testset "NautyGraphs" begin
    include("modify.jl")
    include("nauty.jl")
end
