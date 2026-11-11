#!/usr/bin/env node
// Synchronize the system color preference and an existing adw-gtk3 theme pair.
import { readFile, writeFile } from 'node:fs/promises';
import { existsSync } from 'node:fs';
import { join, resolve } from 'node:path';
import { homedir } from 'node:os';
import { execFileSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

export async function syncMode({ isLight, configDir, settings, hasTheme }) {
  const selected = settings.get('gtk-theme');
  const target = isLight ? 'adw-gtk3' : 'adw-gtk3-dark';
  const isAdw = selected === 'adw-gtk3' || selected === 'adw-gtk3-dark';
  const switchTheme = isAdw && hasTheme(target);
  // Update explicit GTK settings before publishing the new preference.
  if (switchTheme) {
    for (const version of ['gtk-3.0', 'gtk-4.0']) {
      const path = join(configDir, version, 'settings.ini');
      let content;
      try { content = await readFile(path, 'utf8'); } catch (error) {
        if (error.code === 'ENOENT') continue;
        throw error;
      }
      // Do not overwrite independent per-toolkit themes.
      if (!/^gtk-theme-name[ \t]*=[ \t]*adw-gtk3(?:-dark)?[ \t\r]*$/m.test(content)) continue;
      content = content.replace(/^(gtk-theme-name[ \t]*=[ \t]*)adw-gtk3(?:-dark)?[ \t\r]*$/m, `$1${target}`)
        .replace(/^(gtk-application-prefer-dark-theme[ \t]*=[ \t]*)[01][ \t\r]*$/m, `$1${isLight ? '0' : '1'}`);
      await writeFile(path, content);
    }
  }
  settings.set('color-scheme', isLight ? 'prefer-light' : 'prefer-dark');
  if (switchTheme) settings.set('gtk-theme', target);
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const mode = process.argv[2];
  if (!['light', 'dark'].includes(mode)) throw new Error('Expected light or dark');
  const configDir = process.env.XDG_CONFIG_HOME || join(homedir(), '.config');
  const schema = 'org.gnome.desktop.interface';
  const settings = {
    get: key => execFileSync('gsettings', ['get', schema, key], { encoding: 'utf8' }).trim().replace(/^'|'$/g, ''),
    set: (key, value) => execFileSync('gsettings', ['set', schema, key, value], { stdio: 'inherit' }),
  };
  const roots = [join(process.env.XDG_DATA_HOME || join(homedir(), '.local/share'), 'themes'), join(homedir(), '.themes'), ...((process.env.XDG_DATA_DIRS || '/usr/local/share:/usr/share').split(':').map(dir => join(dir, 'themes')))];
  await syncMode({ isLight: mode === 'light', configDir, settings, hasTheme: name => roots.some(root => existsSync(join(root, name, 'gtk-3.0', 'gtk.css'))) });
}
