using Test
using Random
using Graphs
using NautyGraphs


@testset "nauty" begin
    g = erdos_renyi(50, 0.1, is_directed=true, seed=0)
    g_nauty = NautyDiGraph(g)
    @test adjacency_matrix(g_nauty) == adjacency_matrix(g)

    idxs = sort([1, 5, 20, 33, 11, 2, 50, 34, 10, 4, 45, 44, 28, 30])
    rem_vertices!(g, idxs, keep_order=true)
    rem_vertices!(g_nauty, idxs)

    @test g_nauty ≃ NautyDiGraph(g)
    @test g_nauty.graphset == NautyDiGraph(g).graphset
end
