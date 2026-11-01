# Tessera — 180 Proposed Player Skill Cards

**IMPORTANT:** This is an IDEATION POOL, not a balanced launch deck. All effects, costs, timings and rarities marked PROPOSED. No card replaces the 1–7 edge-connected Block rule. Every card must also define its delivery type, origin, travel animation, impact animation and affected cell mask (`01` §1A, 2026-11-01). The gameplay design separates Skill Card (effect) from Block Token (tile geometry); validate that proposal first.

Use `cards.json` to import into a tool. `proposed_cost` uses an invented 0–3 energy scale that must be tuned, not canon. `Neutral` means all heroes can potentially obtain the card.

## Attack / Damage — 40

| ID | Card | Affinity | Rarity / Energy | Shape | Effect (VN) / Tags |
|---|---|---|---|---|---|
| `atk_001` | First Cut | Knight | common / 1 | `any` | Gây 1 đòn vào các ô được chọn; +25% lên mục tiêu chưa bị đánh trong chuỗi hiện tại. (`slash / starter`) |
| `atk_002` | Second Cut | Knight | common / 1 | `any` | Đòn sau trúng cùng mục tiêu trong vòng 2 beat gây thêm 1 sát thương và không tự tạo echo. (`slash / combo`) |
| `atk_003` | Steel Sweep | Knight | uncommon / 2 | `bar` | Đánh vào dãy ngang đã chọn, thêm sát thương nếu bao phủ đủ 3 ô hợp lệ. (`slash / row`) |
| `atk_004` | Iron Column | Knight | uncommon / 2 | `bar` | Đóng dấu theo cột, phá một tầng Guard. (`stamp / guardbreak`) |
| `atk_005` | Cross Cleave | Knight | rare / 3 | `cross` | Đánh trên các ô dạng chữ thập, mỗi mục tiêu chịu 1 lần sát thương. (`slash / area`) |
| `atk_006` | Lancer's Step | Knight | common / 1 | `any` | Sau khi đổi vị trí một ô hợp lệ, đòn đánh kế tiếp có cộng sát thương. (`move / slash`) |
| `atk_007` | Slab Breaker | Knight | common / 1 | `any` | Đòn phá Guard gây thêm một mảnh vuông choáng ngắn trên ô mục tiêu. (`shatter / guardbreak`) |
| `atk_008` | Hammer Down | Knight | uncommon / 2 | `any` | Charge lâu hơn, gây đòn mạnh lên tối đa 4 ô hợp lệ của Block. (`heavy / stamp`) |
| `atk_009` | Armor Pierce | Knight | uncommon / 2 | `any` | Bỏ qua một phần Guard, nhưng hồi phục lâu hơn. (`pierce / slash`) |
| `atk_010` | Retaliation Stamp | Knight | rare / 3 | `any` | Nếu vừa đỡ được một đòn, dập lại hình Block đã dùng trước đó với nửa sức mạnh. (`counter / stamp`) |
| `atk_011` | Amber Flicker | Mage | common / 1 | `any` | Gây một điểm Burn trên mỗi ô đánh trúng. (`burn / attack`) |
| `atk_012` | Cinder L | Mage | common / 1 | `L3` | Đòn lửa dạng L-3; nạn nhân đang Burn chịu thêm sát thương. (`burn / burst`) |
| `atk_013` | Furnace Bar | Mage | uncommon / 2 | `bar4` | Dập 4 ô hàng thẳng, gây bonus lên ô đã bị Burn ở lượt trước. (`burn / row`) |
| `atk_014` | Coal Split | Mage | uncommon / 2 | `domino` | Dập hai ô liền kề rồi thêm một hit phụ vào ô đã đánh dấu gần đó. (`burn / chain`) |
| `atk_015` | Ash Stamp | Mage | rare / 3 | `any` | Gây sát thương nhẹ và xóa một tầng Burn để tạo hit vuông thêm trên cùng ô. (`burn / convert`) |
| `atk_016` | Thermal Fracture | Mage | common / 1 | `any` | Mục tiêu đang Freeze nhận thêm Shatter khi bị Block này đánh trúng. (`frost / shatter`) |
| `atk_017` | Heat Cycle | Mage | common / 1 | `any` | Đòn đánh ở ô lặp lại có sát thương tăng nhưng đặt thêm một nhịp hồi phục. (`burn / repeat`) |
| `atk_018` | Volcanic Ledge | Mage | uncommon / 2 | `any` | Đòn nổ vuông lan từ ô đầu đến các ô khác của cùng Block theo từng beat. (`chain / burst`) |
| `atk_019` | Flame Quilt | Mage | uncommon / 2 | `any` | Mỗi ô đang Burn liền kề một ô trúng sẽ kích hoạt thêm 1 hit nhẹ; giới hạn 2 lần. (`burn / adjacent`) |
| `atk_020` | Cinder Wake | Mage | rare / 3 | `any` | Để lại một dấu than tạm trên đúng ô vừa trúng, nổ vuông sau 1 beat và báo trước. (`burn / delayed`) |
| `atk_021` | Twin Dagger Mark | Rogue | common / 1 | `any` | Đòn đầu gây Mark và đòn thứ hai trên cùng Block tiêu thụ Mark để tăng damage. (`mark / slash`) |
| `atk_022` | Silent L | Rogue | common / 1 | `L3` | Đánh 3 ô dạng L với ít thời gian charge hơn, sát thương cơ bản thấp. (`speed / L`) |
| `atk_023` | Shadow Stitch | Rogue | uncommon / 2 | `any` | Sau khi né thành công, đòn kế gây thêm hit lên ô mục tiêu đã Mark. (`dodge / mark`) |
| `atk_024` | Rear Tile | Rogue | uncommon / 2 | `any` | Đòn đánh lên mục tiêu ở rìa grid gây bonus; không dịch chuyển vào grid địch. (`edge / slash`) |
| `atk_025` | Quick Cut | Rogue | rare / 3 | `1-2` | Charge gần như tức thời trên tối đa 2 ô, hồi chiêu dài hơn. (`speed / slash`) |
| `atk_026` | Fang Pattern | Rogue | common / 1 | `domino` | Khi hai ô chọn kề nhau đều trúng mục tiêu khác nhau, gây thêm 1 hit lên mỗi mục tiêu. (`multi / combo`) |
| `atk_027` | Sap Strike | Rogue | common / 1 | `any` | Một đòn nhẹ + Fragile ngắn trên ô mục tiêu. (`fragile / slash`) |
| `atk_028` | Echo Knife | Rogue | uncommon / 2 | `any` | Nếu ô mục tiêu đang Mark, lặp một hit 50%; hit phụ không tạo proc. (`echo / mark`) |
| `atk_029` | Trap Reversal | Rogue | uncommon / 2 | `any` | Kích nổ vuông những trap của chính mình nằm trong Block thay vì đặt trap mới. (`trap / burst`) |
| `atk_030` | Cross Ambush | Rogue | rare / 3 | `cross` | Chọn hình chữ thập, sát thương cao lên mục tiêu chưa cảnh giác, hiệu quả thấp khi lặp. (`cross / ambush`) |
| `atk_031` | Briar Bolt | Ranger | common / 1 | `any` | Trên ô chọn, gây damage và dựng dấu Root ngắn; không có đạn bay. (`root / stamp`) |
| `atk_032` | Longshot Bar | Ranger | common / 1 | `bar` | Sát thương tăng theo độ dài Block thẳng liên tục, tối đa 4 ô. (`bar / damage`) |
| `atk_033` | Crosshair Stamp | Ranger | uncommon / 2 | `any` | Đòn dấu tại ô có Mark được cộng sát thương, chỉ một check trên ô có địch. (`mark / precision`) |
| `atk_034` | Wooden Fork | Ranger | uncommon / 2 | `L3` | 3-cell T/L tạo bẫy nhỏ một beat trên ô không có địch. (`trap / area`) |
| `atk_035` | Snare Breaker | Ranger | rare / 3 | `any` | Gây thêm sát thương lên đối tượng đang Root hoặc Slow. (`root / damage`) |
| `atk_036` | Split Trigger | Ranger | common / 1 | `any` | Hai vùng tấn công khác ô sẽ tăng công nếu đều chạm các đơn vị khác nhau. (`multi / chain`) |
| `atk_037` | Rain of Squares | Ranger | common / 1 | `any` | Block dập theo thứ tự từng ô, mỗi ô có hiệu ứng vuông nhỏ, không tạo mưa mũi tên. (`sequential / stamp`) |
| `atk_038` | Lattice Lance | Ranger | uncommon / 2 | `bar4` | Dập thẳng 4 ô và làm vỡ một phần Guard, không bắn tia. (`bar / guardbreak`) |
| `atk_039` | Consecrated Stamp | Cleric | uncommon / 2 | `any` | Gây sát thương ivory nhẹ, tăng Guard cho mình nếu đánh trúng đơn vị đã Mark. (`guard / holy`) |
| `atk_040` | Judgment Cross | Cleric | rare / 3 | `cross` | Đòn chữ thập gây thêm damage trên kẻ đã gây sát thương trong beat trước. (`cross / retaliation`) |

