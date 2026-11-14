# Âm thanh nền theo vùng (đề xuất 2026-11-14; làm xong và người dùng duyệt cùng ngày)

Nguồn hướng: `docs/skill-v2/10-audio-system-design.md` §8 (bảng "Ambience palette", "under music, culled first",
Ambience 2 loops + 2 one-shots, Ogg, giảm âm thì bỏ one-shot) và bản sắc chung `unified-audio-identity.md` (nhẹ,
thưa, không drone gây căng). Điều kiện "sau Phase 4 multi-enemy" đã đủ (1d859a17, ký a40b53bb).

## Nguyên tắc
- **Một lớp nền liên tục mỗi vùng** (gió, nước, lửa...) + **2 tiếng lẻ hiếm** (chim, xích, ếch...) phát ngẫu nhiên
  mỗi 15–40 s. Không giai điệu, không tiếng nói, không tiếng gây giật mình.
- Nằm **dưới nhạc ~8 dB**: nhạc đang ở −23 LUFS → nền ~−31 LUFS. Trong trận nền hạ thêm 6 dB và tắt tiếng lẻ,
  để dải cảnh báo luôn sạch.
- Chế độ **Giảm âm thanh** bỏ tiếng lẻ (như tài liệu §8). Thanh âm lượng Ambience đã có sẵn trong cài đặt.
- Đổi vùng: crossfade 2 s. Màn tiêu đề: không có nền.

## Bảng vùng
| Vùng (id) | Lớp nền 30 s | 2 tiếng lẻ (~3 s) |
|---|---|---|
| Rừng Sương (ch1) | gió nhẹ qua lá, sương tĩnh | chim xa hót một câu; giọt nước rơi trên đá |
| Hầm Ngục (ch2) | không khí phòng đá ẩm, vang trầm | nước nhỏ giọt vang; xích kéo lê xa |
| Tháp Sương (ch3) | gió rít lạnh qua khe | băng nứt kêu răng rắc; tinh thể leng keng |
| Đầm Lầy Độc (swamp) | côn trùng rì rầm, bùn sủi nhẹ | ếch kêu; bong bóng bùn vỡ |
| Sa Mạc Cát Vùi (desert) | gió khô, cát rít | gió giật cuốn cát; đá cổ lạo xạo |
| Thành Hỏa Ngục (hellfire) | lửa xa rền, đất ầm trầm | dung nham phụt; than nổ lách tách |
| Không Đảo (sky_isles) | gió cao lộng | chuông gió; đá đảo kêu kẽo kẹt |
| Tâm Lưới (an_dai) | tiếng ngân cộng hưởng trầm, yên | một tiếng tinh thể ngân; nhịp ngân sâu |

## Công cụ và chi phí
PixelLab `create_sound_effect` (gói Tier 2, đã dùng cho nhạc): 1 clip / lần, không có take đôi.
- Lớp nền 30 s = 19 gen × 8 vùng = **152 gen**.
- Tiếng lẻ ~3 s = 2 gen × 16 = **32 gen**.
- **Tổng ~184 gen** (còn ~918 sau phần nhạc). Làm lại clip hỏng: mỗi clip tính riêng, hỏi trước.
- Vòng lặp: PixelLab không làm điểm lặp cho hiệu ứng, nên tôi tự nối bằng ffmpeg: đuôi 3 s crossfade vào đầu
  (miễn phí; tiếng nền dạng nhiễu nối rất dễ không lộ). Kiểm bằng file nghe chỗ nối như phần nhạc.

## Code (sau khi có file)
- `src/audio/ambience_player.gd` (bus Ambience) gắn trong `AudioRig` cạnh MusicPlayer: chọn nền theo `region_id`,
  crossfade khi đổi vùng, hạ 6 dB và ngắt tiếng lẻ khi đang đánh, tiếng lẻ theo hẹn giờ ngẫu nhiên có seed.
- Dữ liệu: mục `ambience` trong `audio_events.json` {regions: {id: {bed, oneshots[], gap_sec}}, battle_db}.
- Test như `music_player_test`; chạy Godot ngay sau khi thêm `class_name` mới (bài học class cache).
- Quay trong game bằng `tools/audio/music_capture.gd` (đã in cả nhạc; thêm dòng nền).

## Đợt đề xuất
1. **Đợt A (thử, 21 gen):** Rừng Sương: nền 30 s + 1 tiếng lẻ, để duyệt độ to và chất trước khi làm cả 8 vùng.
2. **Đợt B (~163 gen):** 7 vùng còn lại + tiếng lẻ còn lại.

## Kết quả (2026-11-14)
- Đợt A (21 gen) + đợt B (163 gen) xong, người dùng duyệt từng đợt bằng file nghe thử và video trong game.
- 24 file OGG (`assets/audio/ambience/`, 8 nền + 16 tiếng lẻ, 2.4 MB): nền lặp 23 s (Tâm Lưới 19 s, bỏ 6 s đầu đang to dần) ở −31 LUFS,
  tiếng lẻ −30 LUFS có giới hạn đỉnh −12 dBFS. Nguồn và id: `audio_src/pixellab/ambience/SOURCES.md` (WAV gốc chỉ để máy).
- `src/audio/ambience_player.gd` (không class_name, AudioRig preload), dữ liệu mục `ambience` trong audio_events.json,
  test `tests/unit/audio/ambience_player_test.gd`; bằng chứng `production/qa/evidence/ambience/ingame/README.md`.
