# One Step From Eden (v1.6.2) — tài liệu tham chiếu thiết kế cho Ấn Kiếm

> Mục đích: đọc dữ liệu game đã phát hành (OSFE, Unity 2018.4, lưới 4×8 thời gian thực, deckbuilder roguelike kiểu MMBN) để rút ra số liệu và quy ước có thể dùng cho **Ấn Kiếm** (repo `Kaiten Duel`). Mọi mục đều tách **Quan sát** (đọc trực tiếp từ file, có đường dẫn) và **Suy luận** (kết luận của người viết, hoặc kiến thức về game chưa kiểm chứng được trong file).
>
> **Phương pháp và giới hạn.** Phiên làm việc này không có shell nên không chạy được Python; dữ liệu được trích bằng tìm kiếm regex trên XML rồi đếm tay. Các con số phân phối ở mục 2 có sai số ±2 mục. Những giá trị chỉ nằm trong mã C# (`Assembly-CSharp.dll`: `DeckCtrl.minDeckSize`, `HeroProfile.numCastSlots`, `ShopCtrl.*Cost`, tỉ lệ loại zone, công thức SpellPower) **không đọc được** và được ghi rõ là "không xác định". File `osfe_members.json` trong scratchpad không trả về kết quả nào cho các tên trường trên; file localization nhị phân (`osfe_localization.bin`) chỉ đọc được **danh sách khóa** `MechTooltips/*`, không đọc được nội dung.
>
> **Kiểm chứng 2026-10-24 (parser XML, Python):** tổng 842 mục `<Spell>`, 254 lá tag `Player`; phân phối mana 0–6 = 12/26/38/13/6/4/1 % và độ hiếm 0–4 = 22/34/22/13/9 % **khớp** với mục 2. Hai số cần đọc theo bản kiểm chứng: lá niệm tức thì (`CastDelay` = 0) là **71 %** (tài liệu ghi ≈60 %), chỉ 2 % niệm ≥ 1 s; sát thương khai báo × số phát mỗi mana, trung vị theo độ hiếm 0→4 = **60 / 50 / 40 / 32 / 38** (tài liệu ghi R3 ≈ 20; xu hướng giảm theo độ hiếm vẫn đúng, độ lớn nhỏ hơn). Bảng nhân vật và boss chưa kiểm chứng bằng parser.
>
> Nguồn OSFE: `C:\GOG Games\One Step From Eden\OSFE_Data\StreamingAssets\Data\` — `Spells.xml`, `Spells.lua`, `Effects.lua`, `Lib.lua`, `Artifacts.xml`, `Pacts.xml`, `Enemies.xml`, `Heroes.xml`, `HeroesExtra.xml`, `Zones.xml`, `ZonesStorage.xml`, `Battles.xml`.
> Nguồn Ấn Kiếm: `design/game-brief.md`, `assets/data/cards.json`, `characters.json`, `chapters.json`, `rewards.json`, `combat.json`.

---

## 1. Mô hình dữ liệu

### 1.1 Quan sát: OSFE định nghĩa nội dung thế nào

| Loại | File | Khóa | Trường stat chính | Trường hành vi |
|---|---|---|---|---|
| Spell (lá) | `Spells.xml` | `itemID` | `Mana`, `Damage`, `Shots`, `Tiles`, `CastDelay`, `CastDuration`, `Rarity` (0–4), `Tags`, `Location`, `ShotVelocity`, `ShotDuration`, `TimeBetweenShots`, `BlastDuration`, `DestroyOnHit`, `HitEnemies/HitAllies/HitSelf/HitStructures`; attr trên `<Stats>`: `cooldown`, `recoveryTime`, `animShot`, `shotSound`, `pierceDefense` | `Action` (tên hành vi Lua: `Multishot`…), danh sách `<OnCast>` / `<OnHit>` với attr `effect`-như-nội-dung, `amount`, `target`, `check`, `checkAmount`, `checkValue`, `value`, `duration`, `Pattern`, `Location` |
| Artifact | `Artifacts.xml` | `itemID` | `Rarity` (0–3), `Tags` (`Player`, `Starting`, `Negative`, `Solo`, `NoDuplicate`, `Cpu`, `Buff`, `LoopMutation`…) | một hoặc nhiều `<App trigger=… effect=… amount=… target=… check=… checkAmount=… duration=… chance=… triggerCooldown=…>` |
| Pact | `Pacts.xml` | `itemID` | `Duration` (số **trận**), `Rarity`, `Tags` (`Challenge` / `Reward` / `Hell`) | `<App …>` cùng schema với artifact |
| Enemy / Boss / Structure | `Enemies.xml` | `beingID` | `Health`, `Experience`, `Money`, `Defense`, `MovPattern`, `Movements`, `MovementDelay`, `StartDelay`, `LoopDelay`, `LerpTime`, `Stagger`, `Deathrattle`, `DeathDelay`, `Startup`, `Timeout`, `ClearDelay`, `Tags` | hành vi tấn công nằm ở spell cùng tên tag `Cpu` trong `Spells.xml` và script Lua |
| Hero | `Heroes.xml` (+ `HeroesExtra.xml` bản test) | `beingID` | `Health`, `MaxHealth`, `Money`, `MaxMana`, `BasicCooldown`, `ManaRegen`, `ShuffleTime`, `GracePeriod`, `Defense`, `LerpTime`, `Weapon`, `Deck` (lặp), `Artifacts` (lặp), `Stats startingBrands` | vũ khí là một spell tag `Weapon` |
| World / stage pool | `Zones.xml` | `world num`, `stage num` / `description` | `tags` (biome, `Pool`), `background`, `transition`; mỗi stage là danh sách `<set>` gồm 1–3 `<enemy name>` | — |
| Battle cố định | `Battles.xml` | `battle name` | `<enemy xpos ypos>` | — |

**Ví dụ spell (rút gọn, `Spells.xml` — `Frostbolt`, lá khởi đầu của Saffron):**

```xml
<Spell itemID="Frostbolt">
  <Tags>Player, Demo, Live, PvP</Tags>
  <Meta>Charge for 0.15s then fire a frostbolt</Meta>
  <Rarity>0</Rarity>  <Mana>1</Mana>  <Damage>40</Damage>  <Tiles>1</Tiles>
  <CastDelay>0.15</CastDelay>  <CastDuration>0.15</CastDuration>
  <OnHit>Frost</OnHit>
