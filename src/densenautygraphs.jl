# This is a simple wrapper for Nauty
using Graphs
using SparseArrays

abstract type AbstractNautyGraph{T} <: AbstractGraph{T} end
abstract type AbstractDenseNautyGraph{T} <: AbstractNautyGraph{T} end
#TODO: abstract type AbstractSparseNautyGraph{T} <: AbstractNautyGraph{T} end

mutable struct DenseNautyGraph{T<:Cint} <: AbstractDenseNautyGraph{T}
    graphset::Vector{WordType}
    n_vertices::T
    n_edges::T
    n_words::T
    labels::Vector{T}
    hashval::Union{HashType,Nothing}
end
function DenseNautyGraph(n::Integer, vertex_labels::Union{Vector{<:Integer},Nothing}=nothing)
    m = ceil(Cint, n / WORDSIZE)
    graphset = zeros(WordType, Int(n * m))
    if isnothing(vertex_labels)
        labels = zeros(Cint, n)
    else
        labels = convert(Vector{Cint}, vertex_labels)
    end
    hashval = nothing
    return DenseNautyGraph{Cint}(graphset, Cint(n), zero(Cint), Cint(m), labels, hashval)
end
DenseNautyGraph{Cint}(args...) = DenseNautyGraph(args...)
function DenseNautyGraph(adjmx::AbstractMatrix, vertex_labels::Union{Vector{<:Integer},Nothing}=nothing)
    n, _n = size(adjmx)
    @assert n == _n
    @assert adjmx == adjmx'

    graphset, m = adjmatrix_to_graphset(adjmx)
    if isnothing(vertex_labels)
        labels = zeros(Cint, n)
    else
        labels = convert(Vector{Cint}, vertex_labels)
    end
    n_edges = sum(adjmx) // 2
    return DenseNautyGraph{Cint}(graphset, Cint(n), Cint(n_edges), Cint(m), labels, nothing)
end

mutable struct DirectedDenseNautyGraph{T<:Cint} <: AbstractDenseNautyGraph{T}
    graphset::Vector{WordType}
    n_vertices::T
    n_edges::T
    n_words::T
    labels::Vector{T}
    hashval::Union{HashType,Nothing}
end
function DirectedDenseNautyGraph(n::Integer, vertex_labels::Union{Vector{<:Integer},Nothing}=nothing)
    m = ceil(Cint, n / WORDSIZE)
    graphset = zeros(WordType, Int(n * m))
    if isnothing(vertex_labels)
        labels = zeros(Cint, n)
    else
        labels = convert(Vector{Cint}, vertex_labels)
    end
    hashval = nothing
    return DirectedDenseNautyGraph{Cint}(graphset, Cint(n), zero(Cint), Cint(m), labels, hashval)
end
DirectedDenseNautyGraph{Cint}(args...) = DirectedDenseNautyGraph(args...)
function DirectedDenseNautyGraph(adjmx::AbstractMatrix, vertex_labels::Union{Vector{<:Integer},Nothing}=nothing)
    n, _n = size(adjmx)
    @assert n == _n

    graphset, m = adjmatrix_to_graphset(adjmx)
    if isnothing(vertex_labels)
        labels = zeros(Cint, n)
    else
        labels = convert(Vector{Cint}, vertex_labels)
    end
    n_edges = sum(adjmx)
    return DirectedDenseNautyGraph{Cint}(graphset, Cint(n), Cint(n_edges), Cint(m), labels, nothing)
end

# Create Identical structs for DenseNautyGraph and DirectedDenseNautyGraph
for nauty_graph_type in (:DenseNautyGraph, :DirectedDenseNautyGraph)
    @eval begin
        $nauty_graph_type(g::AbstractGraph, vertex_labels::Union{Vector{<:Integer},Nothing}=nothing) = 
            $nauty_graph_type(adjacency_matrix(g), vertex_labels)
    end
end

