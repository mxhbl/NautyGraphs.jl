mutable struct NautyOptions
    getcanon::Cint # Warning: setting getcanon to false means that nauty will NOT compute the canonical representative, which may lead to unexpected results.
    digraph::Cbool # This needs to be true if the graph is directed or has loops. Disabling this option for undirected graphs with no loops may increase performance.
    writeautoms::Cbool
    writemarkers::Cbool
    defaultptn::Cbool
    cartesian::Cbool
    linelength::Cint

    outfile::Ptr{Cvoid}
    userrefproc::Ptr{Cvoid}
    userautomproc::Ptr{Cvoid}
    userlevelproc::Ptr{Cvoid}
    usernodeproc::Ptr{Cvoid}
    usercanonproc::Ptr{Cvoid}
    invarproc::Ptr{Cvoid}

    tc_level::Cint
    mininvarlevel::Cint
    maxinvarlevel::Cint
    invararg::Cint

    dispatch::Ptr{Cvoid}

    schreier::Cbool
    extra_options::Ptr{Cvoid}

    NautyOptions(; digraph_or_loops=true, ignorelabels=false, groupinfo=false) = new(
        1, digraph_or_loops, groupinfo, false, ignorelabels, false, 78,
        C_NULL, C_NULL, C_NULL, C_NULL, C_NULL, C_NULL, C_NULL,
        100, 0, 1, 0,
        cglobal((:dispatch_graph, libnauty), Cvoid),
        false, C_NULL
    )
end

const DEFAULT_OPTIONS = NautyOptions(digraph_or_loops=true)

mutable struct NautyStatistics
    grpsize1::Cdouble
    grpsize2::Cint
    numorbits::Cint
    numgenerators::Cint
    errstatus::Cint
    numnodes::Culong
    numbadleaves::Culong
    maxlevel::Cint
    tctotal::Culong
    canupdates::Culong
    invapplics::Culong
    invsuccesses::Culong
    invarsuclevel::Cint

    NautyStatistics() = new(
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
    )
end

struct AutomorphismGroup
    n::Float64
    orbits::Vector{Cint}
    # generators::Vector{Vector{Cint}} #TODO: not implemented
end

function _densenauty(g::DenseNautyGraph, options::NautyOptions=DEFAULT_OPTIONS, statistics::NautyStatistics=NautyStatistics())
    # TODO: allow the user to pass pre-allocated arrays for lab, ptn, orbits, canong in a safe way.
    n, m = g.n_vertices, g.n_words

    lab, ptn = _vertexlabels_to_labptn(g.labels)
    orbits = zeros(Cint, n)
    canong = zero(g.graphset)

    @ccall libnauty.densenauty(
        g.graphset::Ref{WordType},
        lab::Ref{Cint},
        ptn::Ref{Cint},
        orbits::Ref{Cint},
        Ref(options)::Ref{NautyOptions},
        Ref(statistics)::Ref{NautyStatistics},
        m::Cint,
        n::Cint,
        canong::Ref{WordType})::Cvoid

    canonperm = (lab .+= 1)
    return canong, canonperm, orbits, statistics
end

function _sethash!(g::DenseNautyGraph, canong, canonperm)
    # Base.hash skips elements in arrays of length >= 8192
    # Use SHA in these cases
    canong_hash = length(canong) >= 8192 ? hash_sha(canong) : hash(canong)
    labels_hash = @views length(g.labels) >= 8192 ? hash_sha(g.labels[canonperm]) : hash(g.labels[canonperm])

    hashval = hash(labels_hash, canong_hash)
    g.hashval = hashval
    return
end
function _canonize!(g::DenseNautyGraph, canong, canonperm)
    copyto!(g.graphset, canong)
    permute!(g.labels, canonperm)
    return
end


"""
    nauty(g::AbstractNautyGraph, [options::NautyOptions]; [canonize=false])

Compute a graph `g`'s canonical form and automorphism group.
"""
function nauty(::AbstractNautyGraph, ::NautyOptions; kwargs...) end

function nauty(g::DenseNautyGraph, options::NautyOptions=DEFAULT_OPTIONS; canonize=false, compute_hash=true)
    if is_directed(g) && !isone(options.digraph)
        error("Nauty options need to match the directedness of the input graph. Make sure to instantiate options with `digraph=true` if the input graph is directed.")
    end
    if !isone(options.getcanon)
        # Right now, all implemented functionality is based on computing the canonical form, so it makes no sense to run nauty without computing it.
        error("`options.getcanon` needs to be enabled.")
    end

    canong, canonperm, orbits, statistics = _densenauty(g, options)
    # generators = Vector{Cint}[] # TODO: extract generators from nauty call
    autg = AutomorphismGroup(statistics.grpsize1 * 10^statistics.grpsize2, orbits)

    compute_hash && _sethash!(g, canong, canonperm)
    canonize && _canonize!(g, canong, canonperm)
    return canonperm, autg
end

"""
    canonize!(g::AbstractNautyGraph)

Reorder `g`'s vertices to be in canonical order. Returns the permutation `p` used to canonize `g`.
"""
function canonize!(::AbstractNautyGraph) end

function canonize!(g::DenseNautyGraph)
    canong, canonperm, _ = _densenauty(g)
    _sethash!(g, canong, canonperm)
    _canonize!(g, canong, canonperm)
    return canonperm
end

"""
    canonical_permutation(g::AbstractNautyGraph)

Return the permutation `p` needed to canonize `g`. This permutation satisfies `g[p] = canong`.
"""
function canonical_permutation(::AbstractNautyGraph) end

function canonical_permutation(g::DenseNautyGraph)
    _, canonperm, _ = _densenauty(g)
    return canonperm
end

"""
    is_isomorphic(g::AbstractNautyGraph, h::AbstractNautyGraph)

Check whether two graphs `g` and `h` are isomorphic to each other by comparing their canonical forms.
"""
function is_isomorphic(::AbstractNautyGraph, ::AbstractNautyGraph) end

function is_isomorphic(g::DenseNautyGraph, h::DenseNautyGraph)
    canong, permg, _ = _densenauty(g)
    canonh, permh, _ = _densenauty(h)
    return canong == canonh && view(g.labels, permg) == view(h.labels, permh)
end
≃(g::AbstractNautyGraph, h::AbstractNautyGraph) = is_isomorphic(g, h)


"""
    ghash(g::AbstractNautyGraph)

Hash the canonical version of `g`, so that (up to hash collisions) `ghash(g1) == ghash(g2)` implies `is_isomorphic(g1, g2) == true`.
Hashes are computed using `Base.hash` for small graphs (nv < 8192), or using the first 64 bits of `sha256` for larger graphs.
"""
function ghash(::AbstractNautyGraph) end

function ghash(g::DenseNautyGraph)
    if !isnothing(g.hashval)
        return g.hashval
    end

    canong, canonperm, _ = _densenauty(g)
    _sethash!(g, canong, canonperm)
    return g.hashval
end