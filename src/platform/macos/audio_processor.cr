{% if flag?(:macos) %}

module Scribe::Platform::MacOS
  # WAV file reading, format conversion, and resampling for whisper.cpp.
  # Extracted from app.cr (Story 8.4).
  module AudioProcessor
    # Read a WAV file and return float32 PCM samples at 16kHz mono.
    # whisper.cpp requires WHISPER_SAMPLE_RATE (16000) Hz mono float32.
    def self.read_wav_as_float32(path : String) : Slice(Float32)?
      begin
        data = File.read(path).to_slice

        # Parse WAV header (minimal -- we know our recorder outputs 16-bit PCM WAV)
        return nil if data.size < 44
        return nil unless String.new(data[0, 4]) == "RIFF"
        return nil unless String.new(data[8, 4]) == "WAVE"

        # Read format info
        channels = (data[22].to_u16 | (data[23].to_u16 << 8))
        sample_rate = (data[24].to_u32 | (data[25].to_u32 << 8) | (data[26].to_u32 << 16) | (data[27].to_u32 << 24))
        bits_per_sample = (data[34].to_u16 | (data[35].to_u16 << 8))

        puts "[Scribe] WAV: #{sample_rate}Hz, #{channels}ch, #{bits_per_sample}bit"

        # Find data chunk
        offset = 12
        data_offset = 0
        data_size = 0_u32
        while offset < data.size - 8
          chunk_id = String.new(data[offset, 4])
          chunk_size = (data[offset + 4].to_u32 | (data[offset + 5].to_u32 << 8) |
                        (data[offset + 6].to_u32 << 16) | (data[offset + 7].to_u32 << 24))
          if chunk_id == "data"
            data_offset = offset + 8
            data_size = chunk_size
            break
          end
          offset += 8 + chunk_size
        end

        return nil if data_offset == 0 || data_size == 0

        # Convert to float32
        if bits_per_sample == 16
          n_samples = data_size // 2
          samples = Slice(Float32).new(n_samples.to_i32)
          n_samples.times do |i|
            byte_offset = data_offset + i * 2
            raw = (data[byte_offset].to_i16 | (data[byte_offset + 1].to_i16 << 8))
            samples[i] = raw.to_f32 / 32768.0_f32
          end
        elsif bits_per_sample == 32
          # Assume float32 PCM
          n_samples = data_size // 4
          samples = Slice(Float32).new(n_samples.to_i32)
          n_samples.times do |i|
            byte_offset = data_offset + i * 4
            samples[i] = data[byte_offset, 4].unsafe_as(Float32)
          end
        else
          puts "[Scribe] Unsupported bit depth: #{bits_per_sample}"
          return nil
        end

        # Downmix stereo to mono if needed
        if channels == 2
          mono = Slice(Float32).new(samples.size // 2)
          (samples.size // 2).times do |i|
            mono[i] = (samples[i * 2] + samples[i * 2 + 1]) / 2.0_f32
          end
          samples = mono
        end

        # Resample to 16kHz if needed (simple linear interpolation)
        if sample_rate != 16000
          ratio = 16000.0 / sample_rate.to_f64
          new_size = (samples.size * ratio).to_i32
          resampled = Slice(Float32).new(new_size)
          new_size.times do |i|
            src_pos = i.to_f64 / ratio
            src_idx = src_pos.to_i32
            frac = (src_pos - src_idx).to_f32
            if src_idx + 1 < samples.size
              resampled[i] = samples[src_idx] * (1.0_f32 - frac) + samples[src_idx + 1] * frac
            elsif src_idx < samples.size
              resampled[i] = samples[src_idx]
            end
          end
          samples = resampled
          puts "[Scribe] Resampled #{sample_rate}Hz -> 16000Hz (#{samples.size} samples)"
        end

        samples
      rescue ex
        puts "[Scribe] Failed to read WAV: #{ex.message}"
        nil
      end
    end
  end
end

{% end %}
