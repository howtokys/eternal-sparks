# Feature Shop Changelog

## Timeline Summary (Nov 23, 2026 to Current Working Tree)

| Toronto date | Milestone |
| --- | --- |
| Nov 23, 04:21 | `72462d6` added physical shops, data-driven buffs and room-clear rewards, a First Room start, run checkpoints, Game Over, HUD updates, fullscreen sync, and the initial regression suite. It also imported the dungeon art and retired the fixed-boost picker assets. |
| Current working tree | Split coin and pact traders into separate rooms with shared infrastructure. Added fallback stock, organized and replaced icons, animated the shop torches, removed redundant asset packs, and matched Pause and both buff pickers to the gold UI atlas. These changes are visible in the diff against `72462d6` and are still uncommitted. |

## Repository History Through the Shop Baseline (Sep 16–Nov 9, 2026)

These changes landed on `main` before `feature/shop` branched. The ranges end at the revisions where each set of systems was in place.

| Date | Git milestones | What the shop branch inherited |
| --- | --- | --- |
| Sep 16–25 | `d8b6810` → `57cb85b`, including project setup in `4ef2b52` | Godot project skeleton, World and player scenes, guns and bullets, damage numbers, and the first enemy and damage components. |
| Sep 28–Oct 13 | Menu integration `0dc7817` (PR #49), enemy integration `25ff88b` (PR #50), health system `f5eaa87` (PR #27) | Main Menu, Pause, Continue and basic save handling, screen and audio controls, keyboard navigation, boar detection and contact damage, obstacle collisions, and the health/shield/mana HUD foundation. |
| Oct 25–29 | `ecf878e` and `6d95bc2` through `2e29330` (PR #69) | `BuffData` and `BuffManager`, fixed starting boosts, active buff HUD, and updated pause UI and sounds. These are the systems the shop branch later extended with random rolls, caps, and pacts. |
| Oct 30–31 | `6e80656` through `4fae337` (PR #70) | First Room tilemap, destructible crates, debris, item data, pickups, and randomized health and mana potion loot. |
| Oct 31–Nov 3 | Weapon merges `aefce52`, `b949382`, `282e500` (PRs #74, #75, #77), and dungeon merge `4040549` (PR #79) | Data-driven melee and ranged weapons, melee timing, weapon switching, chest loot and pickup interactions, new weapon art and fire modes, spike and poison traps, fireblast crates, and status effects. |
| Nov 9 | Coin implementation `ce3695e`, merged at `e1ed14b` (PR #80) | Coin scenes and resources, money tracking, enemy and crate drops, and dungeon fixes. `e1ed14b` is the baseline for the Nov 23 feature commit. |


### Files changed in merge `e1ed14b` (Nov 9, PR #80)

Compared with the first parent, `4040549` on `main`, the merge added 14 files, modified 15, and renamed 10. Its tree matches the second parent, `ce3695e` on the Dungeon branch.

| Change | Exact paths | Effect at the merge |
| --- | --- | --- |
| Added | `coin.tscn`, `scripts/coin.gd`, `scripts/coin.gd.uid`, `bronze_coin.tres`, `silver_coin.tres`, `gold_coin.tres` | Added animated magnetic pickups worth 1, 3, and 5 coins. |
| Added | `sprites/Bronze Coin.png`, `sprites/Bronze Coin.png.import`, `sprites/Silver Coin.png`, `sprites/Silver Coin.png.import`, `sprites/Gold coin.png`, `sprites/Gold coin.png.import`, `sprites/mana particle.png`, `sprites/mana particle.png.import` | Added coin textures and Godot import metadata. The mana particle texture was imported without a gameplay reference in this revision. |
| Modified | `scripts/GlobalData.gd`, `scripts/enemy.gd`, `scripts/crate.gd` | Added the money counter and randomized coin counts and denominations. Enemy deaths requested a guaranteed drop and crate destruction a 3% drop. Crates also began rolling eligible loot by item weight. |
| Modified | `Crate_loot/health_potion_large.tres`, `Crate_loot/health_potion_normal.tres`, `Crate_loot/mana_potion_large.tres`, `Crate_loot/mana_potion_normal.tres`, `scripts/player.gd` | Set the four potion drop weights, adjusted the health and normal mana restore values, and raised the player’s default max mana from 50 to 200. |
| Modified | `scenes/First_Room.tscn` | Updated the tile layout and regrouped crates, enemies, spike traps, and a fireblast crate under the floor. Removed the room’s placed poison crates. |
| Modified | `scenes/explosion.tscn`, `scenes/fireblast_crate.tscn`, `scenes/gas_cloud.tscn`, `scenes/status_effect_component.tscn`, `Status/fire_effect.tres`, `Status/poison_effect.tres` | Updated references to the relocated scripts. The explosion animation also changed from 20 to 15 FPS. |
| Renamed | `StatusEffect.gd` → `scripts/StatusEffect.gd`, `StatusEffect.gd.uid` → `scripts/StatusEffect.gd.uid` | Moved the status-effect resource script and kept its UID. |
| Renamed | `explosion.gd` → `scripts/explosion.gd`, `explosion.gd.uid` → `scripts/explosion.gd.uid` | Moved the explosion script and kept its UID. |
| Renamed | `fireblast_crate.gd` → `scripts/fireblast_crate.gd`, `fireblast_crate.gd.uid` → `scripts/fireblast_crate.gd.uid` | Moved the fireblast crate script and kept its UID. |
| Renamed | `gas_cloud.gd` → `scripts/gas_cloud.gd`, `gas_cloud.gd.uid` → `scripts/gas_cloud.gd.uid` | Moved the gas cloud script and kept its UID. |
| Renamed | `status_effect_component.gd` → `scripts/status_effect_component.gd`, `status_effect_component.gd.uid` → `scripts/status_effect_component.gd.uid` | Moved the status-effect component and kept its UID. |

## File-by-File Changes

Paths are project-relative. Numbered art packs and Godot sidecars are grouped by directory.

| Subsystem | Added, modified, renamed, or deleted | Previous behavior → updated behavior |
| --- | --- | --- |
| Shop rooms and routes | **Added** `scenes/shop_room.tscn`, `shop_room_base.tscn`, `mysterious_shop_room.tscn`, `dungeon_trader.tscn`, `shop_door.tscn`, `scripts/shop_door.gd`, `mysterious_trader.gd`. **Modified** `scenes/First_Room.tscn`, `World.tscn`, `scripts/main_menu.gd`. | World-only entry → First Room starts the run, with shops linked through authored doors and return markers. The rooms share camera, exit, and decor. The Mysterious Trader gets a separate room, animated sprite, and reactive stock. |
| Shop transactions | **Added** `scenes/shop_pedestal.tscn`, `shop_menu.tscn`, `scripts/shop_pedestal.gd`, `shop_item_data.gd`, `shop_menu.gd`, and `scripts/Shop/*.tres`. **Modified** `scripts/player.gd`, `pickup.gd`, `coin.gd`, `enemy.gd`, `Chest_loot/weapon_railgun.tres`. | Coin collection → reusable physical offers with validation, equip/swap/drop, confirmation for pacts, and persistent sold markers. Coin and death events are guarded against duplicates. The old Railgun loot reference now resolves to Laser Gun. The tabbed shop remains a test fixture. |
| Buffs, combat and HUD | **Added** seven standard and three pact definitions under `scripts/Buffs/`, compatibility pact resources, and `buff_impact.gd` / `shockwave_pulse.tres`. **Modified** `buff_manager.gd`, `scripts/gun.gd`, `bullet.gd`, `crate.gd`, `health_component.gd`, `hurt_box.gd`, `hud.gd`, `scenes/bullet.tscn`, `HUD.tscn`. | Fixed boosts → capped random rolls, weapon and damage hooks, crate loot modifiers, and a signal-driven HUD for vitals, coins, weapon slots, and buff levels. Ten Raven icons now live under `sprites/buffs/standard/` and `special/`. |
| Run persistence | **Modified** `scripts/GlobalData.gd` and `player.gd`. **Added** `scenes/game_over.tscn` and `game_over.gd`. | Basic save position → validated checkpoints with economy, loadout, buff levels, sacrifices, room routes, outcomes, and timers. Death closes the run and removes the checkpoint. |
| Pause, Buff Selection and Settings | **Modified** `scenes/Pause_scene.tscn`, `BuffSelection.tscn`, `buff_choice_card.tscn` (added in the feature commit), `buff_selection.gd`, `Main-Menu.tscn`, `scripts/pause_scene.gd`, `settings_menu.gd`, `project.godot`. **Added** `fonts/minecraftia_ui.tres`, `sprites/ui/ui_big_pieces.png`, `sprites/ui/frames/gold_panel.tres` and `pause_buttons.png`. | Flat or legacy art → shared gold 9-slice frames with distinct card states and stable sizing. Decorative controls ignore the mouse, the first card gets focus, and Escape stays with the picker. Settings now uses native window IDs, waits for acknowledgment, and keeps the dropdown caption synchronized. |
| Animated torches and assets | **Added** `scenes/torch.tscn`, `scripts/torch.gd`, and trader/effect source art. **Renamed** `sprites/DungeonTilesetII/` → `sprites/dungeon_tileset/`. **Moved** the fire sheet to `sprites/effects/fire/`, HUD art to `sprites/hud/icons/`, the vitals frame to `sprites/ui/frames/`, menu icons to `sprites/Main-ui/icons/`, shield art to `sprites/shop/icons/`, and compatibility icons to `sprites/buffs/legacy/`. **Deleted** unused `sprites/Boost-UI/` and `sprites/Pause-UI/` art, legacy `mana_regen.wav`, `shield_boost.wav`, `speed_boost.wav`, `scenes/buff_test.gd`, and `scripts/Buffs/test_buff.tres`, `sprites/quit_icon.png`, `__MACOSX/`, the redundant root `0x72_DungeonTilesetII_v1.7/` pack, and unused extracted Raven copies. | Static wall fixtures → shared 12 FPS nearest-filtered torches with offset flicker, amber in the regular shop and crimson in the pact room. Godot references and import sidecars follow the active assets. |
| Regression tests | **Added** `tests/shop_regression.tscn` and `shop_regression.gd`, then extended the suite with room routes, weapon fallbacks, sacrifices, save/reset, fullscreen, dependencies, torches, and atlas states. | Manual checks → isolated, repeatable playthrough assertions at both target resolutions. |

## How Both Traders Work

| | Regular Dungeon Trader | Mysterious Trader |
| --- | --- | --- |
| Room and stock | `scenes/shop_room.tscn` has five blue pedestals. Health Potion restores up to 3 HP for 20 coins, Shield Recharge up to 3 shield for 15, and Mana Potion up to 20 mana for 15. Shotgun costs 40 and Long Katana 35. These offers are fixed. | `scenes/mysterious_shop_room.tscn` is a separate special room with three horizontal red pedestals. A gated or owned pact gets an unequipped fallback weapon with that stand's original sacrifice. The pool is Ember Staff, Frost Staff, Storm Staff, Spear and War Hammer. |
| Interaction | Press **E** once to purchase. An empty weapon slot fills first. With both slots occupied, the purchase replaces the active weapon and drops the old one near the stand. | Press **E** to reveal the warning, then **[E] Confirm** to revalidate and trade. Leaving or pausing cancels the prompt. The code enforces floors of **2 max HP, 1 base shield and 50 max mana**. Fallback weapons use the same equip/swap flow. |

Successful transactions mark the stand sold and request a checkpoint. Failed validation leaves the offer unclaimed.

## Standard and Special Pact Buffs

`BuffManager` shuffles eligible standard buffs and offers up to three distinct cards at the start and after a room clear. Choosing a duplicate raises its level by one, up to the cap. Capped entries are excluded. The live pool contains **seven** standard buffs, including the single-level Reflect.

| Standard buff | Cap | Effect |
| --- | ---: | --- |
| Bullet Ricochet | 3 | One extra bullet bounce per level. |
| Reflect | 1 | Active melee strikes return hostile non-laser projectiles. |
| Deadly Strike | 3 | Each level subtracts 20% of base spread and adds a 10 percentage point chance per pellet to deal double damage. |
| Shockwave | 3 | A surviving hit, including a shield hit, emits a wave for 2 damage per level. |
| Life | 3 | +1 max HP per level and passive healing at level ÷ 10 HP/s while injured. |
| Protection | 3 | +1 shield capacity per level. Recharge delay is divided by `1 + 0.5 × level`. |
| Looting | 3 | Crate loot weight is multiplied by `1 + 0.35 × level`. Long Katana can join the candidate pool at 5% per level. |

| Single-level pact | Cost and prerequisite | Effect |
| --- | --- | --- |
| Movement Surge | −1 max shield | +30% of base movement speed. |
| How Dare You Touch Me | −1 max HP, requires Shockwave | Replaces the wave with three cross-shaped pulses dealing 3 damage per Shockwave level per pulse. |
| Heed My Call | −30 max mana, or surrender Reflect for zero stat loss | A 12-damage meteor every 30 seconds, targeted at an active boss or a random screen position. Every fifth kill resets the timer. |

`GlobalData.gd` saves coins, sold stand IDs, routes, defeated spawns and reward claims. The player snapshot adds equipment, buff IDs and levels, sacrifices, vitals and timers. Continue restores the checkpoint. New Game and Restart clear run state and reopen the starting picker. Dropped floor pickups have no checkpoint field.

## Verification

| Resolution | Passed | Failed | Inspected render |
| --- | ---: | ---: | --- |
| 640×360 | 201 | 0 | Starting picker |
| 1280×720 | 201 | 0 | Room-clear picker |

Both Godot 4.7.2 Compatibility runs exited successfully. The suite verified first-card focus, Escape handling, card bounds, four atlas states, and 83 texture dependencies with zero broken paths. Godot still reported the previously observed renderer and shutdown resource diagnostics.
