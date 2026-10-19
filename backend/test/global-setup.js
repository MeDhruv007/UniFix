// Runs once in the main vitest process, so this notice is always visible.
export default function globalSetup() {
  if (!process.env.DATABASE_URL) {
    process.stderr.write(
      '\n[fixmycampus] DATABASE_URL is not set: integration tests are SKIPPED; only unit tests run.\n' +
        '  Start the test DB:  docker compose -f docker-compose.test.yml up -d db-test\n' +
        '  Then run:           DATABASE_URL=postgres://fixmycampus:fixmycampus@localhost:5433/fixmycampus_test npm test\n\n',
    );
  }
}
