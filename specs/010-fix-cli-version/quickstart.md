# Quickstart: Testing `--version`

After implementing the change:

1. Build the CLI:
   ```bash
   tuist build
   ```

2. Run the binary directly to check the version:
   ```bash
   ./Derived/Build/Products/Debug/idocs --version
   ```
   *Expected output: the version from `npm/package.json` for local builds, or `idocs.version` for release bundles.*

3. Verify help output includes version flag:
   ```bash
   ./Derived/Build/Products/Debug/idocs --help
   ```
   *Expected output: Should include `-v, --version Show the version.` in the OPTIONS section.*

4. Run the deterministic E2E gate:
   ```bash
   IDOCS_NPM_STRICT_INSTALL=1 ./scripts/e2e-cli.sh offline
   ```
   *Expected output: `idocs --version` matches `npm/package.json` in both link and pack flows.*
