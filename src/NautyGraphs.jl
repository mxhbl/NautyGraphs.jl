module NautyGraphs

include("utils.jl")
include("densenautygraphs.jl")
include("nauty.jl")

export
    AbstractNautyGraph,
    AbstractDenseNautyGraph,
    DenseNautyGraph,
    DirectedDenseNautyGraph,
    blockdiag,
    nauty,
    canonize!
end