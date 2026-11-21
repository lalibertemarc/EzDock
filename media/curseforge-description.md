# EzDock

*All your Ez addons' icons in one tidy dock.*

You log in on your alt. The EzEmote icon is in the middle of the screen, where you dragged it out of the way once. The EzNotebook icon sits on top of the EzLines one. EzAcquaintances is somewhere above the chat box, and on your main they were all in a neat row. Every character, the same little cleanup.

**EzDock** gathers those icons into one dock, in the same spot and the same order on every character. Fold it away with one click when you want a clean screen.

## What goes in

EzDock takes in the launcher icons of these addons by itself, with nothing to set up:

- **EzEmote**
- **EzOutfitter**
- **EzAcquaintances**
- **EzLines**
- **EzNotebook**

Only the ones you have installed show up. Other Ez addons with an icon join the dock as they come out. These are the real buttons, moved into the dock, so they work just as before: same clicks, same right-click menus, same gold border when something waits for you.

EzDock doesn't take other addons' minimap buttons.

## Fold it away

Click the small handle at the end of the dock and the icons fold into it. Click again and they're back. It works in combat too.

While folded, the handle shows how many icons it holds, and a **gold mark** when one of them is waiting for you (like EzLines when the rest of a long line waits for your next press). Your fold is kept per character.

## Make it yours

- **Move it**: unlock the dock and drag the handle anywhere. By default it sits just above the chat box.
- **Reorder**: unlocked, drag an icon onto another spot.
- **Which way**: icons line up to the left, the right, up or down from the handle, in one line or in rows of up to 12.
- **Size and spacing** of the icons, a **background** behind them or not, and a **fade** so the dock goes see-through until your mouse is over it (it lights up when an icon needs you).
- **Pick the icons**: the Icons page of the options lists every icon, docked or not, with arrows to set the order. Take one out and it goes back where its addon puts it.
- An icon its addon hides leaves **no gap**. When it shows again, it takes its place.

Your dock looks the same on every character on your account.

## Good to know

- Turn the dock off (`/dock off`) and every icon goes back to where its own addon puts it.
- **WoW Forever and Classic Era**, from one download.
- For addon authors: any addon can hand its own button to the dock with `EzDockAPI.Add(button, { key = "...", label = "..." })`.

## Commands

`/dock` or `/ezdock`

| Command | Does |
|---|---|
| `/dock` | Open the options |
| `/dock fold \| unfold` | Fold the icons into the handle, or bring them back |
| `/dock lock \| unlock` | Stop or allow dragging the dock and its icons |
| `/dock left \| right \| up \| down` | Which way the icons line up |
| `/dock list` | Every icon and where it is |
| `/dock add \| remove <name>` | Put an icon in the dock, or give it back |
| `/dock on \| off` | Use the dock (off gives every icon back) |
| `/dock reset` | Put the dock back above the chat box |
| `/dock help` | List the commands in chat |

## More from the EzAddons family

- **EzNotebook**: notes and todo lists in folders, with links. Linked tasks tick themselves.
- **EzLines**: your prewritten lines, one search away.
- **EzEmote**: an emote palette with favorites, chains and emote wheels.
- **EzAcquaintances**: a contact book for the people you meet. You write who they are.
- **EzOutfitter**: gear set, transmog outfit and an emote, put on together.

Every one of them is free and stands on its own.

## Join us on Discord

Come say hi: **[join the EzAddons Discord](https://discord.com/invite/bZrAYqbsD8)**.

- Hear about new versions first (pick the addons you care about and get pinged when they update).
- Suggest an icon that should join the dock.
- Report bugs, and help test what's coming next.

## Tell us what you think!

An icon that won't sit still? A dock in the wrong place? **Drop it in the [Discord](https://discord.com/invite/bZrAYqbsD8), leave a comment, or open an issue on [GitHub](https://github.com/lalibertemarc/EzDock/issues)** and it might be in the next update.
