module InteractiveSynthPOC

using SimpleDirectMediaLayer
using SimpleDirectMediaLayer.LibSDL2
import Base.sin
import LinearAlgebra.norm
using Random
using Base.Threads
using Setfield

# Structure for sine wave with frequency, phase, volume and panning
struct SineWave
    frequency::Float64
    volume::Float64
    panning::Float64 # range -1 (left) to 1 (right)
    phase::Float64
    SineWave(frequency::Union{Float64, Int}, volume::Float64,
     panning::Float64 = 0.0, phase::Float64=0.0) = new(Float(frequency), volume, panning, phase)
end

# Create an array to hold the sine waves
sines::Vector{SineWave} = SineWave[]

# Create a lock to protect the sines array
sines_lock::ReentrantLock = ReentrantLock()

function add_sine(frequency::Union{Float64, Int}; volume_db::Float64 = -30.0, panning::Float64 = 0.0)::Nothing
    volume = 10^(volume_db/20)
    lock(sines_lock) do
        #@info "user thread lock aquired"
        sw = SineWave(frequency, volume, panning)
        push!(sines, sw)
        #println(sines)
        return nothing
    end
    #@info "user thread lock freed"
end

function delete_sine(index::Int)::Nothing
    lock(sines_lock) do
        if index > length(sines) || index < 1
            println("Invalid index.")
        else
            deleteat!(sines, index)
        end
    end
    return nothing
end

function clear()::Nothing
    lock(sines_lock) do
        empty!(sines)
    end
    return nothing
end

function add_naive_sawtooth(frequency::Union{Float64, Int}; volume_db::Float64 = -30.0, panning::Float64 = 0.0)::Nothing
    # A VERY naive bandlimited sawtooth, this is very inefficient and for testing only
    volume = 10^(volume_db/20)
    lock(sines_lock) do
        #@info "user thread lock aquired"
        n = 1
        while frequency * n < 48000 / 2  # nyquist frequency, hardcoded for simplicity
            harmonic_volume = volume / n
            sw = SineWave(frequency*n, harmonic_volume, panning)
            push!(sines, sw)
            n += 1
        end
    end
    return nothing
    #@info "user thread lock freed"
end

function update_sine(index::Int;
     frequency::Union{Float64, Int, Nothing}=nothing,
     volume::Union{Float64, Nothing}=nothing,
     panning::Union{Float64, Nothing}=nothing)::Nothing

    lock(sines_lock) do
        if index > length(sines) || index < 1
            println("Invalid index.")
        else
            wave = sines[index]
            frequency = isnothing(frequency) ? wave.frequency : frequency
            volume = isnothing(volume) ? wave.volume : volume
            panning = isnothing(panning) ? wave.panning : panning
            
            sines[index] = @set wave.frequency = frequency  
            sines[index] = @set wave.volume = volume
            sines[index] = @set wave.panning = panning
        end
    end
    @info "total number of sines: " length(sines)
    return nothing
end

function supersaw(center_frequency::Union{Float64, Int};
                           variance_hz::Float64 = 1.0, 
                           num_saws::Int = 2, 
                           volume_db::Float64 = -30.0)::Nothing
    lock(sines_lock) do
        saw_volume = volume_db - 20*log10(sqrt(num_saws))# adjust volume per sawtooth wave for equal loudness
        for _ in 1:num_saws
            # random frequency within variance
            frequency = center_frequency + (Random.rand() - 0.5) * 2 * variance_hz
            # uniform panning
            saw_panning = 2 * Random.rand() - 1
            add_naive_sawtooth(frequency; volume_db=saw_volume, panning=saw_panning)
        end
    end
    @info "total number of sines: " length(sines)
    return nothing
end

