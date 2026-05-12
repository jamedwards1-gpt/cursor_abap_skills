---
name: sap-abap-adt-develop
description: >-
  Develops SAP BTP ABAP (steampunk) objects through ADT MCP with read and
  high-level write tools, then refreshes the local mirror. Use for ABAP, RAP,
  CDS, classes, steampunk changes, ADT MCP, or syncing package ZZSD.
---

# SAP ABAP ADT development

## Session

- Auth file: `.secrets/btp-abap.env` (create with `npm run btp:auth -- --key .secrets/service-key.json`).
- MCP server: `abap-adt` in `.cursor/mcp.json` with `--exposition=readonly,high`.
- Reload Cursor after MCP or auth changes.

## Where changes go

- **Steampunk system**: use `abap-adt` MCP for ADT read, create, update, lock, unlock, validate, activate, and transport tools exposed by the server.
- **Workspace mirror**: `btp-content/abap/<PACKAGE>/` is a read-only snapshot until refreshed.
- **Git**: tracks the mirror and tooling only. It is not the ABAP source of truth.

## Develop and push workflow

1. Confirm the target package and object (for example `ZZSD` / `ZCL_QAD_QUERYSHIPMENT_SVC`).
2. Use MCP to read the live object before editing when the mirror may be stale.
3. Lock, change, check, activate, and unlock through ADT MCP on the system.
4. Refresh the mirror: `npm run btp:sync-package -- <PACKAGE>`.
5. Commit mirror updates only when the user asks.

## Safety

- Do not commit `.secrets/`, service keys, or `.env` files with tokens.
- Do not enable `low` exposition unless the user explicitly requests it.
- Prefer small, reviewable ADT changes over bulk rewrites.
