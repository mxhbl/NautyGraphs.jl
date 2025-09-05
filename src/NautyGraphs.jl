module NautyGraphs

using Graphs, LinearAlgebra
using Graphs.SimpleGraphs: SimpleEdgeIter
import nauty_jll
import xxHash_jll, SHA, Serialization

const Cbool = Cint
abstract type AbstractNautyGraph{T} <: AbstractGraph{T} end

include("utils.jl")
include("graphset.jl")
include("hashing.jl")
include("densenautygraph.jl")
include("nauty.jl")

const NautyGraph = DenseNautyGraph{false}
const NautyDiGraph = DenseNautyGraph{true}

function __init__()
    # global default options to nauty carry a pointer reference that needs to be initialized at runtime
    DEFAULTOPTIONS16.dispatch = cglobal((:dispatch_graph, libnauty(UInt16)), Cvoid)
    DEFAULTOPTIONS32.dispatch = cglobal((:dispatch_graph, libnauty(UInt32)), Cvoid)
    DEFAULTOPTIONS64.dispatch = cglobal((:dispatch_graph, libnauty(UInt64)), Cvoid)
    return
end

export
    AbstractNautyGraph,
    NautyGraph,
    NautyDiGraph,
    DenseNautyGraph,
    AutomorphismGroup,
    labels,
    nauty,
    canonize!,
    canonical_permutation,
    is_isomorphic,
    ≃,
    ghash,
    AbstractHashAlg, XXHash64Alg, XXHash128Alg, SHA64Alg, SHA128Alg, Base64Alg
end
