abstract type AbstractNautyGraph <: AbstractGraph{Cint} end
# TODO: abstract type AbstractSparseNautyGraph <: AbstractNautyGraph end

mutable struct DenseNautyGraph{D} <: AbstractNautyGraph
    graphset::Vector{WordType}
    n_vertices::Cint
    n_edges::Cint
    n_words::Cint
    labels::Vector{Cint}
    hashval::Union{HashType,Nothing}

    function DenseNautyGraph(graphset, labels, directed::Bool)
        n_vertices = length(labels)
        n_words = n_vertices > 0 ? length(graphset) ÷ n_vertices : 1

        if length(graphset) != n_words * n_vertices
            error("length of `graphset` is not compatible with length of `labels`. See the nauty user guide for how to correctly construct `graphset`.")
        end

        n_edges = 0
        for word in graphset
            n_edges += count_bits(word)
        end
        if !directed
            n_edges ÷= 2
        end
        return new{directed}(graphset, n_vertices, n_edges, n_words, labels, nothing)
    end
    function DenseNautyGraph{D}(graphset, n_vertices, n_edges, n_words, labels, hashval) where {D}
        return new{D}(graphset, n_vertices, n_edges, n_words, labels, hashval)
    end
end

function DenseNautyGraph{D}(n::Integer, vertex_labels=nothing) where {D}
    if !isnothing(vertex_labels) && n != length(vertex_labels)
        error("Incompatible length: `vertex_labels` has length $(length(vertex_labels)) instead of `n=$n`.")
    end
    m = ceil(Cint, n / WORDSIZE)
    graphset = zeros(WordType, Int(n * m))
    labels = isnothing(vertex_labels) ? zeros(Cint, n) : convert(Vector{Cint}, vertex_labels)
    return DenseNautyGraph(graphset, labels, D)
end
function DenseNautyGraph{D}(adjmx::AbstractMatrix, vertex_labels=nothing) where {D}
    n, n2 = size(adjmx)

    if !D
        !issymmetric(adjmx) && error("Cannot create an undirected NautyGraph from a non-symmetric adjacency matrix. Make sure the adjacency matrix is square symmetric!")
    else
        n != n2 && error("Cannot create a NautyGraph from a rectangular matrix. Make sure the adjacency matrix is square!")
    end
    
    graphset = _adjmatrix_to_graphset(adjmx)
    labels = isnothing(vertex_labels) ? zeros(Cint, n) : convert(Vector{Cint}, vertex_labels)

    return DenseNautyGraph(graphset, labels, D)
end

function (::Type{G})(g::AbstractGraph, vertex_labels=nothing) where {G<:AbstractNautyGraph}
    if is_directed(g) != is_directed(G)
        error("Cannot create an undirected NautyGraph from a directed graph (or vice versa). Please make sure the directedness of the graph types is matching.")
    end

    ng = G(nv(g), vertex_labels)

    for e in edges(g)
        add_edge!(ng, e)
    end
    return ng
end

Base.copy(g::G) where {G<:DenseNautyGraph} = G(copy(g.graphset), g.n_vertices, g.n_edges, g.n_words, copy(g.labels), g.hashval)
function Base.copy!(dest::G, src::G) where {G<:DenseNautyGraph}
    copy!(dest.graphset, src.graphset)
    copy!(dest.labels, src.labels)
    dest.n_vertices = src.n_vertices
    dest.n_edges = src.n_edges
    dest.n_words = src.n_words
    dest.hashval = src.hashval
    return dest
end

Base.show(io::Core.IO, g::DenseNautyGraph{false}) = print(io, "{$(nv(g)), $(ne(g))} undirected NautyGraph")
Base.show(io::Core.IO, g::DenseNautyGraph{true}) = print(io, "{$(nv(g)), $(ne(g))} directed NautyGraph")

Base.hash(g::DenseNautyGraph, h::UInt) = hash(g.labels, hash(g.graphset, h))
Base.:(==)(g::DenseNautyGraph, h::DenseNautyGraph) = (g.graphset == h.graphset) && (g.labels == h.labels)

