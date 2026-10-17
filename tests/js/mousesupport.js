.import "../../ui/js/MouseHints.js" as Hints
.import "../../ui/js/TabMenu.js" as TabMenu
.import "../../ui/js/Tabs.js" as Tabs
.import "tabsfixture.js" as Fixture

function run(check) {
    check("tooltip fits right edge", Hints.position(98, 20, 40, 10, 100, 100, 12).x, 60)
    check("tooltip flips above bottom edge", Hints.position(20, 95, 40, 10, 100, 100, 12).y, 73)
    check("label without a key stays plain", Hints.text("Close", ""), "Close")
    check("shortcut follows label", Hints.text("Back", "Alt+Left"), "Back  ·  Alt+Left")
    function item(changes) {
        var result = { width: 100, height: 100, z: 0, children: [],
            mapFromItem: function(parent, x, y) { return { x: x, y: y } } }
        for (var key in changes) result[key] = changes[key]
        return result
    }
    var leaf = item({ mouseHint: "Filename" })
    var surface = item({ children: [leaf] })
    check("deepest hint wins", Hints.at(surface, 1, 1), leaf)
    var overlay = item({ z: 5 })
    surface.children = [leaf, overlay]
    check("inert full-window overlay passes through", Hints.at(surface, 1, 1), leaf)
    overlay.acceptedButtons = Qt.LeftButton
    overlay.hoverEnabled = false
    check("interactive overlay blocks an underlying hint", Hints.at(surface, 1, 1), null)
    overlay.visible = false
    check("hidden scrim does not block hints", Hints.at(surface, 1, 1), leaf)
    overlay.visible = true
    overlay.enabled = false
    check("disabled scrim does not block hints", Hints.at(surface, 1, 1), leaf)
    overlay.enabled = true
    overlay.z = -1
    check("lower scrim does not cover higher hint", Hints.at(surface, 1, 1), leaf)
    check("outside item is not a target", Hints.at(surface, 150, 1), null)

    var p = Fixture.pane("/work")
    Tabs.openNew(p, "/other")
    var context = TabMenu.capture(p, 0)
    check("tab context captures the clicked path", context.path, "/work")
    check("tab menu has new, duplicate and close actions", TabMenu.entries(context).filter(function(e) { return !e.separator }).map(function(e) { return e.action }).join(","), "tabNew,tabDuplicate,tabClose")
    Tabs.move(p, 0, 1)
    check("menu follows reordered tab identity", TabMenu.indexOf(context), 1)
    check("duplicate runs through tab command", TabMenu.choose(context, "tabDuplicate"), true)
    check("duplicate opens clicked path, not current path", p.path, "/work")
    check("duplicate adds one tab", Tabs.count(p), 3)
    check("close runs through tab command", TabMenu.choose(context, "tabClose"), true)
    check("close removes captured identity", TabMenu.indexOf(context), -1)
    check("closed tab cannot close its replacement", TabMenu.choose(context, "tabClose"), false)
    var moved = TabMenu.capture(p, p.tabs.index)
    p.path = "/changed"
    check("navigated tab invalidates menu", TabMenu.indexOf(moved), -1)
    check("invalidated tab rows are disabled", TabMenu.entries(moved).filter(function(e) { return !e.separator && !e.disabled }).length, 0)
}
