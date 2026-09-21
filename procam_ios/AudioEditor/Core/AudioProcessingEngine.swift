import Foundation
import AVFoundation

/// High-performance, 100% App Store compliant native audio processing engine
/// using AVFoundation, AudioToolbox, and CoreMedia.
public final class AudioProcessingEngine {
    
    public static let shared = AudioProcessingEngine()
    
    private init() {}
    
    // MARK: - Video to Audio Extraction
    
    /// Extracts audio track from video file and exports to audio format (M4A/AAC or WAV)
    public func extractAudioFromVideo(
        videoURL: URL,
        outputURL: URL,
        progressHandler: ((Float) -> Void)? = nil
    ) async throws {
        let asset = AVURLAsset(url: videoURL)
        let audioTracks = try await asset.loadTracks(withMediaType: .audio)
        guard !audioTracks.isEmpty else {
            throw AudioProcessingError.noAudioTrackFound
        }
        
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("extract_\(UUID().uuidString).m4a")
        try? FileManager.default.removeItem(at: tempURL)
        defer {
            try? FileManager.default.removeItem(at: tempURL)
        }
        
        guard let exportSession = AVAssetExportSession(
            asset: asset,
            presetName: AVAssetExportPresetAppleM4A
        ) else {
            throw AudioProcessingError.exportSessionCreationFailed
        }
        
        exportSession.outputURL = tempURL
        exportSession.outputFileType = .m4a
        
        // Progress polling task
        let progressMonitor = Task {
            while !Task.isCancelled {
                let p = exportSession.progress
                progressHandler?(p)
                if exportSession.status == .completed || exportSession.status == .failed || exportSession.status == .cancelled {
                    break
                }
                try? await Task.sleep(nanoseconds: 50_000_000) // 50ms interval
            }
        }
        
        await withTaskCancellationHandler {
            await exportSession.export()
        } onCancel: {
            exportSession.cancelExport()
        }
        
        progressMonitor.cancel()
        
        if Task.isCancelled || exportSession.status == .cancelled {
            throw CancellationError()
        }
        
        if let error = exportSession.error {
            throw error
        }
        if exportSession.status != .completed {
            throw AudioProcessingError.exportFailed(exportSession.status)
        }
        
        progressHandler?(1.0)
        
        // Clean and move to final output destination
        try? FileManager.default.removeItem(at: outputURL)
        try FileManager.default.moveItem(at: tempURL, to: outputURL)
    }
    
    // MARK: - Audio Trimming
    
    /// Trims an audio file to the specified time window
    public func trimAudio(
        inputURL: URL,
        outputURL: URL,
        startTime: TimeInterval,
        endTime: TimeInterval
    ) async throws {
        let asset = AVURLAsset(url: inputURL)
        let duration = try await asset.load(.duration)
        let durationSeconds = CMTimeGetSeconds(duration)
        
        let validStart = max(0, min(startTime, durationSeconds))
        let validEnd = min(max(validStart + 0.1, endTime), durationSeconds)
        
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("trim_\(UUID().uuidString).m4a")
        try? FileManager.default.removeItem(at: tempURL)
        defer {
            try? FileManager.default.removeItem(at: tempURL)
        }
        
        guard let exportSession = AVAssetExportSession(
            asset: asset,
            presetName: AVAssetExportPresetAppleM4A
        ) else {
            throw AudioProcessingError.exportSessionCreationFailed
        }
        
        let startCMTime = CMTime(seconds: validStart, preferredTimescale: 600)
        let durationCMTime = CMTime(seconds: validEnd - validStart, preferredTimescale: 600)
        let timeRange = CMTimeRange(start: startCMTime, duration: durationCMTime)
        
        exportSession.outputURL = tempURL
        exportSession.outputFileType = .m4a
        exportSession.timeRange = timeRange
        
        await exportSession.export()
        
        if let error = exportSession.error {
            throw error
        }
        if exportSession.status != .completed {
            throw AudioProcessingError.exportFailed(exportSession.status)
        }
        
        try? FileManager.default.removeItem(at: outputURL)
        try FileManager.default.moveItem(at: tempURL, to: outputURL)
    }
    
    // MARK: - Audio Merging
    
    /// Concatenates multiple audio files into a single continuous track
    public func mergeAudioFiles(
        inputURLs: [URL],
        outputURL: URL
    ) async throws {
        guard !inputURLs.isEmpty else {
            throw AudioProcessingError.emptyInputList
        }
        
        let composition = AVMutableComposition()
        guard let compositionAudioTrack = composition.addMutableTrack(
            withMediaType: .audio,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ) else {
            throw AudioProcessingError.compositionTrackCreationFailed
        }
        
        var currentTime = CMTime.zero
        
        for url in inputURLs {
            let asset = AVURLAsset(url: url)
            let tracks = try await asset.loadTracks(withMediaType: .audio)
            guard let track = tracks.first else { continue }
            
            let trackDuration = try await track.load(.timeRange).duration
            let range = CMTimeRange(start: .zero, duration: trackDuration)
            
            try compositionAudioTrack.insertTimeRange(range, of: track, at: currentTime)
            currentTime = CMTimeAdd(currentTime, trackDuration)
        }
        
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("merge_\(UUID().uuidString).m4a")
        try? FileManager.default.removeItem(at: tempURL)
        defer {
            try? FileManager.default.removeItem(at: tempURL)
        }
        
        guard let exportSession = AVAssetExportSession(
            asset: composition,
            presetName: AVAssetExportPresetAppleM4A
        ) else {
            throw AudioProcessingError.exportSessionCreationFailed
        }
        
        exportSession.outputURL = tempURL
        exportSession.outputFileType = .m4a
        
        await exportSession.export()
        
        if let error = exportSession.error {
            throw error
        }
        if exportSession.status != .completed {
            throw AudioProcessingError.exportFailed(exportSession.status)
        }
        
        try? FileManager.default.removeItem(at: outputURL)
        try FileManager.default.moveItem(at: tempURL, to: outputURL)
    }
    
