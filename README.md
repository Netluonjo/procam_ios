# MP3 Converter & Audio Editor for iOS

Ứng dụng biên tập, chuyển đổi âm thanh và đồng bộ lời bài hát Karaoke chuyên nghiệp cho iOS (viết bằng **SwiftUI**, **AVFoundation**, **Network framework**, **Speech Recognition**).

---

## 🎵 Tính năng cốt lõi (Features)

### 1. Trình phát nhạc Studio & Lời bài hát Karaoke (Studio Player & Synced Lyrics)
- **Sóng âm thanh trực quan (Waveform Visualizer):** Hiển thị dạng sóng âm thanh tương tác theo thời gian thực, hỗ trợ cuộn và trượt playhead với kim đỏ trung tâm chuẩn xác.
- **Lời bài hát Karaoke chạy chữ thời gian thực (Synchronized Lyrics):**
  - Tự động cuộn mượt mà theo đúng câu hát đang phát.
  - Chạm vào bất kỳ câu hát nào để nhảy ngay đến đoạn nhạc tương ứng (Tap to Seek).
  - Tinh chỉnh độ lệch thời gian (Offset +/- 0.5s) để khớp hoàn hảo giữa âm thanh và lời.
- **Tìm kiếm lời bài hát tự động (Online & Offline LRC Search):**
  - Kho lời ngoại tuyến sẵn có cho nhiều bài hát thịnh hành (như *Xương Rồng - Dangrangto*, *Ghi âm 1*, v.v.).
  - Tìm kiếm lời đồng bộ trực tuyến từ cơ sở dữ liệu mở quốc tế (LRCLIB).
- **Tự động trích xuất lời thoại bằng AI (Speech Recognition):** Sử dụng Apple Speech AI để nhận diện giọng nói và chia mốc thời gian LRC tự động.

### 2. Bộ công cụ xử lý âm thanh chuyên nghiệp (Audio Processing Tools)
- **Bóc âm thanh từ Video (Video to MP3):** Chọn video trực tiếp từ Photos, trích xuất âm thanh ra các định dạng MP3, M4A, WAV, AAC với vòng tiến trình phần trăm hiển thị 1-100%.
- **Cắt nhạc (Audio Trimmer):** Cắt đoạn điệp khúc bằng 2 tay cầm trượt trực quan, nghe thử đoạn cắt tức thì.
- **Ghép nhạc (Audio Merger):** Nối nhiều file âm thanh tuần tự thành một bài hát duy nhất.
- **Tăng âm lượng (Volume Booster):** Khuếch đại âm lượng lên đến 200% - 300%.
- **Hiệu ứng mờ dần (Fade In / Fade Out):** Tùy chỉnh hiệu ứng to dần ở đầu bài và nhỏ dần ở cuối bài.
- **Đổi định dạng âm thanh (Format Converter):** Tùy biến linh hoạt Format (MP3, M4A, WAV, AAC, FLAC, M4R), Sample Rate (44.1kHz, 48kHz, 96kHz) và Bitrate (128k, 192k, 256k, 320k).
- **Nhạc chuông iPhone (M4R):** Xuất định dạng M4R kèm hướng dẫn cài đặt qua GarageBand không cần máy tính.

### 3. Truyền file hai chiều qua Wi-Fi (Wi-Fi Web Transfer)
- Tích hợp sẵn máy chủ HTTP nhẹ (`NWListener`) trên iPhone cổng `8080`.
- Mở trình duyệt web trên máy tính (PC/Mac) theo địa chỉ IP cục bộ để:
  - Tải lên (upload) nhạc từ máy tính sang điện thoại nhanh chóng.
  - Nghe thử và tải về (download) các bài hát đã chỉnh sửa từ điện thoại về máy tính.
  - Xem nhật ký truyền nhận file thời gian thực trên màn hình ứng dụng.

---

## 🏗 Cấu trúc dự án (Project Structure)

