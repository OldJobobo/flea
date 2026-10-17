.pragma library

// Original, deliberately open silhouettes. No third-party logos or imported artwork.
var paths = {
    home: "M23 39l9-8 9 8M26 38v9h12v-9M30 47v-7h4v7",
    documents: "M27 31h8l4 4v14H27zM35 31v5h4M30 40h6m-6 4h6",
    downloads: "M32 31v13m-6-6 6 6 6-6M24 46v3h16v-3",
    pictures: "M23 33h18v15H23zM24 45l6-6 5 5 3-3 3 3M36 37h.1",
    music: "M29 44V33l10-2v11M29 35l10-2M29 44c0 5-8 5-8 1 0-3 6-4 8-1M39 42c0 5-8 5-8 1 0-3 6-4 8-1",
    videos: "M27 32v16l14-8z",
    public: "M22 40h20M32 30c-9 0-9 20 0 20s9-20 0-20zM32 30c-3 4-3 16 0 20m0-20c3 4 3 16 0 20",
    templates: "M24 32h16v17H24zM24 37h16M30 37v12",
    desktop: "M22 32h20v14H22zM32 46v4m-6 0h12",
    code: "M27 34l-6 6 6 6m10-12 6 6-6 6m-3-14-4 16",
    terminal: "M23 34l6 6-6 6m10 0h8",
    editor: "M24 45l-1 5 5-1 14-14-4-4zM35 34l4 4",
    files: "M23 35h7l2 3h10v12H23zM26 31h7l2 3h7v4",
    image: "M22 33h20v17H22zM23 47l6-6 5 5 4-4 4 5M36 38h.1",
    audio: "M26 40v6m4-12v18m4-14v10m4-6v2",
    video: "M27 33v18l14-9z",
    archive: "M22 34h20v16H22zM21 30h22v5H21zM29 39h6v4h-6z",
    document: "M25 35h14m-14 5h14m-14 5h9",
    spreadsheet: "M23 32h18v18H23zM23 38h18m-18 6h18M29 32v18m6-18v18",
    presentation: "M22 32h20v15H22zM32 47v5m-6 0 6-5 6 5M28 43v-4m4 4v-7m4 7v-9",
    font: "M23 48l9-17 9 17m-14-6h10",
    executable: "M30 31l-6 11h8l-2 9 11-14h-9l3-6"
}
var folders = { "Home": "home", "Documents": "documents", "Downloads": "downloads",
    "Pictures": "pictures", "Music": "music", "Videos": "videos", "Public": "public",
    "Templates": "templates", "Desktop": "desktop" }
var names = {
    "folder": ["folder", ""], "user-home": ["folder", "home"],
    "user-desktop": ["folder", "desktop"], "folder-open": ["folder", ""],
    "folder-documents": ["folder", "documents"], "folder-download": ["folder", "downloads"],
    "folder-downloads": ["folder", "downloads"], "folder-pictures": ["folder", "pictures"],
    "folder-music": ["folder", "music"], "folder-videos": ["folder", "videos"],
    "folder-publicshare": ["folder", "public"], "folder-templates": ["folder", "templates"],
    "text-x-generic": ["document", "document"], "application-x-generic": ["document", "document"],
    "image-x-generic": ["image", "image"], "audio-x-generic": ["audio", "audio"],
    "video-x-generic": ["video", "video"], "package-x-generic": ["archive", "archive"],
    "application-x-archive": ["archive", "archive"], "application-pdf": ["document", "documents"],
    "text-x-script": ["code", "code"], "text-x-source": ["code", "code"],
    "x-office-document": ["document", "document"], "x-office-spreadsheet": ["code", "spreadsheet"],
    "x-office-presentation": ["archive", "presentation"], "font-x-generic": ["document", "font"],
    "application-x-executable": ["app", "executable"],
    "utilities-terminal": ["app", "terminal"], "accessories-text-editor": ["app", "editor"],
    "system-file-manager": ["app", "files"]
}
function resolve(row) {
    if (!row) return null
    var name = row.i || (row.d ? "folder" : "text-x-generic")
    if (typeof name !== "string" || !Object.prototype.hasOwnProperty.call(names, name)) return null
    var match = names[name]
    // Conventional display names get emblems without reading directories or desktop files.
    var mark = name === "folder" && Object.prototype.hasOwnProperty.call(folders, row.n) ? folders[row.n] : match[1]
    return { kind: match[0], mark: mark, key: match[0] + ":" + mark }
}