## Block Manipulation — 35

| ID | Card | Affinity | Rarity / Energy | Shape | Effect (VN) / Tags |
|---|---|---|---|---|---|
| `block_001` | Quarter Turn | Neutral | common / 1 | `any` | Xoay một Block 90 độ ngay trước khi chọn ô; giảm một chút thời gian charge. (`rotate / utility`) |
| `block_002` | Half Turn | Neutral | uncommon / 2 | `any` | Xoay 180 độ; lần đặt kế tiếp lên đúng đường cảnh báo được cộng Guard. (`rotate / guard`) |
| `block_003` | Counter Turn | Neutral | uncommon / 2 | `any` | Đảo chiều thứ tự các ô khi một kỹ năng đánh theo chuỗi. (`rotate / sequential`) |
| `block_004` | Lattice Mirror | Neutral | rare / 3 | `any` | Cho phép phản chiếu hình Block theo trục dọc trong lần này; giữ liên thông. (`reflect / shape`) |
| `block_005` | Small Split | Neutral | common / 1 | `4+` | Tách Block 4+ thành hai mảnh liên thông, tổng số ô không đổi. (`split / shape`) |
| `block_006` | Twin Fragments | Neutral | uncommon / 2 | `3+` | Tách Block 3+ để dùng hai lần, mỗi hit giảm sức mạnh; một phần không được rỗng. (`split / echo`) |
| `block_007` | Square Weld | Neutral | uncommon / 2 | `two tokens` | Ghép 2 Token có cạnh chạm nhau; chỉ cho phép kết quả 1–7 ô liên thông. (`merge / shape`) |
| `block_008` | Extra Stud | Neutral | rare / 3 | `1-6` | Thêm 1 ô cạnh bên nếu chưa đủ 7; kỹ năng kế tốn thêm charge. (`grow / shape`) |
| `block_009` | Trim Edge | Neutral | common / 1 | `2+` | Bỏ 1 ô ở đầu mút mà vẫn giữ Block liên thông; đổi lấy giảm thời gian charge. (`shrink / speed`) |
| `block_010` | Cross Forge | Neutral | uncommon / 2 | `size5` | Biến một Block 5 ô thành chữ thập nếu có đủ 5 ô. (`reshape / cross`) |
| `block_011` | U Forge | Neutral | uncommon / 2 | `size5` | Đúc Block 5 ô thành dạng U; giảm tác dụng trên ô giữa không có thật. (`reshape / U`) |
| `block_012` | T Forge | Neutral | rare / 3 | `size4` | Đúc Block 4 ô thành dạng T, giữ nguyên material. (`reshape / T`) |
| `block_013` | S Forge | Neutral | common / 1 | `size4` | Đúc Block 4 ô thành dạng S, giữ nguyên material. (`reshape / S`) |
| `block_014` | L Forge | Neutral | uncommon / 2 | `size3-4` | Đúc Block 3 hoặc 4 ô thành L cùng size. (`reshape / L`) |
| `block_015` | Bar Forge | Neutral | uncommon / 2 | `size2-5` | Biến Block thành thanh liên tục nếu shape vừa kích thước grid. (`reshape / bar`) |
| `block_016` | Stagger Rotate | Neutral | rare / 3 | `any` | Hai lần cast liên tiếp được xoay hình trước khi dập mà không tốn chi phí quay. (`rotate / combo`) |
| `block_017` | Shape Bank | Neutral | common / 1 | `any` | Lưu một shape đã đặt để sử dụng lại một lần, không lưu mục tiêu. (`bank / shape`) |
| `block_018` | Block Reroll | Neutral | uncommon / 2 | `any` | Thay Token kế bằng shape khác cùng size từ danh mục hợp lệ. (`reroll / shape`) |
| `block_019` | Material Swap | Neutral | uncommon / 1 | `any` | Đổi diện mạo material của Token kế; không tự tạo hiệu ứng status. (`material / utility`) |
| `block_020` | Edge Snap | Neutral | rare / 3 | `any` | Tự đưa hình đặt sát biên hợp lệ gần nhất nếu vị trí mong muốn sai. (`placement / assist`) |
| `block_021` | Anchor Lock | Neutral | common / 1 | `any` | Cố định góc xoay của Token trong hai lần dập kế, nhận giảm charge. (`rotation / consistency`) |
| `block_022` | Ghost Preview | Neutral | uncommon / 1 | `any` | Hiện preview ô hợp lệ của hai góc xoay trước khi commit; không gây damage. (`preview / utility`) |
| `block_023` | Twin Offset | Neutral | uncommon / 2 | `any` | Lựa chọn dời Block đúng 1 ô trước khi dập mà không đổi hướng. (`translate / shape`) |
| `block_024` | Odd Stabilizer | Neutral | rare / 1 | `6-7` | Block 6–7 ô tốn ít charge hơn, nhưng không được split ở cast đó. (`odd / utility`) |
| `block_025` | Mosaic Stitch | Neutral | common / 1 | `two fragments` | Nếu đã lưu 2 mảnh liên thông, ráp thành shape mới tối đa 7 ô. (`merge / combo`) |
| `block_026` | Spare Corner | Neutral | uncommon / 2 | `2+` | Cho phép thay một đầu mút bằng một ô ở góc liền kề, vẫn liên thông. (`reshape / flex`) |
| `block_027` | Diagonal Echo | Neutral | uncommon / 2 | `any` | Lặp shape ở vị trí dời ngang một ô sau 1 beat; vị trí mới phải hợp lệ, hit 50%. (`echo / translate`) |
| `block_028` | Shape Exchange | Neutral | rare / 3 | `two tokens` | Đổi chỗ hai Block token trong thanh chờ, không thêm hoặc mất ô. (`economy / shape`) |
| `block_029` | Pocket Square | Neutral | common / 1 | `any` | Dự trữ một ô rời làm Token đơn cho lần sau, không ghép vào shape đang dùng. (`bank / token`) |
| `block_030` | Conserve Form | Neutral | uncommon / 2 | `5+` | Sau khi dập Block 5+ ô, xác suất giữ lại Token tăng (đề xuất 30%). (`resource / shape`) |
| `block_031` | Shape Refund | Neutral | uncommon / 2 | `any` | Nếu kỹ năng không đánh trúng mục tiêu, hoàn lại một phần năng lượng Block. (`economy / miss`) |
| `block_032` | First Tile Priority | Neutral | rare / 3 | `any` | Chọn ô bắt đầu cho kỹ năng chuỗi trong các ô Block đã chạm. (`sequence / control`) |
| `block_033` | Last Tile Focus | Neutral | common / 1 | `any` | Đòn cuối của chuỗi Block có bonus nếu kẻ địch vẫn ở ô đó. (`sequence / damage`) |
| `block_034` | Grid Fit | Neutral | uncommon / 1 | `any` | Cho phép chọn nhanh góc xoay tối ưu để tránh hố; không dịch chuyển đối tượng. (`pit / utility`) |
| `block_035` | Lattice Rewrite | Neutral | uncommon / 2 | `any` | Một lần mỗi trận đổi shape Token bất kỳ thành shape khác cùng kích cỡ. (`reshape / rare`) |