```
procam_ios/
├── procam_ios.xcodeproj/
│   └── project.pbxproj             # File cấu hình đồ án Xcode đã tối ưu sạch 100%
├── README.md
│
└── procam_ios/
    ├── ProCamApp.swift             # Điểm khởi chạy ứng dụng SwiftUI (@main)
    ├── Info.plist                  # Cấu hình quyền Microphone, PhotoLibrary, Speech, LocalNetwork
    │
    ├── AudioEditor/
    │   ├── Models/
    │   │   ├── AudioTrack.swift            # Model bài hát, thời lượng, kích thước, waveform
    │   │   ├── AudioExportConfig.swift     # Enums định dạng, sample rate, bitrate, effects
    │   │   ├── AudioToolType.swift         # Định nghĩa các công cụ trong app
    │   │   └── LyricLine.swift             # Model câu lời bài hát & bộ phân giải LRC
    │   │
    │   ├── Core/
    │   │   ├── AudioFileManager.swift          # Quản trị file Documents, import & lưu trữ
    │   │   ├── AudioPlayerManager.swift        # Trình phát nhạc AVPlayer, scrubbing & sync lyrics
    │   │   ├── AudioProcessingEngine.swift     # Xử lý cắt ghép, trích xuất, fade an toàn
    │   │   ├── FFmpegCommandBridge.swift       # Xây dựng chuỗi lệnh FFmpeg chuẩn
    │   │   ├── LyricSearchService.swift        # Tìm kiếm lời bài hát trực tuyến (LRCLIB API)
    │   │   ├── OfflineLyricsStore.swift        # Kho lời bài hát ngoại tuyến (Xương Rồng, etc.)
    │   │   ├── SpeechRecognitionService.swift  # Apple Speech AI trích xuất lyric từ giọng nói
    │   │   ├── WaveformExtractor.swift         # Tính toán biên độ sóng âm thanh
    │   │   ├── WifiHttpServer.swift            # Embedded HTTP Server phục vụ Web Transfer
    │   │   └── WifiTransferManager.swift       # Quản trị trạng thái server & IP Wi-Fi
    │   │
    │   └── UI/
    │       ├── Theme/
    │       │   └── AudioEditorTheme.swift      # Bảng màu Coral Red & Surface Dark/Light
    │       ├── Components/
    │       │   ├── AudioControlButtonsView.swift   # Cụm phím Play/Pause, tua 10s, tốc độ, loop
    │       │   ├── AudioLyricsSyncedView.swift    # View lời bài hát Karaoke chạy chữ thời gian thực
    │       │   ├── AudioScrubberBar.swift          # Thanh trượt thời gian nghe nhạc
    │       │   ├── AudioWaveformVisualizer.swift   # Bàn hiển thị sóng âm thanh trượt
    │       │   └── WaveformTrimmerOverlay.swift    # Hai tay cầm cắt nhạc trực quan
    │       └── Screens/
    │           ├── AudioEditorMainView.swift       # 3 Tab điều hướng (Studio, Công cụ, Thư viện)
    │           ├── AudioPlayerDetailView.swift     # Màn hình nghe nhạc chi tiết
    │           ├── AudioToolsGridView.swift        # Màn hình lưới chọn công cụ
    │           ├── AudioLibraryView.swift          # Màn hình danh sách nhạc & import
    │           ├── VideoToAudioView.swift          # Màn hình bóc MP3 từ Video
    │           ├── AudioTrimmerSheet.swift         # Modal cắt nhạc
    │           ├── AudioMergerView.swift           # Màn hình ghép nối file
    │           ├── AudioEffectsSheet.swift         # Modal chỉnh âm lượng & Fade
    │           ├── ExportSettingsSheet.swift       # Modal xuất file & đổi định dạng
    │           ├── LyricSearchSheet.swift          # Modal tìm kiếm lời bài hát
    │           └── WifiTransferView.swift          # Màn hình máy chủ Wi-Fi Transfer
    │
    └── Resources/
        ├── web_transfer.html       # Trang web điều khiển truyền file trên máy tính
        └── Assets.xcassets/        # AppIcon và tài nguyên đồ họa
```

---

## 🚀 Hướng dẫn mở và chạy trên macOS (Xcode)

1. Mở dự án trong **Terminal** trên máy Mac:
   ```bash
   git clone https://github.com/Netluonjo/procam_ios.git
   cd procam_ios
   open procam_ios.xcodeproj
   ```
2. Chọn thiết bị đích trên thanh công cụ của Xcode (iPhone thật hoặc iOS Simulator iPhone 15/16).
3. Vào tab **Signing & Capabilities** để chọn Team cá nhân của bạn.
4. Nhấn **Cmd + R** (hoặc nút Play) để biên dịch và trải nghiệm!
