# Tasks: npm Distribution for iDocs CLI

## Phase 1 - Distribution Shell

- [x] T001 Add npm package wrapper with `idocs` bin entrypoint in `npm/package.json`
- [x] T002 Add launcher script that dispatches to packaged binary in `npm/bin/idocs.js`
- [x] T003 Add postinstall binary download script in `npm/scripts/postinstall.mjs`

## Phase 2 - Local Registration

- [x] T004 Add local binary linking helper in `npm/scripts/link-local.mjs`
- [x] T005 Add npm wrapper docs for install/link modes in `npm/README.md`

## Phase 3 - Release Packaging

- [x] T006 Add release artifact packaging script in `scripts/release-package.sh`
- [x] T007 Define release asset and installer contract in `specs/007-npm-cli-distribution/contracts/npm-interface.md`

## Phase 4 - Validation

- [x] T008 Run local `npm link` validation for `idocs --help`
- [x] T009 Run `npm pack` + local install smoke test
- [x] T010 Add unified E2E CLI validation script in `scripts/e2e-cli.sh`
- [x] T011 Define E2E contract and structured assertion criteria in `specs/007-npm-cli-distribution/contracts/e2e-interface.md`