## Status / Control — 30

| ID | Card | Affinity | Rarity / Energy | Shape | Effect (VN) / Tags |
|---|---|---|---|---|---|
| `status_001` | Burn Seed | Mage | common / 1 | `any` | Dập tạo 1 Burn ở mỗi ô đánh trúng, sát thương ban đầu thấp. (`burn / status`) |
| `status_002` | Ash Debt | Mage | common / 1 | `any` | Mỗi 3 stack Burn trên kẻ địch chuyển thành thêm một hit vuông 1 lần rồi giảm 1 stack. (`burn / convert`) |
| `status_003` | Lingering Ember | Mage | uncommon / 2 | `any` | Burn kéo dài thêm 1 beat nhưng sát thương mỗi tick không tăng. (`burn / duration`) |
| `status_004` | Furnace Pressure | Mage | rare / 3 | `any` | Đòn trúng mục tiêu đã Burn thêm 1 Fragile ngắn. (`burn / fragile`) |
| `status_005` | Flare Clock | Mage | common / 1 | `any` | Sau 2 beat, các ô từng trúng Burn của cast này nhận thêm một dấu cảnh báo rồi nổ vuông. (`burn / delayed`) |
| `status_006` | Poison Seed | Rogue | common / 1 | `any` | Gây Poison 1 lên kẻ trúng, chỉ một proc cho mỗi cast. (`poison / status`) |
| `status_007` | Venom Bloom | Rogue | uncommon / 2 | `any` | Đòn trên mục tiêu đủ 3 Poison tạo thêm 1 Poison cho kẻ ở ô kề hợp lệ. (`poison / spread`) |
| `status_008` | Toxic Memory | Rogue | rare / 3 | `any` | Khi Poison tick, đánh dấu ô hiện tại làm vị trí mục tiêu ưu tiên của skill kế. (`poison / mark`) |
| `status_009` | Rotting Edge | Rogue | common / 1 | `any` | Poison giảm 1 tầng Guard trước khi tick damage, tối đa một lần mỗi beat. (`poison / guardbreak`) |
| `status_010` | Venom Harvest | Rogue | common / 1 | `any` | Hạ gục kẻ Poison hồi một ít năng lượng, giới hạn một lần mỗi trận. (`poison / economy`) |
| `status_011` | Frost Mark | Cleric | uncommon / 2 | `any` | Đặt 1 stack Slow trên ô đánh trúng bằng hiệu ứng vuông jade-white. (`frost / slow`) |
| `status_012` | Ice Chain | Cleric | rare / 3 | `any` | Nếu mục tiêu đã Slow, cast này chuyển một Slow thành Freeze ngắn. (`frost / freeze`) |
| `status_013` | Cold Shatter | Cleric | common / 1 | `any` | Gây thêm damage lên đối tượng Freeze rồi gỡ Freeze để chống khóa vô hạn. (`frost / shatter`) |
| `status_014` | Crystal Guard | Cleric | common / 1 | `any` | Khi chịu hit trong lúc đang Guard, kẻ đánh nhận Slow nhẹ, có hồi chiêu. (`frost / guard`) |
| `status_015` | Pale Stillness | Cleric | uncommon / 2 | `any` | Giảm tốc hồi chiêu của kẻ đã trúng băng trong thời gian ngắn. (`frost / debuff`) |
| `status_016` | Root Point | Ranger | rare / 3 | `any` | Đòn đánh áp Root 0.6s, nhưng không thể lặp lên cùng kẻ trong 2 beat. (`root / trap`) |
| `status_017` | Briar Lock | Ranger | common / 1 | `any` | Trap trúng kẻ Root tăng 1 sát thương và giải Root ngay sau hit. (`root / combo`) |
| `status_018` | Mud Step | Ranger | common / 1 | `any` | Các ô chọn trống thành Slow hazard trong 2 beat, không phải pit. (`slow / terrain`) |
| `status_019` | Snare Relay | Ranger | uncommon / 2 | `any` | Nếu một bẫy tự kích nổ, tạo dấu bẫy mới ở ô kề hợp lệ, giới hạn 1. (`trap / chain`) |
| `status_020` | Bark Hold | Ranger | rare / 3 | `any` | Cấp Guard nhỏ cho mình và Root lên kẻ trên ô mục tiêu nếu đánh trúng. (`root / guard`) |
| `status_021` | Mark Target | Rogue | common / 1 | `any` | Dấu Mark tồn tại 2 beat; hit đầu từ skill khác tiêu thụ để nhận bonus. (`mark / status`) |
| `status_022` | Double Mark | Rogue | common / 1 | `any` | Mark trên tối đa hai kẻ khác nhau trong cùng Block; không tăng stack trên một kẻ. (`mark / multi`) |
| `status_023` | Expose Armor | Knight | uncommon / 2 | `any` | Gây Fragile trong một beat nếu hit phá được Guard. (`fragile / guardbreak`) |
| `status_024` | Weak Spot | Rogue | rare / 3 | `any` | Nếu có Mark, đòn kế có thêm hit nhưng không dùng lại Mark để kích Echo. (`mark / combo`) |
| `status_025` | Stagger Stamp | Knight | common / 1 | `any` | Hit trên mục tiêu đang charge kéo dài charge một nhịp nếu có thể interrupt. (`interrupt / control`) |
| `status_026` | Purifying Square | Cleric | common / 1 | `any` | Xóa một stack Poison/Burn của bản thân khi đánh trúng mục tiêu. (`cleanse / heal`) |
| `status_027` | Status Recycle | Cleric | uncommon / 2 | `any` | Khi xóa debuff, nhận 1 Guard nhỏ; giới hạn 1/beat. (`cleanse / guard`) |
| `status_028` | Fragile Echo | Neutral | rare / 3 | `any` | Tấn công lên Fragile cho thêm 1 square shard hit 50%, không tự proc. (`fragile / echo`) |
| `status_029` | Burden Shift | Neutral | common / 1 | `any` | Chuyển một Slow bản thân thành Mark lên một kẻ trên ô đã chọn. (`convert / mark`) |
| `status_030` | Clean Slate | Neutral | common / 1 | `any` | Xóa 1 debuff của bản thân và 1 buff của địch trên cùng nhịp; không gây hit. (`cleanse / purge`) |

