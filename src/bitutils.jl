function push_bits(word::WordType, fill::WordType, n::Integer, k::Integer)
    # Pushes n rightmost bits k steps to the left, overwriting step by step and replacing with values from fill
    #TODO: OPTIMIZE THIS
    wmax = one(WordType) << (WORDSIZE - 1)
    move_mask = reduce(|, one(WordType) << i for i in 0:n-1; init=zero(WordType))
    fill_mask = reduce(|, wmax >> i for i in 0:k-1; init=zero(WordType))
    write_mask = ~reduce(|, one(WordType) << i for i in 0:n+k-1; init=zero(WordType))

    move_chunk = (word & move_mask) << k
    copy_chunk = (fill & fill_mask) >> (WORDSIZE - k)

    return (word & write_mask) | move_chunk | copy_chunk
end
function rightshift_set!(set::Vector{WordType}, offset::Integer)
    # @assert offset > 0

    overflow = zero(WordType)
    for i in eachindex(set)
        w = set[i]
        set[i] = (w >> offset) | overflow
        overflow = w << (WORDSIZE - offset)
    end
    if overflow > 0
        push!(set, overflow)
    end
end
function transfer_set!(target::Vector{WordType}, set::Vector{WordType}, offset::Integer, m_target::Integer=1, m_set::Integer=1)
    # @assert offset >= 0

    overflow = zero(WordType)
    dn = offset ÷ WORDSIZE
    dk = offset % WORDSIZE
    for i in eachindex(set)
        target_idx = dn + 1 + (i - 1) % m_set + m_target * ((i - 1) ÷ m_set)
        w = set[i]
        target[target_idx] |= (w >> dk)
        overflow = w << (WORDSIZE - dk)
        if overflow > 0
            target[target_idx+1] |= overflow
        end
    end
    return
end


@inline function has_bit(word::WordType, i::Integer)
    mask = one(WordType) << (WORDSIZE - i)
    return (mask & word) != zero(WordType)
end

@inline function count_bits(word::WordType)
    return sum(has_bit(word, i) for i in 1:WORDSIZE)
end

function word_to_bitvec(word::WordType)
    bitvec = BitArray(undef, WORDSIZE)
    word_to_bitvec!(word, bitvec)
    return bitvec
end
function word_to_bitvec!(word::WordType, bitvec::BitVector)
    @inbounds for i in 1:WORDSIZE
        bitvec[i] = has_bit(word, i)
    end
    return
end
# From https://discourse.julialang.org/t/parse-an-array-of-bits-bitarray-to-an-integer/42361/23
function bitvec_to_word(b::AbstractVector)
    w = WordType(0)
    v = WordType(1)

    @inbounds for j in length(b):-1:1
        w += v * convert(WordType, b[j])
        v <<= 1
    end

    return w
end

function word_to_idxs(word::WordType, max_nidxs::Integer=WORDSIZE)
    idxs = zeros(Int, max_nidxs)
    k = word_to_idxs!(word, idxs)
    resize!(idxs, k)
    return idxs
end
function word_to_idxs!(word::WordType, idxs::AbstractVector{<:Integer})
    k = 1
    @inbounds for i in 1:WORDSIZE
        if has_bit(word, i)
            idxs[k] = i
            k += 1
        end
    end
    return k - 1
end

function set_to_idxs(set::AbstractVector{WordType}, shift::Bool=false, max_nidxs::Integer=WORDSIZE)
    n = length(set)
    idxs = zeros(Int, n * max_nidxs)

    nidx = set_to_idxs!(set, idxs, shift)
    resize!(idxs, nidx)
    return idxs
end
function set_to_idxs!(set::AbstractVector{WordType}, idxs::AbstractVector{<:Integer}, shift::Bool=false)
    n = length(set)

    nidx = 0
    for i in 1:n
        k = word_to_idxs!(set[i], @view idxs[nidx+1:end])
        if shift
            @views idxs[nidx+1:end] .+= (i - 1) * WORDSIZE
        end
        nidx += k
    end
    return nidx
end

function _concatbytes(bytes::AbstractVector{<:UInt8})
    # @assert length(bytes) == sizeof(HashType)
    w = HashType(0)
    for b in bytes
        w |= b
        w <<= 8
    end
    return w
end

function _to_matrixidx(idx::Integer, m::Integer)
    return 1 + (idx - 1) ÷ m, mod1(idx, m)
end

function _to_vecidx(i::Integer, j::Integer, m::Integer)
    # @assert j <= m
    return (i - 1) * m + j
end
