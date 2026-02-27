import SwiftUI

struct ChatView: View {
    @State private var viewModel = ChatViewModel()
    @State private var showingImagePicker = false
    @State private var imageSourceType: UIImagePickerController.SourceType = .camera
    @State private var keyboardHeight: CGFloat = 0
    @State private var store = ConversationStore()
    @State private var showHistory = false
    @State private var historyRefreshID = UUID()  // bumped each time history opens to force reload

    var body: some View {
        ZStack {
            VedaCosmicBackground().ignoresSafeArea()

            // Root layout — never moves with keyboard
            VStack(spacing: 0) {
                headerView

                ZStack {
                    if viewModel.messages.isEmpty {
                        WelcomeView(onSuggestionTap: { suggestion in
                            viewModel.currentInput = suggestion
                            viewModel.sendMessage()
                        })
                        .transition(.opacity)
                    } else {
                        messageListView
                            .transition(.opacity)
                    }
                }
                // Animate only when clearing (empty→WelcomeView).
                // When first message arrives, skip animation to prevent blank frame jump.
                .animation(
                    viewModel.messages.isEmpty ? .easeInOut(duration: 0.2) : .none,
                    value: viewModel.messages.isEmpty
                )

                // Bottom bar — always sticks above keyboard
                bottomBar
            }
            .ignoresSafeArea(.keyboard)

            // Overlays
            if viewModel.isModelLoading {
                LoadingOverlayView().transition(.opacity)
            }

            if viewModel.showErrorBanner {
                VStack {
                    ErrorBannerView(message: viewModel.errorMessage)
                        .transition(.move(edge: .top).combined(with: .opacity))
                    Spacer()
                }
                .padding(.top, 80)
                .animation(.spring(response: 0.4, dampingFraction: 0.75), value: viewModel.showErrorBanner)
            }
        }
        .sheet(isPresented: $showingImagePicker) {
            ImagePicker(sourceType: imageSourceType) { image in
                withAnimation { viewModel.selectedImage = image }
            }
        }
        .sheet(isPresented: $showHistory) {
            HistoryView(store: store, refreshID: historyRefreshID) { conversation, restored in
                viewModel.restore(conversation: conversation, messages: restored)
            }
        }
        .onChange(of: showHistory) {
            if showHistory { historyRefreshID = UUID() }
        }
        .toolbar(.hidden, for: .navigationBar)
        .preferredColorScheme(.dark)
        .onAppear { viewModel.checkStatus() }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { n in
            guard let frame = n.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect,
                  let duration = n.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double,
                  let curveRaw = n.userInfo?[UIResponder.keyboardAnimationCurveUserInfoKey] as? Int
            else { return }

            let curve = UIView.AnimationCurve(rawValue: curveRaw) ?? .easeInOut
            let animator = UIViewPropertyAnimator(duration: duration, curve: curve)
            animator.addAnimations {
                // Use the safe area bottom to avoid double-counting home indicator
                let safeBottom = (UIApplication.shared.connectedScenes
                    .compactMap { $0 as? UIWindowScene }
                    .first?.windows.first?.safeAreaInsets.bottom) ?? 0
                keyboardHeight = frame.height - safeBottom
            }
            animator.startAnimation()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { n in
            guard let duration = n.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double,
                  let curveRaw = n.userInfo?[UIResponder.keyboardAnimationCurveUserInfoKey] as? Int
            else {
                withAnimation { keyboardHeight = 0 }
                return
            }
            let curve = UIView.AnimationCurve(rawValue: curveRaw) ?? .easeInOut
            let animator = UIViewPropertyAnimator(duration: duration, curve: curve)
            animator.addAnimations { keyboardHeight = 0 }
            animator.startAnimation()
        }
        .onReceive(NotificationCenter.default.publisher(for: .vedaDeepLink)) { note in
            if let q = note.userInfo?["question"] as? String {
                viewModel.currentInput = q
                viewModel.sendMessage()
            }
        }
    }

    // MARK: - Bottom Bar (image strip + input, always above keyboard)
    private var bottomBar: some View {
        VStack(spacing: 0) {
            // Image preview strip — animates in/out cleanly
            if let img = viewModel.selectedImage {
                ImagePreviewStrip(image: img, onRemove: {
                    withAnimation(.spring(response: 0.3)) {
                        viewModel.selectedImage = nil
                    }
                })
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            InputBarView(
                text: $viewModel.currentInput,
                onSend: {
                    // Dismiss keyboard immediately when message is sent
                    UIApplication.shared.sendAction(
                        #selector(UIResponder.resignFirstResponder),
                        to: nil, from: nil, for: nil
                    )
                    viewModel.sendMessage()
                },
                onCameraTap: {
                    imageSourceType = .camera
                    showingImagePicker = true
                },
                onPhotoLibraryTap: {
                    imageSourceType = .photoLibrary
                    showingImagePicker = true
                }
            )
            .background(.ultraThinMaterial.opacity(0.5))

            // This spacer fills the keyboard height so the bar floats above it
            Color.clear.frame(height: keyboardHeight)
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: viewModel.selectedImage != nil)
    }

    // MARK: - Header
    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text("VEDA")
                    .font(.system(size: 13, weight: .heavy, design: .serif))
                    .tracking(6)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.orange.opacity(0.9), Color.yellow.opacity(0.7)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                HStack(spacing: 5) {
                    Circle()
                        .fill(viewModel.isModelLoading ? Color.orange.opacity(0.5) : Color.green.opacity(0.8))
                        .frame(width: 5, height: 5)
                    Text(viewModel.isModelLoading ? "Awakening..." : "Wisdom in Motion")
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.4))
                }
            }

            Spacer()

            // Export button — only visible when there are messages
            if !viewModel.messages.isEmpty {
                ExportButton(messages: viewModel.messages)
            }

            // History button
            Button {
                // 1. Save or Update current progress before leaving the view
                if !viewModel.messages.isEmpty {
                    if let existing = viewModel.activeConversation {
                        store.updateConversation(existing, messages: viewModel.messages)
                    } else {
                        store.saveConversation(messages: viewModel.messages)
                    }
                }
                
                // 2. Now show the history
                showHistory = true
            } label: {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 14))
                    .foregroundStyle(.orange.opacity(0.8))
                    .padding(12)
                    .background(
                        Circle()
                            .fill(.ultraThinMaterial)
                            .overlay(Circle().stroke(Color.orange.opacity(0.2), lineWidth: 0.5))
                    )
            }

            // New chat button — saves or updates before clearing
            Button {
                if let existing = viewModel.activeConversation {
                    // User was continuing a restored thread — update it in place
                    store.updateConversation(existing, messages: viewModel.messages)
                } else {
                    // Fresh chat — create a new record
                    store.saveConversation(messages: viewModel.messages)
                }
                viewModel.clearChat()
            } label: {
                Image(systemName: "plus.bubble.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(.orange.opacity(0.8))
                    .padding(12)
                    .background(
                        Circle()
                            .fill(.ultraThinMaterial)
                            .overlay(Circle().stroke(Color.orange.opacity(0.2), lineWidth: 0.5))
                    )
            }
            .disabled(viewModel.messages.isEmpty)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 14)
        .background(
            LinearGradient(
                colors: [Color.black.opacity(0.8), Color.indigo.opacity(0.4)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    // MARK: - Message List
    private var messageListView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 20) {
                    ForEach(viewModel.messages) { message in
                        MessageBubbleView(message: message)
                            .id(message.id)
                    }

                    if viewModel.isGenerating {
                        TypingIndicatorContainer()
                            .id("typing")
                    }

                    if let last = viewModel.messages.last, last.isError {
                        Button(action: viewModel.retryLastUserMessage) {
                            Label("Retry", systemImage: "arrow.clockwise")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.orange)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 10)
                                .background(
                                    Capsule()
                                        .fill(.ultraThinMaterial)
                                        .overlay(Capsule().stroke(Color.orange.opacity(0.3), lineWidth: 1))
                                )
                        }
                        .padding(.top, 4)
                    }

                    Color.clear.frame(height: 16).id("bottom")
                }
                .padding(.top, 20)
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: viewModel.messages.count) {
                withAnimation(.spring(response: 0.4)) { proxy.scrollTo("bottom") }
            }
            .onChange(of: viewModel.isGenerating) {
                withAnimation { proxy.scrollTo("bottom") }
            }
            .onChange(of: keyboardHeight) {
                withAnimation(.spring(response: 0.35)) { proxy.scrollTo("bottom") }
            }
            // Scroll to bottom immediately when the list first appears
            // (covers both new chats and restored threads)
            .onAppear {
                proxy.scrollTo("bottom", anchor: .bottom)
            }
        }
    }
}