## Defense / Mobility — 25

| ID | Card | Affinity | Rarity / Energy | Shape | Effect (VN) / Tags |
|---|---|---|---|---|---|
| `def_001` | Steel Guard | Knight | common / 1 | `self` | Nhận một lượng Guard nhỏ trong 2 beat; giảm tốc chạy 0.3s. (`guard / defense`) |
| `def_002` | Shield Corner | Knight | uncommon / 2 | `self` | Nếu đứng sát góc hợp lệ, Guard tăng một chút nhưng không chặn mọi hướng. (`guard / position`) |
| `def_003` | Bastion Step | Knight | rare / 3 | `self` | Bước sang một ô an toàn trước khi Guard xuất hiện; không qua hố. (`move / guard`) |
| `def_004` | Guard Counter | Knight | common / 1 | `self` | Sau khi đỡ đúng lúc, skill tiếp theo có 1 hit vuông bonus, giới hạn một proc. (`counter / guard`) |
| `def_005` | Brace Line | Knight | uncommon / 2 | `self` | Nếu warning là thanh thẳng, nhận Guard tăng, chỉ dùng mỗi 4 beat. (`guard / row`) |
| `def_006` | Quiet Dodge | Rogue | rare / 3 | `self` | Bước nhanh một ô hợp lệ, không phải teleport, hồi chiêu ngắn. (`dodge / move`) |
| `def_007` | Afterimage Square | Rogue | common / 1 | `self` | Né đúng trước hit đặt dấu Mark ở kẻ gần nhất, không tạo clone nhân vật. (`dodge / mark`) |
| `def_008` | Side Slip | Rogue | uncommon / 2 | `self` | Chỉ dịch ngang một ô hợp lệ; cast tiếp giảm charge. (`move / speed`) |
| `def_009` | Corner Escape | Rogue | rare / 3 | `self` | Nếu đang ở rìa board, có thể chọn dịch theo trục còn lại an toàn. (`move / edge`) |
| `def_010` | Hidden Footing | Rogue | common / 1 | `self` | Trong một nhịp sau né, bẫy tự đặt không mất token. (`dodge / trap`) |
| `def_011` | Rooted Stance | Ranger | uncommon / 2 | `self` | Đổi một bước di chuyển thành Guard để chống knockback, không chặn status. (`guard / anchor`) |
| `def_012` | Forest Cover | Ranger | rare / 3 | `self` | Guard bổ sung khi đứng trên ô không có enemy warning ở cuối charge. (`guard / position`) |
| `def_013` | Bridge Sense | Ranger | common / 1 | `self` | Hiện ô sắp biến thành pit thêm 1 beat; không đổi logic map. (`pit / preview`) |
| `def_014` | Rapid Retreat | Ranger | uncommon / 2 | `self` | Lùi một ô hợp lệ sau khi đặt Block, không đi vào vùng đang warning. (`move / postcast`) |
| `def_015` | Snare Evade | Ranger | rare / 3 | `self` | Khi né thành công tạo một trap tại ô đã rời (nếu hợp lệ). (`move / trap`) |
| `def_016` | Ivory Ward | Cleric | common / 1 | `self` | Cấp Guard dựa trên số ô của Block đang dùng, tối đa 5 ô tính. (`guard / block`) |
| `def_017` | Square Sanctuary | Cleric | uncommon / 2 | `self` | Tạo một ô hỗ trợ trên phe mình giúp giảm một hit tiếp theo. (`guard / terrain`) |
| `def_018` | Healing Lattice | Cleric | rare / 3 | `self` | Hồi HP nhỏ nếu đứng trên một ô an toàn khi cast kết thúc. (`heal / position`) |
| `def_019` | Silver Exchange | Cleric | common / 1 | `self` | Đổi 1 Guard hiện có thành hồi máu tức thời, giới hạn 1/lượt charge. (`heal / guard`) |
| `def_020` | Last Shelter | Cleric | uncommon / 2 | `self` | Khi sắp về 0 HP, tự tạo một Guard bảo hiểm 1 lần mỗi trận. (`emergency / guard`) |
| `def_021` | Ice Footing | Neutral | rare / 3 | `self` | Không bị Slow từ một hazard trong 2 beat, không miễn hoàn toàn Freeze. (`resist / move`) |
| `def_022` | Stone Pivot | Neutral | common / 1 | `self` | Đổi vị trí trong một hàng hoặc cột 1 ô trước khi hiệu ứng Block kết thúc. (`move / shape`) |
| `def_023` | Emergency Tile | Neutral | uncommon / 2 | `self` | Khôi phục một ô pit đã đánh dấu từ trước thành ô tạm 2 beat; không tạo đường không hợp lệ. (`terrain / restore`) |
| `def_024` | Shatter Shield | Neutral | rare / 3 | `self` | Đỡ một hit rồi tạo tối đa 2 mảnh vuông ở ô đang đứng, không gây sát thương địch. (`guard / shatter`) |
| `def_025` | Safe Passage | Neutral | common / 1 | `self` | Sau khi né một warning, lần di chuyển kế bỏ qua một Slow hazard, không đi qua pit. (`dodge / resist`) |

