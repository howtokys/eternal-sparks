# Dungeon progression checks

Run from the project root with Godot 4.7.2. Use an isolated data directory because the existing Player saves automatically on entering a room.

```bash
GODOT_MCP_RUNTIME=off XDG_DATA_HOME=/tmp/eternal-sparks-validation godot --headless --path . --script res://tests/dungeon_progression.gd -- Third
GODOT_MCP_RUNTIME=off XDG_DATA_HOME=/tmp/eternal-sparks-validation godot --headless --path . --script res://tests/dungeon_progression.gd -- Fourth
GODOT_MCP_RUNTIME=off XDG_DATA_HOME=/tmp/eternal-sparks-validation godot --headless --path . --script res://tests/dungeon_progression.gd -- Fifth
GODOT_MCP_RUNTIME=off XDG_DATA_HOME=/tmp/eternal-sparks-validation godot --headless --path . --script res://tests/dungeon_progression.gd -- chain
```

Individual checks cover all three starting buff resources, incoming levels 2 and 3, maximum-level caps, enemy counts, hidden/disabled portals, unlocking only on the last death, portal animation, pause/resume, HUD and weapon presence, and absence of repeated starting selection. Physics shape queries verify spawn-to-enemy/exit reachability with obstacles intact and that enemies spawn clear of static collision shapes.

The chain check chooses each starting buff through First Room's existing selection, defeats enemies through HealthComponent, enters actual exit areas, and checks every scene transition, levels 1 → 2 → 3 → 3 → 3, the completion summary, and return-to-menu button.

Validation on 2026-11-03: all individual checks and all three complete runs passed, with zero assertion failures. Scenes also opened in the connected editor; Rooms 3–5 and the completion screen were visually checked through MCP screenshots. First Room was not edited.

Observed engine diagnostics: headless shader compiler reports `!actions.custom_samplers.has(function->arguments[j].tex_builtin)`; Camera2D reports its automatic physics-process override for interpolation. Complete-run test shutdown also reports an AudioStreamPlaybackWAV/AudioStreamWAV resource leak for the existing `dungeon_menu_loop.wav` after returning to the main menu. These diagnostics remain unresolved; gameplay assertions passing does not mean the engine log is error-free.

Room 5 uses six instances of the existing enemy scene, rather than a new boss type. All new dungeon rooms reuse `scenes/second_room.gd`, with per-scene destinations and buff upgrade settings.

## Enemy damage and shields

```bash
GODOT_MCP_RUNTIME=off XDG_DATA_HOME=/tmp/eternal-sparks-validation godot --headless --path . --script res://tests/player_damage.gd
```

The damage regression test uses actual attack-range and hostile hitbox overlaps. It checks configured melee damage, shield absorption, health overflow, cooldown and repeat attacks, range exit, HUD shield display, rejection of nonpositive damage, and recharge/recharge-delay reset. All 20 checks passed on 2026-11-03, including close-contact range, the default one-point hit every 1.5 seconds, and a one-second shared damage protection window against multiple enemies. The headless shader diagnostic and camera warning described above still appear.
