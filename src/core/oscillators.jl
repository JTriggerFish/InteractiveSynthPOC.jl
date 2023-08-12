
mutable struct Phasor{T} <: Block{1}
    freq::T
    phase::Sample
    const sample_freq::Sample
end

function process!(p::Phasor{T})::Sample where {T}
    f::Sample = process!(p.freq)
    c::Sample = 2 * π * f / p.sample_freq
    ret::Sample = p.phase
    p.phase = mod2pi(p.phase + c)
    ret
end


mutable struct SineOsc{P, A} <: Block{1}
    phase::P
    amplitude::A
end
SineOsc(freq::Number, amplitude::Number = 1.0, sample_freq::Union{Number, Nothing}=nothing) = SineOsc{Phasor{Sample}, Sample}(
    Phasor{Sample}(Sample(freq), Sample(0.0), sample_freq isa Number ? Sample(sample_freq) : AudioSystem.sample_freq), 
    Sample(amplitude))

function process!(o::SineOsc{A})::Sample where {A}
    p::Sample = process!(o.phase)
    a::Sample = process!(o.amplitude)
    a * sin(p)
end
