# Workspaces (per monitor)

An [Omarchy](https://omarchy.org/) bar widget that splits one global set of workspaces
between your monitors, and shows each bar only the ones on its own monitor.

## The problem

Omarchy draws one bar surface per monitor, and its built-in `omarchy.workspaces` widget
does not show which workspaces live where.

- **Omarchy 4.0** rendered *every* workspace on *every* bar. Even after you bound
  workspaces to outputs in Hyprland, both bars showed all of them, and because the
  highlight tracked the globally focused workspace, only one bar ever lit up.
- **Omarchy 4.5** gives every monitor its own workspaces 1–10 instead. Each bar reads
  `1 2 3 4 5`, so all of them look the same, and Super + 4 means "slot 4 on whichever
  monitor has focus" rather than one particular workspace.

This widget is for the other arrangement: workspaces 1–10 shared out between the
monitors, each with one fixed home.

```
4.0 stock   DP-1  ● 2 3 4 5 6 7 8     DP-2  1 2 3 4 5 6 7 8
4.5 stock   DP-1  ● 2 3 4 5           DP-2  1 2 3 ● 5

this        DP-1  ● 2 3 4             DP-2  5 ● 7 8
```

Each bar also highlights *its own* monitor's active workspace, so every dot is lit at
once. The right-hand one stays visible even while the left monitor has focus.

## Requirements

- Omarchy 4.5 or later. For 4.0, use [v1.0.0](https://github.com/ragnacron/omarchy-workspaces-per-monitor/tree/b0de0f7), which needs no Hyprland setup.
- Workspaces bound to monitors with workspace rules
- Omarchy's per-monitor numbering switched off, with `hypr/global-workspaces.lua`
  from this plugin. See below.

### Workspace rules

The widget reads everything from Hyprland, so it only does something useful once
workspaces have rules. In `~/.config/hypr/monitors.lua`:

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

`persistent = true` matters. Without it an empty workspace stops existing, so each bar
would show only the workspaces that currently hold windows and would visibly reflow as you
open and close things.

### Global workspace numbering (Omarchy 4.5+)

Omarchy 4.5 numbers workspaces in blocks of ten per monitor
(`$OMARCHY_PATH/default/hypr/monitor-workspaces.lua`): ids 1–10 on the first monitor,
11–20 on the next, and so on. Super + N goes to slot N on the focused monitor, and every
config reload or monitor change renumbers workspaces into those blocks. Left alone, it
turns workspace 5 on DP-2 into 15, which none of the rules above name.

`hypr/global-workspaces.lua` puts global numbering back:

- Super + N, Super + Shift + N and Super + Shift + Alt + N act on workspace N itself,
  on whichever monitor its rule puts it, as in Omarchy 4.0.
- Super + Shift + Alt + arrow moves a workspace to another monitor without renumbering it.
- The renumbering is switched off.

Load it in `~/.config/hypr/hyprland.lua`, directly after Omarchy's defaults and before
your own files, so an `o.rebind` of yours still wins:

```lua
-- Load Omarchy defaults.
require("default.hypr.omarchy")

-- Global workspace numbering for the "Workspaces (per monitor)" bar widget:
-- Super + N goes to workspace N on whichever monitor monitors.lua puts it,
-- instead of Omarchy's per-monitor 1-10. Skipped once the plugin is removed.
local global_workspaces = os.getenv("HOME") .. "/.config/omarchy/plugins/ragnacron.workspaces-per-monitor/hypr/global-workspaces.lua"
local global_workspaces_file = io.open(global_workspaces, "r")
if global_workspaces_file then
  global_workspaces_file:close()
  dofile(global_workspaces)
end
```

The file-exists check keeps Hyprland loading if the plugin is removed. It then falls back
to Omarchy's own per-monitor numbering.

Omarchy has no setting for its per-monitor blocks. This file turns them off by replacing
the `o.workspaces.reconcile` function that Omarchy's monitor and reload hooks call. If an
Omarchy update renames that function, renumbering comes back. You'll notice it as a
workspace on your second monitor showing up as `14`.

## Install

```bash
omarchy plugin add https://github.com/ragnacron/omarchy-workspaces-per-monitor.git --enable
```

Then add the loader above to `hyprland.lua` and the workspace rules to `monitors.lua`,
in that order, and run `hyprctl reload`. If the rules come first, Omarchy's renumbering
is still active when they load and moves any workspace already holding windows into its
own blocks.

Workspaces Omarchy has already renumbered (`11`, `14`, `21`…) keep their ids. The widget
still shows them, so their windows don't go missing, and they disappear once empty. To
fold one back in straight away, give it a free global id:

```bash
hyprctl dispatch 'hl.dsp.workspace.change_id({ workspace = "14", id = 4 })'
```

The widget declares `clonedFrom: omarchy.workspaces`, so it takes over the built-in
widget's existing slot in your bar, with the same position and inline settings. Nothing to move.

If you have already replaced the built-in with your own clone (via
`omarchy plugin clone omarchy.workspaces`), remove that first. The slot takeover looks for
`omarchy.workspaces` in your layout. If it is not there, this lands *beside* your clone
in the left section instead of replacing it, leaving two workspace widgets in the bar:

```bash
omarchy plugin remove <username>.workspaces --yes   # restores the built-in to its slot
```

## Configuration

The widget has none. Its monitor-to-workspace mapping is read live from Hyprland, so
`monitors.lua` stays the single source of truth.

## How it works

The widget changes three things in the stock 4.0 widget:

- **Finds its own screen.** A bar surface exists per monitor, so each widget instance
  resolves `QsWindow.window.screen` to learn which output it was drawn on.
- **Filters by monitor name.** Workspaces are kept when `workspace.monitor.name` matches
  that screen. Quickshell screen names and Hyprland monitor names are the same namespace
  (the connector name, e.g. `DP-1`), which is the pairing Omarchy's own bar already relies
  on for panel routing.
- **Highlights per monitor.** The active marker reads `workspace.active`
  ("active on its own monitor") instead of `Hyprland.focusedWorkspace` ("active *and* its
  monitor has focus"), which is why both bars can show a dot simultaneously.

Like the 4.5 built-in, it asks Hyprland to refresh its monitor and workspace state after
workspace switches and moves. Quickshell credits every switch to the focused monitor,
which would otherwise leave a stale dot on the bar of a monitor that switched without focus.

`hypr/global-workspaces.lua` is the Hyprland half. See
[Global workspace numbering](#global-workspace-numbering-omarchy-45).

## Behaviour worth knowing

- **Moving a workspace across outputs works live.** An unpinned workspace moved with
  `SUPER+SHIFT+ALT+←/→` disappears from one bar and appears on the other immediately.
- **Rule-pinned workspaces cannot be moved.** Hyprland snaps them back to the monitor
  their `workspace_rule` names. That is the rule working, not the widget.
- **Unplugging a monitor is handled.** Hyprland relocates that output's workspaces, so the
  remaining bar grows to include them, and shrinks again when the monitor returns. A
  static mapping table would show the wrong answer here; reading it live from Hyprland
  does not.
- **It falls back to the stock behaviour.** Until a bar surface reports its screen, the
  filter is off and every workspace shows. That also means a single-monitor session, or a
  setup with no workspace rules, behaves exactly like the built-in widget.
- **Every workspace with a positive id shows**, including ones above 10. Super + N only
  reaches 1–10, but a workspace a window rule or an older session left at `14` still holds
  windows, and hiding it would hide them. Special and scratchpad workspaces (negative ids)
  are excluded, same as the built-in.

## Uninstall

```bash
omarchy plugin remove ragnacron.workspaces-per-monitor
```

`clonedFrom` makes this restore the built-in `omarchy.workspaces` widget in the same slot.
The loader in `hyprland.lua` then finds no file and skips itself, so Hyprland is back on
Omarchy's per-monitor numbering at the next reload. Delete the loader and your
`hl.workspace_rule` lines as well: the built-in widget lists every workspace in a monitor's
block, so rules that pin 1–9 across monitors leave the first monitor's bar showing `1…9`.

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

Symlinking one to the other will not work, because `omarchy plugin validate` rejects any
symlink inside a plugin folder. If you installed by copying the folder rather than through
`omarchy plugin add`, the installed directory is a plain copy and you sync it with:

```bash
rsync -a --delete --exclude .git \
  ./ ~/.config/omarchy/plugins/ragnacron.workspaces-per-monitor/
```

Three things that will otherwise cost you an afternoon:

- **Editing the QML needs a full `omarchy restart shell`.** Omarchy logs
  `Local plugin changed, reloading: <id>` and `omarchy-shell shell rescanPlugins` reports
  success, but an already-mounted bar widget keeps running the old code. You will debug
  code that is not executing.
- **Editing `hypr/global-workspaces.lua` needs `hyprctl reload`**, then
  `hyprctl configerrors`. Hyprland auto-reloads the files it `require`s, but this one is
  loaded with `dofile` from the plugin folder, so don't count on a save reloading it.
- **QML errors go to the journal**, since the shell runs under `systemd-cat`:

  ```bash
  journalctl --user -t omarchy-shell -f
  ```

Useful while iterating. This prints widget width per bar surface, one row per monitor:

```bash
omarchy-shell shell debugBarGeometry | jq -r '.[] | select(.id|test("workspaces")) | "\(.id) \(.width)"'
```

To check the renumbering is really off, ask Hyprland where `reconcile` now comes from.
It should name `global-workspaces.lua`:

```bash
hyprctl dispatch "hl.dsp.exec_cmd('echo ' .. debug.getinfo(o.workspaces.reconcile, 'S').short_src .. ' > /tmp/reconcile')"
cat /tmp/reconcile
```

Validate before publishing:

```bash
omarchy plugin validate .
```

## Credits

Derived from the `omarchy.workspaces` bar widget in
[Omarchy](https://github.com/basecamp/omarchy) by David Heinemeier Hansson (DHH).

## Licence

MIT. See [LICENSE](LICENSE). Upstream copyright retained.

## Related plugins

Other Omarchy plugins with an overlapping purpose, listed to help you compare. They are
separate projects that may differ in features and approach, and this plugin shares no
code with them. Each description is the project's own:

- [derluke/omarchy-dual-monitor-workspaces](https://github.com/derluke/omarchy-dual-monitor-workspaces):
  "Independent workspace banks, navigation, safe window movement, and per-screen dots for
  dual-monitor Omarchy"
- [mmsbrggr/omarchy-per-monitor-workspaces](https://github.com/mmsbrggr/omarchy-per-monitor-workspaces)
  (archived): "Independent workspaces per monitor for Omarchy: SUPER+N always means this
  screen's Nth workspace"

Omarchy 4.5 also has per-monitor workspaces built in. If you want every monitor to have
its own 1–10, the stock `omarchy.workspaces` widget already does that. This plugin is for
one global set of workspaces split between monitors.
