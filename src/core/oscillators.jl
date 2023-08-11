
mutable struct Phasor <: Block{1}
    freq::Union{Sample,Block{1}}
    phase::Sample
    const sample_freq::Sample
end

function process!(p::Phasor)::Sample
    f::Sample = process!(p.freq)
    c::Sample = 2 * π * f / p.sample_freq
    ret::Sample = p.phase
    p.phase = mod2pi(p.phase + c)
    ret
end


mutable struct SineOsc <: Block{1}
    phase::Phasor
    amplitude::Union{Sample,Block{1}}
    SineOsc(freq::Union{Number,Block{1}}, amplitude::Union{Number,Block{1}} = 1.0,
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
