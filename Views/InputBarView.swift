import SwiftUI

// MARK: - Pulsing Ring
struct PulsingRingView: View {
    @State private var animate = false

    var body: some View {
        Circle()
            .stroke(
                LinearGradient(
                    colors: [Color.red.opacity(0.7), Color.orange.opacity(0.5)],
                    startPoint: .top, endPoint: .bottom
                ),
                lineWidth: 2
            )
            .scaleEffect(animate ? 1.55 : 1.0)
            .opacity(animate ? 0.0 : 0.85)
            .animation(.easeOut(duration: 1.1).repeatForever(autoreverses: false), value: animate)
            .onAppear { animate = true }
    }
}

// MARK: - Input Bar
@available(iOS 17.0, *)
struct InputBarView: View {
    @Binding var text: String
    let onSend: () -> Void
    let onCameraTap: () -> Void
    let onPhotoLibraryTap: () -> Void

    @State private var speechService = SpeechService.shared
    @State private var isSendHighlighted = false
    @State private var showSpeechError = false
    @State private var showAttachments = false

    private var isTextEmpty: Bool {
        text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            // Speech error inline hint
            if showSpeechError, let err = speechService.errorMessage {
                Text(err)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.red.opacity(0.75))
                    .padding(.bottom, 8)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            HStack(alignment: .bottom, spacing: 10) {
                // Expandable Attachment Menu
                HStack(alignment: .bottom, spacing: 10) {
                    Button {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                            showAttachments.toggle()
                        }
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(.orange)
                            .rotationEffect(.degrees(showAttachments ? 45 : 0))
                    }
                    .buttonStyle(.plain)

                    if showAttachments {
                        HStack(spacing: 12) {
                            iconButton(icon: "camera.fill", color: .orange, action: onCameraTap)
                            iconButton(icon: "photo.fill", color: .purple, action: onPhotoLibraryTap)
                            //micButton
                        }
                        .transition(.move(edge: .leading).combined(with: .opacity))
                    }
                }

                // Text field (automatically expands to fill remaining space)
                textField

                // Send
                sendButton
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 28)
                            .stroke(
                                LinearGradient(
                                    colors: [Color.orange.opacity(0.18), Color.indigo.opacity(0.08)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 0.8
                            )
                    )
                    .shadow(color: .black.opacity(0.3), radius: 16, x: 0, y: 8)
            )
        }
        .padding(.horizontal, 8)
        .padding(.bottom, 8)
        .onAppear {
            speechService.onAutoStop = {
                text = speechService.transcribedText
            }
        }
    }

    private var textField: some View {
        TextField(
            speechService.isRecording ? "Listening..." : "Ask Veda...",
            text: $text,
            axis: .vertical
        )
        .textFieldStyle(.plain)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.ultraThinMaterial.opacity(0.9))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.white.opacity(0.07), lineWidth: 0.6)
                )
        )
        .lineLimit(1...4)
        .fixedSize(horizontal: false, vertical: true)
        .onSubmit(of: .text) {
            if !isTextEmpty { onSend() }
        }
    }

    private var sendButton: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            onSend()
            withAnimation(.easeOut(duration: 0.12)) { isSendHighlighted = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                withAnimation { isSendHighlighted = false }
            }
        } label: {
            Image(systemName: "arrow.up.circle.fill")
                .font(.system(size: 30))
                .foregroundStyle(isTextEmpty ? Color.white.opacity(0.16) : Color.orange)
                .scaleEffect(isSendHighlighted ? 1.14 : 1.0)
        }
        .disabled(isTextEmpty)
        .buttonStyle(.plain)
        .animation(.spring(response: 0.28, dampingFraction: 0.6), value: isSendHighlighted)
    }

    private func iconButton(icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(color.opacity(0.9))
                .frame(width: 38, height: 38)
                .background(
                    Circle()
                        .fill(.ultraThinMaterial)
                        .overlay(Circle().stroke(color.opacity(0.22), lineWidth: 1))
                        .shadow(color: color.opacity(0.15), radius: 5)
                )
        }
        .buttonStyle(.plain)
    }
    
    private func handleMicTap() async {
            showSpeechError = false

            if speechService.isRecording {
                // If we are already recording, tapping stops it
                speechService.stopRecording()
                // The text is assigned via the onAutoStop callback defined in onAppear
                return
            }

            // Handle Permissions
            if speechService.permissionStatus == .notDetermined {
                await speechService.requestPermissions()
            }

            guard speechService.permissionStatus.isAllowed else {
                withAnimation { showSpeechError = true }
                try? await Task.sleep(for: .seconds(4))
                withAnimation { self.showSpeechError = false }
                return
            }

            // Prepare UI for new recording
            // We do not reset speechService.transcribedText here because
            // startRecording() handles its own internal cleanup.
            text = ""

            do {
                try speechService.startRecording()
            } catch {
                speechService.errorMessage = error.localizedDescription
                withAnimation { showSpeechError = true }
                try? await Task.sleep(for: .seconds(4))
                withAnimation { self.showSpeechError = false }
            }
        }
}
