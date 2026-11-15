// ============================================================
//  logdirs.mjs — the per-ROM log folders, as paths.sh names them
//
//  The dashboard tests and replays write under $DMEKLR_TMP/dme_klr/<rom>
//  (dash_logs, v_dash_logs, replay), <rom> from the ROM pair they ran on:
//  89 (the default 1989 pair), 86 (run86.sh), carpokes (run_carpokes.sh),
//  any other pair <DME image>+<KLR image> without the extensions.
//  paths.sh (dmeklr_rom_variant) and dmeklr_paths.py (rom_variant) say the
//  same.
// ============================================================
import { existsSync, readdirSync, statSync } from 'node:fs';
import { join } from 'node:path';

const NAMED = { '89DME_951pin+89KLR_951': '89', '28PIN_86DME+86KLR_951': '86',
                '28PIN_DME_PERFORMANCE+87KLR_951': 'carpokes' };
export const DEFAULT_ROMS = { dme: '89DME_951pin.mem', klr: '89KLR_951.mem' };
const stem = f => String(f).replace(/\\/g, '/').split('/').pop().replace(/\.[^.]*$/, '');

// romVariant(dme, klr): the folder name of that pair (unset = the 1989 images)
export function romVariant(dme, klr) {
  const key = `${stem(dme || DEFAULT_ROMS.dme)}+${stem(klr || DEFAULT_ROMS.klr)}`;
  return NAMED[key] ?? key.replace(/[^A-Za-z0-9_.+-]/g, '_');
}

// logsDir(TMP_ROOT, variant): $DMEKLR_TMP/dme_klr/<variant>
export const logsDir = (TMP_ROOT, variant) => join(TMP_ROOT, 'dme_klr', variant);

// The ROM folders under $DMEKLR_TMP/dme_klr that hold dashboard logs,
// the named three first
export function romVariants(TMP_ROOT) {
  const base = join(TMP_ROOT, 'dme_klr');
  let names = [];
  try {
    names = readdirSync(base).filter(n => {
      if (n === 'replay' || n.startsWith('.')) return false;   // replay/: the replays' folder before the ROM folders
      const d = join(base, n);
      try { return statSync(d).isDirectory() && (existsSync(join(d, 'dash_logs')) || existsSync(join(d, 'v_dash_logs'))); }
      catch { return false; }
    });
  } catch { /* no folder yet */ }
  const order = ['89', '86', 'carpokes'];
  return names.sort((a, b) => ((order.indexOf(a) + 1 || 99) - (order.indexOf(b) + 1 || 99)) || a.localeCompare(b));
}
