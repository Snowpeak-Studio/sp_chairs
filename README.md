# sp_chairs

Standalone sit/lie interactions for chairs, stools, and medical beds using  **ox_lib**, **sp_core**
No framework required.
Utilizes sp_core bridge, target must be configured.

---

## Requirements
- `ox_lib` (uses `lib.requestAnimDict`, `lib.playAnim`, `lib.getClosestPlayer`)
- `sp_core` [Free to download from our tebex ] (https://shop.snowpeakstudio.com/package/7015578
)
---

## Features
- Target options for **chair**, **chair2**, **chair3**, **chair4**, **stool**, **slots**, **sunbed**, and **medical**.
- Per-model pose data: `offset` (attach), `rotation` (attach rot), optional `anim`, optional `camera`.
- Optional action to **Put Person On Bed** (uses nearest player within 2.0).

---

## How it works (quick)
- Base poses (default anims/text) live in `shared/bases.lua`.
- Model-specific poses (offsets/rotations/optional cameras) live in `shared/models.lua`.
- Client attaches the player to the entity, plays the pose’s anim, and (if defined) spawns a simple look-at camera.
- Press **E** to stand up.

**Camera tips**
- “Zoom out” by moving `camera.offset.y` further negative (e.g., `-3.0`).
- Lower/raise camera with `camera.offset.z`.
- Aim center using `camera.target.z`.

---

## In-game Usage
Look at a supported prop and use the **ox_target** options:
- **Sit (Chair / Chair 2 / Chair 3 / Chair 4)**
- **Sit (Stool)**
- **Use Slots**
- **Lay (Medical)**
- **Put Person On Bed** (appears when a player is within ~2.0)

Press **E** to stand up.

---

## Events

### Client
```lua
-- Make the local player perform a pose on an entity
TriggerEvent('sp_chairs:doPose', entity, 'medical') -- or 'chair'|'chair2'|'chair3'|'chair4'|'stool'|'slots'|'sunbed'

-- Find nearest supported bed within ~2.0 and lay down
TriggerEvent('sp_chairs:forceMedical')
```

### Server → Client
```lua
-- Tell a specific player to lay in medical pose on the targeted bed
TriggerServerEvent('sp_chairs:putOnMedical', targetServerId)
```

---

## Add a Model (example)
Add entries to `shared/models.lua` under the model hash or backticked model name:

```lua
[`v_med_bed2`] = {
  medical = {
    offset  = vector3(-0.1, 0.0, 1.35),
    rotation = vector3(0.0, 0.0, 180.0),
    camera  = { offset = vector3(0.0, -3.0, 1.25), target = vector3(0.0, 0.0, 0.0) },
  },
}

[GetHashKey('prop_office_chair_01')] = {
  chair = {
    offset   = vector3(0.0, 0.08, 0.49),
    rotation = vector3(0.0, 0.0, 180.0),
    -- camera = { offset = vector3(0.0, -2.4, 1.2), target = vector3(0.0, 0.0, 0.5) }
  },
}
```

---

## Troubleshooting
- **No target option?** Ensure the prop’s model exists in `shared/models.lua`.
- **Wrong orientation?** Adjust `rotation.z` (heading) and `offset` values.
- **Camera too close?** Decrease `camera.offset.y` (e.g., `-3.0`).
- **Animations not playing?** Verify anim `dict`/`name` are valid and loadable.

---
