using BenchmarkTools
using NautyGraphs, Graphs
using Random

# Benchmark common graph operations on NautyGraphs against standard Graphs

symmetrize_adjmx(A) = (A = convert(typeof(A), (A + A') .> 0); for i in axes(A, 1); A[i, i] = 0; end; A)
function isomorphism_benchmark(rng, graph_gen, args...; n, random_gen=true, digraph=false)
    gs = random_gen ? [graph_gen(args...; rng=rng) for _ in 1:n] : [graph_gen(args...) for _ in 1:n]
    gps = []

    ngs = []
    ngps = []

    for g in gs
        admx = adjacency_matrix(g)
        perm = shuffle(rng, collect(1:size(admx, 1)))
        admx_perm = admx[perm, perm]
        
        if digraph
            gperm = DiGraph(admx_perm)
            ng = NautyDiGraph(g)
            ngperm = NautyDiGraph(gperm)
        else
            gperm = Graph(admx_perm)
            ng = NautyGraph(g)
            ngperm = NautyGraph(gperm)
        end

        push!(gps, gperm)
        push!(ngs, ng)
        push!(ngps, ngperm)
    end
    nautygraph_benchs = @benchmarkable foreach(a->(is_isomorphic(a[1], a[2]); a[1].hashval=nothing; a[2].hashval=nothing;), zip($ngs, $ngps))
    graph_benchs = @benchmarkable foreach(a->Graphs.Experimental.has_isomorph(a[1], a[2]), zip($gs, $gps))

    return nautygraph_benchs, graph_benchs
end

begin # SETUP
    rng = Random.Random.MersenneTwister(0) # Use MersenneTwister for Julia 1.6 compat
    A10 = symmetrize_adjmx(rand(rng, [0, 1], 10, 10))
    A100 = symmetrize_adjmx(rand(rng, [0, 1], 100, 100))
    A1000 = symmetrize_adjmx(rand(rng, [0, 1], 1000, 1000))

    ng10 = NautyGraph(A10)
    ng100 = NautyGraph(A100)
    ng1000 = NautyGraph(A1000)
    g10 = Graph(A10)
    g100 = Graph(A100)
    g1000 = Graph(A1000)

    SUITE = BenchmarkGroup()
    nautygraphs = SUITE["nautygraphs"] = BenchmarkGroup()
    graphs = SUITE["graphs"] = BenchmarkGroup()
end

begin # GRAPH CREATION
    nautygraphs["creation"] = BenchmarkGroup()
    graphs["creation"] = BenchmarkGroup()

    nautygraphs["creation"]["create_empty10"] = @benchmarkable NautyGraph(10)
    nautygraphs["creation"]["create_empty100"] = @benchmarkable NautyGraph(100)
    nautygraphs["creation"]["create_empty1000"] = @benchmarkable NautyGraph(1000)

    graphs["creation"]["create_empty10"] = @benchmarkable Graph(10)
    graphs["creation"]["create_empty100"] = @benchmarkable Graph(100)
    graphs["creation"]["create_empty1000"] = @benchmarkable Graph(1000)

    nautygraphs["creation"]["create_fromA10"] = @benchmarkable NautyGraph($A10)
    nautygraphs["creation"]["create_fromA100"] = @benchmarkable NautyGraph($A100)
    nautygraphs["creation"]["create_fromA1000"] = @benchmarkable NautyGraph($A1000)

    graphs["creation"]["create_fromA10"] = @benchmarkable Graph($A10)
    graphs["creation"]["create_fromA100"] = @benchmarkable Graph($A100)
    graphs["creation"]["create_fromA1000"] = @benchmarkable Graph($A1000)
end

begin # GRAPH METHODS
    nautygraphs["methods"] = BenchmarkGroup()
    graphs["methods"] = BenchmarkGroup()

    nautygraphs["methods"]["edges10"] = @benchmarkable edges($ng10)
    nautygraphs["methods"]["edges100"] = @benchmarkable edges($ng100)
    nautygraphs["methods"]["edges1000"] = @benchmarkable edges($ng1000)

    nautygraphs["methods"]["has_edge10"] = @benchmarkable has_edge($ng10, 5, 10)
    nautygraphs["methods"]["has_edge100"] = @benchmarkable has_edge($ng100, 5, 10)
    nautygraphs["methods"]["has_edge1000"] = @benchmarkable has_edge($ng1000, 5, 10)

    nautygraphs["methods"]["has_vertex10"] = @benchmarkable has_vertex($ng10, 5)
    nautygraphs["methods"]["has_vertex100"] = @benchmarkable has_vertex($ng100, 5)
    nautygraphs["methods"]["has_vertex1000"] = @benchmarkable has_vertex($ng1000, 5)

    nautygraphs["methods"]["inneighbors10"]  = @benchmarkable inneighbors($ng10, 5)
    nautygraphs["methods"]["inneighbors100"] = @benchmarkable inneighbors($ng100, 5)
    nautygraphs["methods"]["inneighbors1000"] = @benchmarkable inneighbors($ng1000, 5)

    nautygraphs["methods"]["outneighbors10"]  = @benchmarkable outneighbors($ng10, 5)
    nautygraphs["methods"]["outneighbors100"] = @benchmarkable outneighbors($ng100, 5)
    nautygraphs["methods"]["outneighbors1000"] = @benchmarkable outneighbors($ng1000, 5)

    nautygraphs["methods"]["indegree10"]  = @benchmarkable indegree($ng10, 5)
    nautygraphs["methods"]["indegree100"] = @benchmarkable indegree($ng100, 5)
    nautygraphs["methods"]["indegree1000"] = @benchmarkable indegree($ng1000, 5)

    nautygraphs["methods"]["outdegree10"]  = @benchmarkable outdegree($ng10, 5)
    nautygraphs["methods"]["outdegree100"] = @benchmarkable outdegree($ng100, 5)
    nautygraphs["methods"]["outdegree1000"] = @benchmarkable outdegree($ng1000, 5)

    nautygraphs["methods"]["ne10"]  = @benchmarkable ne($ng10)
    nautygraphs["methods"]["ne100"] = @benchmarkable ne($ng100)
    nautygraphs["methods"]["ne1000"] = @benchmarkable ne($ng1000)

    nautygraphs["methods"]["nv10"]  = @benchmarkable nv($ng10)
    nautygraphs["methods"]["nv100"] = @benchmarkable nv($ng100)
    nautygraphs["methods"]["nv1000"] = @benchmarkable nv($ng1000)

    nautygraphs["methods"]["vertices10"]  = @benchmarkable vertices($ng10)
    nautygraphs["methods"]["vertices100"] = @benchmarkable vertices($ng100)
    nautygraphs["methods"]["vertices1000"] = @benchmarkable vertices($ng1000)

    nautygraphs["methods"]["adjmx10"]  = @benchmarkable adjacency_matrix($ng10)
    nautygraphs["methods"]["adjmx100"] = @benchmarkable adjacency_matrix($ng100)
    nautygraphs["methods"]["adjmx1000"] = @benchmarkable adjacency_matrix($ng1000)

    ###############################################################################

    graphs["methods"]["edges10"] = @benchmarkable edges($g10)
    graphs["methods"]["edges100"] = @benchmarkable edges($g100)
    graphs["methods"]["edges1000"] = @benchmarkable edges($g1000)

    graphs["methods"]["has_edge10"] = @benchmarkable has_edge($g10, 5, 10)
    graphs["methods"]["has_edge100"] = @benchmarkable has_edge($g100, 5, 10)
    graphs["methods"]["has_edge1000"] = @benchmarkable has_edge($g1000, 5, 10)

    graphs["methods"]["has_vertex10"] = @benchmarkable has_vertex($g10, 5)
    graphs["methods"]["has_vertex100"] = @benchmarkable has_vertex($g100, 5)
    graphs["methods"]["has_vertex1000"] = @benchmarkable has_vertex($g1000, 5)

    graphs["methods"]["inneighbors10"]  = @benchmarkable inneighbors($g10, 5)
    graphs["methods"]["inneighbors100"] = @benchmarkable inneighbors($g100, 5)
    graphs["methods"]["inneighbors1000"] = @benchmarkable inneighbors($g1000, 5)

    graphs["methods"]["outneighbors10"]  = @benchmarkable outneighbors($g10, 5)
    graphs["methods"]["outneighbors100"] = @benchmarkable outneighbors($g100, 5)
    graphs["methods"]["outneighbors1000"] = @benchmarkable outneighbors($g1000, 5)

    graphs["methods"]["indegree10"]  = @benchmarkable indegree($g10, 5)
    graphs["methods"]["indegree100"] = @benchmarkable indegree($g100, 5)
    graphs["methods"]["indegree1000"] = @benchmarkable indegree($g1000, 5)

    graphs["methods"]["outdegree10"]  = @benchmarkable outdegree($g10, 5)
    graphs["methods"]["outdegree100"] = @benchmarkable outdegree($g100, 5)
    graphs["methods"]["outdegree1000"] = @benchmarkable outdegree($g1000, 5)

    graphs["methods"]["ne10"]  = @benchmarkable ne($g10)
    graphs["methods"]["ne100"] = @benchmarkable ne($g100)
    graphs["methods"]["ne1000"] = @benchmarkable ne($g1000)

    graphs["methods"]["nv10"]  = @benchmarkable nv($g10)
    graphs["methods"]["nv100"] = @benchmarkable nv($g100)
    graphs["methods"]["nv1000"] = @benchmarkable nv($g1000)

    graphs["methods"]["vertices10"]  = @benchmarkable vertices($g10)
    graphs["methods"]["vertices100"] = @benchmarkable vertices($g100)
    graphs["methods"]["vertices1000"] = @benchmarkable vertices($g1000)

    graphs["methods"]["adjmx10"]  = @benchmarkable adjacency_matrix($g10)
    graphs["methods"]["adjmx100"] = @benchmarkable adjacency_matrix($g100)
    graphs["methods"]["adjmx1000"] = @benchmarkable adjacency_matrix($g1000)
end

begin # MODIFY
    nautygraphs["modify"] = BenchmarkGroup()
    graphs["modify"] = BenchmarkGroup()

    nautygraphs["modify"]["add_edge10"] = @benchmarkable add_edge!(gg, 2, 8) setup=(gg=copy(ng10)) evals=1
    nautygraphs["modify"]["add_edge100"] = @benchmarkable add_edge!(gg, 2, 8) setup=(gg=copy(ng100)) evals=1
    nautygraphs["modify"]["add_edge1000"] = @benchmarkable add_edge!(gg, 2, 8) setup=(gg=copy(ng100)) evals=1

    nautygraphs["modify"]["add_vertex10"] = @benchmarkable add_vertex!(gg) setup=(gg=copy(ng10)) evals=1
    nautygraphs["modify"]["add_vertex100"] = @benchmarkable add_vertex!(gg) setup=(gg=copy(ng100)) evals=1
    nautygraphs["modify"]["add_vertex1000"] = @benchmarkable add_vertex!(gg) setup=(gg=copy(ng1000)) evals=1

    nautygraphs["modify"]["add_vertices10"] = @benchmarkable add_vertices!(gg, 10) setup=(gg=copy(ng10)) evals=1
    nautygraphs["modify"]["add_vertices100"] = @benchmarkable add_vertices!(gg, 100) setup=(gg=copy(ng100)) evals=1
    nautygraphs["modify"]["add_vertices1000"] = @benchmarkable add_vertices!(gg, 1000) setup=(gg=copy(ng1000)) evals=1

    foreach(g->add_edge!(g, 2, 8), [ng10, ng100, ng1000])

    nautygraphs["modify"]["rem_edge10"] = @benchmarkable rem_edge!(gg, 2, 8) setup=(gg=copy($ng10)) evals=1
    nautygraphs["modify"]["rem_edge100"] = @benchmarkable rem_edge!(gg, 2, 8) setup=(gg=copy($ng100)) evals=1
    nautygraphs["modify"]["rem_edge1000"] = @benchmarkable rem_edge!(gg, 2, 8) setup=(gg=copy($ng100)) evals=1

    nautygraphs["modify"]["rem_vertex10"] = @benchmarkable rem_vertex!(gg, 5) setup=(gg=copy($ng10)) evals=1
    nautygraphs["modify"]["rem_vertex100"] = @benchmarkable rem_vertex!(gg, 50) setup=(gg=copy($ng100)) evals=1
    nautygraphs["modify"]["rem_vertex1000"] = @benchmarkable rem_vertex!(gg, 500) setup=(gg=copy($ng1000)) evals=1

    nautygraphs["modify"]["rem_vertices10"] = @benchmarkable rem_vertices!(gg, [1, 5, 8]) setup=(gg=copy($ng10)) evals=1
    nautygraphs["modify"]["rem_vertices100"] = @benchmarkable rem_vertices!(gg, [1, 50, 80]) setup=(gg=copy($ng100)) evals=1
    nautygraphs["modify"]["rem_vertices1000"] = @benchmarkable rem_vertices!(gg, [1, 500, 800]) setup=(gg=copy($ng1000)) evals=1

    ######################################################

    graphs["modify"]["add_edge10"] = @benchmarkable add_edge!(gg, 2, 8) setup=(gg=copy($g10)) evals=1
    graphs["modify"]["add_edge100"] = @benchmarkable add_edge!(gg, 2, 8) setup=(gg=copy($g100)) evals=1
    graphs["modify"]["add_edge1000"] = @benchmarkable add_edge!(gg, 2, 8) setup=(gg=copy($g100)) evals=1

    graphs["modify"]["add_vertex10"] = @benchmarkable add_vertex!(gg) setup=(gg=copy($g10)) evals=1
    graphs["modify"]["add_vertex100"] = @benchmarkable add_vertex!(gg) setup=(gg=copy($g100)) evals=1
    graphs["modify"]["add_vertex1000"] = @benchmarkable add_vertex!(gg) setup=(gg=copy($g1000)) evals=1

    graphs["modify"]["add_vertices10"] = @benchmarkable add_vertices!(gg, 10) setup=(gg=copy($g10)) evals=1
    graphs["modify"]["add_vertices100"] = @benchmarkable add_vertices!(gg, 100) setup=(gg=copy($g100)) evals=1
    graphs["modify"]["add_vertices1000"] = @benchmarkable add_vertices!(gg, 1000) setup=(gg=copy($g1000)) evals=1

    foreach(g->add_edge!(g, 2, 8), [g10, g100, g1000])

    graphs["modify"]["rem_edge10"] = @benchmarkable rem_edge!(gg, 2, 8) setup=(gg=copy($g10)) evals=1
    graphs["modify"]["rem_edge100"] = @benchmarkable rem_edge!(gg, 2, 8) setup=(gg=copy($g100)) evals=1
    graphs["modify"]["rem_edge1000"] = @benchmarkable rem_edge!(gg, 2, 8) setup=(gg=copy($g100)) evals=1

    graphs["modify"]["rem_vertex10"] = @benchmarkable rem_vertex!(gg, 5) setup=(gg=copy($g10)) evals=1
    graphs["modify"]["rem_vertex100"] = @benchmarkable rem_vertex!(gg, 50) setup=(gg=copy($g100)) evals=1
    graphs["modify"]["rem_vertex1000"] = @benchmarkable rem_vertex!(gg, 500) setup=(gg=copy($g1000)) evals=1

    graphs["modify"]["rem_vertices10"] = @benchmarkable rem_vertices!(gg, [1, 5, 8]) setup=(gg=copy($g10)) evals=1
    graphs["modify"]["rem_vertices100"] = @benchmarkable rem_vertices!(gg, [1, 50, 80]) setup=(gg=copy($g100)) evals=1
    graphs["modify"]["rem_vertices1000"] = @benchmarkable rem_vertices!(gg, [1, 500, 800]) setup=(gg=copy($g1000)) evals=1
end

begin # ISOMORPHISM
    nautygraphs["isomorphism"] = BenchmarkGroup()
    graphs["isomorphism"] = BenchmarkGroup()

    nautygraphs["isomorphism"]["erdos_renyi10"], graphs["isomorphism"]["erdos_renyi10"] = isomorphism_benchmark(rng, erdos_renyi, 10, 0.5; n=100)
    nautygraphs["isomorphism"]["erdos_renyi100"], graphs["isomorphism"]["erdos_renyi100"] = isomorphism_benchmark(rng, erdos_renyi, 100, 0.05; n=100)
    nautygraphs["isomorphism"]["erdos_renyi1000"], graphs["isomorphism"]["erdos_renyi1000"] = isomorphism_benchmark(rng, erdos_renyi, 1000, 0.005; n=100)

    nautygraphs["isomorphism"]["regular10_3"], graphs["isomorphism"]["regular10_3"] = isomorphism_benchmark(rng, random_regular_graph, 10, 3; n=100)
    nautygraphs["isomorphism"]["regular100_3"], graphs["isomorphism"]["regular100_3"] = isomorphism_benchmark(rng, random_regular_graph, 100, 3; n=100)

    nautygraphs["isomorphism"]["regular10_8"], graphs["isomorphism"]["regular10_8"] = isomorphism_benchmark(rng, random_regular_graph, 10, 8; n=100)
    nautygraphs["isomorphism"]["regular100_8"], graphs["isomorphism"]["regular100_8"] = isomorphism_benchmark(rng, random_regular_graph, 100, 8; n=100)

    nautygraphs["isomorphism"]["binary_tree4"], graphs["isomorphism"]["binary_tree4"] = isomorphism_benchmark(rng, binary_tree, 4; n=100, random_gen=false)
    nautygraphs["isomorphism"]["binary_tree8"], graphs["isomorphism"]["binary_tree8"] = isomorphism_benchmark(rng, binary_tree, 8; n=100, random_gen=false)

    nautygraphs["isomorphism"]["uniform_tree10"], graphs["isomorphism"]["uniform_tree10"] = isomorphism_benchmark(rng, uniform_tree, 10; n=100)
    nautygraphs["isomorphism"]["uniform_tree100"], graphs["isomorphism"]["uniform_tree100"] = isomorphism_benchmark(rng, uniform_tree, 100; n=100)
    nautygraphs["isomorphism"]["uniform_tree1000"], graphs["isomorphism"]["uniform_tree1000"] = isomorphism_benchmark(rng, uniform_tree, 1000; n=100)

    nautygraphs["isomorphism"]["grid5"], graphs["isomorphism"]["grid5"] = isomorphism_benchmark(rng, grid, [5, 5]; n=100, random_gen=false)
    nautygraphs["isomorphism"]["grid10"], graphs["isomorphism"]["grid10"] = isomorphism_benchmark(rng, grid, [10, 10]; n=100, random_gen=false)
    nautygraphs["isomorphism"]["grid20"], graphs["isomorphism"]["grid20"] = isomorphism_benchmark(rng, grid, [20, 20]; n=100, random_gen=false)
end

begin # EVAL
    res = BenchmarkTools.run(SUITE, verbose=true)
    mgraphs = median(res["graphs"])
    mnautygraphs = median(res["nautygraphs"])
    compare = judge(mnautygraphs, mgraphs)
end
