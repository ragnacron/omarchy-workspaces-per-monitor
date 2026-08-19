# Workspaces (per monitor)

An [Omarchy](https://omarchy.org/) bar widget that shows only the workspaces belonging to
the monitor each bar is on.

## The problem

Omarchy draws one bar surface per monitor, but the built-in `omarchy.workspaces` widget
renders *every* workspace on *every* bar. So even after you bind workspaces to outputs in
Hyprland, both bars still show all of them — and because the highlight tracks the globally
focused workspace, only one bar ever lights up.

```
before   DP-1  ● 2 3 4 5 6 7 8        DP-2  1 2 3 4 5 6 7 8

after    DP-1  ● 2 3 4                DP-2  5 ● 7 8
```

Each bar now also highlights *its own* monitor's active workspace, so both dots are lit at
once — the right-hand one stays visible even while the left monitor has focus.

## Requirements

- Omarchy 4.x (the Quickshell-based shell)
- Workspaces actually bound to monitors

The widget derives everything from Hyprland, so it only does something useful once you
have workspace rules. In `~/.config/hypr/monitors.lua`:

```lua
hl.workspace_rule({ workspace = "1", monitor = "DP-1", persistent = true, default = true })
hl.workspace_rule({ workspace = "2", monitor = "DP-1", persistent = true })
hl.workspace_rule({ workspace = "3", monitor = "DP-1", persistent = true })
hl.workspace_rule({ workspace = "4", monitor = "DP-1", persistent = true })

hl.workspace_rule({ workspace = "5", monitor = "DP-2", persistent = true, default = true })
hl.workspace_rule({ workspace = "6", monitor = "DP-2", persistent = true })
hl.workspace_rule({ workspace = "7", monitor = "DP-2", persistent = true })
hl.workspace_rule({ workspace = "8", monitor = "DP-2", persistent = true })
```

`persistent = true` matters: without it an empty workspace stops existing, so each bar
would show only the workspaces that currently hold windows and would visibly reflow as you
open and close things.

## Install

```bash
omarchy plugin add https://github.com/ragnacron/omarchy-workspaces-per-monitor.git --enable
```

The widget declares `clonedFrom: omarchy.workspaces`, so it takes over the built-in
widget's existing slot in your bar — same position, same inline settings. Nothing to move.

If you have already replaced the built-in with your own clone (via
`omarchy plugin clone omarchy.workspaces`), remove that first. The slot takeover looks for
`omarchy.workspaces` in your layout, and if it is not there this lands *beside* your clone
in the left section instead of replacing it, leaving two workspace widgets in the bar:

```bash
omarchy plugin remove <username>.workspaces --yes   # restores the built-in to its slot
```

## Configuration

None. The monitor-to-workspace mapping is read live from Hyprland, so `monitors.lua`
stays the single source of truth.

## How it works

Three changes to the stock widget:

- **Finds its own screen.** A bar surface exists per monitor, so each widget instance
  resolves `QsWindow.window.screen` to learn which output it was drawn on.
- **Filters by monitor name.** Workspaces are kept when `workspace.monitor.name` matches
  that screen. Quickshell screen names and Hyprland monitor names are the same namespace
  (the connector name, e.g. `DP-1`), which is the pairing Omarchy's own bar already relies
  on for panel routing.
- **Highlights per monitor.** The active marker reads `workspace.active`
  ("active on its own monitor") instead of `Hyprland.focusedWorkspace` ("active *and* its
  monitor has focus"), which is why both bars can show a dot simultaneously.

## Behaviour worth knowing

- **Moving a workspace across outputs works live.** An unpinned workspace moved with
  `SUPER+SHIFT+ALT+←/→` disappears from one bar and appears on the other immediately.
- **Rule-pinned workspaces cannot be moved.** Hyprland snaps them back to the monitor
  their `workspace_rule` names. That is the rule working, not the widget.
- **Unplugging a monitor is handled.** Hyprland relocates that output's workspaces, so the
  remaining bar grows to include them, and shrinks again when the monitor returns. A
  static mapping table would show the wrong answer here; deriving live does not.
- **It degrades to the stock behaviour.** Until a bar surface reports its screen, the
  filter is off and every workspace shows. That also means a single-monitor session, or a
  setup with no workspace rules, behaves exactly like the built-in widget.
- Special and scratchpad workspaces (negative ids) and workspaces above 10 are excluded,
  same as the built-in.

## Uninstall

```bash
omarchy plugin remove ragnacron.workspaces-per-monitor
```

`clonedFrom` makes this restore the built-in `omarchy.workspaces` widget in the same slot.

## Development

The plugin folder is the repo root, which is exactly the layout `omarchy plugin add`
expects. That command installs the plugin as a **git checkout** of this repo with `origin`
set, so after installing you have two working copies of the same thing: the clone you
develop in, and `~/.config/omarchy/plugins/ragnacron.workspaces-per-monitor/`. Pick one as
your editing copy and pull into the other:

```bash
# editing in your own clone
git push
omarchy plugin update ragnacron.workspaces-per-monitor

# or editing the installed checkout directly, then syncing your clone
git -C /path/to/your/clone pull
```

Symlinking one to the other will not work — `omarchy plugin validate` rejects any symlink
inside a plugin folder. If you installed by copying the folder rather than through
`omarchy plugin add`, the installed directory is a plain copy and you sync it with:

```bash
rsync -a --delete --exclude .git \
  ./ ~/.config/omarchy/plugins/ragnacron.workspaces-per-monitor/
```

Two things that will otherwise cost you an afternoon:

- **Editing the QML needs a full `omarchy restart shell`.** Omarchy logs
  `Local plugin changed, reloading: <id>` and `omarchy-shell shell rescanPlugins` reports
  success, but an already-mounted bar widget keeps running the old code. You will debug
  code that is not executing.
- **QML errors go to the journal**, since the shell runs under `systemd-cat`:

  ```bash
  journalctl --user -t omarchy-shell -f
  ```

Useful while iterating — widget width per bar surface, one row per monitor:

```bash
omarchy-shell shell debugBarGeometry | jq -r '.[] | select(.id|test("workspaces")) | "\(.id) \(.width)"'
```

Validate before publishing:

```bash
omarchy plugin validate .
```

## Credits

Derived from the `omarchy.workspaces` bar widget in
[Omarchy](https://github.com/basecamp/omarchy) by David Heinemeier Hansson (DHH).

## Licence

MIT — see [LICENSE](LICENSE). Upstream copyright retained.
