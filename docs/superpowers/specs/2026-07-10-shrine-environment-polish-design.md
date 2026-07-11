# Shrine Environment Polish Design

## Goal

Upgrade the shrine hub into a layered shrine town while preserving its clear sightline to the main hall, current walkable lanes, NPC and quest coordinates, time-of-day system, and scene entry points.

## Approved direction

Use the medium-cost modular approach approved in conversation. Keep the main street and west side street layout, then add visual-only architectural layers and stronger shop variation instead of rebuilding navigation.

## Design

- Close the west side-street void with a stone wall, service gate, roof silhouettes, trees, and atmospheric depth.
- Reduce cobblestone scale and bump so the street supports rather than dominates the architecture.
- Give generated shops three recognizable archetypes with distinct roof palettes and facade details.
- Refine the torii silhouette with slimmer posts, darker feet, upward end caps, a ritual rope, and paper streamers.
- Add a shrine forecourt with a quieter paving transition, low stone borders, lanterns, and a purification basin.
- Soften morning contrast without making the map dark; retain a bright, warm, readable daytime mood.
- Reduce spherical lantern and blossom shapes, and make distant conifers less spike-like.

## Technical approach

`ShrineStreet` owns a visual-only `ShrineArchitecture` root with `SideStreetEndcap`, `ShrineForecourt`, `ToriiDetails`, `BackdropDepth`, and `TownDetails`. Generated shops are grouped as `shrine_shop` and expose one of three archetype metadata values for validation. Existing colliders, map data, and trigger placement remain unchanged.

## Acceptance criteria

- Headless polish test observes all five architecture modules and all three shop archetypes.
- Ground cobbles use street-scale stones and restrained bump.
- Morning ambient energy is high enough to soften the hard shadow split while keeping sunlit readability.
- Existing map, mouse-look, and boundary tests pass.
- Fresh GPU captures show no side-street sky void, no blocked lane, and a clear shrine sightline.

