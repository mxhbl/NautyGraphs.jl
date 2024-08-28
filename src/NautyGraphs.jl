module NautyGraphs

const nauty_lib = joinpath(@__DIR__, "..", "bin", "densenauty.so")
const WORDSIZE = @ccall nauty_lib.wordsize()::Cint
const WordType = WORDSIZE == 32 ? Cuint : WORDSIZE == 64 ? Culong : error("only wordsize 32 or 64 supported") 
const Cbool = Cint
const HashType = UInt

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