    // MARK: - Audio Effects & Export (Volume & Fade)
    
    /// Exports audio applying volume multiplier and fade in / fade out ramps
    public func processAudioWithEffects(
        inputURL: URL,
        outputURL: URL,
        config: AudioExportConfig
    ) async throws {
        let asset = AVURLAsset(url: inputURL)
        let tracks = try await asset.loadTracks(withMediaType: .audio)
        guard let audioTrack = tracks.first else {
            throw AudioProcessingError.noAudioTrackFound
        }
        
        let composition = AVMutableComposition()
        guard let compTrack = composition.addMutableTrack(
            withMediaType: .audio,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ) else {
            throw AudioProcessingError.compositionTrackCreationFailed
        }
        
        let assetDuration = try await asset.load(.duration)
        let assetDurationSecs = CMTimeGetSeconds(assetDuration)
        
        let startSec = max(0, config.trimStartTime ?? 0)
        let endSec = min(assetDurationSecs, config.trimEndTime ?? assetDurationSecs)
        let effectiveDuration = max(0.1, endSec - startSec)
        
        let sourceRange = CMTimeRange(
            start: CMTime(seconds: startSec, preferredTimescale: 600),
            duration: CMTime(seconds: effectiveDuration, preferredTimescale: 600)
        )
        
        try compTrack.insertTimeRange(sourceRange, of: audioTrack, at: .zero)
        
        // Build Audio Mix with Volume and Fade Ramps
        let audioMix = AVMutableAudioMix()
        let mixParams = AVMutableAudioMixInputParameters(track: compTrack)
        
        let baseVolume = config.effects.volumeMultiplier
        let fadeIn = config.effects.fadeInDuration
        let fadeOut = config.effects.fadeOutDuration
        
        if fadeIn > 0 {
            let fadeInCM = CMTime(seconds: min(fadeIn, effectiveDuration / 2), preferredTimescale: 600)
            mixParams.setVolumeRamp(
                fromStartVolume: 0.0,
                toEndVolume: baseVolume,
                timeRange: CMTimeRange(start: .zero, duration: fadeInCM)
            )
        } else {
            mixParams.setVolume(baseVolume, at: .zero)
        }
        
        if fadeOut > 0 {
            let fadeOutDurationSecs = min(fadeOut, effectiveDuration / 2)
            let fadeOutStartSecs = max(0, effectiveDuration - fadeOutDurationSecs)
            let fadeOutStartTime = CMTime(seconds: fadeOutStartSecs, preferredTimescale: 600)
            let fadeOutDurationCM = CMTime(seconds: fadeOutDurationSecs, preferredTimescale: 600)
            
            mixParams.setVolumeRamp(
                fromStartVolume: baseVolume,
                toEndVolume: 0.0,
                timeRange: CMTimeRange(start: fadeOutStartTime, duration: fadeOutDurationCM)
            )
        }
        
        audioMix.inputParameters = [mixParams]
        
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("effects_\(UUID().uuidString).m4a")
        try? FileManager.default.removeItem(at: tempURL)
        defer {
            try? FileManager.default.removeItem(at: tempURL)
        }
        
        guard let exportSession = AVAssetExportSession(
            asset: composition,
            presetName: AVAssetExportPresetAppleM4A
        ) else {
            throw AudioProcessingError.exportSessionCreationFailed
        }
        
        exportSession.outputURL = tempURL
        exportSession.outputFileType = .m4a
        exportSession.audioMix = audioMix
        
        await exportSession.export()
        
        if let error = exportSession.error {
            throw error
        }
        if exportSession.status != .completed {
            throw AudioProcessingError.exportFailed(exportSession.status)
        }
        
        try? FileManager.default.removeItem(at: outputURL)
        try FileManager.default.moveItem(at: tempURL, to: outputURL)
    }
}

public enum AudioProcessingError: LocalizedError {
    case noAudioTrackFound
    case exportSessionCreationFailed
    case compositionTrackCreationFailed
    case emptyInputList
    case exportFailed(AVAssetExportSession.Status)
    
    public var errorDescription: String? {
        switch self {
        case .noAudioTrackFound:
            return "Không tìm thấy luồng âm thanh trong tệp này."
        case .exportSessionCreationFailed:
            return "Không thể khởi tạo phiên xuất âm thanh."
        case .compositionTrackCreationFailed:
            return "Không thể tạo track âm thanh tổng hợp."
        case .emptyInputList:
            return "Danh sách tệp cần ghép đang trống."
        case .exportFailed(let status):
            return "Quá trình xuất tệp thất bại (mã trạng thái: \(status.rawValue))."
        }
    }
}
