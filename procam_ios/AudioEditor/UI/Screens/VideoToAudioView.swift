import SwiftUI
import PhotosUI
import AVFoundation

/// Video to MP3 / Audio extractor screen
public struct VideoToAudioView: View {
    @ObservedObject public var fileManager: AudioFileManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedItem: PhotosPickerItem? = nil
    @State private var selectedVideoURL: URL? = nil
    @State private var videoTitle: String = ""
    @State private var videoDuration: TimeInterval = 0.0
    @State private var videoFileSize: Int64 = 0
    
    // Output options
    @State private var outputFormat: AudioFormat = .mp3
    @State private var outputBitrate: AudioBitrate = .kbps320
    @State private var isExtracting: Bool = false
    @State private var extractionProgress: Float = 0.0
    @State private var extractionTask: Task<Void, Never>? = nil
    @State private var showSuccessAlert: Bool = false
    @State private var errorMessage: String? = nil
    
    public init(fileManager: AudioFileManager = .shared) {
        self.fileManager = fileManager
    }
    
    public var body: some View {
        NavigationStack {
            ZStack {
                ScrollView {
                    VStack(spacing: 24) {
                        // MARK: - Video Picker Box
                        if let selectedVideoURL = selectedVideoURL {
                            videoSelectedCard
                        } else {
                            videoPickerPlaceholder
                        }
                        
                        // MARK: - Format & Bitrate Settings
                        VStack(alignment: .leading, spacing: 16) {
                            Text("CẤU HÌNH ÂM THANH XUẤT")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.secondary)
                            
                            // Format Picker
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Định dạng file")
                                    .font(.system(size: 14, weight: .medium))
                                
                                Picker("Định dạng", selection: $outputFormat) {
                                    Text("MP3 (Phổ biến nhất)").tag(AudioFormat.mp3)
                                    Text("M4A (Chuẩn Apple AAC)").tag(AudioFormat.m4a)
                                    Text("WAV (Không nén Lossless)").tag(AudioFormat.wav)
                                    Text("AAC (Chuẩn phát thanh)").tag(AudioFormat.aac)
                                }
                                .pickerStyle(SegmentedPickerStyle())
                            }
                            
                            // Bitrate Picker (if not WAV)
                            if outputFormat != .wav {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Chất lượng Bitrate")
                                        .font(.system(size: 14, weight: .medium))
                                    
                                    Picker("Bitrate", selection: $outputBitrate) {
                                        Text("128 kbps").tag(AudioBitrate.kbps128)
                                        Text("192 kbps").tag(AudioBitrate.kbps192)
                                        Text("256 kbps").tag(AudioBitrate.kbps256)
                                        Text("320 kbps (Cao nhất)").tag(AudioBitrate.kbps320)
                                    }
                                    .pickerStyle(SegmentedPickerStyle())
                                }
                            }
                        }
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color(UIColor.secondarySystemBackground))
                        )
                        .padding(.horizontal, 20)
                        