## Combo / Economy — 25

| ID | Card | Affinity | Rarity / Energy | Shape | Effect (VN) / Tags |
|---|---|---|---|---|---|
| `combo_001` | First Spark | Neutral | common / 1 | `any` | Skill đầu mỗi trận được giảm 1 năng lượng nếu có ít nhất 1 token hợp lệ. (`economy / opening`) |
| `combo_002` | Second Wind | Neutral | uncommon / 2 | `any` | Sau 2 cast liên tiếp trúng, hồi 1 năng lượng, có cooldown nội bộ. (`combo / economy`) |
| `combo_003` | Three Stamp Rhythm | Neutral | uncommon / 2 | `any` | Đòn thứ ba liên tiếp thành công gây thêm một hit 50% lên ô cuối, không đẻ proc. (`combo / echo`) |
| `combo_004` | Tile Accountant | Neutral | rare / 3 | `any` | Mỗi ô riêng biệt trúng trong cast cộng 1 điểm charge, giới hạn 4. (`economy / area`) |
| `combo_005` | Empty-Slot Dividend | Neutral | common / 1 | `any` | Nếu có HUD slot Block trống, kỹ năng kế giảm thời gian charge. (`economy / slots`) |
| `combo_006` | Guard Dividend | Neutral | uncommon / 2 | `any` | Mỗi lần Guard hấp thụ hit nhận 1 năng lượng, tối đa một mỗi beat. (`guard / economy`) |
| `combo_007` | Status Bank | Neutral | uncommon / 2 | `any` | Lưu lại một stack debuff đã tiêu thụ cho skill khác, giới hạn 2. (`status / bank`) |
| `combo_008` | Chain Ledger | Neutral | rare / 3 | `any` | Mỗi chain hit trong cast tăng hit cuối 10%, cap 3 stacks. (`chain / scaling`) |
| `combo_009` | Combo Reset | Neutral | common / 1 | `any` | Chủ động xóa combo count để hồi một chút Guard, một lần mỗi 4 beat. (`combo / guard`) |
| `combo_010` | Card Sifter | Neutral | uncommon / 2 | `any` | Đổi một Skill Card chờ thành card khác cùng rarity từ deck, tốn 1 năng lượng. (`draw / economy`) |
| `combo_011` | Block Sifter | Neutral | uncommon / 2 | `any` | Đổi Block Token chờ sang token khác cùng size và shape hợp lệ. (`token / economy`) |
| `combo_012` | Pocket Cache | Neutral | rare / 3 | `any` | Giữ một token đã dùng vào bộ nhớ một lần trong encounter, không giữ toàn hand. (`bank / token`) |
| `combo_013` | Precise Timing | Neutral | common / 1 | `any` | Dập trong 0.2s trước enemy impact được bonus guard ngắn. (`timing / guard`) |
| `combo_014` | Clockwork Charge | Neutral | uncommon / 2 | `any` | Không dùng skill trong 2 beat, skill kế giảm 1 năng lượng; reset khi đánh. (`charge / economy`) |
| `combo_015` | Echo Reserve | Neutral | uncommon / 2 | `any` | Tích 2 điểm combo để cấp một lần repeat 50% không tái kích proc. (`echo / resource`) |
| `combo_016` | Skilled Rotation | Neutral | rare / 3 | `any` | Sau mỗi lần xoay đúng 90 độ thành công, cast tiếp thêm 1 Mark nhẹ. (`rotate / mark`) |
| `combo_017` | Pity Token | Neutral | common / 1 | `any` | Nếu ba token gần nhất không đặt được, lần tiếp theo bảo đảm token 1–3 ô. (`bar / accessibility`) |
| `combo_018` | Merchant's Edge | Neutral | uncommon / 0 | `meta` | Lần mua skill đầu mỗi shop giảm giá nhỏ, không thêm sức mạnh trong trận. (`shop / economy`) |
| `combo_019` | Scrap Recovery | Neutral | uncommon / 0 | `meta` | Gỡ một card yếu ngoài combat nhận coins và đổi lấy one-use token. (`shop / remove`) |
| `combo_020` | Deep Pockets | Neutral | rare / 0 | `meta` | Tăng số token lưu trữ +1 nhưng làm chậm tốc xuất hiện ban đầu. (`slots / economy`) |
| `combo_021` | Rare Momentum | Neutral | common / 1 | `any` | Khi dùng rare card, skill common kế tăng guard/tốc charge thay vì damage thô. (`rarity / combo`) |
| `combo_022` | Fragile Engine | Neutral | uncommon / 2 | `any` | Khi hạ kẻ có Fragile, nhận một token đơn 1 ô. (`fragile / resource`) |
| `combo_023` | Burn Cycle | Mage | uncommon / 2 | `any` | Burn bị tiêu thụ hồi một phần charge; không kích chuỗi vô hạn. (`burn / engine`) |
| `combo_024` | Poison Cycle | Rogue | rare / 3 | `any` | Poison kết liễu mục tiêu hồi một lượt Mark, giới hạn 1 per enemy. (`poison / engine`) |
| `combo_025` | Support Cycle | Cleric | common / 1 | `any` | Mỗi khi hồi máu thật sự, skill gây Guard kế tiếp giảm chi phí; giới hạn 1/beat. (`heal / economy`) |

