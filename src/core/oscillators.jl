
mutable struct Phasor <: Block
    freq::Union{Sample,Block}
    phase::Sample
    sample_freq::Sample
end

function process!(p::Phasor)::Sample
    f::Sample = process!(p.freq)
    c::Sample = 2 * π * f / p.sample_freq
    ret::Sample = p.phase
    p.phase = mod2pi(p.phase + c)
    ret
end


struct SineOsc <: Block
    phase::Phasor
    amplitude::Union{Sample,Block}
    SineOsc(freq::Union{Number,Block}, amplitude::Union{Number,Block} = 1.0,
        sample_freq::Union{Number,Nothing}=nothing) = new(
        Phasor(freq isa Number ? Sample(freq) : freq, 0.0,
         sample_freq isa Number ? Sample(sample_freq) : AudioSystem.sample_freq),
        amplitude isa Number ? Sample(amplitude) : amplitude
    )
end

function process!(o::SineOsc)::Sample
    p::Sample = process!(o.phase)
    a::Sample = process!(o.amplitude)
    a * sin(p)
end