begin # BASIC GRAPH API
    labels(g::AbstractNautyGraph) = g.labels
    Graphs.nv(g::DenseNautyGraph) = g.n_vertices
    Graphs.ne(g::DenseNautyGraph) = g.n_edges
    Graphs.vertices(g::DenseNautyGraph) = Base.OneTo(nv(g))
    Graphs.has_vertex(g::DenseNautyGraph, v) = v ∈ vertices(g)
    function Graphs.has_edge(g::DenseNautyGraph, s::Integer, d::Integer)
        i_row = s
        i_col = 1 + (d - 1) ÷ WORDSIZE
        k = mod1(d, WORDSIZE)
        i_vec = _to_vecidx(i_row, i_col, g.n_words)
        return has_bit(g.graphset[i_vec], k)
    end
    function Graphs.outdegree(g::DenseNautyGraph, v::Integer)
        m = g.n_words
        i = _to_vecidx(v, 1, m)
        return sum(count_bits, @view g.graphset[i:i+m-1])
    end
    function Graphs.outneighbors(g::DenseNautyGraph, v::Integer)
        neighs = zeros(Int, nv(g))
        k = outneighbors!(neighs, g, v)
        resize!(neighs, k)
        return neighs
    end
    function outneighbors!(neighs::AbstractVector{<:Integer}, g::DenseNautyGraph, v::Integer)
        m = g.n_words
        i = _to_vecidx(v, 1, m)
        return set_to_idxs!((@view g.graphset[i:i+m-1]), neighs, true)
    end
    function Graphs.indegree(g::DenseNautyGraph, v::Integer)
        m = g.n_words
        i_col = 1 + (v - 1) ÷ WORDSIZE
        vmod = mod1(v, WORDSIZE)

        idx_convert(i) = _to_vecidx(i, i_col, m)
        counter(i) = has_bit(g.graphset[idx_convert(i)], vmod)
        return sum(counter, 1:nv(g))
    end
    function Graphs.inneighbors(g::DenseNautyGraph, v::Integer)
        i_col = 1 + (v - 1) ÷ WORDSIZE
        idxs = _to_vecidx.(1:nv(g), Ref(i_col), Ref(g.n_words))

        neighs = zeros(Cint, nv(g))
        k = 1
        vmod = mod1(v, WORDSIZE)
        for (i, word) in enumerate(@view g.graphset[idxs])
            if has_bit(word, vmod)
                neighs[k] = i
                k += 1
            end
        end
        resize!(neighs, k - 1)
        return neighs
    end
    function Graphs.edges(g::DenseNautyGraph{true})
        #TODO: define edgeiterator
        return _directed_edges(g)
    end
    function Graphs.edges(g::DenseNautyGraph{false})
        edges = _directed_edges(g)
        filter!(e -> e.src <= e.dst, edges) #TODO: optimize
        return edges
    end

    Graphs.is_directed(::Type{<:DenseNautyGraph{D}}) where {D} = D
    Graphs.edgetype(::AbstractNautyGraph) = Edge{Cint}
    Base.eltype(::AbstractNautyGraph) = Cint
    Base.zero(::G) where {G<:AbstractNautyGraph} = G(0)
    Base.zero(::Type{G}) where {G<:AbstractNautyGraph} = G(0)

    function _induced_subgraph(g::DenseNautyGraph, iter)
        h, vmap = invoke(Graphs.induced_subgraph, Tuple{AbstractGraph,typeof(iter)}, g, iter)
        @views h.labels .= g.labels[vmap]
        return h, vmap
    end

    Graphs.induced_subgraph(g::DenseNautyGraph, iter::AbstractVector{<:Integer}) = _induced_subgraph(g::DenseNautyGraph, iter)
    Graphs.induced_subgraph(g::DenseNautyGraph, iter::AbstractVector{Bool}) = _induced_subgraph(g::DenseNautyGraph, iter)
    Graphs.induced_subgraph(g::DenseNautyGraph, iter::AbstractVector{<:AbstractEdge}) = _induced_subgraph(g::DenseNautyGraph, iter)
end

