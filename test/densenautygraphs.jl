rng = Random.Random.MersenneTwister(0) # Use MersenneTwister for Julia 1.6 compat
symmetrize_adjmx(A) = (A = convert(typeof(A), (A + A') .> 0); for i in axes(A, 1); A[i, i] = 0; end; A)

@testset "modify" begin
    nverts = [5, 10, 20, 31, 32, 33, 50, 63, 64, 65, 100, 200, 500, 1000]
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

        add_vertices!(g, 500)
        add_vertices!(ng, 500)
        add_edge!(g, 1, 2)
        add_edge!(ng, 1, 2)
        @test adjacency_matrix(g) == adjacency_matrix(ng)
    end

    g_loop = Graph(2)
    ng_loop = NautyGraph(2)

    add_edge!(g_loop, 1, 1)
    add_edge!(ng_loop, 1, 1)
    @test ne(ng_loop) == ne(g_loop)

    @test adjacency_matrix(ng_loop) == adjacency_matrix(g_loop)

    add_edge!(g_loop, 1, 2)
    add_edge!(ng_loop, 1, 2)
    @test ne(ng_loop) == ne(g_loop)

    g_diloop = DiGraph(2)
    ng_diloop = NautyDiGraph(2)
    add_edge!(g_diloop, 1, 1)
    add_edge!(ng_diloop, 1, 1)
    @test ne(ng_diloop) == ne(g_diloop)

    @test adjacency_matrix(ng_diloop) == adjacency_matrix(g_diloop)

    add_edge!(g_diloop, 1, 1)
    @test add_edge!(ng_diloop, 1, 1) == false
    @test ne(ng_diloop) == ne(g_diloop)

    @test adjacency_matrix(ng_diloop) == adjacency_matrix(g_diloop)

    add_edge!(g_diloop, 1, 2)
    add_edge!(ng_diloop, 1, 2)
    @test ne(ng_diloop) == ne(g_diloop)
end

@testset "methods" begin
    empty_g = NautyGraph(0)
    @test nv(empty_g) == 0
    @test ne(empty_g) == 0
    
    g0 = erdos_renyi(70, 100; rng=rng)
    rand_g = NautyGraph(g0)
    @test_throws ErrorException (rand_g_dir = NautyDiGraph(g0))

    @test nv(rand_g) == 70
    @test ne(rand_g) == 100
    @test vertices(rand_g) == Base.OneTo(70)

    for edge in edges(rand_g)
        @test has_edge(rand_g, edge)
    end
    for edge in edges(g0)
        @test has_edge(rand_g, edge)
    end
    for vertex in vertices(rand_g)
        @test has_vertex(rand_g, vertex)
        @test outdegree(rand_g, vertex) == length(outneighbors(rand_g, vertex))
        @test indegree(rand_g, vertex) == length(inneighbors(rand_g, vertex))
    end

    g = NautyDiGraph(4)
    add_edge!(g, 1, 2)
    add_edge!(g, 2, 3)
    add_edge!(g, 2, 4)

    g2 = copy(g)
    g3 = copy(g)

    @test add_edge!(g2, 2, 5) == false
    @test g2 == g3

    @test outneighbors(g, 2) == [3, 4]
    @test outneighbors(g, 1) == [2]

    @test inneighbors(g, 2) == [1]
    @test inneighbors(g, 1) == []

    @test add_edge!(copy(g), 1, 3) == true
    @test add_edge!(copy(g), 1, 2) == false

    @test rem_edge!(copy(g), 1, 3) == false
    @test rem_edge!(copy(g), 1, 2) == true
    @test rem_edge!(copy(g), Edge(1, 2)) == true

    @test add_vertices!(copy(g), 3, [1, 2, 3]) == 3

    @test rem_vertex!(copy(g), 5) == false

    h = NautyDiGraph(4)
    copy!(h, g)
    @test h.graphset == g.graphset
    @test h.n_vertices == g.n_vertices
    @test h.n_edges == g.n_edges
    @test h.n_words == g.n_words
    @test h.labels == g.labels
    @test h.hashval == g.hashval


    g = NautyGraph(5, collect(1:5))
    add_edge!(g, 1, 2)
    add_edge!(g, 1, 3)
    add_edge!(g, 1, 4)
    add_edge!(g, 1, 5)
    add_edge!(g, 2, 5)

    gind1 = g[[1, 5, 2]]
    @test gind1.labels == [1, 5, 2]

    gind2 = g[[Edge(1, 2), Edge(1, 4)]]
    @test gind2.labels == [1, 2, 4]
end