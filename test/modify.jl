using Random, Graphs, LinearAlgebra

@testset "modify" begin
    rng = Xoshiro(0)
    symmetrize_adjmx(A) = (A = convert(typeof(A), (A + A') .> 0); for i in axes(A, 1); A[i, i] = 0; end; A)

    nverts = [5, 10, 20, 50, 100, 200, 500, 1000]
    rvs = [sort(unique(rand(rng, 1:i, 4))) for i in nverts]
    As = [symmetrize_adjmx(rand(rng, [0, 1], i, i)) for i in nverts]

    gs = [Graph(A) for A in As]
    ngs = [NautyGraph(A) for A in As]

    for (g, ng, rv) in zip(gs, ngs, rvs)
        g, ng = copy(g), copy(ng)

        @test adjacency_matrix(g) == adjacency_matrix(ng)

        rem_vertices!(g, rv, keep_order=true)
        rem_vertices!(ng, rv)
        @test adjacency_matrix(g) == adjacency_matrix(ng)
    end

    for (g, ng, rv) in zip(gs, ngs, rvs)
        g, ng = copy(g), copy(ng)

        edge = collect(edges(g))[end]

        rem_edge!(g, edge)
        rem_edge!(ng, edge)
        @test adjacency_matrix(g) == adjacency_matrix(ng)
    end

    for (g, ng, rv) in zip(gs, ngs, rvs)
        g, ng = copy(g), copy(ng)

        add_vertex!(g)
        add_vertex!(ng)
        add_edge!(g, 1, nv(g))
        add_edge!(ng, 1, nv(ng))
        @test adjacency_matrix(g) == adjacency_matrix(ng)
    end

    for (g, ng, rv) in zip(gs, ngs, rvs)
        g, ng = copy(g), copy(ng)

        add_edge!(g, 1, 2)
        add_edge!(ng, 1, 2)
        @test adjacency_matrix(g) == adjacency_matrix(ng)
    end
end