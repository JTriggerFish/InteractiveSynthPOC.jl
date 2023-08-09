
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
        sample_freq::Union{Number,Nothing}=nothing) = new(
        Phasor(freq, 0, sample_freq ? sample_freq : AudioSystem.sample_freq),
        amplitude
    )
end

function process!(o::SineOsc)::Sample
    p = process!(o.phase)
    a = process!(o.amplitude)
    a * sin(p)
end
