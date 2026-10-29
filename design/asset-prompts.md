# Prompt tạo ảnh demo cho Tessera (pixel art)

> **Mục đích:** tạo ảnh concept **để hình dung và kiểm hướng** phong cách đã chốt, trước khi vẽ asset thật. Đây không phải asset dùng trong game.
> **Nguồn:** `design/art/art-bible.md` mục 1–4 (phong cách, không khí, hình khối, màu; chốt 2026-10-28), `design/world-context.md`, `design/glossary.md`.
> Prompt viết bằng **tiếng Anh**, vì công cụ tạo ảnh hiểu tiếng Anh tốt nhất. Phần hướng dẫn viết tiếng Việt.
> Bản trước của file này viết cho kiểu vẽ tay. Art bible đã chọn **pixel art, góc nhìn như One Step From Eden** (chỉ góc nhìn; phần còn lại là bản sắc riêng của Tessera), nên toàn bộ prompt đã viết lại.

---

## Cần biết trước

- **ChatGPT không vẽ pixel art thật.** Ảnh ra "trông như pixel" nhưng pixel không đều, không đúng lưới, màu tràn ra ngoài bảng. Hãy dùng ảnh ChatGPT để chốt **dáng, màu, bố cục**. Đừng dùng làm sprite.
- **Sprite thật** đi theo pipeline trong art bible: gen → thu nhỏ nearest-neighbor → ép bảng màu → sửa tay. Ở cỡ ~40 px, dọn ảnh AI có thể nhanh ngang vẽ tay; đo ở vertical slice.
- **Công cụ pixel chuyên dụng** cho ra đúng lưới hơn, nhưng có phí. Ví dụ PixelLab, Retro Diffusion. Nếu thử, dùng cùng các prompt dưới đây.
- **Cách kiểm ảnh nhân vật:** thu ảnh về cao khoảng 40 px (nearest-neighbor) và tô đen. Vẫn nhận ra được nhân vật thì đạt (test P2 của art bible).

---

## Cách dùng với ChatGPT

1. **Mở một cuộc trò chuyện mới**, chỉ dùng cho Tessera. ChatGPT giữ phong cách tốt hơn khi mọi ảnh nằm chung một cuộc trò chuyện.
2. **Dán tin nhắn "Bối cảnh"** (mục 1) làm tin nhắn đầu tiên. Chỉ để nó đọc, đừng yêu cầu ảnh ngay.
3. **Gửi prompt thử phong cách** (mục 2). Sửa đến khi ưng.
4. **Khóa phong cách.** Gửi câu sau, kèm ảnh bạn chọn:
   > *Use exactly this pixel-art style, pixel size, outline and palette for every image from now on in this chat.*
5. **Gửi từng prompt ở mục 3–9.** Mỗi tin nhắn một prompt.
6. **Muốn sửa thì nói cụ thể.** Ví dụ: *"Same image, but make the knight's sword bigger and keep the background darker."*
7. **Lưu ảnh ưng ý**, kèm ghi chú theo mục 10, rồi gửi cho Claude.

**Lưu ý**
- ChatGPT hay **tự chèn chữ**. Mọi prompt đã có "no text". Nếu ảnh vẫn có chữ, nhắc: *"Remove all text and letters."*
- Ảnh màn hình trận (mục 5) là **quan trọng nhất**.
- Hay bị vi phạm, cần nhắc lại khi thấy:
  - **đỏ** dùng ngoài ô báo đòn;
  - **nền phát sáng**;
  - **lưới nghiêng**.
- Tỉ lệ ảnh:
  - **16:9 ngang:** màn hình, vùng đất, ảnh chủ đề, bản đồ.
  - **1:1 vuông:** nhân vật, boss, bảng khối.

---

## 1. Tin nhắn "Bối cảnh" (dán đầu tiên)