// MARK: - Welcome View
struct WelcomeView: View {
    let onSuggestionTap: (String) -> Void

    private let suggestions = [
        ("🌌", "What is the nature of consciousness?"),
        ("🌿", "How can I build better daily habits?"),
        ("💡", "Explain quantum entanglement simply"),
        ("🧘", "Give me a short meditation prompt"),
    ]

    var body: some View {
        VStack(spacing: 28) {
            Spacer()
            VStack(spacing: 10) {
                Text("✦")
                    .font(.system(size: 40))
                    .foregroundStyle(.orange.opacity(0.7))
                Text("Ask Veda anything")
                    .font(.system(size: 22, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.8))
                Text("Tap a suggestion or type your own")
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.35))
            }
            VStack(spacing: 12) {
                ForEach(suggestions, id: \.1) { emoji, text in
                    Button(action: { onSuggestionTap(text) }) {
                        HStack(spacing: 12) {
                            Text(emoji).font(.system(size: 18))
                            Text(text)
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                .foregroundStyle(.white.opacity(0.75))
                                .multilineTextAlignment(.leading)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 11))
                                .foregroundStyle(.white.opacity(0.2))
                        }
                        .padding(.horizontal, 18)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(.ultraThinMaterial)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(Color.white.opacity(0.07), lineWidth: 1)
                                )
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 24)
            Spacer()
        }
    }
}

