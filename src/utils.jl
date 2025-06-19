function _adjmatrix_to_graphset(A::AbstractMatrix{<:Integer})
    n, _n = size(A)
    @assert n == _n

    m = ceil(Cint, n / WORDSIZE)

    G = zeros(Cint, n, m * WORDSIZE)
    G[:, 1:n] .= A
    # Reshape the padded adjacency matrix from 
    # (a b c)
    # (d f g)
    # to
    # (a b c d f g)'
    G = reshape(G', Int(WORDSIZE), Int(n * m))'

    graphset = zeros(WordType, Int(n * m))
    for i in eachindex(graphset)
        graphset[i] = bitvec_to_word(@view G[i, :])
    end
    return graphset
end

function _directed_edges(g::DenseNautyGraph)
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

function _vertexlabels_to_labptn(labels::Vector{<:Integer})
    n = length(labels)
    lab = zeros(Cint, n)
    ptn = zeros(Cint, n)
    return _vertexlabels_to_labptn!(lab, ptn, labels)
end
function _vertexlabels_to_labptn!(lab::Vector{<:Integer}, ptn::Vector{<:Integer}, labels::Vector{<:Integer})
    lab .= 1:length(labels)
    sort!(lab, alg=QuickSort, by=k -> labels[k])
    @views lab .-= 1

    for i in 1:length(lab)-1
        ptn[i] = labels[lab[i+1]+1] == labels[lab[i]+1] ? 1 : 0
    end
    return lab, ptn
end

function _modify_edge!(g::AbstractNautyGraph, e::Edge, add::Bool)
    # Adds or removes the edge e
    n, m = g.n_vertices, g.n_words
    i, j = e.src, e.dst
    if i > n || j > n
        return false
    end

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

function hash_sha(x)
    io = IOBuffer()
    write(io, x)
    return _concatbytes(sha256(take!(io))[1:8])
end