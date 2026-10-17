.import "../../ui/js/SemanticColors.js" as Semantic
.import "sourcefixture.js" as Source

function run(check) {
    function role(patch) {
        return Semantic.noticeRole(Object.assign({transient: "", transientIsError: false,
            armLive: false, stickyHere: false, searching: false, noticeKind: ""}, patch))
    }
    check("untyped non-error is not success", role({transient: "Copied successfully"}), "foreground")
    check("typed completion is success", role({transient: "Done", noticeKind: "success"}), "success")
    check("unknown kinds are neutral", role({transient: "Done", noticeKind: "whatever"}), "foreground")
    check("an error outranks a typed completion", role({transient: "Failure", transientIsError: true, noticeKind: "success"}), "error")
    check("an armed action is caution", role({transient: "Press again", armLive: true}), "warning")
    check("activity supersedes a stored success", role({transient: "Done", noticeKind: "success", stickyHere: true}), "info")
    check("search supersedes a stored warning", role({transient: "Partial", noticeKind: "warning", searching: true}), "info")
    check("empty notices cannot leak old state", role({noticeKind: "success"}), "foreground")
    var receive = new Function("pane", "root", "Ops", "Search", "id", "ok", "failed", "skipped", "cancelled", "retryPaths", "durable", "note", "merged", "keptBoth", "into",
        Source.block(Source.source("ui/PaneWire.qml"), "function onTransferDone(id, ok, failed, skipped, cancelled, retryPaths, durable, note, merged, keptBoth, into)", "ui/PaneWire.qml"))
    var cases = [
        [1, 0, 0, false, "", "success"], [1, 1, 0, false, "", "warning"],
        [0, 0, 0, true, "", "info"], [1, 0, 0, true, "", "info"],
        [0, 0, 0, false, "", "info"], [1, 0, 1, false, "", "warning"],
        [1, 0, 0, false, "remote upload pending", "warning"]
    ]
    for (var i = 0; i < cases.length; i++) {
        var sample = cases[i], kind = "", messages = []
        var p = {transfer: {id: 12, failureReported: false}, path: "/files", searchMode: "",
            sticky: function () {}, refresh: function () {},
            message: function (text, error) { messages.push(error) },
            statusBar: { classifyNotice: function (text, k) { kind = k } }}
        receive(p, {flushItems: function () {}}, {emptyTransfer: function () { return {} }, transferDone: function () { return "Done" }},
            {RESULTS: "search"}, 12, sample[0], sample[1], sample[2], sample[3], [], false, sample[4], 0, 0, "")
        check("actual transfer producer kind " + i, kind, sample[5])
        check("actual transfer error route preserved " + i, messages[0], sample[1] > 0)
    }
}