// MARK: - Image Preview Strip
struct ImagePreviewStrip: View {
    let image: UIImage
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 52, height: 52)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.orange.opacity(0.4), lineWidth: 1)
                )
            Text("Image ready to send")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.6))
            Spacer()
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(.white.opacity(0.35))
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
    }
}

// MARK: - Loading Overlay
struct LoadingOverlayView: View {
    @State private var rotation: Double = 0

    var body: some View {
        ZStack {
            Color.black.opacity(0.6).ignoresSafeArea()
            VStack(spacing: 20) {
                ZStack {
                    Circle()
                        .stroke(Color.orange.opacity(0.15), lineWidth: 2)
                        .frame(width: 64, height: 64)
                    Circle()
                        .trim(from: 0, to: 0.75)
                        .stroke(
                            LinearGradient(colors: [.orange, .yellow.opacity(0.5)], startPoint: .leading, endPoint: .trailing),
                            style: StrokeStyle(lineWidth: 2.5, lineCap: .round)
                        )
                        .frame(width: 64, height: 64)
                        .rotationEffect(.degrees(rotation))
                        .onAppear {
                            withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: false)) {
                                rotation = 360
                            }
                        }
                    Text("✦")
                        .font(.system(size: 22))
                        .foregroundStyle(.orange.opacity(0.8))
                }
                VStack(spacing: 6) {
                    Text("Awakening Veda")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.85))
                    Text("Loading Apple Intelligence model...")
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.35))
                }
            }
            .padding(36)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.orange.opacity(0.15), lineWidth: 1))
            )
        }
    }
}

// MARK: - Error Banner
struct ErrorBannerView: View {
    let message: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
                .font(.system(size: 14))
            Text(message)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.85))
                .lineLimit(2)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.red.opacity(0.15))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.red.opacity(0.3), lineWidth: 1))
        )
        .padding(.horizontal, 16)
    }
}

// MARK: - Cosmic Background
struct VedaCosmicBackground: View {
    @State private var animate = false

    var body: some View {
        ZStack {
            Color.black
            Circle()
                .fill(Color.indigo.opacity(0.3))
                .frame(width: 400)
                .blur(radius: 80)
                .offset(x: animate ? 100 : -100, y: animate ? -200 : -100)
            Circle()
                .fill(Color.orange.opacity(0.15))
                .frame(width: 300)
                .blur(radius: 70)
                .offset(x: animate ? -150 : 50, y: animate ? 200 : 100)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 15).repeatForever(autoreverses: true)) {
                animate.toggle()
            }
        }
    }
}

// MARK: - Typing Indicator
struct TypingIndicatorContainer: View {
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Veda is contemplating...")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.orange.opacity(0.6))
                    .padding(.leading, 4)
                HStack(spacing: 6) {
                    ForEach(0..<3) { i in
                        Circle()
                            .fill(LinearGradient(colors: [.orange, .yellow], startPoint: .top, endPoint: .bottom))
                            .frame(width: 6, height: 6)
                            .phaseAnimator([0, 1]) { content, phase in
                                content
                                    .scaleEffect(phase == 1 ? 1.3 : 0.7)
                                    .opacity(phase == 1 ? 1 : 0.3)
                            } animation: { _ in
                                .easeInOut(duration: 0.8).delay(Double(i) * 0.2)
                            }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(.white.opacity(0.05))
                .clipShape(Capsule())
            }
            Spacer()
        }
        .padding(.horizontal, 20)
    }
}
