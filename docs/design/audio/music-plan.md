# Nhạc MVP — kế hoạch (2026-11-13)

Quyết định A8 (`docs/skill-v2/10-audio-system-design.md` dòng 340): người dùng chọn **tự làm bằng AI**, dùng công cụ đã kết
nối. Hướng nhạc giữ §8 của tài liệu đó (fantasy u buồn, hoà tấu nhỏ, 70–90 bpm, Dorian / Aeolian, nhạc trận để trống dải
1–4 kHz cho cảnh báo) và tinh thần bản sắc chung (`unified-audio-identity.md`): **nhẹ, thưa, dễ chịu, không điện ảnh**.

## Công cụ: PixelLab
- `create_music`: 2 take / lần, $0.08 (10 generation), nhạc không lời.
- `make_music_loop`: làm lại bài thành vòng lặp liền mạch có điểm lặp (`loop_start` / `loop_end`), $0.033.
- `restyle_song_id`: giữ giai điệu, đổi phối khí → bản trận đấu cùng chủ đề với bản khám phá (thay cho stem thật,
  crossfade giữa hai bản cùng tempo và giọng).
- ElevenLabs Music không có vòng lặp liền mạch và không giữ giai điệu khi đổi phối, nên không chọn cho nhạc.

## 4 bản MVP
| # | Bản | Cách làm | Dùng ở |
|---|---|---|---|
| 1 | Chủ đề Rừng Sương (khám phá) | create → chọn take → loop | bản đồ leo, ngoài trận |
| 2 | Rừng Sương — trận đấu | restyle bản 1 (cùng giai điệu, thêm nhịp) → loop | trận thường, crossfade từ bản 1 |
| 3 | Boss | create → chọn take → loop | trận boss |
| 4 | Thắng / thua | create ngắn, cắt 3–5 s | cuối trận (thay nốt `flow.*` hiện có hay đi kèm: quyết định khi nghe) |

Mỗi đợt tạo đều chờ người dùng đồng ý (PixelLab: duyệt từng đợt). File gốc lưu `audio_src/pixellab/music/`,
bản dùng trong game ở `assets/audio/music/` (OGG lặp, ghi nguồn trong `CREDITS.md`).

## Phát nhạc (sau khi có file)
`MusicPlayer` trong `src/audio` (bus Music, đã có sẵn trong bus layout và cài đặt âm lượng): theo pha của GameFlow /
RunController (bản đồ → khám phá, trận → trận đấu, boss → boss), crossfade 1–2 s, không phát lại từ đầu khi chuyển
khám phá ↔ trận; bị duck bởi cảnh báo như §6. Chỉ lắng nghe tín hiệu, không sửa gameplay.

## Âm thanh nền theo vùng
Hoãn theo `unified-audio-identity.md` §8 mục 4: bắt đầu sau khi Phase 4 multi-enemy được commit.

## Trạng thái (2026-11-13)
- Đợt 1 (40 gen) + đợt 2 (22 gen) xong; người dùng chọn take 1 cho mọi bản. File game: `assets/audio/music/`
  (`MUSIC_CREDITS.md`), file gốc + song id: `audio_src/pixellab/music/SOURCES.md`.
- Thắng / thua giữ đủ ~9.8 s (đo âm lượng: còn mạnh đến ~6.5 s, cắt 5 s là cắt giữa câu). Nốt chuông `flow.victory` /
  `flow.defeat` cũ (Đô trưởng, lệch giọng với nhạc Rê) đã bỏ khỏi `on_match_ended` theo lời người dùng; sự kiện và file
  vẫn giữ trong data nhưng không ai phát.
- `MusicPlayer` (src/audio/music_player.gd), gắn trong `AudioRig`: khám phá ngoài trận, trận / boss khi đang đánh,
  stinger khi trận kết thúc (giữ 7 s rồi trở lại khám phá), crossfade 1.5 s, quay lại bản đã rời thì phát tiếp từ chỗ cũ.
