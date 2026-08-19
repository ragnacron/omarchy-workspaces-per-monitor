import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "omarchy.workspaces"
  
  // The bar builds one surface per screen, so each live copy has to work out
  // which screen it landed on. QsWindow.window and window.screen both notify,
  // so the chain re-resolves if the panel is built before its window exists.
  readonly property var barWindow: root.QsWindow ? root.QsWindow.window : null
  readonly property string screenName: barWindow && barWindow.screen ? String(barWindow.screen.name || "") : ""

  // The ids this surface paints. A property rather than a function so `columns`
  // and `model` share one evaluation. Reading Hyprland.workspaces.values and
  // each workspace's monitor -- both notifying -- is what makes the list
  // recompute when a workspace appears, disappears, or is thrown to the other
  // output.
  readonly property var workspaceIds: {
    var mine = root.screenName
    var values = Hyprland.workspaces.values
    var ids = []

    for (var i = 0; i < values.length; i++) {
      var workspace = values[i]
      var id = workspace.id
      if (id <= 0 || id > 10 || ids.indexOf(id) !== -1) continue

      // Until the screen is known there is nothing to filter by, so everything
      // shows: stock behaviour, which is also what a single-monitor session
      // with no workspace rules wants.
      if (mine) {
        // A workspace whose output just went away reports no monitor until
        // Hyprland reassigns it, and belongs to no surface until then.
        var monitor = workspace.monitor
        if (!monitor || String(monitor.name || "") !== mine) continue
      }

      ids.push(id)
    }

    ids.sort(function(left, right) { return left - right })
    return ids
  }

  function workspaceById(id) {
    var values = Hyprland.workspaces.values
    for (var i = 0; i < values.length; i++) {
      if (values[i].id === id) return values[i]
    }

    return null
  }

  function focusWorkspace(id) {
    if (!root.bar) return
    root.bar.run("hyprctl dispatch " + Util.shellQuote("hl.dsp.focus({ workspace = \"" + id + "\" })"))
  }

  readonly property real trailingGap: root.vertical ? 0 : Style.spaceReal(1.5)

  // No workspaces on this screen means no slot: the trailing gap would
  // otherwise be a 2px sliver that is also a 2px drag handle.
  implicitWidth: root.workspaceIds.length > 0 ? grid.implicitWidth + trailingGap : 0
  implicitHeight: grid.implicitHeight

  GridLayout {
    id: grid
    anchors.fill: parent
    anchors.rightMargin: root.trailingGap
    columns: root.vertical ? 1 : Math.max(1, root.workspaceIds.length)
    columnSpacing: root.vertical ? 0 : Style.space(1)
    rowSpacing: root.vertical ? Style.space(2) : 0

    Repeater {
      model: root.workspaceIds

      WidgetButton {
        required property int modelData

        readonly property var workspace: root.workspaceById(modelData)
        readonly property bool occupied: workspace !== null && workspace.toplevels.values.length > 0
        // workspace.active is active-on-its-own-monitor; the global
        // Hyprland.focusedWorkspace lit the same number on every bar.
        readonly property bool focused: workspace !== null && workspace.active

        bar: root.bar
        text: focused ? "\uDB85\uDCFB" : (modelData === 10 ? "0" : String(modelData))
        opacity: occupied || focused ? 1 : 0.5
        horizontalMargin: 6
        verticalPadding: 6
        fixedWidth: root.vertical ? root.barSize : Style.space(20)
        fixedHeight: root.barSize
        onPressed: function() { root.focusWorkspace(modelData) }
      }
    }
  }
}
