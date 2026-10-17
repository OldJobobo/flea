#!/usr/bin/env node
// Render the shipped QML-JS recipes, not a second implementation. No packages required.
import fs from 'node:fs';
import path from 'node:path';
import vm from 'node:vm';
import { fileURLToPath } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const loaded = new Map();
function load(file) {
    if (loaded.has(file)) return loaded.get(file);
    const code = fs.readFileSync(file, 'utf8');
    const globals = {};
    for (const match of code.matchAll(/^\.import "([^"]+)" as (\w+)$/gm)) {
        globals[match[2]] = load(path.resolve(path.dirname(file), match[1]));
    }
    const context = vm.createContext(globals);
    vm.runInContext(code.replace(/^\.(pragma|import).*$/gm, ''), context, { filename: file });
    loaded.set(file, context);
    return context;
}
const colors = load(path.join(root, 'ui/js/IconColors.js'));
const marks = load(path.join(root, 'ui/js/AdaptiveMarks.js'));
const artwork = load(path.join(root, 'ui/js/AdaptiveArtwork.js'));
const fixtures = load(path.join(root, 'tests/js/iconpalettes.js'));
const icons = [
    ['Folder', 'folder'], ['Home', 'user-home'], ['Documents', 'folder-documents'],
    ['Downloads', 'folder-download'], ['Pictures', 'folder-pictures'], ['Music', 'folder-music'],
    ['Videos', 'folder-videos'], ['Text', 'text-x-generic'], ['Image', 'image-x-generic'],
    ['Audio', 'audio-x-generic'], ['Archive', 'package-x-generic'], ['Code', 'text-x-script'],
    ['Terminal', 'utilities-terminal'], ['Editor', 'accessories-text-editor'], ['Files', 'system-file-manager']
];
const width = 1390, height = 112 + fixtures.palettes.length * 190;
const out = [`<svg xmlns="http://www.w3.org/2000/svg" width="${width}" height="${height}" viewBox="0 0 ${width} ${height}">`,
    '<rect width="100%" height="100%" fill="#171b22"/>'];
function text(x, y, label, color, size = 12) {
    out.push(`<text x="${x}" y="${y}" fill="${color}" font-size="${size}" font-family="DejaVu Sans, sans-serif">${label}</text>`);
}
text(26, 37, 'Adaptive icons', '#e1e6ee', 26);
text(26, 65, 'One set of artwork. Theme-derived materials. Original, small and selected states.', '#b8c4d6', 13);
text(26, 88, 'Folders / files / generic apps — brand-specific artwork falls back unchanged.', '#b8c4d6', 11);
let serial = 0;
function draw(name, palette, x, y, size) {
    const id = `face-${serial++}`;
    const body = artwork.svg(marks.resolve({ i: name }), palette, size <= 24)
        .replace(/^<svg[^>]*>/, '').replace(/<\/svg>$/, '')
        .replaceAll('id="face"', `id="${id}"`).replaceAll('url(#face)', `url(#${id})`);
    out.push(`<g transform="translate(${x} ${y}) scale(${size / 64})">${body}</g>`);
}
fixtures.palettes.forEach((input, row) => {
    const y = 112 + row * 190;
    const palette = colors.derive(input, input.background, input.foreground, input.accent);
    out.push(`<rect y="${y}" width="${width}" height="190" fill="${input.background}"/>`);
    text(26, y + 41, input.name, input.foreground, 20);
    text(26, y + 65, input.accent, input.foreground, 11);
    text(26, y + 116, '64 px', input.foreground, 11);
    text(26, y + 145, '20 px / selected', input.foreground, 11);
    icons.forEach(([label, name], col) => {
        const x = 190 + col * 79;
        draw(name, palette, x, y + 21, 64);
        text(x + 1, y + 106, label, input.foreground, 10);
        draw(name, palette, x + 8, y + 126, 20);
        out.push(`<rect x="${x + 33}" y="${y + 121}" width="30" height="30" rx="5" fill="${input.selection}"/>`);
        draw(name, palette, x + 38, y + 126, 20);
    });
});
out.push('</svg>');
const destination = path.resolve(process.argv[2] || path.join(root, 'target/adaptive-icons/proof.svg'));
fs.mkdirSync(path.dirname(destination), { recursive: true });
fs.writeFileSync(destination, out.join('\n') + '\n');
console.log(`Adaptive icon proof: ${destination}`);
