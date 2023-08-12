using Setfield
using StaticArrays
import Base.>>
import Base.*

const Sample::DataType = Float32
abstract type AbstractBlock{N, T} end

get_block_type(::Val{1}) = Sample
get_block_type(N) = SVector{N, Float32}

abstract type Block{N} <: AbstractBlock{N, get_block_type(N)} end


const SampleVec2::DataType = SVector{2, Float32}
const SampleVec4::DataType = SVector{4, Float32}
const SampleVec8::DataType = SVector{8, Float32}
const SampleOrVec = Union{Sample, SampleVec2, SampleVec4, SampleVec8}

struct _AudioSystem
    initialized::Bool
    sample_freq::Sample
end

AudioSystem::_AudioSystem = _AudioSystem(false, 0)

include("oscillators.jl")

process!(x::Sample)::Sample = x

mutable struct MonoToStereoMix{I<:Block{1}, A, P} <: Block{2}
    input::I
    amplitude_dB::A
    panning::P
end
MonoToStereoMix(input::Block{1}, amplitude_dB::Number=-30.0, 
panning::Number=0.0) = MonoToStereoMix{Block{1}, Sample, Sample}(input, Sample(amplitude_dB), Sample(panning))

function process!(m::MonoToStereoMix{I, A, P})::SampleVec2 where {I<:Block{1}, A,P}
    x::Sample = process!(m.input)
    a::Sample = process!(m.amplitude_dB)
    x *= 10^(a / 20)
    left::Sample = sqrt((1 - m.panning) / 2) * x
    right::Sample = sqrt((1 + m.panning) / 2) * x
    return [left, right]
end


mutable struct StereoOutput <: Block{2}
    blocks::Vector{Block{2}}
    StereoOutput(blocks::Union{Vector{Block{2}},Nothing}=nothing) = new(blocks isa Vector{Block{2}} ? blocks :  [])
end

function process!(s::StereoOutput)::SampleVec2
    output::MVector{2,Sample} = zeros(2)
    for b in s.blocks
        output += process!(b)
    end
    output[1] = clamp(output[1], -1.0, 1.0)
    output[2] = clamp(output[2], -1.0, 1.0)
    return output
end

mutable struct Product{A, B} <: Block{1}
    a::A
    b::B
end

function process!(p::Product{A, B})::SampleOrVec where {A, B}
    ai::Sample = process!(p.a)
    bi::Sample = process!(p.b)
    return ai * bi
end

function >>(b::Block, o::StereoOutput)::Nothing
    push!(o.blocks, b)
    return nothing
end

*(a::Number, b::Block{1}) = Product(convert(Sample, a), b)
*(a::Block{1} , b::Number) = Product(b, convert(Sample, a))
*(a::Block{1} , b::Block{T} where T) = Product(a, b)


