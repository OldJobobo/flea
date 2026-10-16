.import "../../ui/js/MouseHints.js" as Hints
.import "../../ui/js/TabMenu.js" as TabMenu
.import "../../ui/js/Tabs.js" as Tabs
.import "tabsfixture.js" as Fixture

function run(check) {
    check("tooltip fits right edge", Hints.position(98, 20, 40, 10, 100, 100, 12).x, 60)
    check("tooltip flips above bottom edge", Hints.position(20, 95, 40, 10, 100, 100, 12).y, 73)
    check("label without a key stays plain", Hints.text("Close", ""), "Close")
    check("shortcut follows label", Hints.text("Back", "Alt+Left"), "Back  ·  Alt+Left")
    var leaf = { mouseHint: "Filename", childAt: function() { return null } }
    var surface = { childAt: function() { return leaf } }
    leaf.mapFromItem = function() { return { x: 0, y: 0 } }
    check("deepest hint wins", Hints.at(surface, 1, 1), leaf)
    surface.childAt = function() { return { childAt: function() { return null }, mapFromItem: leaf.mapFromItem } }
    check("overlay blocks an underlying hint", Hints.at(surface, 1, 1), null)

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
