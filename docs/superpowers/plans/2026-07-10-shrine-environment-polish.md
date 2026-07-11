# Shrine Environment Polish Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Improve the shrine hub buildings, forecourt, street materials, vegetation, and backdrop without changing gameplay navigation.

**Architecture:** Extend the existing procedural `ShrineStreet` builder with a named visual-only architecture root and three tagged shop archetypes. Keep all gameplay data and colliders unchanged, and guard the result with headless integration assertions plus fresh GPU captures.

**Tech Stack:** Godot 4.5, GDScript, existing stylized shaders and procedural mesh helpers.

## Global Constraints

- Treat all source files as UTF-8 and preserve existing Chinese text.
- Use `apply_patch` for edits.
- Preserve lane boundaries, NPC positions, quest coordinates, and time-period behavior.
- Do not modify the already-dirty `LocationTrigger.gd`.
- Do not commit because the shared branch contains unrelated user changes.

---

### Task 1: Shrine visual acceptance test

**Files:**
- Modify: `test/TestEnvironmentPolish.gd`

- [ ] Instantiate `ShrineStreet.tscn` and require the five named architecture modules.
- [ ] Require at least three tagged shop archetypes, restrained cobbles, and readable morning ambient light.
- [ ] Run the test and confirm it fails for missing shrine polish.

### Task 2: Street material and shop variation

**Files:**
- Modify: `src/screens/MapScreen/environments/ShrineStreet.gd`

- [ ] Reduce cobblestone scale and bump.
- [ ] Wrap generated shops in tagged roots and apply three roof/facade archetypes.
- [ ] Soften morning sun/ambient balance while keeping the map bright.

### Task 3: Shrine architecture modules

**Files:**
- Modify: `src/screens/MapScreen/environments/ShrineStreet.gd`

- [ ] Add the side-street endcap and backdrop roof silhouettes.
- [ ] Add the shrine forecourt, torii detail layer, and town facade accents.
- [ ] Keep all new meshes visual-only so existing traversal remains unchanged.

### Task 4: Organic-shape polish

**Files:**
- Modify: `src/screens/MapScreen/environments/ShrineStreet.gd`

- [ ] Refine paper lantern proportions and daylight emission.
- [ ] Flatten and rotate blossom clusters and reduce spike-like tree silhouettes.

### Task 5: Verification

**Files:**
- Reuse: `test/TestEnvironmentPolish.tscn`
- Reuse: `test/TestMapScreen3D.tscn`
- Reuse: `test/TestMouseLook.tscn`
- Reuse: shrine capture scenes.

- [ ] Run editor parse/import and targeted headless regression tests.
- [ ] Capture main street, shrine approach, and side street on the GPU.
- [ ] Inspect sightline, clipping, side-street closure, lighting, and navigation.
- [ ] Review the final diff and confirm unrelated files are untouched.

