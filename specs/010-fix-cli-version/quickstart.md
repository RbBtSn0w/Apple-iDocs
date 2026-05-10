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
   *Expected output: `1.3.1`*

3. Verify help output includes version flag:
   ```bash
   ./Derived/Build/Products/Debug/idocs --help
   ```
   *Expected output: Should include `-v, --version Show the version.` in the OPTIONS section.*
