using Graphs
using SparseArrays, LinearAlgebra

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
        if n_vertices > 0
            n_words = length(graphset) ÷ n_vertices
        else
            n_words = 1
        end

        @assert length(graphset) == n_words * n_vertices
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

function DenseNautyGraph{D}(n::Integer, vertex_labels::Union{Vector{<:Integer},Nothing}=nothing) where {D}
    !isnothing(vertex_labels) && @assert n == length(vertex_labels)
    m = ceil(Cint, n / WORDSIZE)
    graphset = zeros(WordType, Int(n * m))
    labels = _initialize_vertexlabels(n, vertex_labels)
    return DenseNautyGraph(graphset, labels, D)
end
function DenseNautyGraph{D}(adjmx::AbstractMatrix, vertex_labels::Union{Vector{<:Integer},Nothing}=nothing) where {D}
    n, _n = size(adjmx)

    # Self loops are not allowed
    @assert all(iszero, diag(adjmx))

    if !D
        @assert adjmx == adjmx'
    else
        @assert n == _n
    end
    
    graphset = _adjmatrix_to_graphset(adjmx)
    labels = _initialize_vertexlabels(n, vertex_labels)

    return DenseNautyGraph(graphset, labels, D)
end

(::Type{G})(g::AbstractGraph, vertex_labels::Union{Vector{<:Integer},Nothing}=nothing) where {G<:AbstractNautyGraph} = G(adjacency_matrix(g), vertex_labels)

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

    function Graphs.adjacency_matrix(g::DenseNautyGraph, T::DataType=Int; dir::Symbol=:out)
        n = nv(g)
    
        es = _directed_edges(g)
        k = length(es)
        is, js, vals = zeros(T, k), zeros(T, k), ones(T, k)
        for (i, e) in enumerate(es)
            is[i] = e.src
            js[i] = e.dst
        end
        return sparse(is, js, vals, n, n)
    end
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
        bwd_edge_added = _modify_edge!(g, reverse(e), true)
        edge_added = fwd_edge_added && bwd_edge_added

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

    function Graphs.add_vertex!(g::DenseNautyGraph, label::Union{<:Integer,Nothing}=nothing)
        if isnothing(label)
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

        append!(g.graphset, [zero(WordType) for _ in 1:m])

        if isnothing(label)
            push!(g.labels, zero(Cint))
        else
            push!(g.labels, convert(Cint, label))
        end

        g.hashval = nothing
        g.n_vertices += 1
        return true
    end
    function Graphs.add_vertices!(g::AbstractNautyGraph, n::Integer, labels::Union{AbstractVector{<:Integer},Nothing}=nothing)
        if isnothing(labels)
            return sum([add_vertex!(g) for i in 1:n])
        end

        @assert n == length(labels)
        for l in labels
            add_vertex!(g, l)
        end
        return n
    end

    function Graphs.rem_vertices!(g::DenseNautyGraph, inds::AbstractVector{<:Integer})
        n = nv(g)
        if any(inds .> n)
            return false
        end

        inds = sort(inds)
        m = g.n_words

        i_vecs = _to_vecidx.(inds, Ref(1), m)
        deleteat!(g.graphset, Iterators.flatten(i:i+m-1 for i in sort(i_vecs)))
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

        m_new = ceil(Cint, g.n_vertices / WORDSIZE)
        if m_new < m
            deleteat!(g.graphset, Iterators.flatten(i+m_new:i+m-1 for i in 1:m:g.n_vertices*m))
            g.n_words = m_new
        end
        
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
function blockdiag!(g::G, h::G) where {G<:DenseNautyGraph}
    @assert g !== h # Make sure g and h are different objects (TODO: could be lifted)

    for i in vertices(h)
        add_vertex!(g, h.labels[i])
    end
    ng, mg = g.n_vertices, g.n_words
    nh, mh = h.n_vertices, h.n_words

    transfer_set!(g.graphset, h.graphset, (ng - nh) * mg * WORDSIZE + (ng - nh), mg, mh)
    g.n_edges += h.n_edges
    return g
end