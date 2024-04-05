module NautyGraphs

include("utils.jl")
include("densenautygraphs.jl")
include("nauty.jl")

export
    AbstractNautyGraph,
    NautyGraph,
    NautyDiGraph,
    labels,
    nauty,
    canonize!,
    is_isomorphic,
    ≃
end