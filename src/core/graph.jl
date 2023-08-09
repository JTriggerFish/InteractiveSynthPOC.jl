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

const AudioSystem = _AudioSystem(false, 0)

process!(x::Number)::Number = x

struct Phasor <: Block
    freq::Union{Sample,Block}
    phase::PreciseSample
    sample_freq::Sample
end

function process!(p::Phasor)::Sample
    f = process!(p.freq)
    c = 2 * π * f / p.sample_freq
    ret::Sample = p.phase
    @set p.phase = mod2pi(p.phase + c)
    ret
end


struct SineOsc <: Block
    phase::Phasor
    amplitude::Union{Sample,Block}
    SineOsc(freq::Union{Number,Block}, amplitude::Union{Number,Block},
        sample_freq::Union{number,Nothing}=nothing) = new(
        Phasor(freq, 0, sample_freq ? sample_freq : AudioSystem.sample_freq),
        amplitude
    )
end

function process!(o::SineOsc)::Sample
    p = process!(o.phase)
    a = process!(o.amplitude)
    a * sin(p)
end

struct MonoToSteroMix <: Block
    input::Block
    amplitude_dB::Union{Sample,Block}
    panning::Union{Sample,Block}
end

function process!(b::MonoToSteroMix)::StereoSample
    x = process!(b.input)
    a = process!(b.amplitude_dB)
    x *= 10^(a / 20)
    left += sqrt((1 - p.panning) / 2) * x
    right += sqrt((1 + p.panning) / 2) * x
    return SVector(left, right)
end


function stereo_brickwall_limiter(lr::StereoSample)::StereoSample
    return clamp.(lr, -1.0, 1.0)
end

struct StereroOutput <: Block
    blocks::Vector{Block}
    limiter::Function
    StereroOutput(blocks::Vector{Block},
        limiter::Union{Function,Nothing}=nothing) = new(blocks, limiter ? limiter : stereo_brickwall_limiter)
end

function process!(s::StereroOutput)::StereoSample
    output = SA_F32[0, 0]
    for b in s.blocks
        output += process!(b)
    end
    return p.limiter(output)
end

struct Product <: Block
    a::Union{Number,Block}
    b::Union{Number,Block}
end

function process!(p::Product)::Union{Sample,StereoSample}
    ai = process!(p.a)
    bi = process!(p.b)
    return ai * bi
end

function >>(b::Block, o::StereroOutput)::Nothing
    push!(o.blocks, b)
    return nothing
end

*(a::Number, b::Block) = Product(a, b)
*(a::Block, b::Number) = Product(a, b)
*(a::Block, b::Block) = Product(a, b)


