import { copyFileSync, existsSync, mkdirSync } from 'node:fs';
const resources = new URL('../apps/ios/Empezar/Resources/', import.meta.url);
mkdirSync(resources, { recursive: true });
for (const file of ['catalog.json', 'lessons.json']) copyFileSync(new URL(`../packages/contracts/${file}`, import.meta.url), new URL(file, resources));
const config = new URL('Config.plist', resources);
if (!existsSync(config)) copyFileSync(new URL('../apps/ios/Config.example.plist', import.meta.url), config);
console.log('iOS resources ready. Run: cd apps/ios && xcodegen generate');