function push_audio(audio_device::Cint, buffer_size::UInt32,
     sample_rate::Cint, output_buffer::Vector{Float32})::Nothing
    #@info "Starting audio loop"
    for i in 1:buffer_size
        sample_left::Float32 = Float32(0)
        sample_right::Float32 = Float32(0)

        # Calculate the output for each sine wave
        for j in eachindex(sines)
            wave = sines[j]
            c = 2 * π * wave.frequency / sample_rate
            phase = wave.phase
            output::Float32 = wave.volume * sin(phase)

            # Add the output to the left and right channels, taking panning into account
            sample_left  += sqrt((1 - wave.panning) / 2) * output
            sample_right += sqrt((1 + wave.panning) / 2) * output

            # Update the phase for the next cycle
            sines[j] = @set wave.phase=mod2pi(phase + c)
        end

        output_buffer[2*i-1] = sample_left
        output_buffer[2*i] = sample_right
    end
    SDL_QueueAudio(audio_device, output_buffer, sizeof(Float32) * buffer_size * 2)
    #@info "Audio pushed"
    return nothing
end

# Thread for continuously producing and playing audio
function audio_thread(audio_device::Cint, sample_rate::Cint, audio_spec::SDL_AudioSpec)
    #@info "Audio thread start"
    set_zero_subnormals(true) # Denormals are slow and pointless for audio
    sample_size::Int = sizeof(Float32) * 2 # 2 for stereo
    buffer_size::UInt32 = audio_spec.samples
    output_buffer::Vector{Float32} = zeros(buffer_size*2)
    try
        while true
            # Wait if the queue is full
            #Note this in practice means that the total latency can be up to 2x buffer size
            while SDL_GetQueuedAudioSize(audio_device) > buffer_size * sample_size * 2
                sleep(buffer_size / sample_rate / 2)
            end
            #@info "Done waiting"
            lock(sines_lock) do
                #@info "audio thread lock aquired"
                push_audio(audio_device, buffer_size, sample_rate, output_buffer)
                #@info "Audio pushed"
            end
        end
    catch e
        @error "Error encountered in audio_thread:"
        @error e, Base.catch_stack()
        @error "Terminating the program."
        exit(1)
    end
end

macro eval_catch_discard_output(code_snippets...)
    quote
        buffer = IOBuffer()
        for code_str in $code_snippets
            try
                eval(Meta.parse(code_str))
            catch err
                println(buffer, "Invalid command.", err)
                showerror(buffer, err)
            end
        end
    end
end

function warmup_jit()
    println("Starting synth")
    @eval_catch_discard_output "some rubbish", "missing_function_blablabla()", "supersaw()"
end

function main()
    #precompile(add_naive_sawtooth, (Float64,))
    #precompile(add_naive_sawtooth, (Int,))
    #precompile(supersaw, (Float64,))
    #precompile(supersaw, (Int,))
    #
    #warmup_jit()

    SDL_Init(SDL_INIT_AUDIO)

    # NOTE ! Not sure what is going in SDL but using something than 44_100 seems to lead to audible distortion
    sample_rate::Cint = 44_100
    buffer_size::UInt32 = 512

    audio_spec = SDL_AudioSpec(sample_rate, AUDIO_F32SYS, 2, 0, buffer_size, 0, 0, C_NULL, C_NULL)
    audio_device::Cint = SDL_OpenAudioDevice(C_NULL, 0, Ref(audio_spec), C_NULL, 0)
    try
        # Unpausing the audio device (starts playing)
        SDL_PauseAudioDevice(audio_device, 0)
        
        #Run this in the command line
        #supersaw(220)

        @spawn audio_thread(audio_device, sample_rate, audio_spec)

        user_thread = @spawn begin
            add_sine(220, panning = -0.99)
            add_sine(220.5, panning = 0.99)

            while true
                print("\nSynth>")
                command::String = readline()
                try
                    eval(Meta.parse(command))
                catch err
                    println("Invalid command.", err)
                    showerror(stdout, err)
                end
            end
        end


        wait(user_thread)  # Wait for user_thread to finish
    finally
        SDL_CloseAudioDevice(audio_device)
        SDL_Quit()
    end
end

if abspath(PROGRAM_FILE) == @__FILE__
    main()
end

end # module InteractiveSynthPOC
