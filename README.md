# NautyGraphs.jl
NautyGraphs.jl is a simple Julia interface to _nauty_ that allows for efficient isomorphism checking, canonical labeling, and hashing, of vertex-labeled graphs. The graph representations defined by NautyGraphs.jl are fully compatible with the [Graphs.jl](https://github.com/JuliaGraphs/Graphs.jl) API.
## Installation
To install NautyGraphs.jl from the Julia REPL, enter `]` to enter Pkg mode, and then run
```
pkg> add https://github.com/maxhbl/NautyGraphs.jl
```
## Basic Usage
NautyGraphs.jl defines the `NautyGraph` or `NautyDiGraph` graph formats, which can be constructed through a number of different ways:
```
using Graphs
using NautyGraphs

A = [0 1 0 0;
     1 0 1 1;
     0 1 0 1;
     0 1 1 0]
g = NautyGraph(A)

h = NautyGraph(4)
for edge in [(2, 4), (4, 1), (4, 3), (1, 3)]
  add_edge!(h, edge...)
end
```
To check whether two graphs are isomorphic, use `is_isomorphic` or `≃` (`\simeq`):
```
julia> adjacency_matrix(g) == adjacency_matrix(h)
false

julia> g ≃ h
true
```
If you want to reorder a graph's vertices into canonical order, use `canonize!(g)`. This will return the permutation needed to canonize `g`, as well as the size of the automorphism group:
```
julia> canonize!(g)
([1, 3, 4, 2], 2)

julia> canonize!(h)
([2, 1, 3, 4], 2)

julia> adjacency_matrix(g) == adjacency_matrix(h)
true
```
Isomorphisms are computed by comparing hashes. `hash(g)` computes the canonical representative of a graph's isomorphism class and then hashes the canonical adjacency matrix and vertex labels.
```
julia> hash(g)
0x3127d9b726f2c846
julia> hash(h)
0x3127d9b726f2c846
```
