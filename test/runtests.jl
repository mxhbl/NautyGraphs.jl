using NautyGraphs, Graphs
using NautyGraphs: Graphset
using Test
using Random, LinearAlgebra
using Base.Threads

using Pkg; Pkg.add(url="https://github.com/JuliaGraphs/GraphsInterfaceChecker.jl")
using GraphsInterfaceChecker, Interfaces


@testset verbose=true "NautyGraphs" begin
    include("densenautygraph.jl")
    include("nauty.jl")
    include("graphset.jl")
    include("interface.jl")
end
