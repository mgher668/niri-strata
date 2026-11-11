import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdtemp, mkdir, writeFile, readFile } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { syncMode } from '../scripts/theme-mode-sync.mjs';

test('switches installed adw GTK theme and preferences in both directions without touching other settings', async () => {
  const dir = await mkdtemp(join(tmpdir(), 'strata-theme-'));
  for (const version of ['gtk-3.0', 'gtk-4.0']) {
    await mkdir(join(dir, version));
    await writeFile(join(dir, version, 'settings.ini'), '[Settings]\ngtk-theme-name=adw-gtk3\ngtk-icon-theme-name=origin\ngtk-application-prefer-dark-theme=0\n');
  }
  const calls = [];
  const settings = { get: () => 'adw-gtk3', set: (key, value) => calls.push([key, value]) };
  await syncMode({ isLight: false, configDir: dir, settings, hasTheme: () => true });
  assert.deepEqual(calls, [['color-scheme', 'prefer-dark'], ['gtk-theme', 'adw-gtk3-dark']]);
  for (const version of ['gtk-3.0', 'gtk-4.0']) {
    const data = await readFile(join(dir, version, 'settings.ini'), 'utf8');
    assert.match(data, /gtk-theme-name=adw-gtk3-dark/);
    assert.match(data, /gtk-application-prefer-dark-theme=1/);
    assert.match(data, /gtk-icon-theme-name=origin/);
  }
  calls.length = 0;
  settings.get = () => 'adw-gtk3-dark';
  await syncMode({ isLight: true, configDir: dir, settings, hasTheme: () => true });
  assert.deepEqual(calls, [['color-scheme', 'prefer-light'], ['gtk-theme', 'adw-gtk3']]);
  assert.match(await readFile(join(dir, 'gtk-3.0', 'settings.ini'), 'utf8'), /gtk-application-prefer-dark-theme=0/);
});

test('does not replace an unrelated GTK theme', async () => {
  const dir = await mkdtemp(join(tmpdir(), 'strata-theme-'));
  const calls = [];
  await syncMode({ isLight: false, configDir: dir, settings: { get: () => 'Arc', set: (...args) => calls.push(args) }, hasTheme: () => true });
  assert.deepEqual(calls, [['color-scheme', 'prefer-dark']]);
});
