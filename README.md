# EzDock

One dock for the launcher icons of the Ez addons, so they sit together on every character instead of wherever each one was dragged.

- Takes in the Ez addons' launcher icons (EzEmote, EzOutfitter, EzAcquaintances, EzLines, EzNotebook…) by their global names (`ns.KNOWN` in `Data.lua`) — those addons need no change. Other addons: `EzDockAPI.Add(button, { key, label, attention })` (see `Core.lua`).
- The real buttons are moved in (re-parented), so their gold borders and counts keep working. Their addons' own `SetPoint` calls are caught and the button put back in its slot; drag = reorder while docked. Given back (`/dock remove`, `/dock off`) where their addon last put them.
- The handle folds/unfolds the dock through a secure click, so it works in combat. Gold mark on the handle while folded and an icon has a gold border.
- An icon its addon hides leaves no gap; shown again, it takes its slot.

`/dock` (`/ezdock`): options; `fold|unfold`, `lock|unlock`, `left|right|up|down`, `list`, `add|remove <name>`, `on|off`, `reset`.

Saved: `EzDockDB` (account: `order`, `skip`, `pos`, look), `EzDockCharDB` (`collapsed`).

`lua tests/smoke.lua` runs the addon against a stubbed game API.
