# VaultPad controls

VaultPad starts in **Hybrid** mode. The first-run controls screen and in-game Settings can switch modes later.

## Touch modes

| Mode | Behavior |
| --- | --- |
| Hybrid | Direct taps plus momentary two-finger map panning. Trackpad behavior is used only when selected. Recommended. |
| Direct | Every tap moves the game cursor to the finger before activating the target. |
| Trackpad | Drag to move the game cursor, then tap to click at the cursor. |

Cursor speed affects relative Trackpad movement. Touch controls apply with **Apply & Return**; display changes apply after restarting VaultPad.

## Gestures

- Tap: select, move, interact, or activate the control under the finger.
- Long-press and drag: hold and drag when a legacy screen still expects it.
- Two-finger tap: reminds you that map panning is a two-finger drag when the command bar is visible.
- Two-finger drag: pan maps and scroll panels only while both fingers are down; lifting returns to the selected command.
- Three-finger swipe down: Back / Escape.
- Three-finger hold: highlight nearby interactive objects.
- Four-finger hold: quicksave.

## Touch command bar

The compact bar above the game HUD only adds commands that Fallout does not already expose clearly for touch:

- **Move**: tap the ground to move. The selected mode stays highlighted.
- **Use**: tap a person, door, or object to interact. This is a direct choice, not a cycling cursor button.
- **Attack**: appears during combat and selects the attack cursor.
- **Strong Kick / 4, Aim Strong Kick / 5, Reload, or Use Item**: shows the current action and its action-point cost. Tapping it moves to the next action the item supports.
- **Alternate action**: shows what tapping it will select next, such as **Kick / 4** when Punch is active.
- **End turn**: appears during combat. Use it when the remaining action points cannot pay for the selected action; points refill after enemies act.
- **Settings**: opens the native VaultPad Field Terminal.

Use Fallout's original **Skilldex** control for skills and its original **CMBT** control for attempting to leave combat. End turn is intentionally duplicated because the original target is small and the turn boundary was easy to miss on touch. Choosing **Settings Only** in the Field Terminal hides the action buttons but retains a compact Settings control, so the preference is always reversible.

## Display

- **Full HUD**: 640×480, preserving Fallout's 4:3 aspect and filling a 4:3 iPad with the original bottom interface. Recommended for touch.
- **More Map**: wider internal canvas with more world visible, but the original 640-pixel HUD becomes narrower and centered.

## Touch-native legacy screens

- Inventory: tap an item, then tap a hand slot or destination; repeat to move it back. Drag remains available.
- Barter: tap an item to move it between inventory and offer columns. Quantity entry opens the numeric keyboard.
- Character editor and save/load: the full visible Done and Cancel labels are touch targets.
- Dialogue: tap a response row directly.

Hardware keyboard, Magic Keyboard trackpad, Bluetooth mouse, Pencil hover, and accessibility behavior inside the bitmap game UI still require physical-device validation.
