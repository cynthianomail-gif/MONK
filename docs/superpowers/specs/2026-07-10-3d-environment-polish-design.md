# 3D Environment Polish Design

## Goal

Improve the Armory District, Underground Parlor, and Soup Carry restaurant without changing their navigation contracts, collision boundaries, minigame rules, save data, or scene entry points.

## Approved direction

Use the medium-cost modular approach approved in conversation: keep the current procedural layouts and replace their flat-box appearance with reusable architectural layers, stronger focal lighting, and clearer gameplay landmarks.

## Scene design

### Armory District

- Keep the forge at the end of the street as the primary landmark.
- Add overhead gantries, pipe runs, tanks, roof machinery, and facade frames so the street has vertical industrial silhouettes.
- Reduce the repeated-lantern look and preserve warm forge light against a cooler street fill.
- Keep the existing walkable corridor and forge blocker unchanged.

### Underground Parlor

- Keep the four existing interaction stations and their trigger positions.
- Add black-metal structural frames, recessed station alcoves, ceiling trusses, and partition details.
- Reduce the full-room red/gold wash; reserve brighter gold for station landmarks and the central chandelier.
- Keep all wall and table collision boundaries unchanged.

### Soup Carry

- Keep the first-person movement, table positions, pickup point, and 75-second loop unchanged.
- Brighten the navigation plane and build a readable wooden restaurant interior with floor planks, wall frames, shelves, menu boards, and counter depth.
- Make pickup and delivery routes readable through local lighting rather than relying only on the HUD arrow.

## Technical approach

Each scene owns a named architecture root (`ArmoryArchitecture`, `ParlorArchitecture`, `SoupArchitecture`). The roots contain only visual meshes and lights; existing gameplay nodes and colliders remain untouched. A headless integration test instantiates each scene and checks that these layers and their required landmarks exist, and that the parlor and restaurant lighting stay within readable ranges.

## Acceptance criteria

- Existing Ares art, parlor, Soup Carry 3D, mouse-look, and map tests still pass.
- Each scene exposes its named architecture root with multiple visual modules.
- Armory has overhead industrial silhouettes and a cool/warm lighting split.
- Parlor ambient saturation and bloom are reduced while station landmarks remain visible.
- Soup Carry has a brighter ambient level, a wood floor layer, wall framing, and kitchen shelving.
- Fresh GPU captures show no camera-blocking geometry, clipped entrances, or obscured interaction stations.