```
I am designing a 2D pixel-art mobile game called "Tessera". Please read this context and the style rules; I will then ask you for concept images one at a time. Do not generate an image for this message.

WORLD: Tessera was an ordinary Western high-fantasy world until "the Cataclysm": the Primal Form that shaped every land shattered at the summit of a great mountain, now called the Lattice Heart. A lattice of square tiles spread across the world. Since then ALL power — magic, swordplay, any technique — only works when channeled through BLOCKS: glowing shapes made of square tiles joined edge to edge (like tetromino and pentomino pieces, 1 to 7 tiles). Heroes and monsters pick up blocks that fall on their side of the grid, rotate them and stamp them onto the enemy's half to strike. Each land lies on its own grid of stone slabs over its old terrain and is guarded by a Warden holding a shard of the Primal Form.

TONE: Western fantasy (NOT Asian wuxia or xianxia, no Chinese ornament), quiet and melancholic, very readable.

STYLE RULES (apply to every image):
1. Pixel art with crisp square pixels of one consistent size, no anti-aliasing, no blur, no painterly brush texture. The battlefield is drawn at 640x360 and scaled up exactly; characters are about 40 pixels tall inside a 32x48 frame.
2. Characters and blocks have a 1-pixel dark ink outline (#1B1722, never pure black). Floor slabs and backgrounds have NO outline.
3. ONLY the blocks glow. Backgrounds and floor are desaturated and darker; no bloom, no glowing torches, no glowing scenery. Glow is a small hand-drawn pixel halo around blocks.
4. All magic and effects are made of SQUARES: blocks stamp as glowing squares, shatter into square shards, dissolve into square particles. No round explosions, no beams, no projectiles.
5. Red is reserved ONLY for incoming-attack warning tiles (red with diagonal stripes). Nothing else is red: no red clothes, no red lava, no red health bars.
6. CAMERA like the game "One Step From Eden" (camera only, not its colours or effects): battle grids are FLAT and seen straight from the front, rectangular tiles wider than tall (not tilted, no perspective). Characters stand UPRIGHT with their feet inside one tile; their head and upper body overlap the row behind. Back rows are drawn first. Behind the grid is a SIDE-VIEW landscape with a horizon near the top; the grid sits on the darker ground plane below it. Each slab is dark stone with a thin 2-3 pixel front lip. The two halves of the battlefield are NOT tinted different colours; they are separated by a small gap.
7. Limited palette (about 32-48 colours). Core colours: ink #1B1722, lattice stone #4A4640, mist #7D8896, ivory #EFE6D2, lattice gold #FFD45C, warning red #E5293B (warnings only), odd-block magenta #E04CD0.
8. No runes, letters or symbols on blocks or terrain.

GAME VIEW: landscape mobile screen. Two grids face each other: the hero's grid on the left, the monster's on the right. Every character stands with its feet in ONE tile. Blocks are never drawn big on the battlefield and heroes never hold or throw them. Placing a block only SELECTS target tiles: those enemy floor tiles light up in the hero's block colour and grow brighter while the spell charges; then the spell effect (made of small squares) falls onto exactly those tiles. When a hero starts a cast they make one short gesture toward the enemy at shoulder height (no glow aura). Monsters casting stand still in a wind-up pose: body hunched, one hand pulled back as if about to throw, the other hand forward, a few tiny ivory square particles gathering at the back hand. They hold NO block and do NOT raise both arms (that reads as surrender). There is no hand cursor anywhere: the player's real finger is the pointer.

ALWAYS: no text, no letters, no numbers, no logos, no watermark.
```

---

## 2. Thử phong cách (một cảnh)

```
Style test. Pixel art battle scene, landscape 16:9. Camera: orthographic side-on stage view, NO perspective. Every tile is an identical flat rectangle about 1.5 times wider than tall; all grid lines are perfectly horizontal or vertical; rows do NOT get smaller toward the back. The two grids sit side by side with a small gap and together span almost the full image width, filling the lower two thirds of the image; the landscape and horizon are only a strip in the top third. Two flat front-facing grids of dark mossy stone slabs with thin front lips (3 by 3 tiles each) separated by a small gap, on a dark ground plane. Behind them a side-view landscape of overgrown forest ruins with low mist and a horizon near the top. On the left grid, a chibi knight in steel-blue plate armor with a big greatsword on his back, about 40 pixels tall, standing upright with feet in his tile, head overlapping the row behind, 1-pixel dark outline, mid-gesture: sword swung horizontally toward the enemy. On the right grid, a goblin with long sideways ears. Four FLOOR tiles in an L shape around the goblin are lit in steel blue-grey (#8FA3B8) with a bevelled light edge: the spell target, charging. No block object is drawn on the grid. Background desaturated moss grey-green, darker than the characters. Crisp uniform pixels, no anti-aliasing, no red anywhere. No text.
```

Không ưng điểm nào thì sửa từng điểm. Ví dụ: *"bigger pixels"*, *"darker background"*, *"less detail on the knight"*. Ưng rồi thì khóa phong cách theo bước 4.

