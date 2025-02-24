module NautyGraphs

using Graphs, SparseArrays, LinearAlgebra, SHA
import nauty_jll

const libnauty = nauty_jll.libnautyTL
const WORDSIZE = 64
const WordType = Culong
#const WordType = WORDSIZE == 32 ? Cuint : WORDSIZE == 64 ? Culong : error("only wordsize 32 or 64 supported") 
const Cbool = Cint
const HashType = UInt

include("densenautygraphs.jl")
include("utils.jl")
include("bitutils.jl")
include("nauty.jl")

const NautyGraph = DenseNautyGraph{false}
const NautyDiGraph = DenseNautyGraph{true}

function __init__()
    # global default options to nauty carry a pointer reference that needs to be initialized at runtime
    libnauty_dispatch = cglobal((:dispatch_graph, libnauty), Cvoid)
    DEFAULT_OPTIONS.dispatch = libnauty_dispatch
    return
end

export
    AbstractNautyGraph,
    NautyGraph,
    NautyDiGraph,
    AutomorphismGroup,
    labels,
    nauty,
    canonize!,
    canonical_permutation,
    is_isomorphic,
    ≃,
    ghash
end
