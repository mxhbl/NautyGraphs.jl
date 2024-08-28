module NautyGraphs

const nauty_lib = joinpath(@__DIR__, "..", "bin", "densenauty.so")
const WordType = Cuint # TODO adaptive
const Cbool = Cint
const HashType = UInt
const WORDSIZE = @ccall nauty_lib.wordsize()::Cint

include("densenautygraphs.jl")
include("utils.jl")
include("bitutils.jl")
include("nauty.jl")

const NautyGraph = DenseNautyGraph{false}
const NautyDiGraph = DenseNautyGraph{true}

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