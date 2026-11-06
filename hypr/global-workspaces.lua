-- Global workspace numbering, for the "Workspaces (per monitor)" bar widget.
--
-- Omarchy 4.5 gives every monitor workspaces 1-10 of its own
-- ($OMARCHY_PATH/default/hypr/monitor-workspaces.lua). Hyprland numbers
-- workspaces globally, so each monitor really owns a block of ten ids (1-10,
-- 11-20, ...), Super + N goes to slot N on the focused monitor, and every config
-- reload or monitor change renumbers workspaces into those blocks.
--
-- This widget is built for the other arrangement: one global set of workspaces,
-- split between the monitors by the workspace rules in monitors.lua (1-3 on one,
-- 4-6 on the next, ...). This file puts that back:
--
-- - Super + N, Super + Shift + N and Super + Shift + Alt + N act on workspace N
--   itself, on whichever monitor its rule puts it, as in Omarchy 4.0.
-- - Moving a workspace to another monitor keeps its number.
-- - The renumbering is switched off. Left on, it would turn workspace 4 on the
--   second monitor into 14 at the next config reload.
--
-- Load it from ~/.config/hypr/hyprland.lua after Omarchy's defaults and before
-- your own bindings, so an o.rebind of yours still wins. See the README.

-- Omarchy has no switch for its per-monitor blocks. Its event hooks call
-- reconcile through this shared table, so replacing it here is what stops them.
if o.workspaces and o.workspaces.reconcile then
  o.workspaces.reconcile = function() end
end

-- The same keys Omarchy binds, in $OMARCHY_PATH/default/hypr/bindings/tiling.lua.
for workspace = 1, 10 do
  local key = "code:" .. tostring(workspace + 9)
  local id = tostring(workspace)

  o.rebind("SUPER + " .. key, "Switch to workspace " .. workspace, hl.dsp.focus({ workspace = id }))
  o.rebind("SUPER + SHIFT + " .. key, "Move window to workspace " .. workspace, hl.dsp.window.move({ workspace = id, follow = true }))
  o.rebind("SUPER + SHIFT + ALT + " .. key, "Move window silently to workspace " .. workspace, hl.dsp.window.move({ workspace = id, follow = false }))
end

local function move_workspace_to_monitor(direction)
  local function move()
    -- Hyprland reports a move toward no monitor as an error on screen.
    local target = hl.get_monitor(direction)
    if target then
      hl.dispatch(hl.dsp.workspace.move({ monitor = target.name }))
    end
  end

  -- The keybindings menu replays a function bind through this expression.
  if o.bind_expressions then
    o.bind_expressions[move] = 'hl.dsp.workspace.move({ monitor = "' .. direction .. '" })'
  end

  return move
end

local directions = {
  { key = "LEFT", direction = "l", name = "left" },
  { key = "RIGHT", direction = "r", name = "right" },
  { key = "UP", direction = "u", name = "up" },
  { key = "DOWN", direction = "d", name = "down" },
}

for _, entry in ipairs(directions) do
  o.rebind("SUPER + SHIFT + ALT + " .. entry.key, "Move workspace to " .. entry.name .. " monitor", move_workspace_to_monitor(entry.direction))
end
