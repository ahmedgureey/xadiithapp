import { readFileSync } from 'fs';
import { join } from 'path';

let cached: string | undefined;

/** Reads the version from package.json (cwd first, then relative to dist/). */
export function appVersion(): string {
  if (cached) return cached;
  const candidates = [join(process.cwd(), 'package.json'), join(__dirname, '..', '..', '..', 'package.json')];
  for (const file of candidates) {
    try {
      const pkg = JSON.parse(readFileSync(file, 'utf8')) as { name?: string; version?: string };
      if (pkg.name === 'xadiis-backend' && pkg.version) {
        cached = pkg.version;
        return cached;
      }
    } catch {
      // try next candidate
    }
  }
  cached = process.env.npm_package_version ?? '0.0.0';
  return cached;
}