---

## 3. Ảnh chủ đề thế giới

```
Pixel art key art of Tessera, landscape 16:9. A huge mountain at cold dawn rising through clouds. Its slopes are terraced lands from bottom to top: misty forest ruins, a dark dungeon, an ice tower, a poison swamp, a sand-buried plaza, a charcoal citadel with orange-yellow lava in cracks, floating sky islands. A faint lattice-gold grid of square tiles is laid over everything, more visible near the summit. At the summit, the Lattice Heart: a calm geometric heart of gold light made of square tiles. A tiny hero climbs a path; a few glowing square-tile blocks fall slowly from the summit. Desaturated, melancholic, only the blocks and the Heart glow. No red. No text.
```

---

## 4. Năm nhân vật (mỗi nhân vật một tin nhắn)

Khuôn chung. Thay hai chỗ trong ngoặc vuông bằng dòng trong bảng bên dưới:
```
Pixel art character sheet for Tessera, square 1:1, plain dark grey background. [CHARACTER]. Show: (1) the sprite at true small size, about 40 pixels tall in a 32x48 frame, standing upright facing right, 1-pixel dark ink outline, chibi proportions with a big head, all identifying features (weapon, hat) in the upper half; (2) the same sprite enlarged 6x with crisp pixels; (3) the 2-frame cast gesture: a short motion toward the right at shoulder height (see table), nothing raised above the head, nothing thrown, no glow aura; (4) next to them on the ground, a sample block of [BLOCK]. The silhouette must stay recognizable when filled solid black. No red. No text.
```

Cử chỉ niệm (mục (3) của prompt), theo `design/art/art-bible.md` mục 3:

| Nhân vật | Cử chỉ |
|---|---|
| Kiếm sĩ | rút kiếm, chém ngang |
| Pháp sư | đẩy hai tay ra trước |
| Sát thủ | hất hai dao ra trước |
| Thợ săn | giương nỏ ngang |
| Giáo sĩ | chĩa đầu gậy ra trước |

