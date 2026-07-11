# 3D Environment Polish Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Upgrade the Armory District, Underground Parlor, and Soup Carry restaurant with modular architectural depth and readable lighting while preserving gameplay.

**Architecture:** Add one visual-only architecture root to each existing procedural scene. Build details from the current mesh helpers so no new asset dependency or gameplay data format is introduced, then verify the roots and lighting with one headless integration test plus fresh GPU captures.

**Tech Stack:** Godot 4.5, GDScript, existing stylized shaders, headless scene tests.

## Global Constraints

- Treat all source files as UTF-8 and do not rewrite existing Chinese text.
- Use `apply_patch` for manual edits.
- Preserve all current scene paths, trigger positions, collision boundaries, and gameplay constants.
- Do not commit because the shared feature branch contains unrelated user changes.

---

### Task 1: Visual acceptance test

**Files:**
- Create: `test/TestEnvironmentPolish.gd`
- Create: `test/TestEnvironmentPolish.tscn`

**Interfaces:**
- Consumes: the three existing scene paths.
- Produces: headless assertions for named architecture roots, module counts, and environment readability values.

- [ ] Write a test that instantiates each scene and expects `ArmoryArchitecture`, `ParlorArchitecture`, and `SoupArchitecture`.
- [ ] Assert that each root contains the named landmark modules and enough mesh descendants to represent a real architectural layer.
- [ ] Assert that parlor saturation/bloom are restrained and Soup Carry ambient energy is readable.
- [ ] Run the test and confirm it fails because the three roots do not exist.

Run: `Godot_v4.5-stable_win64_console.exe --headless --path D:/monk/MONK res://test/TestEnvironmentPolish.tscn`

Expected before implementation: exit 1 with missing architecture-root failures.

### Task 2: Armory industrial architecture

**Files:**
- Modify: `src/screens/MapScreen/environments/ArmoryDistrict.gd`

**Interfaces:**
- Produces: `ArmoryArchitecture` containing `Gantries`, `PipeRuns`, `StorageTanks`, and `FacadeFrames`.

- [ ] Add visual-only helper modules under a named root.
- [ ] Add overhead gantries and side-mounted pipes without crossing the player corridor below head height.
- [ ] Add tanks, roof machinery, facade frames, and cool secondary lights.
- [ ] Run `TestEnvironmentPolish` and the existing `TestAresArt` test.

Expected: Armory assertions pass; test remains red only for unimplemented parlor/soup roots.

### Task 3: Parlor architectural zoning

**Files:**
- Modify: `src/screens/MapScreen/environments/UndergroundParlor.gd`

**Interfaces:**
- Produces: `ParlorArchitecture` containing `StationAlcoves`, `CeilingTrusses`, `Partitions`, and `WallPanels`.

- [ ] Add visual-only black-metal frames and station alcoves without changing triggers or colliders.
- [ ] Add ceiling trusses and partitions that preserve the central route.
- [ ] Reduce ambient saturation, glow, and repeated gold intensity.
- [ ] Run `TestEnvironmentPolish` and `TestUndergroundParlor`.

Expected: parlor functionality passes; polish test remains red only for the soup root.

### Task 4: Soup Carry restaurant architecture

**Files:**
- Modify: `src/screens/Minigames/SoupCarry.gd`

**Interfaces:**
- Produces: `SoupArchitecture` containing `WoodFloor`, `WallFrames`, `KitchenShelves`, and `MenuBoards`.

- [ ] Add a wood-plank visual floor above the unchanged collision floor.
- [ ] Add wall framing, shelves, bowls, menu boards, and counter panels.
- [ ] Increase neutral ambient visibility and add local route/pickup lighting.
- [ ] Run `TestEnvironmentPolish`, `TestSoupCarry3D`, and `TestSoupCarry`.

Expected: all scene and gameplay assertions pass.

### Task 5: Visual and regression verification

**Files:**
- Reuse: `test/CaptureArmoryScene.tscn`
- Reuse: `test/CaptureParlor.tscn`
- Reuse: `test/CaptureSoupCarry3D.tscn`

**Interfaces:**
- Produces: fresh screenshots for visual inspection and a clean targeted test result.

- [ ] Run parse/import validation and the targeted regression tests.
- [ ] Capture all three scenes on the GPU.
- [ ] Inspect the captures for blocked routes, clipping, overexposure, and landmark readability.
- [ ] Review the final diff and confirm unrelated user files were not changed.

Expected: targeted tests exit 0; screenshots show clearer depth and navigation without gameplay obstruction.

