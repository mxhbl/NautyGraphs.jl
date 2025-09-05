mutable struct HashCache
    hash64::UInt64
    hash128::UInt128
    alg64::DataType
    alg128::DataType
    set64::Bool
    set128::Bool
end
function HashCache()
    return HashCache(0, 0, XXHash64Alg, XXHash128Alg, false, false)
end
Base.copy(hc::HashCache) = HashCache(hc.hash64, hc.hash128, hc.alg64, hc.alg128, hc.set64, hc.set128)
function Base.copy!(dest::HashCache, src::HashCache)
    dest.hash64 = src.hash64
    dest.hash128 = src.hash128
    dest.alg64 = src.alg64
    dest.alg128 = src.alg128
    dest.set64 = src.set64
    dest.set128 = src.set128
    return dest
end

# function Base.:(==)(hc1::HashCache, hc2::HashCache)
#     if hc1.set64 && hc2.set64 && hc1.alg64 == hc2.alg64
#        return hc1.hash64 == hc2.hash64
#     elseif hc1.set128 && hc2.set128 && hc1.alg128 == hc2.alg128
#         return hc1.hash128 == hc2.hash128
#     else
#         return missing
#     end
# end

abstract type AbstractHashAlg end
struct Base64Alg <: AbstractHashAlg end
struct XXHash64Alg <: AbstractHashAlg end
struct XXHash128Alg <: AbstractHashAlg end
struct SHA64Alg <: AbstractHashAlg end
struct SHA128Alg <: AbstractHashAlg end

function _ghash_base64(gset::Graphset, labels)
    if length(gset) > 8192
        throw(ArgumentError("Graph is too large (`nv(g) > 90`) and cannot be hashed using `Base64Alg`. Use a different hash algorithm instead."))
    end
    return Base.hash(labels, Base.hash(collect(active_words(gset))))
end

__xxhash64(x::AbstractArray) = @ccall xxHash_jll.libxxhash.XXH3_64bits(Ref(x, 1)::Ptr{Cvoid}, sizeof(x)::Csize_t)::UInt64
__xxhash64seed(x::AbstractArray, seed::UInt64) = @ccall xxHash_jll.libxxhash.XXH3_64bits_withSeed(Ref(x, 1)::Ptr{Cvoid}, sizeof(x)::Csize_t, seed::UInt64)::UInt64
function _ghash_xxhash64(gset::Graphset, labels)
    return __xxhash64seed(labels, __xxhash64(collect(active_words(gset))))
end

__xxhash128(x::AbstractArray) = @ccall xxHash_jll.libxxhash.XXH3_128bits(Ref(x, 1)::Ptr{Cvoid}, sizeof(x)::Csize_t)::UInt128
__xxhash128seed(x::AbstractArray, seed::UInt128) = @ccall xxHash_jll.libxxhash.XXH3_128bits_withSeed(Ref(x, 1)::Ptr{Cvoid}, sizeof(x)::Csize_t, seed::UInt128)::UInt128
function _ghash_xxhash128(gset::Graphset, labels)
    return __xxhash128seed(labels, __xxhash128(collect(active_words(gset))))
end

# as suggested by stevengj here: https://discourse.julialang.org/t/hash-collision-with-small-vectors/131702/10
function __SHAhash(x)
    io = IOBuffer()
    Serialization.serialize(io, x)
    return SHA.sha256(take!(io))
end
__SHAhash64(x) = reinterpret(UInt64, __SHAhash(x))[1]
function _ghash_SHA64(gset::Graphset, labels)
    return __SHAhash64((labels, collect(active_words(gset))))
end
__SHAhash128(x) = reinterpret(UInt128, __SHAhash(x))[1]
function _ghash_SHA128(gset::Graphset, labels)
    return __SHAhash128((labels, collect(active_words(gset))))
end

function sethash!(hcache::HashCache, h::UInt64, hashalg)
    hcache.hash64 = h
    hcache.alg64 = typeof(hashalg)
    hcache.set64 = true
    return h
end
function sethash!(hcache::HashCache, h::UInt128, hashalg)
    hcache.hash128 = h
    hcache.alg128 = typeof(hashalg)
    hcache.set128 = true
    return h
end
function gethash(hcache, hashalg::AbstractHashAlg)
    if hcache.set64 && hashalg isa hcache.alg64
        return hcache.hash64
    elseif hcache.set128 && hashalg isa hcache.alg128 
        return hcache.hash128
    else
        return nothing
    end
end
function clearhash!(hcache)
    hcache.set64 = false
    hcache.set128 = false
    return
end

function _ghash(gset, labels; alg::AbstractHashAlg)
    if alg isa XXHash64Alg
        # We need to allocate any views before we pass them to xxHash
        if labels isa SubArray
            h = _ghash_xxhash64(gset, collect(labels))
        else
            h = _ghash_xxhash64(gset, labels)
        end
    elseif alg isa XXHash128Alg
        if labels isa SubArray
            h = _ghash_xxhash128(gset, collect(labels))
        else
            h = _ghash_xxhash128(gset, labels)
        end
    elseif alg isa SHA64Alg
        h = _ghash_SHA64(gset, labels)
    elseif alg isa SHA128Alg
        h = _ghash_SHA128(gset, labels)
    elseif alg isa Base64Alg
        h = _ghash_base64(gset, labels)
    else
        throw(ArgumentError("$alg is not a valid hashing algorithm."))
    end
    return h
end