                        // MARK: - FFmpeg Command Inspection
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Image(systemName: "terminal.fill")
                                    .font(.system(size: 12))
                                Text("LỆNH FFMPEG XỬ LÝ (Background Engine)")
                                    .font(.system(size: 10, weight: .bold))
                            }
                            .foregroundColor(.secondary)
                            
                            let dummyIn = selectedVideoURL ?? URL(fileURLWithPath: "input_video.mp4")
                            let dummyOut = URL(fileURLWithPath: "output.\(outputFormat.fileExtension)")
                            Text(FFmpegCommandBridge.buildVideoToAudioCommand(
                                inputVideoURL: dummyIn,
                                outputAudioURL: dummyOut,
                                format: outputFormat,
                                bitrateKbps: outputBitrate.rawValue
                            ))
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(Color(UIColor.label))
                        }
                        .padding(14)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(UIColor.tertiarySystemBackground))
                        )
                        .padding(.horizontal, 20)
                        
                        // MARK: - Extract Button
                        Button(action: startExtraction) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(selectedVideoURL != nil ? AudioEditorTheme.accentRed : Color(UIColor.systemGray4))
                                    .frame(height: 54)
                                
                                HStack(spacing: 8) {
                                    Image(systemName: "bolt.fill")
                                        .font(.system(size: 17, weight: .bold))
                                    Text("Bắt đầu trích xuất âm thanh")
                                        .font(.system(size: 16, weight: .bold))
                                }
                                .foregroundColor(.white)
                            }
                        }
                        .disabled(selectedVideoURL == nil || isExtracting)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 24)
                    }
                    .padding(.top, 16)
                }
                
                // MARK: - Circular Percentage Progress Overlay
                if isExtracting {
                    progressOverlay
                }
            }
            .navigationTitle("Trích xuất từ Video")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Đóng") { dismiss() }
                        .disabled(isExtracting)
                }
            }
            .alert("Trích xuất hoàn tất!", isPresented: $showSuccessAlert) {
                Button("Xem trong Thư viện") {
                    dismiss()
                }
            } message: {
                Text("Tệp âm thanh '\(videoTitle).\(outputFormat.fileExtension)' đã được trích xuất thành công và lưu vào Thư viện.")
            }
            .alert("Lỗi trích xuất", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("Đóng", role: .cancel) { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "Đã xảy ra lỗi không xác định.")
            }
        }
    }
    
    // MARK: - Subviews
    
    private var videoPickerPlaceholder: some View {
        PhotosPicker(
            selection: $selectedItem,
            matching: .videos,
            photoLibrary: .shared()
        ) {
            VStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(AudioEditorTheme.accentRed.opacity(0.12))
                        .frame(width: 72, height: 72)
                    
                    Image(systemName: "video.badge.plus")
                        .font(.system(size: 32))
                        .foregroundColor(AudioEditorTheme.accentRed)
                }
                
                VStack(spacing: 4) {
                    Text("Chọn Video từ Photos")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(Color(UIColor.label))
                    
                    Text("Hỗ trợ MP4, MOV, Cinematic và Video quay màn hình")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 200)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [6]))
                    .foregroundColor(Color(UIColor.systemGray4))
            )
            .padding(.horizontal, 20)
        }
        .onChange(of: selectedItem) { newItem in
            Task {
                await handlePickedVideo(newItem)
            }
        }
    }
    
    private var videoSelectedCard: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.black.opacity(0.85))
                    .frame(width: 64, height: 64)
                
                Image(systemName: "film.fill")
                    .font(.system(size: 28))
                    .foregroundColor(.white)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(videoTitle)
                    .font(.system(size: 16, weight: .bold))
                    .lineLimit(1)
                
                HStack(spacing: 10) {
                    Text(formatDuration(videoDuration))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(AudioEditorTheme.accentRed)
                    
                    Text("•")
                        .foregroundColor(.secondary)
                    
                    Text(ByteCountFormatter.string(fromByteCount: videoFileSize, countStyle: .file))
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            PhotosPicker(
                selection: $selectedItem,
                matching: .videos,
                photoLibrary: .shared()
            ) {
                Text("Đổi")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(AudioEditorTheme.accentRed)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(AudioEditorTheme.accentRed.opacity(0.12)))
            }
            .onChange(of: selectedItem) { newItem in
                Task {
                    await handlePickedVideo(newItem)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(UIColor.secondarySystemBackground))
        )
        .padding(.horizontal, 20)
    }
    
    // MARK: - Handlers
    
    private func handlePickedVideo(_ item: PhotosPickerItem?) async {
        guard let item = item else { return }
        
        do {
            if let movie = try await item.loadTransferable(type: VideoTransferable.self) {
                let asset = AVURLAsset(url: movie.url)
                let duration = try await asset.load(.duration)
                let durationSecs = CMTimeGetSeconds(duration)
                let resourceValues = try? movie.url.resourceValues(forKeys: [.fileSizeKey])
                let size = Int64(resourceValues?.fileSize ?? 0)
                
                await MainActor.run {
                    self.selectedVideoURL = movie.url
                    self.videoTitle = movie.url.deletingPathExtension().lastPathComponent
                    self.videoDuration = durationSecs.isNaN ? 0 : durationSecs
                    self.videoFileSize = size
                }
            }
        } catch {
            print("Failed to load video: \(error)")
        }
    }
    
    // MARK: - Circular Percentage Progress Overlay
    private var progressOverlay: some View {
        ZStack {
            Color.black.opacity(0.48)
                .ignoresSafeArea()
                .transition(.opacity)
            
            VStack(spacing: 20) {
                // Circular Progress Ring
                ZStack {
                    // Outer background track
                    Circle()
                        .stroke(
                            Color(UIColor.systemGray5),
                            lineWidth: 12
                        )
                        .frame(width: 140, height: 140)
                    
                    // Dynamic filled percentage ring
                    Circle()
                        .trim(from: 0.0, to: CGFloat(min(max(extractionProgress, 0.01), 1.0)))
                        .stroke(
                            LinearGradient(
                                colors: [
                                    AudioEditorTheme.accentRed,
                                    AudioEditorTheme.playedWaveform
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            style: StrokeStyle(lineWidth: 12, lineCap: .round)
                        )
                        .frame(width: 140, height: 140)
                        .rotationEffect(.degrees(-90))
                        .animation(.linear(duration: 0.08), value: extractionProgress)
                    
                    // Percentage & Waveform icon in center
                    VStack(spacing: 3) {
                        Image(systemName: extractionProgress >= 1.0 ? "checkmark.circle.fill" : "waveform")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(extractionProgress >= 1.0 ? .green : AudioEditorTheme.accentRed)
                        
                        Text("\(Int(min(max(extractionProgress * 100, 1), 100)))%")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundColor(Color(UIColor.label))
                    }
                }
                .padding(.top, 6)
                
                VStack(spacing: 6) {
                    Text("Đang trích xuất âm thanh")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(Color(UIColor.label))
                    
                    Text(statusMessageForProgress(extractionProgress))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(height: 36)
                        .padding(.horizontal, 6)
                }
                
                // Cancel button
                Button(action: cancelExtraction) {
                    Text("Hủy bỏ")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(AudioEditorTheme.accentRed)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(AudioEditorTheme.accentRed.opacity(0.12))
                        )
                }
            }
            .padding(26)
            .frame(width: 290)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color(UIColor.systemBackground))
                    .shadow(color: Color.black.opacity(0.2), radius: 24, x: 0, y: 12)
            )
            .transition(.scale(scale: 0.9).combined(with: .opacity))
        }
        .zIndex(100)
    }
    
    private func statusMessageForProgress(_ progress: Float) -> String {
        switch progress {
        case 0.0..<0.25:
            return "Đang nạp video và khởi tạo tiến trình..."
        case 0.25..<0.65:
            return "Đang trích xuất dải âm thanh từ video..."
        case 0.65..<0.90:
            return "Đang mã hóa định dạng \(outputFormat.rawValue)..."
        case 0.90..<1.0:
            return "Đang lưu tệp âm thanh vào Thư viện..."
        default:
            return "Trích xuất thành công! (100%)"
        }
    }
    
    private func cancelExtraction() {
        extractionTask?.cancel()
        withAnimation {
            isExtracting = false
            extractionProgress = 0.0
        }
    }
    
    private func startExtraction() {
        guard let videoURL = selectedVideoURL else { return }
        withAnimation(.easeInOut(duration: 0.2)) {
            isExtracting = true
            extractionProgress = 0.01 // Start immediately at 1%
        }
        
        let outputName = videoTitle.isEmpty ? "Extracted_Audio" : videoTitle
        let targetURL = fileManager.destinationURL(baseName: outputName, format: outputFormat)
        
        extractionTask = Task {
            do {
                var isEngineFinished = false
                var engineError: Error? = nil
                
                // Launch native AVFoundation audio extraction in background
                Task {
                    do {
                        try await AudioProcessingEngine.shared.extractAudioFromVideo(
                            videoURL: videoURL,
                            outputURL: targetURL
                        )
                        isEngineFinished = true
                    } catch {
                        engineError = error
                        isEngineFinished = true
                    }
                }
                
                // Smooth progressive count-up from 1% to 92%
                var currentPercent = 1
                while currentPercent < 92 && !Task.isCancelled {
                    try? await Task.sleep(nanoseconds: 30_000_000) // 30ms per step
                    currentPercent += 1
                    await MainActor.run {
                        self.extractionProgress = Float(currentPercent) / 100.0
                    }
                }
                
                // Await background engine completion
                while !isEngineFinished && !Task.isCancelled {
                    try? await Task.sleep(nanoseconds: 60_000_000)
                    if currentPercent < 96 {
                        currentPercent += 1
                        await MainActor.run {
                            self.extractionProgress = Float(currentPercent) / 100.0
                        }
                    }
                }
                
                if let error = engineError {
                    throw error
                }
                
                guard !Task.isCancelled else { return }
                
                // Smoothly finish 93% -> 100%
                while currentPercent < 100 && !Task.isCancelled {
                    try? await Task.sleep(nanoseconds: 25_000_000)
                    currentPercent += 1
                    await MainActor.run {
                        self.extractionProgress = Float(currentPercent) / 100.0
                    }
                }
                
                await MainActor.run {
                    self.extractionProgress = 1.0
                }
                
                // Hold at 100% so user clearly sees full completion
                try? await Task.sleep(nanoseconds: 450_000_000)
                
                guard !Task.isCancelled else { return }
                
                await MainActor.run {
                    fileManager.reloadLibrary()
                    withAnimation(.easeInOut(duration: 0.25)) {
                        isExtracting = false
                    }
                    showSuccessAlert = true
                }
            } catch is CancellationError {
                await MainActor.run {
                    withAnimation {
                        isExtracting = false
                        extractionProgress = 0.0
                    }
                }
            } catch {
                await MainActor.run {
                    withAnimation {
                        isExtracting = false
                        extractionProgress = 0.0
                    }
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    private func formatDuration(_ s: TimeInterval) -> String {
        let t = Int(max(0, s))
        let m = t / 60
        let sec = t % 60
        return String(format: "%02d:%02d", m, sec)
    }
}

/// Helper transferable type for PhotosPicker video transfer
struct VideoTransferable: Transferable {
    let url: URL
    
    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .movie) { movie in
            SentTransferredFile(movie.url)
        } importing: { received in
            let tempDir = FileManager.default.temporaryDirectory
            let copyUrl = tempDir.appendingPathComponent(received.file.lastPathComponent)
            try? FileManager.default.removeItem(at: copyUrl)
            try FileManager.default.copyItem(at: received.file, to: copyUrl)
            return Self(url: copyUrl)
        }
    }
}
