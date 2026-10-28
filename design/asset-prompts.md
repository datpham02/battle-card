# Prompt tạo ảnh demo cho Tessera (dùng với ChatGPT)

> **Mục đích:** tạo ảnh **để hình dung** thế giới, nhân vật, khối và màn hình trận, rồi chỉnh lại trước khi làm asset thật. Đây không phải asset dùng trong game.
> **Nguồn:** `design/world-context.md` (thế giới), `design/glossary.md` (tên gọi), `design/game-mechanics.md` (cơ chế).
> Prompt viết bằng **tiếng Anh**, vì công cụ tạo ảnh hiểu tiếng Anh tốt nhất. Phần hướng dẫn viết tiếng Việt.

---

## Cách dùng với ChatGPT

1. **Mở một cuộc trò chuyện mới**, chỉ dùng cho việc tạo ảnh Tessera. ChatGPT giữ phong cách tốt hơn khi mọi ảnh nằm chung một cuộc trò chuyện.
2. **Dán tin nhắn "Bối cảnh"** (mục 1) làm tin nhắn đầu tiên. Đừng yêu cầu ảnh ngay, chỉ để nó đọc.
3. **Thử phong cách:** gửi lần lượt 3 prompt ở mục 2. Chọn phong cách ưng nhất.
4. **Khóa phong cách:** gửi câu sau, kèm ảnh bạn chọn (tải lên lại nếu cần):
   > *Use exactly this art style, palette and level of detail for every image from now on in this chat.*
5. **Gửi từng prompt ở mục 3–8.** Mỗi tin nhắn một prompt, mỗi lần một ảnh.
6. **Muốn sửa thì nói cụ thể**, ví dụ: *"Same image, but make the knight's armor darker and the blocks bigger."* Đừng viết lại cả prompt.
7. Lưu ảnh ưng ý lại, kèm vài dòng ghi chú thích hay không thích điểm nào. Gửi cho Claude để đưa vào `/art-bible`.

**Lưu ý:**
- ChatGPT hay **tự chèn chữ** vào ảnh. Mọi prompt dưới đây đã có câu "no text". Nếu ảnh vẫn có chữ, nhắc lại: *"Remove all text and letters."*
- Ảnh màn hình trận (mục 5) là **quan trọng nhất**: nó cho thấy nhân vật đứng trong một ô có còn đọc được không.
- Tỉ lệ ảnh:
  - **16:9 (ngang):** màn hình, vùng đất, ảnh chủ đề.
  - **1:1 (vuông):** nhân vật, boss, bảng khối.

  Ghi tỉ lệ ở cuối prompt, ví dụ *"Landscape 16:9."*

---

## 1. Tin nhắn "Bối cảnh" (dán đầu tiên)

```
I am designing a 2D mobile game called "Tessera". Please read this context; I will then ask you for concept images one at a time. Do not generate an image for this message.

WORLD: Tessera was an ordinary Western high-fantasy world until "the Cataclysm": the Primal Form that shaped every land shattered at the summit of a great mountain, a place now called the Lattice Heart. A grid of square tiles spread across the whole world from there. Since then, ALL power — magic, swordplay, any fighting technique — only works when it is channeled through BLOCKS: glowing shapes made of square tiles joined edge to edge (like tetromino and pentomino pieces, 1 to 7 tiles). Everyone, heroes and monsters alike, picks up blocks that fall on their side of the grid, rotates them and stamps them onto the enemy's half to strike.

LANDS: every land lies on its own ancient grid of square stone tiles laid over its old terrain. Each land is guarded by a Warden who holds a shard of the Primal Form. Heroes climb the mountain through five lands to the Lattice Heart at the summit, choosing to spare or slay each Warden.

TONE: Western fantasy (NOT Asian wuxia or xianxia), quiet and slightly melancholic, very readable shapes, clear silhouettes.

GAME VIEW: landscape mobile screen. Battles happen on two small square grids facing each other: the hero's grid on the left, the monster's grid on the right. A character stands inside ONE tile (about 55 pixels tall on screen at the smallest, up to about 90 pixels on small arenas), so characters must read clearly at small size.

ALWAYS: no text, no letters, no numbers, no logos, no watermark in any image.
```

---

## 2. Thử 3 phong cách (cùng một cảnh)

Gửi lần lượt từng prompt, rồi so sánh 3 ảnh.

