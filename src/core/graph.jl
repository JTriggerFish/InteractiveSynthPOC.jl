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

mutable struct MonoToStereoMix <: Block{2}
    input::Block{1}
    amplitude_dB::Union{Sample,Block{1}}
    panning::Union{Sample,Block{1}}
    
    MonoToStereoMix(input::Block{1}, amplitude_dB::Union{Number,Block{1}}=-30.0, 
    panning::Union{Number,Block{1}}=0.0) = new(input, amplitude_dB isa Number ? Sample(amplitude_dB) : amplitude_dB, 
    panning isa Number ? Sample(panning) : panning)
end

function process!(m::MonoToStereoMix)::SampleVec2
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

mutable struct Product <: Block{1}
    a::Union{Sample,Block{1}}
    b::Union{Sample,Block{1}}
end

function process!(p::Product)::SampleOrVec
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


