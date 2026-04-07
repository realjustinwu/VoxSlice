import SwiftUI

/// Audio player controls for the dashboard detail view per D-14 and UI-SPEC.
/// Displays transport controls (play/pause, skip +-15s), seek slider with
/// monospaced time labels, and segmented speed controls (0.5x-2.0x).
struct AudioPlayerView: View {
    @Bindable var viewModel: AudioPlayerViewModel

    var body: some View {
        if let error = viewModel.errorMessage {
            // Error state per UI-SPEC
            VStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle")
                    .foregroundStyle(.secondary)
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(16)
            .background(Color(NSColor.controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        } else {
            playerControls
        }
    }

    // MARK: - Player Controls

    @ViewBuilder
    private var playerControls: some View {
        VStack(spacing: 8) {
            // Row 1: Transport controls (skip back, play/pause, skip forward)
            HStack(spacing: 16) {
                Spacer()
                Button { viewModel.skipBackward() } label: {
                    Image(systemName: "gobackward.15")
                        .font(.system(size: 16))
                }
                .buttonStyle(.borderless)
                .disabled(!viewModel.audioAvailable)
                .accessibilityLabel("Skip back 15 seconds")

                Button { viewModel.togglePlayPause() } label: {
                    Image(systemName: viewModel.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 24))
                }
                .buttonStyle(.borderless)
                .disabled(!viewModel.audioAvailable)
                .accessibilityLabel(viewModel.isPlaying ? "Pause" : "Play")

                Button { viewModel.skipForward() } label: {
                    Image(systemName: "goforward.15")
                        .font(.system(size: 16))
                }
                .buttonStyle(.borderless)
                .disabled(!viewModel.audioAvailable)
                .accessibilityLabel("Skip forward 15 seconds")
                Spacer()
            }

            // Row 2: Timeline slider with time labels
            HStack(spacing: 8) {
                Text(viewModel.formattedCurrentTime)
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .frame(width: 50, alignment: .leading)

                Slider(
                    value: Binding(
                        get: { viewModel.currentTime },
                        set: { viewModel.seek(to: $0) }
                    ),
                    in: 0...max(viewModel.duration, 0.01)
                )
                .disabled(!viewModel.audioAvailable)
                .accessibilityLabel("Playback position")

                Text(viewModel.formattedDuration)
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .frame(width: 50, alignment: .trailing)
            }

            // Row 3: Speed controls
            HStack(spacing: 8) {
                ForEach([0.5, 1.0, 1.5, 2.0], id: \.self) { rate in
                    Button {
                        viewModel.setRate(Float(rate))
                    } label: {
                        Text("\(rate, specifier: "%.1f")x")
                            .font(.caption)
                            .fontWeight(.medium)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                viewModel.playbackRate == Float(rate)
                                    ? Color.accentColor
                                    : Color.clear
                            )
                            .foregroundStyle(
                                viewModel.playbackRate == Float(rate)
                                    ? .white
                                    : .secondary
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                    .buttonStyle(.borderless)
                    .disabled(!viewModel.audioAvailable)
                    .accessibilityLabel("Playback speed \(rate)x")
                }
            }
        }
        .padding(16)
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