Base.copy(g::G) where {G<:AbstractDenseNautyGraph} = G(copy(g.graphset), g.n_vertices, g.n_edges, g.n_words, copy(g.labels), g.hashval)
function Base.copy!(dest::G, src::G) where {G<:AbstractDenseNautyGraph}
    copy!(dest.graphset, src.graphset)
    copy!(dest.labels, src.labels)
    dest.n_vertices = src.n_vertices
    dest.n_edges = src.n_edges
    dest.n_words = src.n_words
    dest.hashval = src.hashval
    return dest
end

Base.show(io::Core.IO, g::DenseNautyGraph) = println(io, "{$(nv(g)), $(ne(g))} undirected NautyGraph")
Base.show(io::Core.IO, g::DirectedDenseNautyGraph) = println(io, "{$(nv(g)), $(ne(g))} directed NautyGraph")

Graphs.nv(g::AbstractDenseNautyGraph) = g.n_vertices
Graphs.ne(g::AbstractDenseNautyGraph) = g.n_edges
Graphs.vertices(g::AbstractDenseNautyGraph) = Base.OneTo(nv(g))
Graphs.has_vertex(g::AbstractDenseNautyGraph, v) = v ∈ vertices(g)
function Graphs.has_edge(g::AbstractDenseNautyGraph, s::Integer, d::Integer)
    i_row = s
    i_col = 1 + (d - 1) ÷ WORDSIZE
    k = mod1(d, WORDSIZE)
    i_vec = _to_vecidx(i_row, i_col, g.n_words)
    return has_bit(g.graphset[i_vec], k)
end
function Graphs.outdegree(g::AbstractDenseNautyGraph, v::Integer)
    m = g.n_words
    i = _to_vecidx(v, 1, m)
    return sum(count_bits, @view g.graphset[i:i+m-1])
end
function Graphs.outneighbors(g::AbstractDenseNautyGraph, v::Integer)
    neighs = zeros(Int, nv(g))
    k = outneighbors!(neighs, g, v)
    resize!(neighs, k)
    return neighs
end
function outneighbors!(neighs::AbstractVector{<:Integer}, g::AbstractDenseNautyGraph, v::Integer)
    m = g.n_words
    i = _to_vecidx(v, 1, m)
    return set_to_idxs!((@view g.graphset[i:i+m-1]), neighs, true)
end

function Graphs.indegree(g::AbstractDenseNautyGraph, v::Integer)
    m = g.n_words
    i_col = 1 + (v - 1) ÷ WORDSIZE
    vmod = mod1(v, WORDSIZE)

    idx_convert(i) = _to_vecidx(i, i_col, m)
    counter(i) = has_bit(g.graphset[idx_convert(i)], vmod)
    return sum(counter, 1:nv(g))
end
function Graphs.inneighbors(g::AbstractDenseNautyGraph, v::Integer)
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

Graphs.is_directed(::Type{<:DenseNautyGraph}) = false
Graphs.is_directed(::Type{<:DirectedDenseNautyGraph}) = true
Graphs.edgetype(::AbstractNautyGraph{T}) where {T} = Edge{T}
Base.eltype(::AbstractNautyGraph) = WordType
Base.zero(::G) where {G<:AbstractNautyGraph} = G(0)

function Graphs.adjacency_matrix(g::AbstractDenseNautyGraph, T::DataType=Int; dir::Symbol=:out)
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

function _directed_edges(g::AbstractDenseNautyGraph)
    n, m = g.n_vertices, g.n_words

    edges = Edge{Cint}[]
    js = zeros(Cint, WORDSIZE)
    for set_idx in eachindex(g.graphset)
        i = 1 + (set_idx - 1) ÷ m
        j0 = ((set_idx - 1) % m) * WORDSIZE

        k = word_to_idxs!(g.graphset[set_idx], js)
        js .+= j0
        for j in 1:k
            push!(edges, Edge{Cint}(i, js[j]))
        end
    end

    return edges
end

#TODO: define edgeiterator
function Graphs.edges(g::DirectedDenseNautyGraph)
    return _directed_edges(g)
end
function Graphs.edges(g::DenseNautyGraph)
    edges = _directed_edges(g)
    filter!(e -> e.src <= e.dst, edges) #TODO: optimze
    return edges
