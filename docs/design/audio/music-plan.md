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

## Đề xuất: nhạc riêng từng vùng (2026-11-13, chưa tạo)
Giữ chung "ADN" của Tessera (hoà tấu nhỏ, chậm, u buồn, không điện ảnh, dải 1–4 kHz thưa trong bản trận); mỗi vùng đổi
**một nhạc cụ đặc trưng + giọng + tempo**. Mỗi vùng: bản khám phá (create) → bản trận (restyle, cùng giai điệu) → 2 vòng
lặp. Bản boss và stinger thắng / thua dùng chung. Tâm Lưới (an_dai): restyle chủ đề Rừng Sương thành bản trang nghiêm,
để trận cuối nghe lại giai điệu mở đầu.

| Vùng (id) | Nhạc cụ đặc trưng | Giọng / bpm | Không khí |
|---|---|---|---|
| Rừng Sương (ch1) | đã có | D Dorian / 80 | |
| Hầm Ngục (ch2) | cello trầm kéo dài, harp gảy thưa, clarinet trầm | E Aeolian / 70 | lạnh, ẩm, tối, vang đá |
| Tháp Sương (ch3) | celesta / chuông thuỷ tinh, dây cao bồi âm, sáo hơi | F# Aeolian / 72 | lạnh, cao, trong |
| Đầm Lầy Độc (swamp) | bass clarinet, dây gảy trầm, trống tay thưa | G Phrygian / 76 | nặng, ngột, lầy lội |
| Sa Mạc Cát Vùi (desert) | đàn lute gảy, frame drum, sáo thổi đầu | A Phrygian / 84 | nóng, khô, cổ xưa |
| Thành Hỏa Ngục (hellfire) | ostinato cello + bass, trống trầm như nhịp tim, harp tối | C Aeolian / 88 | căng, nóng, nhịp đập |
| Không Đảo (sky_isles) | harp, sáo cao, dây nhẹ, chuông gió | G Lydian / 84 | rộng, gió, sáng hơn |
| Tâm Lưới (an_dai) | restyle chủ đề Rừng Sương: dây chậm, harp, chuông, pad hợp xướng không lời rất nhẹ | D Dorian / 70 | trang nghiêm, yên |

Chi phí (gen gói Tier 2): 6 vùng × (10 create + 10 restyle + 2 × 4 loop) = 168; Tâm Lưới 10 restyle + 4 loop = 14.
Tổng ~182 gen. Hai đợt: đợt 3 = 7 bản khám phá / Tâm Lưới (70 gen) → người dùng chọn take; đợt 4 = 6 bản trận + 13 vòng
lặp (~112 gen).
Code: thêm `music.regions` {region_id: {explore, battle}} vào audio_events.json, MusicPlayer chọn theo vùng của run
(thiếu vùng → Rừng Sương); an_dai dùng bản riêng cho cả khám phá lẫn trận cuối.
