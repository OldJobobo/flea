.import "../../ui/js/FileIcons.js" as FileIcons
.import "../../ui/js/Settings.js" as Settings

function run(check) {
    check("default keeps interface marks", FileIcons.selection(undefined), "builtin")
    check("system is opt in", FileIcons.selection("system"), "system")
    check("adaptive is opt in", FileIcons.selection("adaptive"), "adaptive")
    check("installed names may contain spaces", FileIcons.selection("theme:My Icons"), "theme:My Icons")
    for (var i = 0, bad = ["theme:", "theme:../escape", "theme:/absolute", "theme:a\\b", "theme:a\nb", "theme:..", "unknown", false]; i < bad.length; i++)
        check("bad selection " + i, FileIcons.selection(bad[i]), "builtin")
    check("no unloaded row work", FileIcons.request(null, 24), null)
    check("directory uses folder", FileIcons.request({d:true}, 24).name, "folder")
    check("file uses FDO generic", FileIcons.request({}, 24).name, "text-x-generic")
    check("MIME mark remains a MIME name", FileIcons.request({i:"image-x-generic"}, 24).name, "image-x-generic")
    check("oversized grid request is bounded", FileIcons.request({}, 1000).size, 512)
    check("path is never an icon name", FileIcons.request({i:"../outside"},24), null)
    var choices = FileIcons.choices([{id:"theme:Papirus",label:"Papirus"}], "theme:Removed")
    check("separate choices and a missing selection", choices.ids.join(","), "builtin,adaptive,system,theme:Papirus,theme:Removed")
    check("missing selection is preserved", choices.selected, "theme:Removed")
    var rows = Settings.rows("display", {data:{display:{iconSet:"feather",fileIconTheme:"theme:Papirus"}},fileIconThemes:[{id:"theme:Papirus",label:"Papirus"}]})
    var interfaceRow = rows.filter(function(row) { return row.id === "display.iconSet" })[0]
    var fileRow = rows.filter(function(row) { return row.id === "display.fileIconTheme" })[0]
    check("interface selector keeps its own value", interfaceRow.selected, "feather")
    check("file selector keeps its own value", fileRow.selected, "theme:Papirus")
    check("file row is distinct from interface row", fileRow.label, "File and folder icons")
    check("installed choice is exposed", fileRow.values.join(","), "builtin,adaptive,system,theme:Papirus")
}