**2A. Vẽ tay 2D, hơi chibi (gợi ý mặc định)**
```
Style test A. A knight in steel armor stands on a square stone tile grid in an overgrown forest ruin, holding a glowing L-shaped block made of 4 square steel tiles in front of him. Across from him, on a second grid, a goblin shaman. Style: 2D hand-painted mobile game art, slightly chibi proportions (about 3 heads tall), bold readable silhouettes, soft painterly shading, clean outlines, warm but muted palette. No text. Landscape 16:9.
```

**2B. Pixel art**
```
Style test B. The same scene: a knight on a square stone tile grid in an overgrown forest ruin holding a glowing L-shaped block of 4 steel tiles, facing a goblin shaman on a second grid. Style: high-detail pixel art, crisp pixels, limited palette, 2D mobile game sprites. No text. Landscape 16:9.
```

**2C. Tranh tô bán tả thực**
```
Style test C. The same scene: a knight on a square stone tile grid in an overgrown forest ruin holding a glowing L-shaped block of 4 steel tiles, facing a goblin shaman on a second grid. Style: painterly semi-realistic 2D fantasy illustration, moody lighting, textured brushwork, dark-fairytale tone. No text. Landscape 16:9.
```

Chọn xong thì làm bước 4 ở phần "Cách dùng" để khóa phong cách.

---

## 3. Ảnh chủ đề thế giới

```
Key art of Tessera: a huge mountain rising through clouds. Its slopes are split into terraced lands, from bottom to top: a misty forest, a dark dungeon, an ice tower, a poison swamp, a sand-buried ancient plaza, a lava citadel, floating sky islands. Everything is overlaid with a faint glowing grid of square tiles that gets brighter near the summit. At the summit, the Lattice Heart: a calm, bright geometric heart of light made of square tiles. A small hero climbs a path, glowing square-tile blocks floating around them. No text. Landscape 16:9.
```

---

## 4. Năm nhân vật (mỗi nhân vật một tin nhắn)

Khuôn chung. Thay hai chỗ trong ngoặc vuông bằng dòng trong bảng bên dưới:
```
Character sheet for Tessera: [CHARACTER]. Show a full-body front three-quarter view, a small idle pose, and a casting pose where a glowing block made of [BLOCK MATERIAL] square tiles hovers in front of them. Plain light background. The character must stay recognizable as a tiny sprite about 55 to 90 pixels tall. No text. Square 1:1.
```

| Nhân vật | [CHARACTER] | [BLOCK MATERIAL] |
|---|---|---|
| Kiếm sĩ | a sturdy knight in steel plate armor with a large greatsword, steel blue and white colors, steady stance | polished steel |
| Pháp sư | a frail fire mage in crimson and orange robes with a spellbook or a staff, thin build | cracked glowing ember |
| Sát thủ | a quick rogue with twin daggers in black and dark violet leather, hood up | small sharp translucent ice |
| Thợ săn | a ranger in moss green and brown leather with a crossbow and trap hooks | wooden frames bound with rope |
| Giáo sĩ | a calm cleric in white and silver vestments with a holy emblem on the chest | glowing stained glass |

Sau khi có đủ 5 nhân vật:
```
Put all five Tessera heroes side by side in one lineup at the same scale, each holding their own block material. No text. Landscape 16:9.
```

---

## 5. Màn hình trận đấu (quan trọng nhất)

```
Mobile game battle screen mockup for Tessera, landscape 16:9. Two square stone grids side by side facing each other, each 3 by 3 tiles, separated by a thin vertical line. The knight stands on one tile of the LEFT grid; a goblin shaman stands on one tile of the RIGHT grid. A glowing L-shaped steel block (4 tiles) is being stamped onto the right grid, with a green outline around the tile where the goblin stands (it will hit). On the left grid, three tiles glow red as a warning where the goblin's attack will land. Two small blocks lie on empty tiles of the left grid, waiting to be picked up. HUD: a health bar at the top left and top right, a 4-direction pad at the bottom left, three block slots at the bottom right (one holds a small block), a round skill button in the middle bottom. Background: overgrown stone ruins in a misty forest, kept soft so the grids stand out. No text. Landscape 16:9.
```

Biến thể, gửi sau khi ảnh trên đã ổn:
```
Same battle screen, but the grids are bigger (5 by 4 tiles) with a few missing tiles, the setting is a lava citadel with glowing lava veins between the tiles, the hero is the fire mage and the enemy is an inferno demon. One of the blocks in the slots is an "Odd Block": an irregular 6-tile shape with a shimmering violet-magenta outline, different from all the normal blocks. No text. Landscape 16:9.
```

