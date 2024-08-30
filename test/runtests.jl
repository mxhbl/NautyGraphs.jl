using NautyGraphs, Graphs
using Test
using Random, LinearAlgebra

@testset verbose=true "NautyGraphs" begin
    include("densenautygraphs.jl")
    include("nauty.jl")
end