</Spell>
```

**Ví dụ artifact (`Artifacts.xml` — `Adrenaline`)** — hai App cùng trigger, điều kiện bằng biểu thức:

```xml
<App trigger="OnBattleStart" effect="Haste" check="HPUnder" checkAmount="MaxHP*0.5" duration="Infinite"/>
<App trigger="OnBattleStart" effect="SpellPowerBattle" check="HPUnder" checkAmount="MaxHP*0.5" amount="3" duration="Infinite"/>
```

**Ví dụ enemy (`Enemies.xml` — `Bomberboi` 4 bậc):** `Health 200/230/260/300`, `Defense 2/3/4/5`, `MovementDelay 0.5/0.4/0.3/0.25`, `LoopDelay 4/3.8/3.6/3.5`, `MovPattern CClockwise`.

**Ví dụ hero (`Heroes.xml` — `Saffron` Canon):** `Health 1200, MaxMana 3, ManaRegen 0.5, ShuffleTime 2.5, BasicCooldown 0.1, Defense 0, Weapon CampaignGun, Deck = Thunder, KineticWave, StepSlash, Frostbolt, Artifacts = SubTank`.

**Ví dụ world (`Zones.xml` — world 1 "Selicy", tags `Selicy, Ice, Pool`):** `stage 0` = 6 set đơn (Manticore / Lurker / Sniper / Shardshooter / Minfrost / Reaper); `stage 1` = 7 set 1–3 địch; `stage 2` = 8 set 2–3 địch; `stage 3` = set 3 địch có biến thể bậc 2 (`Lurker2`, `Reaper2`); `stage description="Miniboss"`; `stage description="Boss"`.

### 1.2 Quan sát: cái gì là dữ liệu, cái gì là mã

- **Dữ liệu (XML):** mọi stat số, độ hiếm, tag, danh sách hiệu ứng, điều kiện. `amount`/`checkAmount`/`Damage`/`Mana` nhận **biểu thức**: `Frost*80`, `MaxHP*0.5`, `ManaRegen*-0.5`, `CurrentCardtridges*10`, `ShieldPreCast*2`, `30+Flames*30`, `100+SpellPower*10`, `Money*0.5`, `MissingHP`, `1+CurrentMana`, `MaxMana`, `CurrentMana`, `OtherSlotDamage`, `ParentDamage*2.5`, `HitHP*0.33`, `BrokenTiles`.
- **Dữ liệu (Lua):** `Spells.lua`/`Effects.lua`/`Lib.lua` chứa hành vi của `Action` và các effect phức tạp (bật `Status.Frost`, `Status.Flow`, `Effect.Anchor`…).
- **Mã C#:** giới hạn bộ bài, số ô cast, giá cửa hàng, tỉ lệ zone/reward, công thức SpellPower, logic shuffle. Không đọc được trong phiên này.
- Một schema `App(trigger, effect, amount, target, check, …)` dùng chung cho **spell, artifact, pact, buff địch, pet**. `Tags` làm bộ lọc pool (`Player`, `Cpu`, `PvP`, `Expansion`, `BonusNG`, `SaffronBoss`, `NoDoublecast`, `NoShield`, `NoFlow`, `NoFlex`, `SkipTest`).

### 1.3 So với Ấn Kiếm

| | OSFE | Ấn Kiếm hiện tại |
|---|---|---|
| Lá | stat + danh sách `OnCast/OnHit` tự do | `cards.json`: `effect` enum (damage/push/burn/pin) + tham số phẳng + `upgrade` |
| Nhân vật | stat + vũ khí (một spell) + 4 lá + 1 artifact | `characters.json`: máu, hệ số bước, Tập trung, `passive{id,params}`, `signature{id,params}`, `starter_deck` |
| Địch | 1 entry/bậc, hành vi là spell `Cpu` riêng | `chapters.json`: tham số não + `traits[{id,params}]` |
| Chương | pool theo `stage num` | danh sách trận tuần tự theo tầng |
| Điều kiện/công thức | biểu thức trong attr | số cố định; logic trong lớp GDScript |

**Rút ra cho Ấn Kiếm**
1. Hợp nhất `passive`, `signature`, `traits`, và (về sau) hiệu ứng lá vào **một schema `app` chung** `{trigger, effect, amount, target, check, duration}`; OSFE nuôi 254 lá + ~155 artifact + 37 pact trên đúng một schema đó. Registry hiện tại (`PassiveRegistry`, trait) đã là bước đầu.
2. Cho phép `amount` là **biểu thức nhỏ** (`cells*6`, `max_hp*0.5`, `burn_stacks*2`) thay vì chỉ số; tránh viết lớp mới cho từng lá biến thể.
3. Tách **pool theo độ sâu** (`stage num`) khỏi **danh sách trận cố định** như `chapters.json` đang làm; pool + seed cho phép thay đổi độ khó bằng dữ liệu.
4. Thêm `tags` cho lá để lọc pool (ví dụ `boss_only`, `no_upgrade`, `pvp`) thay cho `implemented: true`.

---

## 2. Kinh tế phép và số liệu

Tập đếm: **254 spell có tag `Player`** trong `Spells.xml` (loại vũ khí tag `Weapon`, spell con `*X`, spell `Cpu`). Đếm tay, sai số ±2.

### 2.1 Quan sát: phân phối

| Mana | 0 | 1 | 2 | 3 | 4 | 5 | 6 | biến (`MaxMana`, `CurrentMana`) |
|---|---|---|---|---|---|---|---|---|
| Số lá | 30 | 67 | 96 | 32 | 16 | 9 | 2 | 2 |
| % | 12 | 26 | **38** | 13 | 6 | 4 | 1 | 1 |

Trung vị mana = **2**; 76 % lá có giá 1–2 mana; hero có 3 mana tối đa, hồi 0,5/s → một lá 2 mana ≈ 4 s hồi.

| Rarity (0–4) | 0 | 1 | 2 | 3 | 4 |
|---|---|---|---|---|---|
| Số lá | 55 | 87 | 56 | 32 | 24 |
| % | 22 | 34 | 22 | 13 | 9 |

(*Suy luận*: 0 = thường, 1 = không thường, 2 = hiếm, 3 = sử thi, 4 = huyền thoại; tên hiển thị nằm trong localization, không đọc được.)

| `CastDelay` (giây) | 0 | 0,05–0,2 | 0,3–0,6 | ≥1 |
|---|---|---|---|---|
| Ước lượng | ≈60 % | ≈30 % | ≈7 % (BowSnipe 0,45; Cryokinesis 0,55; Backstab 0,6; EarthPrayer 0,5; Meditate 0,5) | ≈3 % (BlessingOfSusano 1; Rest 1; Stasis 2; Explosion 3,3) |

`Tiles` (số ô hitbox khai báo): 1 ở đa số; 0 = hình riêng do Lua; lớn: `Hellfire 32` (toàn sân), `Bladeskrieg 16`, `Sweeper 16`, `Tundra 16`, `Cataclysm 12`, `Entangle 10`, `Prophecy 6`, `EarthenArmor 5`, `Swipe 5`, `KineticWave 4`.

`cooldown` (attr) **không dùng cho lá**: chỉ vũ khí (0,05–0,5 s; `ChronoGun 4`), `ThunderLight 1`, `TimeSlow/TimeStop 0,05`. Lá được điều tiết bằng **mana + bộ bài + shuffle**, không bằng cooldown.

`recoveryTime` (khóa người chơi sau cast) chỉ xuất hiện ở lá dash: `StepSlash 0,3`, `StepPierce 0,15`, `StepFury 0,15`, `Warpath 0,2`, `SelicyStep 0,5`.

### 2.2 Quan sát: giá so với sức mạnh (sát thương khai báo mỗi mana, lá có `Damage` số và `Mana ≥ 1`)

| Rarity | Mẫu (dmg/mana) | Trung vị ước lượng | Ghi chú |
|---|---|---|---|
| 0 | Thunder 100, Tremor 140, Ramjet 120, HiredGun 100, Revenge 100, Crossfire 75, Coldstone 67, Fracture 60, Frostbolt 40, KineticWave 20×4 đòn | **≈50–60** | đơn giản, một đòn thẳng |
| 1 | Bombard 200, Knife 100, FlintShot 100, Fadeaway 125, Breakout 120, Cataclysm 80, BombToss 75, Cryokinesis 50, StepSlash 40, Paragon 60, Entangle 20 (10 ô + Root) | **≈40** | thêm hình/điều kiện |
| 2 | Mine 125, Prophecy 120, CrossturretToss 75, BowSnipe 62, Skipper 60, Hellfire 40 (32 ô), Pyroblast 25, Glaive 10 (nảy), StormIce 5×18 đòn | **≈30** | diện rộng / trì hoãn / triệu hồi |
| 3 | Ambush 100, Vivisection 100, Ragnarok 87, Jackhammer 75, Sunder 75, Blackout 50 (mọi địch), Guillotine 20 + hành quyết < 300 HP, Trisect 16 + 33 % HP, EternityCannon 13 vô hạn đòn | **≈20** (số khai báo) | sức mạnh nằm ở điều kiện/nhân |
| 4 | LifeSword 200 (−30 maxHP), Explosion 100 (niệm 3,3 s), SumSilomini 60, HolyGround 37, Warpath 24, Monsoon 5, Sunshine 0,5, Stinger 2, Wonder/Midnight/Overload 0 | **≈25** | phá luật (cast mọi lá, hồi 99 mana) |

**Kết luận quan sát:** sát thương khai báo mỗi mana **giảm** theo độ hiếm. Độ hiếm mua *hình dạng, điều kiện, số đòn, hiệu ứng trạng thái, phá luật*, không mua số to hơn. Thang tham chiếu: hero 800–1200 HP; địch thường 150–450 HP; boss 1200–1600 HP; một lá 1 mana thường gây 40–100.

### 2.3 Quan sát: cơ chế đặc biệt (từ `Meta`, `OnCast`, khóa `MechTooltips/*`)

| Cơ chế | Cách thể hiện trong dữ liệu | Ví dụ | Ý nghĩa (quan sát + *suy luận*) |
|---|---|---|---|
| Flow | `OnCast … FlowStack`, tag `NoFlow`, tooltip `Flow`, `FlowSet`, `FlowStack`, `OnFlow`, `TriggerFlow` | `Fracture` "on Flow doublecast", `EarthPrayer` "Gain 3 Flow", `Waterfall` "shot per Flow stack", `Barrier` "20+10 Shield per Flow" | cộng dồn chồng; lá có Flow nhận thưởng khi cast lúc đang có chồng (*suy luận*: chồng tiêu khi kích) |
| Trinity | `OnCast amount="1">Trinity`, tooltip `Trinity`, `TrinityCast` | `TriShot` "If trinity is full, cast twice", `TriRag`, `Sustain`, artifact `Trinket` "+2 Trinity on battle start" | đếm 0–3; đầy → cast tiếp theo là TrinityCast (*suy luận*: đặt lại về 0) |
| Consume | `<OnCast>Consume` | `Forte` "Shield 150 but consume", `Midnight` "Cast and Consume all spells" | lá biến mất khỏi bộ **trong trận**; artifact `MeatShield`, `CardThrower`, `SecondBreakfast` thưởng khi consume |
| Anchor | `<OnCast>Anchor`, tooltip, artifact `XD40` "Jam spells no longer anchor" | hầu hết lá triệu hồi/ném và mọi `Jam` | không đi được trong lúc cast (*suy luận*) |
| Channel | `<OnCast>Channel` | `AcidRain`, `InfinityBeam` "until move", `ChargeRing` "while held" | hiệu ứng kéo dài khi giữ nút / cho đến khi di chuyển |
| Backfire | `<OnCast>Backfire`, `HitSelf` | `Hellfire`, `CarpetBomb`, `Zenith` "can hit self" | lá tự gây hại; giá rẻ hơn |
| Jam | spell `Jam`: `Mana 2`, `CastDuration 0,72`, "Triggers CastJam and consumes" | `JamShield`, `JamSlam`, `JamCannon`, `LaserSolo` "1 Jam", artifact `BlueberryJam` "Jam cost 1" | lá rác thêm vào bộ, có build thưởng Jam |
| Doublecast | tag `NoDoublecast` trên 10 lá; `Fracture` | *suy luận*: cơ chế cast hai lần từ artifact/Flow; tag chặn vòng lặp vô hạn (`Echo`, `Glaive`, `Ping`, `Stasis`) |
| Status app | `<OnHit amount="N">Poison/Frost/Fragile/Root/Slow/Link` | `Twoxin` "60 Poison, if Fragile double", `SwordLine` "3s Rooting swords" | xem mục 7 |
| Hình biến thiên | `Damage="Money*0.5"`, `"MissingHP"`, `"ShieldPreCast"` | `ShisoGun`, `StepFury`, `ShieldThrow`, `Downfall` | sát thương tham chiếu tài nguyên khác |

### 2.4 Suy luận: 15 lá nguyên mẫu đáng mượn

| # | Lá OSFE | Số liệu | Hiệu ứng của ta | Vì sao |
|---|---|---|---|---|
| 1 | `Thunder` | R0, 1 mana, 100 dmg, ô thứ 4 phía trước | damage | chuẩn "1 mana = 100": neo thang |
| 2 | `KineticWave` | R0, 2 mana, 40×4 đòn, đẩy lùi mỗi đòn | push | đẩy liên tiếp = combo với tường/ô hỏng |
| 3 | `AirSlash` | R0, 2 mana, 40, 1×3, đẩy, có thể trúng nhiều lần | push | đẩy + diện cột |
| 4 | `Pull` / `Undertow` | R1, 0 mana, 1 dmg kéo; R0 2 mana 40 kéo cả hàng | push (ngược) | hướng đẩy âm là lá mới gần như miễn phí |
| 5 | `Ember` / `PekayFire` | R1 0 mana tạo lửa ô; R0 1 mana 30 dmg để lại lửa | burn | lửa là trạng thái **ô**, không phải trạng thái địch |
| 6 | `Combust` | R1, 1 mana, 150 tại mọi ô lửa | burn | kích nổ lửa — đúng ý Thiên Hỏa của Pháp sư |
| 7 | `Rage` | R2, 2 mana, `30+Flames*30` | burn | sát thương theo số ô cháy |
| 8 | `Frostbolt` → `Cryokinesis` | 1 mana 40 + Frost; 2 mana 100 niệm 0,55 | pin | cùng họ, bậc cao đổi tốc độ lấy số |
| 9 | `Entangle` | R1, 1 mana, 20 dmg, nón 10 ô, Root | pin | diện rộng + giữ chân ngắn |
| 10 | `ClawTraps` / `SwordLine` | bẫy Root 2 ô; 0 dmg hàng kiếm Root 3 s | pin | khống chế theo vị trí, không theo mục tiêu |
| 11 | `Glassify` | R0, 1 mana, 10 dmg, Fragile | từ khóa mới | lá "đánh dấu" rẻ làm bệ cho lá nặng |
| 12 | `Guillotine` | R3, 4 mana, 80 + hành quyết < 300 HP | từ khóa mới | ngưỡng hành quyết = finisher |
| 13 | `StepSlash` | R1, 2 mana, 80, dash 3 ô + 2×3, `recoveryTime 0,3` | di chuyển | lá hợp Sát thủ/Ảnh Bộ |
| 14 | `ShieldsUp` / `Entrench` | 1 mana 40 Shield; 80 Shield + Root bản thân | phòng thủ | phòng thủ có giá là đứng yên |
| 15 | `Prophecy` / `Mine` | 2 mana, 240 vào hàng ngẫu nhiên sau thời gian dài; 250 mìn ô ngẫu nhiên | trì hoãn | đòn chậm nhưng to — hợp quy tắc "ai nhanh hơn" của ta |

**Rút ra cho Ấn Kiếm**
1. Thang hiện tại của ta là **tuyến tính theo độ hiếm** (`kiem_khi 6`, `kiem_than 8`, `tu_kiem 10` mỗi ô): đó là power creep phẳng, OSFE tránh. Giữ dmg/ô của lá thường–sử thi trong dải hẹp (6–8) và cho sử thi *điều kiện/hình* (hành quyết, kích nổ, kéo).
2. Ta không có "hiệu ứng theo ô" (Flame/mìn/bẫy); chúng chiếm ~15 % pool OSFE và sinh combo. Hỏa trận đã là "ô cháy 3 s" — khai thác tiếp: lá kích nổ (Combust), lá đếm ô cháy (Rage).
3. OSFE không dùng cooldown cho lá; ta dùng cooldown theo id + số ô tối thiểu. Giữ, nhưng coi `min_cells` là "mana" của ta và kiểm tra bảng: hiện `han_bang` (6 ô, 1,8 s ghim, cd 9) và `bang_phong` (7 ô, 1,2 s, cd 10) đảo chiều — lá hiếm hơn lại mạnh và dễ hơn.

---

## 3. Luật bộ bài và cast

### 3.1 Quan sát

| Tham số | Giá trị | Nguồn |
|---|---|---|
| `BasicCooldown` (nhịp bắn cơ bản) | 0,1 s mọi hero | `Heroes.xml` |
| Vũ khí (0 mana) | `CampaignGun` 2 dmg cd 0,05; `GunnerGun` 5 dmg cd 0,25 (−0,5 mana/phát, +1 khi trúng); `Terraform` 20 dmg 1 mana; `SelicyFrostStep` 1 mana dash, `Frost*80` dmg + 1 mana/chồng; `ShisoGun` dmg = `Money*0.5`, niệm 1 s; `CampaignReflector` Reflect 0,3 s; `ViGun` hiệu ứng theo vị trí đứng | `Spells.xml` |
| `MaxMana` | 3 (Saffron, Reva, Selicy, Hazel, Terra, Shiso, Violette), 4 (Gunner, Shopkeeper, SaffronAlt), 2 (GunnerAlt, ShisoAlt); PvP = 6 | `Heroes.xml` |
| `ManaRegen` /s | 0,5 chuẩn; Selicy 0,45; Violette 0,3; Gunner **0**; alt 0–0,15 | `Heroes.xml` |
| `ShuffleTime` | 2,5 s (Violette 2,0) | `Heroes.xml` |
| Giá của shuffle | mất **25 % Shield** (artifact `DuctTape`: "Lose 10% instead of 25%") | `Artifacts.xml` |
| Shuffle nhanh hơn | `SpeedLoader` −1 s; `FlashLoader` lần đầu tức thì; `DuelDisk` mọi lần sau tức thì nhưng thêm Jam; lá `Preload`/`Gambit` | `Artifacts.xml`, `Spells.xml` |
| `GracePeriod` | 0,03 s (0 ở bản PvP) | `Heroes.xml` |
| Bộ khởi đầu | đúng **4 lá** + 1 artifact + vũ khí | `Heroes.xml` |
| Giữ nút (hold) | `Meta`: "Hold for close range" (`SelicyStep`), "while held" (`ChargeRing`, `DiamondRing`, `EmpowerRing`, `SapphireRing`, `CollectRing`), Channel "until move" | `Spells.xml` |
| Khóa sau cast | `recoveryTime` 0,15–0,5 s chỉ ở lá dash | `Spells.xml` |
| Thời gian | status `Chrono` (`amount` 0,2 / 0,5 / 0,001 ≈ dừng), `Haste`, `Slow` | `Spells.xml`, `Effects.lua` |
| Bất tử | effect `Invincible duration=0.5` khi bị trúng; artifact `GhostCostume` 4 s đầu trận, `PocketSand` 1 s khi shuffle, `PhasePlates` 1 s khi trúng | `Spells.xml`, `Artifacts.xml` |
| Không xác định | `numCastSlots`, `minDeckSize`, `maxDeckSize`, `requeueTime`, `shuffleStaleness*`, `holdTimer`, `baseInvulLength` | chỉ trong mã |

*Suy luận (kiến thức về game, chưa kiểm chứng trong file):* có 2 ô cast (hai lá trên tay cùng lúc), bộ bài tối thiểu khoảng 4–6 lá; shuffle thủ công được.

### 3.2 Căng thẳng "ai nhanh hơn" trong OSFE

- Lá người chơi gần như **tức thời** (60 % `CastDelay` 0): căng thẳng không đến từ niệm mà từ (a) **mana** cạn, (b) **shuffle** 2,5 s trống tay, (c) đạn bay (`ShotVelocity`, `ShotDuration`) và (d) đòn địch có **cảnh báo** trên ô.
- Địch: `LoopDelay` 3–5 s cho lính, 0,45–0,8 s cho boss (mục 5); nhiều đòn địch có `CastDelay` 0,3–0,9 s và spell timer riêng (`ChargecannonTimer`, `CampfireTimer`) — cảnh báo là **thời gian giữa khai hỏa và chạm**.
- **Ngắt**: không thấy "ngắt hai chiều" kiểu ta; thay vào đó `Stagger=true/false` trên enemy, `Root`, `Chrono` và Shield là cách chặn tempo. Lá `Anchor` khiến người chơi đứng yên → bị trúng.
- *Suy luận:* OSFE thưởng cho **đọc ô cảnh báo rồi di chuyển**; ta thưởng cho **ra tay trước**. Hai triết lý khác nhau, không nên trộn nửa vời.

### 3.3 So với Ấn Kiếm

| | OSFE | Ấn Kiếm |
|---|---|---|
| Tay bài | 2 ô cast (*suy luận*), rút liên tục, shuffle 2,5 s khi hết | 4 lá rút mỗi lần Thi triển 2–4 ấn, túi xáo, menu chậm 0,2× trong 3 s |
| Điều tiết | mana 3 max, hồi 0,5/s | ấn rơi 1,8 s, túi 4, cooldown theo lá, `min_cells` |
| Thời gian niệm | 0–0,2 s đa số | 0,45 s (1 ô) → 1,2 s (4 ô) → 2,45 s (9 ô) |
| Phòng thủ | Shield, Defense, Reflect, Invincible | không (đã loại Parry/Guard) |
| Ngắt | không | phá phép hai chiều |

**Rút ra cho Ấn Kiếm**
1. Niệm của ta dài gấp 5–10 lần OSFE; đó là bản sắc, nhưng đòn ≥ 7 ô (niệm ≥ 1,95 s) gần `Stasis 2 s` — mức OSFE chỉ dành cho lá bất tử. Cân nhắc kẹp niệm tối đa ~1,6 s hoặc cho đòn lớn một lớp bảo vệ nhỏ (không bị phá trong 0,3 s cuối).
2. Shuffle của OSFE **có giá** (2,5 s + 25 % Shield). Túi xáo của ta xáo lại miễn phí → kích cỡ bộ bài ít ý nghĩa. Thêm giá nhỏ khi túi rỗng (ví dụ 1 lần rút tiếp theo trễ 1 s hoặc hiện "xáo" 0,8 s).
3. OSFE cho **bất tử 0,5 s** sau khi trúng đòn và `GracePeriod` 0,03 s. Ta nên có i-frame ngắn sau khi bị phá phép/trúng để tránh combo khóa.
4. Lá "giữ để kéo dài" (Channel) hợp với màn hình cảm ứng: giữ nút Thi triển để Hỏa trận cháy thêm, nhả để kết thúc.

---

## 4. Nhân vật

### 4.1 Quan sát: bản Canon (`Heroes.xml`, tag `Campaign, Default`)

| Hero | HP | Mana | Regen | Shuffle | Def | Vũ khí (0 mana trừ ghi chú) | Bộ 4 lá | Artifact | Brand |
|---|---|---|---|---|---|---|---|---|---|
| Saffron | 1200 | 3 | 0,5 | 2,5 | 0 | CampaignGun 2 dmg cd 0,05 | Thunder, KineticWave, StepSlash, Frostbolt | SubTank (hồi sinh 600 HP, 1 lần) | — |
| Reva | 800 | 3 | 0,5 | 2,5 | **2** | CampaignReflector (1 mana, Reflect 0,3 s) | ShieldCatch, ShieldThrow, DiagBeam, ShieldBeam | Eschaton (Shield khi đi) | Phalanx |
| Gunner | 1000 | 4 | **0** | 2,5 | 0 | GunnerGun 5 dmg, −0,5 mana/phát, +1 mana khi trúng | Innervate, BombToss, PekayFire, BlueBullets | CoverFire (+Attack khi shuffle) | — |
| Selicy | 1000 | 3 | 0,45 | 2,5 | 0 | SelicyFrostStep (1 mana, dash, `Frost*80`, +1 mana/chồng Frost) | IceNeedle, ColdMedicine, FateShield, Zenith | Bulwark (40 Shield đầu trận) | — |
| Hazel | 1000 | 3 | 0,5 | 2,5 | 0 | UpgradeWrench (buff công trình: +20 Shield, +1 SpellPower) | Minigun, SumTurretgun, ForcePushUp, ForcePushDown | HexBadge (40 Shield khi triệu hồi) | Hexawan |
| Terra | 1000 | 3 | 0,5 | 2,5 | 0 | Terraform (1 mana, 20 dmg, phá ô) | Entangle, Flurry, Excavate, PoisonTail | Moonstone (hồi mana khi có ô vỡ) | Hearth |
| Shiso | 800 | 3 | 0,5 | 2,5 | 0 | ShisoGun (dmg = `Money*0.5`, −2 tiền, +5 nếu giết, niệm 1 s); khởi đầu 80 tiền | OrbitalBeam, StepSlash, Align, ClawTraps | — | — |
| Violette | 900 | 3 | 0,3 | **2,0** | 0 | ViGun (1 mana, hiệu ứng theo hàng đứng: Trinity / Shield / bắn / mana) | Corset, IronWill, Frostbite, ManaSteal | Feather (SpellPower = Fragile/2) | — |
| Shopkeeper | 400 | 4 | 0,5 | 2,5 | 0 | ShopkeeperGun 10 dmg, dùng HP làm đạn; 400 tiền | HiredGun, BowSnipe, CounterStrike, Swipe | Beret (rơi tiền khi trúng) | — |

Bản Alt (cùng file): đổi **vũ khí + 4 lá + artifact + 1–2 stat**: `GunnerAlt` HP 400, mana 2, regen 0,1, **1 lá** (BombToss); `SaffronAlt` mana 4, def 2, ChronoGun; `SelicyAlt` regen 0,15; `HazelAlt` regen 0; `ShisoAlt` mana 2 Kunai; `VioletteAlt` mana 4. Bản PvP: mana 6, regen 0,35–0,8, HP 500–900. SpellPower mặc định không có trong XML.

### 4.2 Suy luận: bản sắc hero trong OSFE

- Bản sắc = **vũ khí 0-mana có luật riêng** (tiền, Frost, Shield, công trình, ô vỡ) + 4 lá gợi hướng + 1 artifact + chênh HP/regen/def. Không có lớp; mọi lá dùng chung pool; `Brand` (`Phalanx`, `Hexawan`, `Hearth`, `Anima`, `Slashfik`) là nhãn nghiêng pool nhẹ.
- Chênh lệch stat nhỏ (HP 800–1200, regen 0–0,5, def 0–2) nhưng **regen 0** của Gunner đổi hẳn vòng lặp (phải bắn trúng để có mana).

### 4.3 So với Ấn Kiếm

Ta: 3 nhân vật, HP 80–100, hệ số bước 0,9–1,0, Tập trung 4–5 s, nội tại + tuyệt kỹ nạp theo 18 ô, bộ 6 lá chung pool — cấu trúc đã giống OSFE ("không lớp, tuyệt kỹ khuếch đại bộ bài"). Khác: ta không có "vũ khí".

**Rút ra cho Ấn Kiếm**
1. Biến **Kiếm khí 1 ấn** (đòn tức thời không menu) thành "vũ khí" theo nhân vật: Kiếm sĩ chém thẳng, Pháp sư để lại 1 ô cháy, Sát thủ chém ngắn + hồi 1 ấn khi trúng (phản chiếu `GunnerGun` +1 mana khi trúng).
2. Mỗi nhân vật khởi đầu với **một tài nguyên lệch** như Gunner regen 0: ví dụ Sát thủ túi ấn 3 nhưng ấn rơi nhanh 1,4 s; Pháp sư túi 5 nhưng rơi 2,2 s.
3. Bản Alt của OSFE chỉ là dữ liệu (đổi 4 lá + 1 artifact + 1 stat). Ta có thể thêm "bộ khởi đầu thứ hai" cho mỗi nhân vật bằng JSON, không cần nội tại mới.

---

## 5. Địch và boss

### 5.1 Quan sát: lính (`Enemies.xml`, 4 bậc đặt tên `X`, `X2`, `X3`, `X4`)

| Địch | HP bậc 1→4 | `LoopDelay` 1→4 (s) | `MovementDelay` 1→4 | `MovPattern` | Ghi chú |
|---|---|---|---|---|---|
| Artillery | 200/230/260/300 | 4/4/4,1/4,2 | 0,5/0,3/0,2/0,2 | CClockwise | spell `Artillery` 30 dmg `Tiles 1` → bậc 2–4 50 dmg `Tiles 3/5/5` |
| Bomberboi | 200/230/260/300 | 4/3,8/3,6/3,5 | 0,5/0,4/0,3/0,25 | CClockwise | Defense 2/3/4/5; bom 100 dmg phá được |
| Breakbeamer | 200/220/240/260 | 3/3/4,5/4 | 0,2 | — | laser 70/90/110/130, phá ô, `CastDelay` 0,75–0,8 |
| Manticore | 250/350/400/400 | 3/3,2/3,5/3,5 | 0,5/0,4/0,3/0,2 | PatrolRandomEmptyVertical | |
| Shardshooter | 200/300/350/400 | 4/4,5/5/6 | 0,5/0,4/0,35/0,3 | PatrolRandomEmptyVertical | |
| Hailcaster | 220/250/280/310 | 4,5/4,5/6,5/6,5 | 0,3 | Back | |
| Sniper | 200/225/250/275 | 1,9/1,8/1,8/1,7 | 0 | PatrolRandomEmptyVerticalToPlayer → bậc 4 TeleportVerticalToPlayer | bắn nhanh, bám hàng |
| Liger | 200/220/240/260 | 2,5/2,4/2,2/2,1 | 0,24/0,22/0,2/0,18 | PatrolRandomEmpty | nhanh dần cả hai trục |
| Minfrost | 150/180/240/300 | 5/5/4,6/4,4 | 0,5 | PatrolRandomEmpty | lính yếu |
| Ghost | **15/17/19/22** | 4/3,6/3,2/3 | 0,5→0,33 | CClockwise | **Defense 150/200/250/300** — chỉ xuyên giáp mới giết |
| Reacter | 100/140/180/240 | **9999** | 0,5 | — | artifact `ReacterDrive`: dịch chuyển khi người chơi đi — địch phản ứng |
| Exploder | 100 | 20 | — | — | nổ sau ngòi dài |
| Dancer | 200–300 | **0,1** | 0,5 | — | hành động liên tục |
| Spitter | 200–320 | 9–10 | 0,4 | — | hiếm nhưng nặng |
| Chargecannon | 300 | 12 | — | — | `ChargecannonShot` 200 dmg, có thanh timer |
| Lurker | 250/320/333/333 | 5/4,8/4,7/4,5 | — | — | `LurkerOmega` 500 HP loop 1 |
| Healdon | 250–400 | 3,9–4,4 | 0,5 | — | hồi 40–60 + SpellPower cho đồng đội |
| Icefactory | 220/260/320/450 | 4/4/7/8 | — | — | Defense 1–4, sinh lính |
| Monolith* | 350–500 | 1 | — | — | miniboss cột |

Công trình/rương: `Chestcommon 120 HP / 4 tiền`, `rare 160/8`, `epic 200/15`, `legendary 240/25`, `Chestarmored 30 HP Def 95`, `Chestmobile` di chuyển, `Chestdps 350`, `Chestcursed 666`; rương có `Startup ChestTimed` + `Timeout ClearSelfDelayed` → phá trong thời hạn.

26 `MovPattern` (enum trong mã); các giá trị thấy trong XML: `PatrolRandomEmpty`, `PatrolRandomEmptyVertical`, `PatrolRandomEmptyHorizontal`, `PatrolRandomEmptyVerticalToPlayer`, `CClockwise`, `Back`, `MoveToRandom`, `PlayerHalfField`, `JumpToPlayerEndField`, `JumpRandomEndFront`, `TeleportVerticalToPlayer`, `DashRandomEmptyToPlayerRow`, rỗng (đứng yên).

### 5.2 Quan sát: boss

| Boss | HP | Def | `LoopDelay` | `MovementDelay` | Tiền |
|---|---|---|---|---|---|
| BossSaffron | 1200 | 2 | 0,6 | 0,4 | 20 |
| BossSelicy | 1400 | 2 | 0,65 | 0,3 | 20 |
| BossHazel | 1400 | 2 | 0,75 | 0,45 | 20 |
| BossReva | 1400 | 2 | 0,8 | 0,5 | 20 |
| BossShiso | 1400 | 2 | 0,7 | 0,55 | 20 |
| BossGunner | 1500 | 2 | 0,7 | 0,4 | 20 |
| BossViolette | 1500 | 2 | 0,55 | 0,35 | 20 |
| BossTerra | 1600 | 2 | 0,65 | 0,01 | 20 |
| BossTerraDark | 2000 | 4 | 0,5 | 0,4 | 20 |
| BossSerif (cuối) | 2900 | 5 | 0,45 | 0,4 | 30 |
| BossGate (cuối) | 6200 | 5 | 0,6 | 0,4 | 30 |
| BossShopkeeper | 3000 | 3 | 0,4 | 0,3 | 0 |

Boss dùng **lá của người chơi** (tag `SaffronBoss` trên `BladeRain`, `Blastcrystals`, `BowSnipe`, `Cryokinesis`, `Glitterbomb`, `Hellfire`, `KineticWave`, `MagicClaw`, `Ragnarok`, `StepSlash`, `Wildfire`, `Blink`, `Focus`) + spell riêng (`BlackoutSaffron`, `BossHealSelf`, `BossHealShot` "heals player a LOT" — *suy luận*: cơ chế tha mạng/Pacifist).

### 5.3 Quan sát: đòn địch và thang sát thương

Đòn lính 30–130 (Artillery 30→50, AvengerShot 30–60, Breakbeamer 70→130, Bomberboi 100, BombExplosion 150, ChargecannonShot 200, ChestcursedShot 100) trên hero 800–1200 HP → **một đòn ≈ 3–12 % HP**; với Defense 2 trừ phẳng không đáng kể. *Suy luận:* ngân sách của hero ≈ 15–30 đòn trúng cho cả run trước khi cần hồi.

Telegraph: `warningDuration` **không xuất hiện trong XML** (thuộc tính của `SpellObject` được đặt trong Lua/mã); cái đọc được là `CastDelay` 0,3–1,5 s của spell `Cpu` (`AvengerShot 0,3–0,4`, `Breakbeamer 0,75–0,8`, `BomberboiPush 0,9`, `CarpenterX 1,5`) và spell timer (`*Timer`) cho đòn dài. *Suy luận từ game:* ô sắp trúng sáng đỏ trong suốt `warningDuration`.

### 5.4 Quan sát: leo thang theo world và Hell

- Zones: mỗi world có `stage 0..3` + `Miniboss` + `Boss`; set ở stage cao hơn có **nhiều địch hơn (1 → 3)** và **biến thể bậc 2** (`Lurker2`, `Reaper2`) — bậc 3/4 dành cho world sau (*suy luận*: bậc = `RunCtrl.stageNum`/world index). 8 world campaign ghép đôi biome: Ice (Selicy, Violette), Fire (Saffron, Gunner), Forest (Hazel, Shiso), Ruins (Reva, Terra); world 100/101/102 là ba kết thúc (Pacifist / Normal / Genocide với 3 stage + Miniboss + Boss `Throne-corridor`).
- `Pacts.xml`: `HellPass00`–`HellPass14` (15 bậc, `Duration 9999`, một số "Automatic"); nội dung từng pass nằm trong `App` (không trích ở đây).
- `Artifacts.xml` tag `LoopMutation`/`Buff` cho địch: `SpellPowerLoopBuff`, `FrostLoopBuff`, `DefenseLoopBuff`, `HellRegen` "Regen a percentage of max health every second" — leo thang bằng **buff gắn thêm**, không chỉ nhân HP.

### 5.5 So với Ấn Kiếm

Ta: boss 80–160 HP (chương 1–2), `boss_step_cooldown_mult` 1,78 → 1,11, `boss_think_interval_sec` 0,5 → 0,25, `boss_reaction_sec` 0,6 → 0,3, `swing_speed_mult` 1,0 → 0,8, `boss_drop_interval_mult` 1,3 → 0,9, `brain_set` cautious/balanced/aggressive, trait `row_burner`, `rotten_thrower`. Một đòn 6×ô = 6–54 trên 100 HP (**6–54 % HP**).

**Rút ra cho Ấn Kiếm**
1. OSFE leo thang bằng **4 trục**: +10–20 % HP/bậc, bước nhanh hơn, **đòn rộng hơn** (`Tiles` 1 → 5), và đôi khi **nhịp chậm hơn** để bù. Ta mới có HP + nhịp não; thêm trục "trận pháp boss rộng hơn" (boss ưu tiên 3–4 ấn ở tầng sau) và trục Defense phẳng.
2. Thêm 2–3 **địch phá luật** mỗi chương theo mẫu Ghost (HP thấp, giáp cao → chỉ Đốt mới giết), Reacter (hành động khi ta bước), Exploder/Chargecannon (ngòi 12–20 s có thanh đếm) để pool lá có lý do tồn tại.
3. Tỉ lệ sát thương/HP của ta cao gấp ~5 lần OSFE. Nếu giữ máu cả run, hoặc nâng HP lên ~300 và giữ dmg, hoặc thêm Defense/Shield; nếu không, run 10 trận sẽ chết vì 3–4 đòn lệch may.
4. Boss OSFE hành động 5–8 lần nhanh hơn lính nhưng đòn nhỏ hơn — ta nên để boss thi triển nhiều đòn 1–2 ấn (tức thời) xen kẽ ít đòn lớn, thay vì cùng phân phối với người chơi.

---

## 6. Cấu trúc run và kinh tế

### 6.1 Quan sát

| Thứ | Giá trị | Nguồn |
|---|---|---|
| World | 8 world campaign (+ 3 ending, tutorial, test) | `Zones.xml` |
| Stage pool mỗi world | `stage 0,1,2,3` + `Miniboss` + `Boss`; 6–8 set/stage; set 1–3 địch | `Zones.xml` |
| Số zone mỗi world, số stage mỗi run | `World.numZones`, `World.numStages` — **không xác định** (mã) | — |
| Loại zone | enum `ZoneType`: Battle, Boss, Miniboss, Campsite, Danger, DarkShop, Distress, Shop, Treasure — tỉ lệ **không xác định** | brief/mã |
| Loại thưởng | enum `RewardType`: Loot, BossArt, BossSpell, LevelUp, Upgrade, ArtDrop, Blessing, Treasure, Unlock — tỉ lệ **không xác định** | brief/mã |
| Artifact theo nguồn | tag `Miniboss` (Bandage, LuckBox, PaperWallet, Undershirt — Rarity 1), tag `Boss` (`RemoveOne` 1 Removal, `UpgradeOne` 1 Upgrader — Rarity 2), tag `Starting` (SubTank, Eschaton, CoverFire, HexBadge, Beret, CoolShoes, FlakJacket, Fragment, Feather) | `Artifacts.xml` |
| Tiền rơi | lính 2–4, miniboss/elite 10, boss 20–30, rương 4–25; hero khởi đầu 10 (Shiso 80, Shopkeeper 400) | `Enemies.xml`, `Heroes.xml` |
| Giá cửa hàng | `ShopCtrl.baseRefillCost/removeCost/upgradeCost/rarityCostbase/rarityCostMultiplier` — **không xác định** | mã |
| Pact thử thách (16) | kéo dài 0–3 **trận**: −140 HP (`ChalDamage`), dịch chuyển khi cast, địch bắn tên lửa khi trúng, lửa ngẫu nhiên, −2 tiền khi trúng, −5 tiền khi shuffle, 5 dmg khi cast, Shield mục rữa, kiếm rơi mỗi 3 s, regen ÷2, −100 Def, −30 SpellPower, −2 MaxMana, +ShuffleTime, bắt đầu với Fragile, 1 dmg mỗi bước | `Pacts.xml` |
| Pact thưởng (6) | +25 tiền, **+150 Max HP** (≈12–19 %), +5 Luck, +1 Upgrader, +1 Removal, hồi 150 HP | `Pacts.xml` |
| Campsite | spell `CampfireHeal` "Healing mortars at player locations" + `CampfireBurn` 20 dmg self + `CampfireTimer`; các `OnHit Heal 400/400/200/200/50` trong `Spells.xml` (*suy luận*: là đạn hồi) | `Spells.xml` |
| Hồi máu khác | artifact `Medkit` 250 ngay, `HeartOfGold` 999 (−5 Def), `SubTank` hồi sinh 600, `Bandage` ngẫu nhiên; lá `Rest`, `Leech`, `Devour`, `BoosterShot 100` | `Artifacts.xml`, `Spells.xml` |
| Artifact trade-off (tag `Negative`) | `Daffodil` 2 Removal −300 HP; `Lilac` 2 Upgrader −300 HP; `Lily` +0,3 regen −300 HP; `Violet` +2 mana −300 HP; `Stimpack` +3 SpellPower −250 HP; `Thorn` +4 SpellPower mất Shield/s; `Transcendence` MaxHP = 1 | `Artifacts.xml` |
| Mở khóa | tag `Unlock` trên hero PvP; skin có `Description` "Unlocked by achieving Arch Sage/Calamity"; `RewardType.Unlock` | `Heroes.xml` |
| Hồi sinh | `SubTank` (Saffron khởi đầu) | `Artifacts.xml` |

Độ hiếm artifact (đếm tay ≈155 artifact `Player`): Rarity 3 ≈ 27 (≈17 %), còn lại chia gần đều 0/1/2.

### 6.2 So với Ấn Kiếm

Ta: 1 chương = 3 tầng × 3–4 trận + boss (≈10–12 trận, 15–25 phút); thưởng 1/3 lá (70/25/5) hoặc bỏ 1 lá hoặc bỏ qua; hồi 25 sau trận, 40 sau boss; không tiền/cửa hàng/sự kiện; `revive_tokens 0`.

**Rút ra cho Ấn Kiếm**
1. OSFE **không hồi máu tự động sau trận**; hồi đến từ nút Campsite và vật phẩm. Hồi 25/40 của ta tự động làm HP-cả-run ít kịch tính. Đổi thành: hồi 0 sau trận thường, **nút nghỉ** có mini-tương tác (bắt đạn hồi như Campfire) 1 lần/tầng.
2. Pact = thử thách **đếm bằng trận** (1–3) đổi lấy +12 % MaxHP/+1 nâng cấp/+1 bỏ lá. Đây là "sự kiện giữa trận" rẻ nhất để làm cho backlog: 6 pact đầu chỉ cần `app{trigger,effect,amount}` và `duration_matches`.
3. OSFE trao **Removal/Upgrader** như vật phẩm (từ boss, pact, artifact), không phải lựa chọn miễn phí sau mỗi trận. Ta cho "bỏ 1 lá" mỗi trận → bộ bài hội tụ quá nhanh; giới hạn 1 lần bỏ/tầng hoặc đổi thành vật phẩm.
4. Rương có **thời hạn phá** (`ChestTimed`, HP 120–240): một zone Treasure của ta = "phá bia trong 20 s với bộ bài hiện có" — kiểm tra DPS mà không cần địch.

---

## 7. Trạng thái

### 7.1 Quan sát: danh sách

Nguồn: `Status.*` trong `Effects.lua` (18 giá trị), khóa `MechTooltips/*` trong localization (45 khóa), `OnHit`/`OnCast` trong `Spells.xml`, `Meta` artifact. Enum `Status` có 24 giá trị theo brief; 6 giá trị còn lại không xác định được tên.

| Trạng thái | Đọc được | Chồng/thời lượng | Tương tác ghi trong dữ liệu |
|---|---|---|---|
| Poison | `OnHit amount="20…120">Poison`; tooltip `Poison`, `OnPoison`, `OnPoisonDmg` | **chồng số**, tự giảm theo thời gian (`Mitosis` "33 % chance not to decrease", `ResistantStrain` "never drops below 20", `Pendulum` "ticks faster") | `Detox` dmg = 2× poison rồi xóa; `Venoshock` dmg = poison; `Pandemic` lan; `Anthrax`, `SpikeProtein`, `NerveGas` (Root), `ZCell` (Fragile), `Cryophage` (Frost) |
| Frost | `OnHit amount="1|2|3">Frost`; tooltip | **chồng**; *suy luận*: tới 3 chồng nổ "Frost dmg" (`ColdPressedJuice` "after 3 stacks") | `SelicyFrostStep` `Frost*80` + 1 mana/chồng rồi xóa; `Sunder` sét vào mọi mục tiêu Frost; `Meltdown` lửa; `DoubleMint`, `IceFloe` (Flow), `SnowBoots` (Root), `FreezerBurn` (Flame), `MintTea` (mana) |
| Fragile | `OnHit amount="1|3">Fragile`; tooltip | chồng; *suy luận*: nhận 150 % sát thương (`MagnifyingGlass` "200 % instead of 150 %") | `Glassify`, `MagicClaw`, `Showdown` (mọi being), `Twoxin` ×2 poison nếu Fragile; `Entrench` không Root nếu Fragile; `Feather` SpellPower = Fragile/2; `Mirror` |
| Root | `OnHit duration="1…4">Root` | theo giây | `Entangle`, `ClawTraps`, `SwordLine 3 s`, `WeedWacker 2 s`, `MissileTow 1 s`, `Stoplight` |
| Slow / Haste | `OnHit duration="1|1,5">Slow`; `Haste duration=6` | theo giây | `ChocoMintChip`, `Pinwheel`, `RollerBlades 2 s` |
| Shield / ShieldExte / ShieldSet | `amount` 10–999 | **điểm giáp**, mất 25 % khi shuffle | `ShieldThrow` dmg = Shield; `Downfall` 2× Shield; `Northwind` xóa Shield địch; `HardenedShields` |
| Defense / DefenseBattle | ±amount, `duration` | trừ phẳng (*suy luận*) | Ghost 150–300; `Skipper` −5 Def 20 s |
| SpellPower / SpellPowerBattle | ±amount | cộng vào sát thương (công thức trong mã) | `Focus +2`, `Energizer`, `Healdon +1…10` |
| ManaRegen / MaxMana / MaxManaBattle | ±amount | | `Innervate`, `Overload 99/3 s` |
| AtkDmg | | sát thương vũ khí | `HoningSteel +2`, `Rose`, `Transmission` |
| Reflect | `duration 0,3–5,1`, `amount 1–6` | phản đạn | `CampaignReflector`, `Reflector` |
| Link | `duration 3|6|7` | chia sẻ sát thương (*suy luận*) | `SoulLink`, `Cynet`, `LinkCable` |
| Chrono | `amount 0,2|0,5|0,05|0,001`, `duration 1,7–3` | hệ số thời gian | `TimeSlow`, `TimeStop`, `ChronoSphere`, `PocketWatch`, `CassidyScarf` |
| Flow / Trinity | chồng (mục 2.3) | | |
| Invincible | `duration 0,5` | | |
| Flame (trạng thái **ô**) | `<OnHit>Flame`, tooltip | cháy khi đứng lên | `Combust`, `Rage`, `Salamander`, `BlazeOfGlory`, `Tinder`, `Anvil`, `Citrine` |
| TileCrack / TileBreak | effect | ô nứt → vỡ; đứng không được | `Excavate` (tên lửa từ ô vỡ), `FlatEarth`, `Granite`, `Wings` |
| Deplete, Execute, Frantic | chỉ có khóa tooltip | **không xác định** | `Guillotine` "Executing under 300 HP" |

### 7.2 Ánh xạ sang Ấn Kiếm và đề xuất

| Của ta | Gần nhất ở OSFE | Nhận xét |
|---|---|---|
| Ghim (địch bị ghim ăn ×1,5 từ đòn kiếm, đóng băng 0,7–1,8 s) | Root (thời gian) + **Fragile (×1,5)** | Ta đã gộp hai trạng thái OSFE tách riêng; ×1,5 trùng đúng số Fragile |
| Đốt (chồng tối đa 3, mỗi chồng +2 s +1 tick) | Flame (ô) + Poison (chồng số, tự giảm) | Đốt của ta là trạng thái **địch**; Hỏa trận là **ô** — ta đang có cả hai nhưng chưa đặt tên riêng |

Ba từ khóa tiếp theo (đề xuất, *suy luận*):
1. **Rạn** (= Fragile): chồng, mỗi chồng +25 % sát thương nhận, tối đa 2; tách khỏi Ghim để Ghim thuần là khống chế. Lá đánh dấu rẻ 2 ô, lá nặng ăn ×1,5–2.
2. **Hàn** (= Frost): chồng tới 3 rồi nổ sát thương + tự xóa; Băng phong/Băng châu cộng Hàn, Ảnh Bộ của Sát thủ kích nổ. Khác Ghim ở chỗ không khống chế, chỉ tích.
3. **Trói** (= Root 1–3 s không giảm sát thương) hoặc **Chậm** (bước ×1,5): rẻ hơn Ghim, hợp lá 2–3 ô; OSFE dùng Root trên 10+ lá rẻ.
Nếu cần thêm: **Hành quyết** (ngưỡng HP, `Guillotine < 300` ≈ 20 % boss) làm lá sử thi có điều kiện thay vì +dmg.

---

## 8. Khuyến nghị cho Ấn Kiếm

Thứ tự ưu tiên; mỗi mục kèm số OSFE làm căn cứ.

1. **Hợp nhất schema hiệu ứng** thành `app{trigger, effect, amount(expr), target, check, duration}` cho lá, nội tại, tuyệt kỹ, trait, (sau này) pact. OSFE chạy 254 lá + ~155 artifact + 37 pact + buff địch trên một schema; mọi biến thể là JSON, không phải lớp mới.
2. **Dừng tăng dmg/ô theo độ hiếm.** OSFE: dmg/mana trung vị R0 ≈ 50 → R3 ≈ 20; độ hiếm mua hình, điều kiện, phá luật. Đưa `tu_kiem`/`song_kiem` về 7–8 dmg/ô và cho điều kiện (hành quyết dưới 20 % HP, ×2 khi địch Rạn).
3. **Kẹp niệm tối đa ≈ 1,6 s** hoặc bảo vệ 0,3 s cuối cho trận pháp ≥ 7 ô. OSFE chỉ có 4 lá niệm ≥ 1 s và chúng đều là lá bất tử/đặc biệt (`Stasis 2 s`, `Explosion 3,3 s`); niệm 2,45 s ở 9 ô của ta sẽ hầu như luôn bị phá.
4. **Định lại ngân sách đòn trúng cho cả run.** OSFE: 1 đòn = 3–12 % HP, ~15–30 đòn/run; ta: 6–54 %/đòn. Mục tiêu ≈ 20 đòn/run → hoặc HP 300 với dmg hiện tại, hoặc thêm Giáp phẳng theo nhân vật (OSFE Def 0–2 trên đòn 30–130 là ~2–7 %).
5. **Bỏ hồi máu tự động 25/40, thay bằng nút nghỉ có tương tác.** OSFE không hồi sau trận; Campsite bắn đạn hồi 50–400 lên ô người chơi và có đạn cháy 20 dmg; hồi còn lại đến từ vật phẩm (`Medkit 250`, pact `HealGain 150`).
6. **Shuffle phải có giá.** OSFE: 2,5 s trống tay + mất 25 % Shield, và có 4+ artifact chỉ để giảm giá đó. Khi túi xáo của ta rỗng: khóa rút 1 s hoặc giảm nhịp ấn rơi 0,6× trong 3 s — để bộ 6 lá và bộ 12 lá chơi khác nhau.
7. **Leo thang địch bằng 4 trục**, không chỉ HP + nhịp: OSFE +10–20 % HP/bậc, `MovementDelay` 0,5 → 0,25, `Tiles` 1 → 5, Defense 2 → 5; đôi khi `LoopDelay` dài ra để bù đòn to. Thêm `boss_min_runes` (ưu tiên trận pháp lớn) và `boss_defense` vào `chapters.json`.
8. **Thêm 2–3 địch phá luật mỗi chương** theo mẫu `Ghost` (15 HP / Def 150 → chỉ Đốt hoặc xuyên giáp), `Reacter` (hành động khi ta bước), `Chargecannon` (ngòi 12 s, 200 dmg, có thanh đếm). Chúng là lý do để pool 16–20 lá có "lá dở trong trận này".
9. **Tách Ghim thành Ghim (khống chế) + Rạn (×1,5)** và thêm **Hàn** (3 chồng → nổ). OSFE dùng Fragile trên ≥ 12 lá/artifact và Frost trên ≥ 15, đều là trạng thái chồng rẻ 0–1 mana; Ghim hiện gộp cả hai làm lá ghim vừa hiếm vừa quá tốt.
10. **Pact là sự kiện đầu tiên nên làm**: 16 thử thách đếm bằng trận (1–3) × 6 phần thưởng (+150 MaxHP ≈ 12 %, +25 tiền, +1 nâng cấp, +1 bỏ lá, hồi 150, +5 may mắn). Với schema ở mục 1, một pact là 6 dòng JSON. Đồng thời chuyển "bỏ 1 lá" sau mỗi trận thành vật phẩm Removal (OSFE: từ boss/pact/artifact).

Thêm, mức thấp hơn: cho Kiếm khí 1 ấn một luật riêng theo nhân vật (vũ khí OSFE: `GunnerGun` +1 mana khi trúng, `SelicyFrostStep` nổ theo chồng); rương Treasure có thời hạn (`ChestTimed`, 120–240 HP) làm zone kiểm tra DPS; bất tử 0,5 s sau khi trúng/bị phá phép (`Invincible duration=0.5`, `GracePeriod 0,03`).

### Câu hỏi mở (cập nhật 2026-10-24 — các mục đã trả lời chuyển sang §9)

- **Đã trả lời ở §9:** số ô cast (2, hard-code), `minDeckSize`/`maxDeckSize`/`requeueTime`/`cardtridgeLimit`/`shuffleStaleness*`/`deckRegenLimit` (9.1), `holdTimer` (giữ phím di chuyển, 9.1), bất tử/`GracePeriod` (9.1), giá cửa hàng (9.2), `numZones`/`numStages`/luật loại zone/`RewardType` (9.3), SpellPower → sát thương và Defense (9.4), `warningDuration` (9.5 — **có** trong XML, đính chính), Deplete/Execute/Frantic, đủ 23 giá trị `Status`, 15 Hell Pass (9.6).
- `Status.Blessed` và `Status.Resurrect`: không có tooltip; chưa truy vết nhánh xử lý trong `Being.cs`/Lua.
- `HeroProfile` (`numCastSlots`, `baseInvulLength`, …): không có instance nào trong scene chính và bundle `prefabs`; có thể nằm trong bundle khác chưa giải nén (`achievements`, `rewired`…) nhưng vì mã không tham chiếu nên không ảnh hưởng gameplay.
- Nội dung "Automatic" của Hell Pass 01/04/06 (enemy artifact ngẫu nhiên, boss tha không hồi máu): xử lý trong mã, chưa đọc chi tiết (số artifact, pool).
- Tên hiển thị tiếng Anh của spell/artifact: `osfe_localization.bin` đọc được bằng cửa sổ regex quanh khóa (đã dùng cho `MechTooltips/*` ở §9.6); chưa trích `SpellNames/*`, `ArtNames/*` hàng loạt.

---

## 9. Hằng số lấy từ mã (bổ sung ngày 2026-10-24)

> **Phương pháp.** `Assembly-CSharp.dll` (Mono, OSFE 1.6.2) được dịch ngược toàn bộ bằng `ilspycmd 8.2.0` (chạy trên runtime .NET 6, không cài SDK) ra 291 file C#; giá trị khởi tạo trong `.ctor` được đối chiếu thêm bằng bộ giải mã IL đọc thẳng từ DLL (dump REA `osfe_members.json`). Nhiều field là `public` của `MonoBehaviour`, nên giá trị trong mã bị **giá trị serialize trong scene** đè lên: scene chính `BuildPlayer-Main` (node thứ hai của bundle `StreamingAssets/AssetBundles/main`) được giải mã bằng type tree, parser tự viết, chỉ đọc. Mỗi dòng ghi rõ nguồn: *mã* (field initializer / thân hàm), *scene* (giá trị serialize, có `pathID`), *XML/Lua* (dữ liệu), hay *suy luận*. Chỉ ĐỌC file game, không chạy game, không sửa gì trong thư mục game.
>
> **Quy ước:** `mã=X / scene=Y` nghĩa là mã khởi tạo X nhưng scene ghi đè thành Y, **giá trị hiệu lực là Y**. "Không xác định" = không tìm thấy trong mã, scene lẫn prefab.

### 9.1 Bộ bài, ô cast, giữ nút, bất tử

| Hằng số | Giá trị | Nguồn (hàm / scene) | Hệ quả cho Ấn Kiếm |
|---|---|---|---|
| Số ô cast | **2** (hard-code) | `DuelDisk.Setup`: `for (int i = 0; i < 2; i++) castSlots.Add(...)` | Xác nhận suy luận ở §3.1. Ta có 4 lá trên tay, nhiều gấp đôi; đổi lại OSFE rút liên tục. Giữ 4 nhưng cân nhắc chỉ 2 lá "sẵn sàng" còn 2 lá chờ (xem §8). |
| `HeroProfile.numCastSlots` | **không dùng** | field có khai báo, **không** được tham chiếu ở đâu trong mã; không có instance `HeroProfile` nào serialize trong scene chính lẫn bundle `prefabs` | Field chết. Không lấy làm tham chiếu. |
| `DeckCtrl.minDeckSize` | mã=4 / **scene=0** | `DeckCtrl..ctor`; scene `DeckCtrl` pathID 10003. `DeckScreen.RemoveCard` chỉ kiểm `deck.Count > minDeckSize` | OSFE **không** chặn bộ bài tối thiểu bằng kích cỡ; chặn bằng **số token bỏ lá** (mỗi shop mua được 1, khởi đầu 1 — xem 9.2). Ấn Kiếm đang cho bỏ lá miễn phí ở thưởng: nên đổi sang token. |
| `DeckCtrl.maxDeckSize` | mã=100 / **scene=255** (+ bonus artifact `StatsScreen`) | `DropZone` kiểm `childCount <= maxDeckSize` | Thực tế không giới hạn. Ta không cần trần bộ bài. |
| `DeckCtrl.cardtridgeLimit` | mã=9999 / **scene=255** | `DuelDisk.QueueCardtridge` | Không giới hạn thực tế. |
| `DeckCtrl.requeueTime` | mã=0,03 / **scene=0,015 s** | `DuelDisk.Shuffle`: `queueDuration = N × requeueTime + loadSlotDuration×2` | Thời gian "đếm lại" bộ bài khi xáo = 0,015 s/lá + 0,2 s. Với 10 lá ≈ 0,35 s. Giá rất nhỏ; giá thật của shuffle là `ShuffleTime` (2,5 s). |
| `DeckCtrl.loadSlotDuration` | 0,1 s (mã = scene) | như trên | — |
| `DeckCtrl.shuffleStalenessMultiplier` / `shuffleStalenessCap` | mã=0 / **scene=0,15 s / 3,0 s** | `DuelDisk.Shuffle`: `extra = clamp(shufflesThisBattle × 0,15, 0, 3,0 − nextShuffleTimeModifier)` | **Mỗi lần xáo trong cùng trận lâu thêm 0,15 s, tối đa +3 s.** Xáo thủ công ×0,8. Xáo lần đầu trong trận (hoặc ngoài trận) chỉ 0,1 s + đếm lại. → Công thức đầy đủ: `T = ShuffleTime × (manual ? 0,8 : 1) + modifier + extra + N×0,015 + 0,2`. Ví dụ Saffron 2,5 s, xáo lần 2, 8 lá: 2,5 + 0,15 + 0,12 + 0,2 = **2,97 s**. Đây chính là "giá tăng dần" mà §3.3 đề xuất cho túi xáo: ta có thể dùng 0,15 s/lần, trần 3 s. |
| `DeckCtrl.deckRegenLimit` | mã=4 / **scene=3** | `StatsScreen`: `manaRegen += clamp(floor(deck/5), 0, 3) × manaRegenDeckSizeBonus` (0,1; mã = scene) | **Bộ bài dày hồi mana nhanh hơn**: +0,1/s mỗi 5 lá, trần +0,3/s ở ≥15 lá (0,5 → 0,8/s, +60 %). Đây là cơ chế chống "bộ bài mỏng". Ấn Kiếm có thể cho túi dày rút ấn nhanh hơn một chút thay vì phạt. |
| `Player.holdTimer`, `holdStartDelay`, `holdInputDelay` | 0 / **0,2 s** / **0,15 s** (private, chỉ mã) | `Player.CheckHold`: giữ **phím di chuyển** → sau 0,2 s bắt đầu lặp, mỗi 0,15 s một bước (`unscaledDeltaTime`); chỉ khi bật `holdMovementEnabled` | Không liên quan giữ lá. "Giữ lá" = `FTrigger.Hold` do `CastSlot.TriggerHold` bắn mỗi frame khi đang giữ nút, không có hằng số thời gian. |
| `Player.basicCooldown` | mã=1,0 → **ghi đè bằng `Heroes.xml` BasicCooldown (0,1)** | `SpawnCtrl`: `basicCooldown = beingObj.basicCooldown`; `Player.CastWeapon` bắn khi `basicCooldownTime + weapon.cooldown < 0` | Nhịp bắn thực = `BasicCooldown + cooldown vũ khí` (CampaignGun 0,1 + 0,05 = **0,15 s/phát**; GunnerGun 0,35 s). |
| `HeroProfile.baseInvulLength` | **không dùng** | field chết; `ArtifactObject.invulLength` được cộng vào `num7` trong `StatsScreen` nhưng `num7` không được áp vào đâu | Không có i-frame "cơ bản" sau khi trúng đòn. |
| Bất tử (`invinceTime`) | chỉ từ: effect `Invincible` (XML, thường 0,5 s) qua `AddCappedInvince` (nạp tới mức, không cộng dồn); gục `DownC` 1,4 s; hồi sinh 1 s; assist boss 3,5 s; chết 1 s | `Being.Damage` bỏ qua khi `invinceTime ≥ Time.time` trừ `pierceInvince`; `Being.AddCappedInvince` | OSFE **không** cho i-frame mặc định sau khi trúng — khác đề xuất §3.3 mục 3. Nếu ta thêm i-frame sau phá phép, đó là lựa chọn riêng, không phải "theo OSFE". |
| `GracePeriod` | `Heroes.xml` 0,03 s (24 hero) / 0 (11 bản PvP) → `Being.gracePeriodDuration` | `Being.OnTriggerEnter`: một đòn (projectile) chỉ gây sát thương nếu `Time ≥ lastGracePeriod + 0,03`; lửa (`flame`) bỏ qua | Đây là **khử trùng đa-hit trong 30 ms** (nhiều hitbox chạm cùng frame), không phải i-frame. Ta có thể cần tương đương nếu đòn 9 ô có nhiều hitbox. |

### 9.2 Cửa hàng (`ShopCtrl`, scene pathID 11005)

| Hằng số | Giá trị | Nguồn | Hệ quả cho Ấn Kiếm |
|---|---|---|---|
| Làm mới hàng (`baseRefillCost`, `refillInterval`, `refillAdd`) | **30 + 10×n** Sera (n = số lần làm mới trong shop này; `refillAdd` reset ở `SetShopkeeper`); self-mode 140 | `ShopCtrl._Open`, `ClickRefillBtn` | Giá tăng tuyến tính, reset mỗi shop. |
| Bỏ lá (`removeCost`) | mã=0 / **scene=65** Sera, **tối đa 1 lần/shop** (`removePurchased`); mua = +1 token bỏ lá; khởi đầu **1 token** (`DeckScreen.startingRemovals = 1`, cả mã lẫn scene) | `ClickRemoveBtn`, `S.Awake` | Token bỏ lá là tài nguyên hiếm: ~1/world. Ấn Kiếm: thưởng "Bỏ một lá" nên hiếm tương tự (1 token/chương hoặc mua). |
| Nâng cấp (`upgradeCost`, `upgradeInterval`, `baseUpgradeCost`) | mã=0/20/0 / **scene=60 / 10 / 0**: giá = **60 + 10 × số nâng cấp đã mua trong cả run** (`currentRun.shopUpgradesPurchased`) | `ClickUpgradeBtn` | Giá nâng cấp leo thang theo run, không reset. |
| Giá món hàng (`rarityCostbase`, `rarityCostMultiplier`) | mã=0/0 / **scene=35 / 20**. Artifact = `35×2 + 20×rarity` = **70/90/110/130**; Spell = `35 + 20×rarity×0,75` = **35/50/65/80/95**; DarkShop ×2; HellPass 12 ×1,15 | `ShopCtrl.CreateShopOptions` (RoundToInt) | Spell rẻ bằng nửa artifact; bậc hiếm +15 (spell) / +20 (art). Ta có thể dùng tỉ lệ 1 : 1,43 : 1,86 : 2,29 : 2,71 theo độ hiếm nếu thêm shop. |
| Hiến máu (`donate*`) | −100 HP → +20 Sera; mỗi lần sau ×0,8 (floor): 20, 16, 12, 9, 7, 5, 4, 3, 2, 1 (min 1); reset mỗi shop; cần HP > 100 | `ClickDonateBtn` | Đổi máu lấy tiền với lợi suất giảm dần — mẫu tốt cho "trả giá bằng HP" nếu Ấn Kiếm có nút nghỉ. |

### 9.3 Cấu trúc world (`S`, `World`, `WorldBar`, `RunCtrl`, `PostCtrl`)

| Hằng số | Giá trị | Nguồn | Hệ quả cho Ấn Kiếm |
|---|---|---|---|
| `World.numZones` | **7** (= `S.zonesPerWorld`; `S.Awake` gán 7 cho mọi edition trừ Dev; scene cũng 7; QA 2, DemoLive 9); world kết thúc (`ChangeWorld`) 4 | `XMLReader.XMLtoGetWorlds`, `S.Awake`, `RunCtrl.ChangeWorld` | Mỗi world 7 zone + 1 cột chọn world kế. Ấn Kiếm chương 7–8 trận là cùng cỡ. |
| `World.numStages` | **không bao giờ được gán** (0); nhánh `num == numStages − 1` trong `XMLtoZoneData` là mã chết | `World.cs`, `XMLReader.cs:223` | Stage pool chọn thuần theo `stage num` == `CalculateStageNum()`. |
| Ánh xạ zone → stage pool | `CalculateStageNum`: zone 0 → 0; zone 1–2 → 1; zone ≥3 → 2; **kẹp ≤1 nếu `worldTierNum < 2`** (world thứ 1–2 của run); **ép 0 nếu `savedBossKills < 2`** (tổng boss đã giết trong *save*, không phải run); +1 nếu `rand(0,100) + luck > 125`; ≥1 nếu `worldTierNum > 2` | `RunCtrl.CalculateStageNum` | Pool `stage 3` chỉ đến được qua cú +1 may mắn. **Người mới (chưa giết 2 boss) luôn gặp pool stage 0** — onboarding ẩn. Ấn Kiếm có thể làm tương tự: tầng khó của chương 1 chỉ mở sau khi thắng boss lần đầu. |
| Cột và số nút | 8 cột (`GenerateWorldBar(7)` tạo `numSteps+1`): cột 0 = 1 trận; cột 1–5 = **2–3 nút** (`NextWorldRand(2,4)`; cột 1 và 4 luôn 3); cột 6 = Boss; cột 7 = chọn world kế (≤3) | `WorldBar.GenerateWorldBar` | Bản đồ nhánh 2–3, không phải đường thẳng như `chapters.json`. |
| Xác suất loại zone (`WorldBar`) | Scene: mọi `*Chance` = 0, nhưng `ResetZoneVars` gán **battle=shop=distress=100, danger=100 (200 nếu HellPass 02)**; `campsiteChance` và `randomChance` **ở 0** → nhánh "Campsite theo xác suất" và `ZoneType.Random` **không bao giờ xảy ra** (`SpawnCtrl` còn log lỗi "should never happen" cho Random). | `WorldBar.ResetZoneVars`, scene `WorldBar` pathID 10248 | — |
| Luật loại zone theo cột (cột 1,3,4,5) | Mỗi nút: `r = rand(0,100)`: r<20 → **Distress** nếu `distressChance > rand(0,100)` (sau mỗi lần −25 %); 20≤r<40 → **Danger** nếu `dangerChance > rand` (−25 %/lần); 40≤r<60 → Random (0 %, bỏ); còn lại **Battle**. Cột 3: 1 nút ngẫu nhiên → **Miniboss**. Cột 4 (3 nút, hoán vị): 1 nút **Campsite**, 1 nút Treasure-hoặc-Battle 50/50, 1 nút theo luật trên. Cột >3: nút Battle đầu tiên gặp → **Shop** (100 %, **1 shop/world**; không nếu đã giết shopkeeper hoặc chơi Shopkeeper). Cột 2: nút thứ 2 → Distress (theo chance) hoặc **Treasure**; nút khác → Battle. Hậu xử lý: cột có ≥3 Battle → 80 % nút giữa thành Danger/Distress (50/50); hai nút anh em cùng loại bị đổi; cột 1 luôn có đủ Battle/Danger/Distress. Nút tối (`SetDark`) ở cột 1 khi HP đầy và `worldTierNum > 0`. | `WorldBar.GenerateWorldBar` | Mỗi world **chắc chắn** có: 1 Shop, 1 Miniboss (cột 3), 1 Campsite (cột 4), ≥1 Treasure (cột 2 hoặc 4), Boss; Distress/Danger ~2–4 nút. Đó là "khung cố định + ngẫu nhiên trên nền" — đáng dùng cho chương Ấn Kiếm thay vì chỉ danh sách trận. |
| `ZoneType` (16 giá trị) | Battle, Boss, Miniboss, Campsite, Danger (= Battle + `SpawnHazards`), DarkShop, Distress (con tin), Random (chết), Shop, Treasure (`SpawnTreasureZone`, chest), World, Pacifist, Normal, Genocide, Idle, PvP | `ZoneType.cs`, `SpawnCtrl.SetupZone` | — |
| `RewardType` (9) và cách chọn | **Xác định theo zone, không ngẫu nhiên**: Battle/Danger/Distress → `Loot`; Boss → `BossSpell` rồi `BossArt`; Miniboss → 1 artifact từ `minibossRewards` (độ hiếm `GenerateRewardValue(5)`); `Blessing` / `ArtDrop` khi có hàng chờ; `LevelUp` theo XP; `Upgrade` khi dùng token; `Treasure` = rương; `Unlock` = menu | `PostCtrl.StartPostBattle`, `GenerateLootOptions` | Không có "tỉ lệ RewardType theo world". Ấn Kiếm: thưởng theo loại nút là đủ. |
| Độ hiếm loot (`GenerateRewardValue`) | `x = clamp(luck,0,100)/70`; trọng số R0..R4 = `67−36x, 26+9x, 7+18x, 1+5x, −1+4x`; roll đều trong `[bonus, round(Σ)]`. `luck` bắt đầu 0, **+1 mỗi zone** (`luckBonusRate = 1`, scene = mã) + focus/permanent luck. → luck 0: **67 / 26 / 7 / 1 / 0 %**; luck ≥70: **31 / 35 / 25 / 6 / 3 %** | `PostCtrl.GenerateRewardValue`, scene `PostCtrl` pathID 10134 | Độ hiếm trôi dần theo tiến độ run (≈ +1 luck/zone ⇒ R0 giảm ~0,5 điểm/zone). Mô hình "luck tích lũy" đơn giản, có thể áp vào `rewards.json`. |
| Số lựa chọn loot | `baseAmountOfLootDrops = 3` (+ artifact `lootDropsAdd`); `levelUpExtraOptions = 2`; `maxArtifactLimit = 56` | scene `PostCtrl` | 3 lựa chọn, giống Ấn Kiếm hiện tại. |
| XP lên cấp | campaign: cấp `i` cần **`i × 50` XP** (`experienceTiers[i] = i*50`; smallTiers i×10; DemoLive i×35); list `experienceTiersTest` [100,100,150,400,…] chỉ dùng ngoài campaign | `PostCtrl.Awake` | — |
| Thứ tự world | `GenerateRandomWorldList`: pool = world có tag `Pool` **trừ world trùng tag với hero** (không gặp world của chính mình), xáo bằng RNG world; thăm tuần tự | `RunCtrl.GenerateRandomWorldList` | — |

### 9.4 Công thức sát thương, mana, phòng thủ

| Hằng số / công thức | Giá trị | Nguồn | Hệ quả cho Ấn Kiếm |
|---|---|---|---|
| Sát thương một phát (`AmountType.Damage`) | `dmg = Damage(XML, biểu thức) + player.spellPower + Status.SpellPower + tempDamage + permDamage`; `player.spellPower = Hero SpellPower + Σ artifact spellPower` (`StatsScreen`). `ProjectileFactory`: cộng `spellPower` vào **mỗi projectile** có `damage > 0`, **trừ** spell tag `Weapon`/`Drone`; min 1 | `BC.GetAmount`, `ProjectileFactory.CreateProjectile`, `StatsScreen` | **SpellPower là cộng phẳng theo phát**, không phải %. Lá nhiều phát (Shots) hưởng lợi gấp bội; vũ khí 0 mana không hưởng. Ấn Kiếm đang nâng cấp theo lá (`upgrade`); nếu thêm "nội lực" chung thì nên cộng phẳng/ô để lá nhiều ô hưởng nhiều hơn. |
| `SpellObject.CombinedDamage()` | `round(damage + tempDamage + permDamage)` (không gồm SpellPower; dùng hiển thị/so sánh) | `SpellObject.cs:376` | — |
| `Player.CalculateManaCost` | `mana = GetAmount(manaType, mana)` (biểu thức XML) → `RoundToInt`; dòng `Mathf.Clamp(...)` bỏ kết quả nên **không kẹp** | `Player.cs:539` | — |
| `Being.Damage` — Defense | Nếu không `pierceDefense`: **chỉ áp lên phần vượt Shield**: nếu `amount > shield`: nếu `amount − shield > defense` → `amount −= defense (+ Status.Defense)`, nhưng không thấp hơn `shield + 1`; ngược lại `amount = shield + clamp(amount − shield − defense, 1, amount)`. Nếu `amount ≤ shield`: Defense không áp (trừ cờ `shieldDefense`). **Tối thiểu 1 sát thương** luôn lọt. | `Being.cs:1239` | Defense **phẳng, trừ sau Shield, min 1**. Ấn Kiếm đã loại Guard; nếu quay lại, dùng phẳng + min 1 (rõ ràng, không % mập mờ). |
| Fragile | sát thương ×**1,5** (`fragileMultiplierBase` scene = mã 1,5), floor, **trừ 1 stack mỗi hit**, không áp cho spell `Drone`/lửa | `Being.HitAmount`, `BC` scene pathID 10973 | — |
| Shield rụng khi xáo | mã static `shieldDecay = 0,25` nhưng **scene `BC.shieldDecayBase = 0,4`** và `BC.Awake`/`ResetRun` gán `shieldDecay = shieldDecayBase` → **hiệu lực 40 %**; DuctTape `ShieldDecayChange −0,15` → 25 %. Tooltip in `BC.shieldDecay` động (sẽ hiện 40 %); chuỗi `Meta` "Lose 10% instead of 25%" của DuctTape là **text cũ**. | `BC.cs:152, 331, 1441`; `DuelDisk.cs:564`; `Effects.lua ShieldDecayChange` | *Suy luận:* số 25 % ở §3.1 lấy từ text XML, runtime là 40 %. Giá shuffle của OSFE nặng hơn ta tưởng. |
| Hằng số trạng thái (`BC` static) | `hasteAmount 0,05`, `slowAmount 0,2`, `frostDmg 150` (nổ ở 3 stack, xuyên Defense+Shield), `frostLength 99999`, `flameDmg 10 × flameTicks 14`, mỗi `0,4 s`, `poisonDuration 4 s` | `BC.cs:126–152` | Burn của ta (Đốt) có thể lấy mẫu Flame: 14 tick × 0,4 s = 5,6 s. |
| Angel mode | giảm sát thương nhận theo `angelModeCurrentDamageReduction` (tùy chọn trợ năng), bỏ qua nếu `pierceInvince` | `Player.Damage` | — |

### 9.5 Cảnh báo (`warningDuration`) và bất tử

| Hằng số | Giá trị | Nguồn | Hệ quả cho Ấn Kiếm |
|---|---|---|---|
| `SpellObject.warningDuration` mặc định | **0** (không khởi tạo trong `.ctor`; `TryParse` thất bại → 0) — không có "mặc định 0,6 s" nào ở lớp đang dùng | `SpellObject.cs:52, 702–706` | — |
| **Đính chính §3.1/§Câu hỏi mở:** `<WarningDuration>` **có** trong `Spells.xml` | 278 spell có thẻ. Spell `Cpu` (520): 213 có thẻ, **120 > 0, trung vị 0,6 s**, phổ biến 0,4 / 0,5 / 0,6 / 1,0 (19/15/18/19), min 0,1, max 3,4. Spell `Player` (254): 12 > 0 (lá triệu hồi), trung vị 1,0. | `Spells.xml` (parser XML) | Cảnh báo ô của địch chủ yếu **0,4–1,0 s**, khớp với §3.2. Mốc thiết kế cho Ấn Kiếm nếu thêm "ô cảnh báo": 0,5–0,6 s. |
| Ghi đè trong mã | `BossSaffron` 0,4 s (0,55 s theo bậc); `BossShiso` = `baseDelay`; `TerraDiamond` 0,8 s; lớp cũ `Spell.warningLength = 0,6` (kiếm Irelia/Violette 0,34–0,5 s, trừ 0,01–0,025 s × bậc) | `BossSaffron.cs:91`, `BossShopkeeperDemo.cs:412`, `Spell.cs:31`, `Irelia*.cs` | Boss rút cảnh báo theo bậc (−10–25 ms/bậc). |
| Cách dùng | Lua: `CreateWarning(spell, tile, spell.warningDuration [+ shotDelay])` (`Spells.lua` 5 chỗ), triệu hồi (`Effects.lua:592`) | Lua | — |
| `Spell.StartCast` | stub cũ, chỉ log "Legacy CAST"; thực thi ở `SpellObject.StartCast` | `Spell.cs:55` | — |
| `Invincible` | effect XML → Lua `AddCappedInvince(duration)`: nạp tới `duration`, không cộng dồn | `Effects.lua:274`, `Being.cs:1402` | i-frame theo lá (0,5 s điển hình) là **cộng có trần**, tránh lạm dụng xếp chồng. |

### 9.6 Ý nghĩa Deplete / Execute / Frantic, enum `Status`, 15 Hell Pass

| Khái niệm | Ý nghĩa | Nguồn |
|---|---|---|
| `Deplete` | Artifact/pact **dùng một lần**: `Deplete()` đặt `depleted = true`, xám thẻ; `Being.TriggerArtifacts` bỏ qua artifact/pact đã deplete. Tooltip: "Can only be used once". Dùng ở 2 artifact và HellPass 05. | `ArtifactObject.cs:60`, `PactObject.cs:25`, `Being.cs:1866`, `MechTooltips/Deplete` |
| `Execute` | **Trigger "đòn kết liễu"**: khi một being chết, spell cuối cùng trúng nó (`lastSpellHit`) nhận `Trigger(FTrigger.Execute)` nếu người cast còn sống; khi **người chơi gục**, spell địch gây gục cũng nhận Execute. Thẻ `<Execute>` trong XML = hiệu ứng khi kết liễu (Money, Mana, HealBattle, DoubleCast, PowerUpPerm). Tooltip: "If the spell kills an enemy". | `Being.cs:1502`, `Player.cs:739`, `MechTooltips/Execute` |
| `Frantic` | Không phải trạng thái; là **nhãn glow** (`FTrigger.Frantic`) cho hiệu ứng có `check="Fragile"`: hiệu ứng chỉ kích hoạt khi **chính người cast đang có Fragile**. Tooltip: "If you have a Fragile status". | `CastSlot.cs:140–154`, `ItemObject.cs:152`, `MechTooltips/Frantic` |
| `FTrigger` đáng chú ý | `Flow`, `Execute`, `Frantic`, `Hold` (giữ nút cast), `TrinityCast`, `TouchTile`, `OnManaBelow`/`OnHPBelow`, `WhileShieldBelow` (có `triggerCooldown`) | `FTrigger.cs` |
| Enum `Status` (23) | 0 Normal, 1 AtkDmg, 2 Defense, 3 Flow, 4 Fragile, 5 Frost, 6 Haste, 7 Link, 8 ManaRegen, 9 MaxMana, 10 Poison, 11 Regen, 12 Reflect, 13 Root, 14 Shield, 15 ShieldExte, 16 Slow, 17 SpellPower, 18 Stun, 19 Trinity, 20 Blessed, 21 Resurrect, 22 Chrono. Bổ sung ngoài §7: **Link** "Target takes dmg when anything else takes dmg"; **ShieldExte** = Shield + collider rộng (30×50) "Blocks N incoming dmg with a wide shield"; **Trinity** chồng tối đa 3 (lá `TrinityCast`); **AtkDmg** = stat `player.atkDmg`; **Blessed**, **Resurrect**: không có tooltip, chưa truy vết. | `Status.cs`, `Being.cs:585–640`, `MechTooltips/*` |

**15 Hell Pass (`Pacts.xml`, tag `Hell`, `Duration 9999`; "Automatic" = xử lý trong mã):**

| # | Mô tả (XML) | Cơ chế (XML `App` / mã) |
|---|---|---|
| 00 | Normal game mode | — |
| 01 | Enemies start with random artifacts | mã (`Automatic`) |
| 02 | More obstacles and hazards | `WorldBar.ResetZoneVars`: `dangerChance = 200` |
| 03 | Lower defense, no aim marker | `Defense −5` + mã |
| 04 | Spared bosses no longer heal | mã |
| 05 | Max HP is reduced | `MaxHPSet = MaxHP×0,75` + `Deplete` |
| 06 | Enemies start with 2 random artifacts | mã |
| 07 | Luck starts at 20 | `Luck 20` |
| 08 | Enemies regenerate health | `AddDefaultEnemyArt HellRegen` |
| 09 | Bosses start at a higher level | `BaseBossTier 1` |
| 10 | Shield decay + 20% | `ShieldDecayChange +0,2` (→ 60 %) |
| 11 | Hostages are evil | `EvilHostages` |
| 12 | Shops cost more | `ShopCtrl`: giá ×1,15 |
| 13 | All bosses start at max level | `BaseBossTier 3` |
| 14 | Start with 1 max hp | `MaxHPSet 1` |

*Suy luận cho Ấn Kiếm:* Hell Pass là **danh sách modifier xếp bậc, mỗi bậc một dòng dữ liệu** (phần lớn chỉ là một `App`), rất rẻ để làm; ta có thể thêm 5–8 "Ấn Phong" tương tự sau khi có 3 chương.

### 9.7 Tóm tắt khác biệt mã ↔ dữ liệu đã phát hiện

- Giá trị scene **đè** giá trị mã ở 10 field (`minDeckSize`, `maxDeckSize`, `requeueTime`, `cardtridgeLimit`, `shuffleStaleness*`, `deckRegenLimit`, `removeCost`, `upgradeCost`, `upgradeInterval`, `rarityCost*`, `shieldDecayBase`). Đọc mã thuần sẽ sai; cần scene.
- Text XML cũ: DuctTape nói 25 % nhưng runtime 40 %.
- Field chết: `HeroProfile.numCastSlots`, `HeroProfile.baseInvulLength`, `World.numStages`, `ArtifactObject.invulLength` (cộng nhưng không áp), `WorldBar.campsiteChance/randomChance` (0), `ShopCtrl.baseUpgradeCost` (0, không dùng).