---

## 6. Bảng khối

```
Game asset sheet for Tessera: glowing spell blocks made of square tiles, top-down view on a plain dark background. Show these shapes: single tile, 2-tile bar, 3-tile L, 2x2 square, T, S, 4-tile bar, 5-tile cross, 5-tile U. Five rows, one per material: polished steel, cracked ember, sharp ice, wood-and-rope frame, stained glass. A sixth row of "Odd Blocks": irregular 6-tile and 7-tile shapes with an unstable shimmering violet-magenta outline, clearly different from the rows above. Every block must read clearly as separate square tiles. No text. Square 1:1.
```

---

## 7. Vùng đất (mỗi vùng một tin nhắn)

Khuôn chung:
```
Environment concept for a Tessera battle arena: [LAND]. Slight top-down angle, with a clear grid of square stone tiles laid over the terrain where the battle happens; the grid must stay readable. No characters. No text. Landscape 16:9.
```

| Vùng | [LAND] |
|---|---|
| Rừng Sương | overgrown stone ruins in a misty forest, tree roots lifting some tiles, moss between them; moss green, mist grey, wood brown |
| Hầm Ngục | a damp dungeon floor of stone tiles with collapsed pits and two separated sections, chains and torchlight; grey stone, orange torchlight |
| Tháp Sương | the top floor of an ice tower above a sea of clouds, tiles made of ice slabs in a ring shape, frost thorns on some tiles; white, pale blue, cold violet |
| Đầm Lầy Độc | half-sunken stone tiles in black poison mud, toxic fog, glowing mushrooms; poison green, mud brown, violet spores |
| Sa Mạc Cát Vùi | an ancient plaza half-buried in sand, wind blowing sand across some tiles; sand gold, sun orange, old turquoise |
| Thành Hỏa Ngục | a scorched citadel floor with glowing lava veins running between rows of tiles; charcoal black, lava red, ember orange |
| Không Đảo | floating stone islands made of clusters of tiles joined by fragile one-tile bridges, a few tiles cracking and falling into the sky; sky blue, cloud white, thunder yellow |
| Tâm Lưới | a sacred stepped dais at the mountain summit, every tile an engraved stone slab, a calm geometric heart of light hovering above; solemn, bright, clean |

---

## 8. Kẻ Gác (boss vùng) và Người Giữ Tâm Lưới

Khuôn chung:
```
Boss concept for Tessera: [BOSS], the Warden of [LAND NAME]. They hold a glowing shard of the broken Primal Form: an irregular piece made of square tiles. Full body, imposing but still readable as a small sprite. Plain background. No text. Square 1:1.
```

| [BOSS] | [LAND NAME] |
|---|---|
| a forest witch with a staff of twisted roots | the Misty Forest |
| a huge ogre king in rusted chains | the Dungeon |
| a lord of mist and frost, half made of ice | the Mist Tower |
| a giant toad matriarch covered in moss and mushrooms | the Poison Swamp |
| a sand sphinx with a cracked stone body | the Buried Sands |
| an inferno demon lord with lava veins in his armor | the Hellfire Citadel |
| a storm dragon coiled around floating rocks | the Sky Isles |

Trận cuối:
```
Final boss concept for Tessera: the Heart Keeper, a serene robed guardian whose body is partly made of glowing square stone tiles, standing on the Lattice Heart at the summit. Calm, ancient, not evil. Plain background. No text. Square 1:1.
```

---

## 9. Bản đồ thế giới

```
World map screen concept for Tessera, portrait 9:16. A stylized mountain with five tiers of lands and the glowing Lattice Heart at the summit. On each tier, two lands are offered side by side as choices. Inside one highlighted land, a short path of three stages with small node icons: crossed swords, a warning triangle, a skull, a treasure chest, a campfire, a coin pouch, a crown. Clean, readable, painted map style. No text.
```

---

## 10. Ghi chú gửi lại Claude

Khi có ảnh, ghi ngắn cho mỗi ảnh:
- **Thích:** điều gì (ví dụ màu, dáng nhân vật, cách khối phát sáng).
- **Không thích:** điều gì.
- **Đọc được không:** ở ảnh màn hình trận, nhân vật trong ô có nhận ra không.

Claude sẽ dùng các ghi chú này để chốt phong cách, bảng màu và chuẩn asset trong `/art-bible`.