| Nhân vật | [CHARACTER] | [BLOCK] |
|---|---|---|
| Kiếm sĩ | a sturdy knight, rectangular build with square shoulders, steel-blue (#8FA3B8) plate armor with white highlights, a large greatsword strapped diagonally across the back with the hilt above the head | polished steel square tiles with bevelled edges |
| Pháp sư | a thin, tall fire mage with a triangular silhouette, dark charcoal-brown robe (#3A2A26) with amber (#F0A030) trim on the hat band, hem and belt, no book, a tall pointed hat bent at the tip, a spellbook | dark charcoal square tiles with one glowing amber crack each |
| Sát thủ | a low crouching rogue with a flat diamond silhouette, dark leather with pale jade-white (#BFF3EC) accents, a pointed hood, two daggers pointing sideways | small translucent jade-white ice square tiles with sharp corners |
| Thợ săn | a ranger with a T-shaped silhouette, brown leather and moss green, a wide-brimmed hat, a crossbow slung across the shoulders, jade (#46D6A4) rope details | wooden frame square tiles bound with jade rope |
| Giáo sĩ | a calm cleric with a wide bell-shaped robe silhouette, white and pale silver vestments with pale lilac glass details, a staff topped with a square inside a square | pale lilac stained-glass square tiles divided by grey lead lines |

Sau khi có đủ 5 nhân vật:
```
Pixel art lineup of all five Tessera heroes side by side at the same true size (about 40 pixels tall, standing upright), then the same lineup filled solid black as silhouettes below it. Each stands next to a sample of their own block lying on the ground (not holding it). Dark grey background. No text. Landscape 16:9.
```

Hàng bóng đen là test P2: năm dáng phải khác nhau rõ.

---

## 5. Màn hình trận đấu (quan trọng nhất)

```
Pixel art mobile game battle screen mockup for Tessera, landscape 16:9. Camera: orthographic side-on stage view, NO perspective. Every tile is an identical flat rectangle about 1.5 times wider than tall; all grid lines are perfectly horizontal or vertical; rows do NOT get smaller toward the back. The two grids sit side by side with a small gap and together span almost the full image width, filling the lower two thirds of the image; the landscape and horizon are only a strip in the top third. Two FLAT front-facing grids of dark stone slabs, each 3 by 3 tiles, each slab with a thin front lip, separated by a small gap; the two halves are the same colour. Behind them, a side-view landscape with a horizon near the top. The knight (about 40 pixels tall) stands upright on one tile of the LEFT grid, head overlapping the row behind; a goblin stands on one tile of the RIGHT grid in a wind-up casting pose: hunched, one hand pulled back as if about to throw, the other hand forward, a few tiny ivory square particles at the back hand, holding nothing. On the LEFT grid, three tiles are warning red with diagonal stripes and a 2-pixel red outline (the goblin's attack will land there); their red outlines are drawn ON TOP of any character standing in front of them. The player is dragging an L-shaped block: on the RIGHT grid, exactly three WHOLE floor tiles in an L shape including the goblin's tile are lit in the knight's steel blue-grey (#8FA3B8) with a solid 2-pixel outline and ONE small check mark on the goblin's tile (it will hit). No block object is drawn on the grid, and no hand or cursor is drawn. On the right side of the right grid, faint gold engraved tiles remain from earlier hits. Two small blocks lie on empty tiles of the left grid: a tiny steel L-shape and a tiny 3-tile bar, each about a third of a tile wide, hovering 2 pixels above the slab with a small dark square shadow under them. HUD light and uncluttered, drawn crisp and flat, no glow. Health bars: thin flat bars along the very top edge, left and right, with a small name and number, no portrait, no stone frame (green for the hero, ivory for the enemy, NOT red), leaving room below them for the heads of characters in the back row. Only touch buttons have a frame: small, dark semi-transparent (#1E1B24 at 85 %), thin bevel, square corners, with clear empty space between them, the screen edges and the grid: a 4-direction pad at the bottom left, a square cast button in the bottom middle, three block slots at the bottom right (the first holds a small steel L-shape, the others are empty). The grids keep a margin on both sides of the screen. Background: desaturated side-view misty forest ruins, darker than the grids. No text.
```

Biến thể, gửi sau khi ảnh trên đã ổn:
```
Same battle screen layout, but the grids are 5 by 4 tiles with a few missing tiles (dark pits), the setting is a charcoal-black citadel with orange-yellow lava ONLY in the cracks between slabs (no red), the hero is the fire mage in a dark charcoal-brown robe with amber trim and the enemy is an inferno demon. One of the blocks in the HUD slots is an "Odd Block": an irregular 6-tile shape in flat magenta (#E04CD0) with ONE outline around the whole shape and a small plus-shaped sparkle in a corner. No text.
```

Biến thể này kiểm cảnh báo của art bible: **cam của Cháy, dung nham và khối Pháp sư** có tách được bằng hình không.

---

## 6. Bảng khối

```
Pixel art asset sheet for Tessera, square 1:1, plain dark background, top-down view, crisp pixels. Glowing spell blocks made of square tiles. Shapes: single tile, 2-tile bar, 3-tile L, 2x2 square, T, S, 4-tile bar, 5-tile cross, 5-tile U. Five rows, one per material, each with its own shape mark: (1) polished steel, bevelled edges, light top-left; (2) dark charcoal with one glowing amber crack per tile; (3) small translucent jade-white ice with clipped sharp corners; (4) brown wooden frame with a jade rope across each tile; (5) pale lilac stained glass split into 2x2 by grey lead lines. Sixth row: "Odd Blocks", irregular 6-tile and 7-tile shapes in flat magenta with one outline around the whole shape and a plus-shaped sparkle. Seventh row: an enemy block (flat ivory-stone, no material), then one steel block shown shattering into square shards and one dissolving into square particles. Every block reads clearly as separate square tiles. No red. No text.
```

---

## 7. Vùng đất (mỗi vùng một tin nhắn)

Khuôn chung:
```
Pixel art environment concept for a Tessera battle arena, landscape 16:9, camera like One Step From Eden. A SIDE-VIEW backdrop of [LAND], at most 3 flat layers (sky, far land, near land), horizon at about 10 % from the top. In front, on the darker ground plane, a FLAT front-facing grid of dark stone slabs with thin front lips; the grid must stay readable. Backdrop desaturated and darker than the grid, no glowing scenery, no outlines on terrain. No characters. No red. No text.
```

| Vùng | [LAND] |
|---|---|
| Rừng Sương | overgrown stone ruins in a misty forest, roots lifting some slabs, moss between them, low mist hiding the slab bases; dominant moss grey-green (#5E6B55), no bright greens |
| Hầm Ngục | indoors, no sky: a dungeon wall with arches and pillars where the horizon would be, dark ceiling; the floor has collapsed pits and two separated sections, chains; cold blue-grey stone (#3E4450), the darkest land; torches are dull ochre shapes on the wall that do NOT glow |
| Tháp Sương | the top floor of an ice tower above a sea of clouds, slabs in a ring shape, frost thorns on some slabs; pale blue-violet far background (#8E95B8), dark slabs, no bright cyan |
| Đầm Lầy Độc | half-sunken slabs in thick poison mud, dull toxic haze, greyed purple mushrooms; greyed olive mud (#4E4C3C) |
| Sa Mạc Cát Vùi | an ancient plaza half-buried in dusty sand, wind blowing sand across some slabs, dull old turquoise inlays; dusty sand beige (#A89A80) |
| Thành Hỏa Ngục | a scorched citadel floor, charcoal black (#24201E), orange-yellow lava ONLY in the cracks between slab rows; no red anywhere |
| Không Đảo | no ground: the grid sits on floating islands of slab clusters with tapered rock undersides, joined by one-tile bridges, a few slabs cracking and falling into a sea of clouds below; grey sky blue (#8AA2B8), warm stone slabs, small far islands and faint dull yellow thunder on the horizon |
| Tâm Lưới | no horizon: a solemn stepped dais at the summit on deep indigo (#15142A), every slab engraved, a fine lattice-gold grid covering the whole background, a calm geometric heart of gold light above |

---

## 8. Kẻ Gác (boss vùng) và Người Giữ Tâm Lưới

Khuôn chung:
```
Pixel art boss concept for Tessera, square 1:1, plain dark background. [BOSS], the Warden of [LAND NAME]. Show the sprite at true size in a 48x64 frame (about 52 pixels tall, standing upright), then enlarged 6x. Above its head floats its shard of the Primal Form: a small irregular polyomino of lattice-gold square tiles. All identifying features in the upper half of the body. Also show its casting pose: standing still in a wind-up, body hunched, one hand pulled back as if about to throw, the other forward, a few tiny ivory square particles at the back hand, holding nothing, a clearly different silhouette. 1-pixel dark ink outline. No red. No text.
```

| [BOSS] | [LAND NAME] |
|---|---|
| a forest witch with a staff of twisted roots | the Misty Forest |
| a huge ogre king in rusted chains | the Dungeon |
| a lord of mist and frost, half made of ice | the Mist Tower |
| a giant toad matriarch covered in moss and mushrooms | the Poison Swamp |
| a sand sphinx with a cracked stone body | the Buried Sands |
| an inferno demon lord in charcoal armor with orange-yellow cracks (not red) | the Hellfire Citadel |
| a storm dragon coiled around floating rocks | the Sky Isles |

Trận cuối:
```
Pixel art final boss concept for Tessera, square 1:1, deep indigo background. The Heart Keeper: a serene robed guardian whose body is partly made of engraved square stone slabs and lattice-gold tiles, standing on the Lattice Heart. Calm, ancient, not evil. Show true size (about 52 pixels tall in a 48x64 frame) and enlarged 6x. No red. No text.
```

---

## 9. Bản đồ thế giới

```
Pixel art world map screen concept for Tessera, landscape 16:9. A stylized mountain at cold misty dawn with five tiers of lands and the glowing Lattice Heart at the summit; a faint gold lattice grid becomes more visible toward the top. On each tier, two lands are offered side by side as choices. Inside one highlighted land, a short path of three stages with small square pixel node icons: crossed swords, a warning triangle, a skull, a treasure chest, a campfire, a coin pouch, a crown. UI frames are square-cornered dark stone panels. No red. No text.
```

---

## 10. Ghi chú gửi lại Claude

Khi có ảnh, ghi ngắn cho mỗi ảnh:
- **Thích:** điều gì (dáng nhân vật, màu, cách khối phát sáng, cảm giác pixel).
- **Không thích:** điều gì.
- **Test bóng đen:** thu nhân vật về cao khoảng 40 px rồi tô đen. Còn nhận ra không?
- **Đọc được không:** ở màn hình trận, có thấy ngay Khối và ô đỏ trước mọi thứ khác không (test P1)?
- **Vi phạm luật** (nếu có): đỏ ngoài báo đòn, nền phát sáng, lưới nghiêng, pixel mờ.

Claude dùng các ghi chú này để làm mục 5–9 của `design/art/art-bible.md` (nhân vật, môi trường, UI, chuẩn asset, tham chiếu).
