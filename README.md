# NautyGraphs.jl
NautyGraphs.jl is a simple Julia interface to _nauty_ that allows for efficient isomorphism checking, canonical labeling, and hashing of vertex-labeled graphs.
## Installation
To install NautyGraphs.jl from the Julia REPL, enter `]` to enter Pkg mode, and then run
```
pkg> add https://github.com/maxhbl/NautyGraphs.jl
```
## Basic Usage
NautyGraphs.jl defines the `NautyGraph` or `NautyDiGraph` graph formats, which are compatible with the Graphs.jl API.
```
using Graphs
using NautyGraphs

g = NautyGraph(4)
for edge in [(1, 2), (2, 3), (2, 4), (3, 4)]
  add_edge!(g, edge...)
end

h = NautyGraph(4)
for edge in [(2, 4), (4, 1), (4, 3), (1, 3)]
  add_edge!(h, edge...)
end
```
To check two graphs for isomorphism, use `is_isomorphic` or `≃` (`\simeq`):
```
julia> adjacency_matrix(g) == adjacency_matrix(h)
false

julia> g ≃ h
true
```
Isomorphisms are computed by comparing graph hashes.
```
julia> hash(g)
0x3127d9b726f2c846
julia> hash(h)
0x3127d9b726f2c846
```
If you want to reorder a graph's vertices in the canonical order, use `canonize!(g)`. This will also return the canonical label and the size of the automorphism group:
```
julia> canonize!(g)
([1, 3, 4, 2], 2)

julia> canonize!(h)
([2, 1, 3, 4], 2)

julia> adjacency_matrix(g) == adjacency_matrix(h)
true
```