end

function modify_edge!(g::AbstractNautyGraph, e::Edge, add::Bool)
    # Adds or removes the edge e
    _, m = g.n_vertices, g.n_words
    i, j = e.src, e.dst

    set_idx = 1 + (i - 1) * m + (j - 1) ÷ WORDSIZE
    # left = 1000000000.... 
    left = one(WordType) << (WORDSIZE - 1)
    new_edge = left >> ((j - 1) % WORDSIZE)

    word_old = g.graphset[set_idx]
    if add
        g.graphset[set_idx] |= new_edge
        counter = +1
    else
        g.graphset[set_idx] &= ~new_edge
        counter = -1
    end

    return g.graphset[set_idx] != word_old
end

function Graphs.add_edge!(g::DirectedDenseNautyGraph, e::Edge)
    edge_added = modify_edge!(g, e, true)
    if edge_added
        g.n_edges += 1
        g.hashval = nothing
    end
    return edge_added
end
function Graphs.add_edge!(g::DenseNautyGraph, e::Edge)
    fwd_edge_added = modify_edge!(g, e, true)
    bwd_edge_added = modify_edge!(g, reverse(e), true)
    edge_added = fwd_edge_added && bwd_edge_added

    if edge_added
        g.n_edges += 1
        g.hashval = nothing
    end
    return edge_added
end
function Graphs.rem_edge!(g::DirectedDenseNautyGraph, e::Edge)
    edge_removed = modify_edge!(g, e, false)
    if edge_removed
        g.n_edges -= 1
        g.hashval = nothing
    end
    return edge_removed
end
function Graphs.rem_edge!(g::DenseNautyGraph, e::Edge)
    fwd_edge_removed = modify_edge!(g, e, false)
    bwd_edge_removed = modify_edge!(g, reverse(e), false)
    edge_removed = fwd_edge_removed && bwd_edge_removed

    if edge_removed
        g.n_edges -= 1
        g.hashval = nothing
    end
    return edge_removed
end
function Graphs.add_vertex!(g::AbstractDenseNautyGraph{T}, label::Union{<:Integer,Nothing}=nothing) where {T}
    if isnothing(label)
        labelled = !all(iszero, g.labels)
        labelled && error("Cannot add an unlabeled vertex to a labeled nautygraph.")
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
        push!(g.labels, convert(T, label))
    end

    g.hashval = nothing
    g.n_vertices += 1
    return true
end
function Graphs.rem_vertices!(g::AbstractDenseNautyGraph{T}, inds::AbstractVector{<:Integer}) where {T}
    n = nv(g)
    if any(inds .> n)
        return false
    end

    inds = sort(inds)
    m = g.n_words

    for i in inds
        for j in 1:n
            #TODO optimize
            rem_edge!(g, Edge(T(j), T(i)))
            rem_edge!(g, Edge(T(i), T(j)))
        end
    end

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
    return true
end
rem_vertex!(g::AbstractDenseNautyGraph, i::Integer) = rem_vertices!(g, [i])

function Graphs.blockdiag(g::G, h::G) where {G<:AbstractDenseNautyGraph}
    ng, nh = g.n_vertices, h.n_vertices
    vl = vcat(g.labels, h.labels)

    k = G(Int(ng + nh), vl)

    transfer_set!(k.graphset, g.graphset, 0, k.n_words, g.n_words)
    transfer_set!(k.graphset, h.graphset, ng * k.n_words * WORDSIZE + ng, k.n_words, h.n_words)
    k.n_edges = g.n_edges + h.n_edges
    return k
end
function blockdiag!(g::G, h::G) where {G<:AbstractDenseNautyGraph}
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

function Base.hash(g::AbstractNautyGraph)
    hashval = g.hashval
    if !isnothing(hashval)
        return hashval
    end

    # TODO: error checking and so on
    _fill_hash!(g)
    return g.hashval
end
Base.:(==)(g::AbstractNautyGraph, h::AbstractNautyGraph) = hash(g) == hash(h)