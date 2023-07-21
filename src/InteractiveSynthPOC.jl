module InteractiveSynthPOC

using SimpleDirectMediaLayer
using SimpleDirectMediaLayer.LibSDL2
import Base.sin
import LinearAlgebra.norm
using Random
using Printf
using Base.Threads
using Parameters

# Structure for sine wave with frequency, phase, volume and panning
@with_kw mutable struct SineWave
    frequency::Float64
    volume::Float64
    panning::Float64 # range -1 (left) to 1 (right)
    phase::Float64 = 0.0
end

# Create an array to hold the sine waves
sine_waves::Vector{SineWave} = SineWave[]

# Create a lock to protect the sine_waves array
sine_waves_lock = ReentrantLock()

function add_sine_wave(frequency::Float64; volume::Float64 = 0.5, panning::Float64 = 0.0)::Nothing
    lock(sine_waves_lock) do
        push!(sine_waves, SineWave(frequency=frequency, volume=volume, panning=panning))
    end
end

function delete_sine_wave(index::Int)::Nothing
    lock(sine_waves_lock) do
        if index > length(sine_waves) || index < 1
            println("Invalid index.")
        else
            deleteat!(sine_waves, index)
        end
    end
end

function update_sine_wave(index::Int,
     frequency::Union{Float64, Nothing},
     volume::Union{Float64, Nothing},
     panning::Union{Float64, Nothing})::Nothing

    lock(sine_waves_lock) do
        if index > length(sine_waves) || index < 1
            println("Invalid index.")
        else
            wave = sine_waves[index]
            wave.frequency = isnothing(frequency) ? wave.frequency : frequency
            wave.volume = isnothing(volume) ? wave.volume : volume
            wave.panning = isnothing(panning) ? wave.panning : panning
        end
    end
end

let
    output_buffer::Vector{Float32} = zeros(1024*2)
    function push_audio(audio_device::Cint, frame_size::UInt32, sample_rate::Cint)
        buffer_size::UInt32 = frame_size * 2
        if length(output_buffer) < buffer_size
            output_buffer = zeros(buffer_size) # Resize if necessary
        end

        for i in 1:frame_size
            sample_left::Float32 = Float32(0)
            sample_right::Float32 = Float32(0)

            # Calculate the output for each sine wave
            for wave::SineWave in sine_waves
                c = 2 * π * wave.frequency / sample_rate
                phase = wave.phase + c
                output::Float32 = wave.volume * sin(phase)

                # Add the output to the left and right channels, taking panning into account
                sample_left  += sqrt((1 - wave.panning) / 2) * output
                sample_right += sqrt((1 + wave.panning) / 2) * output

                # Update the phase for the next cycle
                wave.phase = phase
            end

            output_buffer[i] = sample_left
            output_buffer[i+1] = sample_right

            SDL_QueueAudio(audio_device, output_buffer, sizeof(Float32) * buffer_size)
        end
    end
end

# Thread for continuously producing and playing audio
function audio_thread(audio_device::Cint, sample_rate::Cint, audio_spec::SDL_AudioSpec, buffer_size::UInt32)
    sample_size::Int = sizeof(Float32) * 2 # 2 for stereo
    while true
        # Wait if the queue is full
        #Note this in practice means that the total latency can be up to 2x buffer size
        while SDL_GetQueuedAudioSize(audio_device) > audio_spec.samples * sample_size
            sleep(buffer_size / sample_rate / 20) # Avoid busy waiting, at the cost of about 5% longer latency
        end
        lock(sine_waves_lock) do
            push_audio(audio_device, audio_spec.samples, sample_rate)
        end
    end
end

function main()
    SDL_Init(SDL_INIT_AUDIO)

    sample_rate::Cint = 480000
    buffer_size::UInt32 = 1024

    audio_spec = SDL_AudioSpec(sample_rate, AUDIO_F32SYS, 2, 0, buffer_size, 0, 0, C_NULL, C_NULL)
    audio_device::Cint = SDL_OpenAudioDevice(C_NULL, 0, Ref(audio_spec), C_NULL, 0)

    @spawn audio_thread(audio_device, sample_rate, audio_spec, buffer_size)
    
    add_sine_wave(100.0, panning = -1.0)
    add_sine_wave(100.1, panning = 1.0)

    while true
        print("Enter command: ")
        command::String = readline()
        try
            eval(Meta.parse(command))
        catch err
            println("Invalid command.")
        end
    end
end

main()

end # module InteractiveSynthPOC
