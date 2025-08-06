module NautyGraphs

using Graphs, SparseArrays, LinearAlgebra, SHA
using Graphs.SimpleGraphs: SimpleEdgeIter
import nauty_jll

const Cbool = Cint
const HashType = UInt

include("utils.jl")
include("densenautygraphs.jl")
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
    ghash
end
