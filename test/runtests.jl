using Test
using Random
using Graphs
using NautyGraphs


@testset "NautyGraphs" begin
    include("densenautygraphs.jl")
    include("nauty.jl")
end
