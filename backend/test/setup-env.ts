/**
 * e2e environment. The e2e suite TRUNCATES user and hadith tables, so it refuses
 * to run unless DATABASE_URL points at a database whose name contains "test"
 * (override with E2E_ALLOW_ANY_DB=true only if you are sure).
 */
const url = process.env.DATABASE_URL;
if (!url) {
  throw new Error(
    'DATABASE_URL must be set for e2e tests, e.g. postgresql://postgres:postgres@127.0.0.1:55432/xadiis_test',
  );
}
const dbName = (() => {
  try {
    return new URL(url).pathname.replace(/^\//, '');
  } catch {
    return '';
  }
})();
if (!/test/i.test(dbName) && process.env.E2E_ALLOW_ANY_DB !== 'true') {
  throw new Error(`Refusing to run destructive e2e tests against database "${dbName}" (name must contain "test")`);
}

process.env.NODE_ENV = 'test';
process.env.JWT_ACCESS_SECRET ??= 'e2e-only-secret-e2e-only-secret-e2e-only-secret';
process.env.JWT_ACCESS_TTL ??= '900';
process.env.JWT_REFRESH_TTL_DAYS ??= '30';
process.env.THROTTLE_LIMIT ??= '100000';
process.env.AUTH_THROTTLE_LIMIT ??= '100000';
process.env.CORS_ORIGINS ??= '';
