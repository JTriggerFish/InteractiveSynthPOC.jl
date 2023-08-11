using Setfield
using StaticArrays
import Base.>>
import Base.*

abstract type Block end

const Sample::DataType = Float32
const PreciseSample::DataType = Float64
const StereoSample::DataType = SVector{2,Float32}

struct _AudioSystem
    initialized::Bool
    sample_freq::Float32
end

AudioSystem::_AudioSystem = _AudioSystem(false, 0)

include("oscillators.jl")

process!(x::Number)::Number = x

struct MonoToStereoMix <: Block
    input::Block
    amplitude_dB::Union{Sample,Block}
    panning::Union{Sample,Block}
    
    MonoToStereoMix(input::Block, amplitude_dB::Union{Number,Block}=-30.0, 
    panning::Union{Number,Block}=0.0) = new(input, amplitude_dB isa Number ? Sample(amplitude_dB) : amplitude_dB, 
    panning isa Number ? Sample(panning) : panning)
end

function process!(m::MonoToStereoMix)::StereoSample
    x::Sample = process!(m.input)
    a::Sample = process!(m.amplitude_dB)
    x *= 10^(a / 20)
    left::Sample = sqrt((1 - m.panning) / 2) * x
    right::Sample = sqrt((1 + m.panning) / 2) * x
    return [left, right]
end


struct StereoOutput <: Block
    blocks::Vector{Block}
    StereoOutput(blocks::Union{Vector{Block},Nothing}=nothing) = new(blocks isa Vector{Block} ? blocks :  [])
end

function process!(s::StereoOutput)::StereoSample
    output::MVector{2,Float32} = zeros(2)
    for b in s.blocks
        output += process!(b)
    end
    output[1] = clamp(output[1], -1.0, 1.0)
    output[2] = clamp(output[2], -1.0, 1.0)
    return output
end

struct Product <: Block
    a::Union{Number,Block}
    b::Union{Number,Block}
end

function process!(p::Product)::Union{Sample,StereoSample}
    ai::Union{Sample,StereoSample} = process!(p.a)
    bi::Union{Sample,StereoSample} = process!(p.b)
    return ai * bi
end

function >>(b::Block, o::StereoOutput)::Nothing
    push!(o.blocks, b)
    return nothing
end

*(a::Number, b::Block) = Product(a, b)
*(a::Block, b::Number) = Product(a, b)
*(a::Block, b::Block) = Product(a, b)