begin # GRAPH MODIFY METHODS
    function Graphs.add_edge!(g::DenseNautyGraph{true}, e::Edge)
        edge_added = _modify_edge!(g, e, true)
        if edge_added
            g.n_edges += 1
            g.hashval = nothing
        end
        return edge_added
    end
    function Graphs.add_edge!(g::DenseNautyGraph{false}, e::Edge)
        fwd_edge_added = _modify_edge!(g, e, true)

        if e.src != e.dst
            bwd_edge_added = _modify_edge!(g, reverse(e), true)
            edge_added = fwd_edge_added && bwd_edge_added
        else
            edge_added = fwd_edge_added
        end

        if edge_added
            g.n_edges += 1
            g.hashval = nothing
        end
        return edge_added
    end
    Graphs.add_edge!(g::AbstractNautyGraph, i::Integer, j::Integer) = Graphs.add_edge!(g, Graphs.Edge{Cint}(i, j))

    function Graphs.rem_edge!(g::DenseNautyGraph{true}, e::Edge)
        edge_removed = _modify_edge!(g, e, false)
        if edge_removed
            g.n_edges -= 1
            g.hashval = nothing
        end
        return edge_removed
    end
    function Graphs.rem_edge!(g::DenseNautyGraph{false}, e::Edge)
        fwd_edge_removed = _modify_edge!(g, e, false)
        bwd_edge_removed = _modify_edge!(g, reverse(e), false)
        edge_removed = fwd_edge_removed && bwd_edge_removed

        if edge_removed
            g.n_edges -= 1
            g.hashval = nothing
        end
        return edge_removed
    end
    Graphs.rem_edge!(g::AbstractNautyGraph, i::Integer, j::Integer) = Graphs.rem_edge!(g, Graphs.Edge{Cint}(i, j))

    function Graphs.add_vertex!(g::DenseNautyGraph, vertex_label::Union{<:Integer,Nothing}=nothing)
        if isnothing(vertex_label)
            labeled = !all(iszero, g.labels)
            labeled && error("Cannot add an unlabeled vertex to a labeled nautygraph. Use `add_vertex!(g, label)` to add a labeled vertex.")
        end

        n = nv(g)
        m = g.n_words

        if n + 1 > m * WORDSIZE
            m = g.n_words += 1
            for i in m:m:n*m
                insert!(g.graphset, i, zero(WordType))
            end
        end

        append!(g.graphset, fill(zero(WordType), m))

        if isnothing(vertex_label)
            push!(g.labels, zero(Cint))
        else
            push!(g.labels, convert(Cint, vertex_label))
        end

        g.hashval = nothing
        g.n_vertices += 1
        return true
    end
    function Graphs.add_vertices!(g::AbstractNautyGraph, n::Integer, vertex_labels::Union{AbstractVector,Nothing}=nothing)
        if isnothing(vertex_labels)
            return sum(_->add_vertex!(g), 1:n)
        end

        n != length(vertex_labels) && error("Incompatible length: `vertex_labels` has length $(length(vertex_labels)) instead of `n=$n`.")
        for l in vertex_labels
            add_vertex!(g, l)
        end
        return n
    end

    function Graphs.rem_vertices!(g::DenseNautyGraph, inds::AbstractVector{<:Integer})
        n = nv(g)
        sort!(inds)
        if last(inds) > n
            return false
        end
        
        m = g.n_words

        i_vecs = sort!(_to_vecidx.(inds, Ref(1), m))
        deleteat!(g.graphset, Iterators.flatten(i:i+m-1 for i in i_vecs))
        # Shift all bits such that the vertices are renamed correctly
        d = 0
        for i in inds
            i -= d

            i_col = 1 + (i - 1) ÷ WORDSIZE
            k = i - (i_col - 1) * WORDSIZE
            for j in eachindex(g.graphset)
                _, j_col = _to_matrixidx(j, m)

                if j_col < i_col
                    continue
                end
                offset = j_col == i_col ? k : 0

                next_word = j_col != m ? g.graphset[j+1] : zero(WordType)
                g.graphset[j] = push_bits(g.graphset[j], next_word, WORDSIZE - offset, 1)
            end

            d += 1
        end

        deleteat!(g.labels, inds)

        g.hashval = nothing
        g.n_vertices -= length(inds)

        # Remove extra words if they are no longer needed
        # TODO: make this optional
        m_new = ceil(Cint, g.n_vertices / WORDSIZE)
        if m_new < m
            deleteat!(g.graphset, Iterators.flatten(i+m_new:i+m-1 for i in 1:m:g.n_vertices*m))
            g.n_words = m_new
        end

        # Recount edges
        n_edges = 0
        for word in g.graphset
            n_edges += count_bits(word)
        end
        if !is_directed(g)
            n_edges ÷= 2
        end
        g.n_edges = n_edges
        return true
    end
    Graphs.rem_vertex!(g::DenseNautyGraph, i::Integer) = rem_vertices!(g, [i])
end

function Graphs.blockdiag(g::G, h::G) where {G<:DenseNautyGraph}
    ng, nh = g.n_vertices, h.n_vertices
    vl = vcat(g.labels, h.labels)

    k = G(Int(ng + nh), vl)

    transfer_set!(k.graphset, g.graphset, 0, k.n_words, g.n_words)
    transfer_set!(k.graphset, h.graphset, ng * k.n_words * WORDSIZE + ng, k.n_words, h.n_words)
    k.n_edges = g.n_edges + h.n_edges
    return k
end

"""
    blockdiag!(g::G, h::G) where {G<:DenseNautyGraph}

Compute `blockdiag(g, h)` and store it in `g`, whose size is increased to accomodate it.
"""
function blockdiag!(g::G, h::G) where {G<:DenseNautyGraph}
    @assert g !== h # Make sure g and h don't alias the same memory.

    for i in vertices(h)
        add_vertex!(g, h.labels[i])
    end
    ng, mg = g.n_vertices, g.n_words
    nh, mh = h.n_vertices, h.n_words

    transfer_set!(g.graphset, h.graphset, (ng - nh) * mg * WORDSIZE + (ng - nh), mg, mh)
    g.n_edges += h.n_edges
    g.hashval = nothing
    return g
end
