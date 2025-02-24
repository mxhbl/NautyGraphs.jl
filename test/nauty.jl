using Base.Threads

@testset "nauty" begin
    verylarge_g = NautyGraph(50)

    _, autg = nauty(verylarge_g)
    @test autg.n > typemax(Int64)

    g1 = NautyGraph(4)
    add_edge!(g1, 1, 2)
    add_edge!(g1, 2, 3)
    add_edge!(g1, 2, 4)

    h1 = NautyGraph(4)
    add_edge!(h1, 3, 4)
    add_edge!(h1, 4, 1)
    add_edge!(h1, 4, 2)

    @test g1 ≃ h1
    @test ghash(g1) == ghash(h1)

    g2 = NautyGraph(4, [0, 0, 1, 1])
    add_edge!(g2, 1, 2)
    add_edge!(g2, 2, 3)
    add_edge!(g2, 2, 4)

    h2 = NautyGraph(4, [1, 1, 0, 0])
    add_edge!(h2, 3, 4)
    add_edge!(h2, 4, 1)
    add_edge!(h2, 4, 2)

    @test g2 ≃ h2
    @test ghash(g2) == ghash(h2)


    k2 = NautyGraph(4, [1, 0, 0, 1])
    add_edge!(k2, 3, 4)
    add_edge!(k2, 4, 1)
    add_edge!(k2, 4, 2)

    @test !(g2 ≃ k2)
    @test ghash(g2) != ghash(k2)


    g3 = NautyGraph(6)
    add_edge!(g3, 1, 2)
    add_edge!(g3, 4, 1)
    add_edge!(g3, 3, 2)
    add_edge!(g3, 2, 5)
    add_edge!(g3, 1, 5)

    h3 = copy(g3)
    canonize!(h3)

    @test g3 ≃ h3
    @test ghash(g3) == ghash(h3)

    k3 = NautyGraph(6)
    add_edge!(k3, 6, 2)
    add_edge!(k3, 5, 6)
    add_edge!(k3, 3, 2)
    add_edge!(k3, 2, 4)
    add_edge!(k3, 6, 4)

    @test k3 ≃ g3
    @test ghash(k3) == ghash(g3)

    m3 = copy(k3)
    canonize!(m3)
    @test adjacency_matrix(m3) == adjacency_matrix(h3)


    g4 = NautyGraph(3, [1, 2, 3])
    h4 = NautyGraph(3, [1, 2, 3])
    add_edge!(g4, 1, 2)
    add_edge!(h4, 1, 2)

    @test g4 == h4
    @test Base.hash(g4) == Base.hash(h4)

    g4.hashval = UInt(0)
    @test g4 == h4
    @test Base.hash(g4) == Base.hash(h4)


    g5 = NautyGraph(10, collect(10:-1:1))
    add_edge!(g5, 1, 2)
    add_edge!(g5, 5, 2)
    add_edge!(g5, 6, 7)
    add_edge!(g5, 8, 1)
    add_edge!(g5, 9, 10)

    canon5 = copy(g5)
    canonize!(canon5)

    canonperm5 = canonical_permutation(g5)
    @test canon5.labels == g5.labels[canonperm5]

    thread_gs = fill(copy(g4), 10)
    vals = []
    @threads for i in eachindex(thread_gs)
        push!(vals, nauty(thread_gs[i]))
    end
    @test length(vals) == length(thread_gs)


    gnoloop = NautyGraph(5)
    add_edge!(gnoloop, 1, 2)
    add_edge!(gnoloop, 3, 5)
    add_edge!(gnoloop, 5, 2)

    gloop = copy(gnoloop)
    add_edge!(gloop, 1, 1)

    @test_nowarn nauty(gloop)
    @test !is_isomorphic(gnoloop, gloop)

    gdinoloop = NautyDiGraph(5)
    add_edge!(gdinoloop, 1, 2)
    add_edge!(gdinoloop, 3, 5)
    add_edge!(gdinoloop, 5, 2)

    gdiloop = copy(gdinoloop)
    add_edge!(gdiloop, 1, 1)

    @test_nowarn nauty(gdiloop)
    @test !is_isomorphic(gdinoloop, gdiloop)
end