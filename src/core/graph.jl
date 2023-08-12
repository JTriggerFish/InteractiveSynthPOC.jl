using Setfield
using StaticArrays
import Base.>>
import Base.*

const Sample::DataType = Float32
abstract type Block{N} end


const SampleVec2::DataType = SVector{2, Sample}
const SampleVec4::DataType = SVector{4, Sample}
const SampleVec8::DataType = SVector{8, Sample}
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

function process!(m::MonoToStereoMix{I, A, P})::SampleVec2 where {I, A, P}
    x = process!(m.input)
    a = process!(m.amplitude_dB)
    x *= 10^(a / 20)
    left = sqrt((1 - m.panning) / 2) * x
    right = sqrt((1 + m.panning) / 2) * x
    return SampleVec2(left, right)
end


mutable struct StereoOutput <: Block{2}
    blocks::Vector{Block{2}}
    output::MVector{2,Sample}
    StereoOutput(blocks::Union{Vector{Block{2}},Nothing}=nothing) = new(
        blocks isa Vector{Block{2}} ? blocks :  [],
        MVector{2, Sample}(undef))
end

function process!(s::StereoOutput)::SampleVec2
    s.output .= 0.0
    for b in s.blocks
        s.output .= s.output .+ process!(b)
    end
    s.output .= clamp.(s.output, -1.0, 1.0)
    return s.output
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


