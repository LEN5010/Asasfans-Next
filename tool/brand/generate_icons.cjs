#!/usr/bin/env node
// Deterministic platform assets from the original A path. Generated with sharp 0.35.4 / libvips 8.18.6.
// No network, package installation, screenshot tracing or platform signing.
const fs = require('node:fs');
const path = require('node:path');
const sharp = require('sharp');
const root = path.resolve(__dirname, '../..');
const read = p => fs.readFileSync(path.join(root, p), 'utf8');
const write = (p, data) => {
  const dest = path.join(root, p);
  fs.mkdirSync(path.dirname(dest), {recursive: true});
  fs.writeFileSync(dest, data);
};
const original = read('assets/brand/asasfans_logo.svg');
const defs = original.match(/<defs>[\s\S]*?<\/defs>/)[0];
const shape = original.match(/<path\s[^>]*\/>/)[0];
const pathData = shape.match(/ d="([^"]+)"/)[1];
const svg = (scale, plate = '') => `<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024">\n${defs}\n${plate}\n<g transform="translate(512,512) scale(${scale}) translate(-772,-757)">${shape}</g>\n</svg>\n`;
const white = '<rect width="1024" height="1024" fill="#FFFFFF"/>';
const mark = svg(.48);
const ios = svg(.46, white);
const mac = svg(.40, '<rect x="102" y="102" width="820" height="820" rx="184" fill="#FAFAFC"/>');
const windows = svg(.55);
const android = svg(.30);
async function png(source, size) {
  // Supersampling also retains smooth diagonals in the 16/24px sizes.
  return sharp(Buffer.from(source), {density: 288})
    .resize(size, size, {kernel: 'lanczos3'}).png({compressionLevel: 9}).toBuffer();
}
async function main() {
  write('assets/brand/asasfans_mark.svg', mark);
  write('assets/brand/asasfans_icon_ios.svg', ios);
  write('assets/brand/asasfans_icon_macos.svg', mac);
  write('assets/brand/asasfans_icon_windows.svg', windows);
  write('assets/brand/asasfans_icon_android_foreground.svg', android);
  write('assets/brand/asasfans_mark.png', await png(mark, 512));
  const images = JSON.parse(read('ios/Runner/Assets.xcassets/AppIcon.appiconset/Contents.json')).images;
  for (const image of images) {
    const size = Math.round(parseFloat(image.size) * parseFloat(image.scale));
    const raster = await sharp(await png(ios, size)).removeAlpha().png().toBuffer();
    write(`ios/Runner/Assets.xcassets/AppIcon.appiconset/${image.filename}`, raster);
  }
  for (const size of [16, 32, 64, 128, 256, 512, 1024]) {
    const raster = await png(mac, size);
    write(`macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_${size}.png`, raster);
    write(`macos/packaging/icon/icon_${size}.png`, raster);
  }
  const sizes = [16, 24, 32, 48, 64, 128, 256];
  const rasters = [];
  for (const size of sizes) rasters.push(await png(windows, size));
  const header = Buffer.alloc(6 + sizes.length * 16);
  header.writeUInt16LE(1, 2); header.writeUInt16LE(sizes.length, 4);
  let offset = header.length;
  sizes.forEach((size, i) => {
    const at = 6 + i * 16;
    header[at] = header[at + 1] = size === 256 ? 0 : size;
    header.writeUInt16LE(1, at + 4); header.writeUInt16LE(32, at + 6);
    header.writeUInt32LE(rasters[i].length, at + 8);
    header.writeUInt32LE(offset, at + 12); offset += rasters[i].length;
  });
  write('windows/runner/resources/app_icon.ico', Buffer.concat([header, ...rasters]));
  for (const [density, factor] of [['mdpi', 1], ['hdpi', 1.5], ['xhdpi', 2], ['xxhdpi', 3], ['xxxhdpi', 4]]) {
    write(`android/app/src/main/res/mipmap-${density}/ic_launcher.png`, await png(ios, 48 * factor));
    write(`android/app/src/main/res/drawable-${density}/ic_launcher_foreground.png`, await png(android, 108 * factor));
  }
  const adaptive = monochrome => `<?xml version="1.0" encoding="utf-8"?>\n<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n  <background android:drawable="@color/ic_launcher_background"/>\n  <foreground android:drawable="@drawable/ic_launcher_foreground"/>\n${monochrome ? '  <monochrome android:drawable="@drawable/ic_launcher_monochrome"/>\n' : ''}</adaptive-icon>\n`;
  write('android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml', adaptive(false));
  write('android/app/src/main/res/mipmap-anydpi-v33/ic_launcher.xml', adaptive(true));
  write('android/app/src/main/res/values/icon_colors.xml', '<?xml version="1.0" encoding="utf-8"?>\n<resources><color name="ic_launcher_background">#FFFFFF</color></resources>\n');
  write('android/app/src/main/res/drawable/ic_launcher_monochrome.xml', `<?xml version="1.0" encoding="utf-8"?>\n<vector xmlns:android="http://schemas.android.com/apk/res/android" android:width="108dp" android:height="108dp" android:viewportWidth="1024" android:viewportHeight="1024">\n  <group android:translateX="512" android:translateY="512"><group android:scaleX="0.30" android:scaleY="0.30"><group android:translateX="-772" android:translateY="-757">\n    <path android:fillColor="#FFFFFFFF" android:pathData="${pathData}"/>\n  </group></group></group>\n</vector>\n`);
  process.stdout.write(`Generated original-path icons with sharp ${sharp.versions.sharp}, libvips ${sharp.versions.vips}\n`);
}
main().catch(error => {console.error(error); process.exitCode = 1;});
