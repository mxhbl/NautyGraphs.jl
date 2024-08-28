@testset "nauty" begin
    overflow_g = NautyGraph(50)

    # Check group size overflow
    grpsize, _, _ = nauty(overflow_g)
    @test grpsize == 0

    g1 = NautyGraph(4)
    add_edge!(g1, 1, 2)
    add_edge!(g1, 2, 3)
    add_edge!(g1, 2, 4)

    h1 = NautyGraph(4)
    add_edge!(h1, 3, 4)
    add_edge!(h1, 4, 1)
    add_edge!(h1, 4, 2)

    @test g1 ≃ h1

    g2 = NautyGraph(4, [0, 0, 1, 1])
    add_edge!(g2, 1, 2)
    add_edge!(g2, 2, 3)
    add_edge!(g2, 2, 4)

    h2 = NautyGraph(4, [1, 1, 0, 0])
    add_edge!(h2, 3, 4)
    add_edge!(h2, 4, 1)
    add_edge!(h2, 4, 2)

    @test g2 ≃ h2

    k2 = NautyGraph(4, [1, 0, 0, 1])
    add_edge!(k2, 3, 4)
    add_edge!(k2, 4, 1)
    add_edge!(k2, 4, 2)

    @test !(g2 ≃ k2)


    g3 = NautyGraph(6)
    add_edge!(g3, 1, 2)
    add_edge!(g3, 4, 1)
    add_edge!(g3, 3, 2)
    add_edge!(g3, 2, 5)
    add_edge!(g3, 1, 5)

    h3 = copy(g3)
    canonize!(h3)

    @test g3 ≃ h3

    k3 = NautyGraph(6)
    add_edge!(k3, 6, 2)
    add_edge!(k3, 5, 6)
    add_edge!(k3, 3, 2)
    add_edge!(k3, 2, 4)
    add_edge!(k3, 6, 4)

    @test k3 ≃ g3

    m3 = copy(k3)
    canonize!(m3)
    @test adjacency_matrix(m3) == adjacency_matrix(h3)
end