## Odd / Legendary / Rule-break — 25

| ID | Card | Affinity | Rarity / Energy | Shape | Effect (VN) / Tags |
|---|---|---|---|---|---|
| `odd_001` | Odd Hexa | Neutral | rare / 3 | `size6` | Dùng một shape liên thông bất quy tắc đúng 6 ô, mỗi ô hit 1 lần rồi mất token. (`odd / 6tile`) |
| `odd_002` | Odd Hepta | Neutral | legendary / 3 | `size7` | Dùng shape bất quy tắc đúng 7 ô, tốn charge dài và giới hạn một lần encounter. (`odd / 7tile`) |
| `odd_003` | Magenta Relay | Neutral | rare / 3 | `size6-7` | Từ ô đầu của Odd, các ô kế trong shape resolve theo chuỗi 0.25s/ô. (`odd / chain`) |
| `odd_004` | Odd Mirror | Neutral | legendary / 3 | `size6-7` | Cho phép phản chiếu một shape Odd trước khi đặt; final pattern luôn preview đầy đủ. (`odd / reflect`) |
| `odd_005` | Odd Twin | Neutral | rare / 3 | `size6-7` | Tách một Odd thành hai shape liên thông cùng tổng ô, mỗi fragment cast 50%. (`odd / split`) |
| `odd_006` | Odd Anchor | Neutral | legendary / 3 | `size6-7` | Giữ lại ô trung tâm của Odd thành trap một beat sau khi stamp. (`odd / trap`) |
| `odd_007` | Odd Refund | Neutral | rare / 3 | `size6-7` | Nếu Odd không đánh trúng, lấy lại một nửa năng lượng, không phục hồi token. (`odd / economy`) |
| `odd_008` | Odd Crown | Neutral | legendary / 3 | `size6-7` | Đòn cuối của Odd được thêm Mark, không cộng thêm tile. (`odd / mark`) |
| `odd_009` | Odd Stitch | Neutral | rare / 3 | `size6-7` | Ghép một Block 4 ô với Block 2 hoặc 3 ô nếu liên thông, tối đa 7 ô. (`odd / merge`) |
| `odd_010` | Odd Chime | Neutral | legendary / 3 | `size6-7` | Một Odd vừa stamp trúng kẻ đang Root giải Root và gây hit 50%. (`odd / root`) |
| `odd_011` | Golden Afterstamp | Neutral | rare / 3 | `any` | Trong một lần cast, lặp *cùng* shape sau 1 beat ở 50% damage; không tự proc. (`legendary / echo`) |
| `odd_012` | Primal Fracture | Neutral | legendary / 3 | `any` | Bắn mảnh vuông trên các ô đã đánh trúng, mỗi ô thêm 1 hit nhỏ; không có projectile. (`legendary / shatter`) |
| `odd_013` | Lattice Bridge | Neutral | rare / 3 | `self` | Khôi phục tối đa 2 pit đã đánh dấu trên grid của mình trong 2 beat. (`legendary / terrain`) |
| `odd_014` | Form Crown | Neutral | legendary / 3 | `any` | Giảm 1 charge nếu shape >=5 ô, tăng hồi chiêu nếu <=2 ô. (`legendary / size`) |
| `odd_015` | Echo Labyrinth | Neutral | rare / 3 | `3+` | Trên target thuộc ít nhất 3 ô liên thông, lặp ô đầu và cuối ở 40%, 1 lần. (`legendary / echo`) |
| `odd_016` | Time Fold | Neutral | legendary / 3 | `any` | Đổi thứ tự resolve của hai skill kế tiếp, không hủy warning enemy. (`legendary / time`) |
| `odd_017` | Broken Symmetry | Neutral | rare / 3 | `any` | Được xoay và phản chiếu ngay trước cast, nếu chọn được shape hợp lệ. (`legendary / shape`) |
| `odd_018` | Status Loom | Neutral | legendary / 3 | `any` | Gộp một Burn và một Poison thành Fragile cộng một hit nhỏ, tiêu thụ cả hai. (`legendary / status`) |
| `odd_019` | Ivory Reversal | Neutral | rare / 3 | `any` | Khi Guard chặn hit, tạo mục tiêu phản công trên 1 ô kẻ tấn công đang đứng. (`legendary / counter`) |
| `odd_020` | Chrysalis Block | Neutral | legendary / 3 | `3-5` | Token 3–5 ô thay đổi shape cùng size sau lần đầu miss, chỉ một lần. (`legendary / reshape`) |
| `odd_021` | Royal Split | Neutral | rare / 3 | `size7` | Một token 7 ô chia thành 3 mảnh liên thông (min 1 ô), cast mỗi mảnh ở 30%. (`legendary / split`) |
| `odd_022` | Primal Memory | Neutral | legendary / 3 | `any` | Ghi nhớ một shape đã dùng; lần sau dùng lại nếu đang có token cùng size. (`legendary / bank`) |
| `odd_023` | Silent Cascade | Neutral | rare / 3 | `any` | Đòn giết một mục tiêu có Mark lặp 1 ô stamp lên kẻ tiếp theo nếu hợp lệ. (`legendary / chain`) |
| `odd_024` | Heart Temper | Neutral | legendary / 3 | `self` | Trong trận boss, lần đầu dưới 30% HP nhận một lớp Guard và giảm 1 Slow. (`legendary / survival`) |
| `odd_025` | Last Pattern | Neutral | rare / 3 | `any` | Sau 4 shape khác nhau được dùng, shape thứ năm tạo thêm 1 hit vuông 50% trên ô cuối. (`legendary / buildaround`) |

## Quality checks before using in game
- Keep each cast fully on valid enemy-grid cells; self/defense affects self-grid. Never allow placement into pits by default.
- Any delayed attack needs a tile-specific visible warning before the hit; no instant hidden damage.
- Resource/echo/status synergies require trigger cap and proc attribution to avoid infinite loops.
- For all 180 cards, Claude should create individual descriptions, VFX frames (square effects only), upgrade variants and balance tests before production.
- `shape_rule` is a type constraint, not a requirement to draw physical BLOCK objects enlarged on battlefield.
- UI may show card titles and effects; in concept art usually no text.
