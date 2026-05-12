# SAP BTP ABAP sandbox (steampunk)

Local tooling, ADT MCP, and a small **parcel monitor** UI that talks to your BTP ABAP environment over ADT using a JWT stored in a gitignored secrets file.

## Prerequisites

- **Node.js** 22+ and npm 9+ (required by `@mcp-abap-adt/core`).
- **Cursor** or VS Code.
- Access to a **SAP BTP** subaccount with an **ABAP environment** instance.

## 1. Get the ABAP service key (not the “token” yet)

The JWT is obtained *after* you have a **service key JSON** for the ABAP API (OAuth client credentials).

1. In **SAP BTP Cockpit**, open your subaccount.
2. Go to **Instances and Subscriptions**.
3. Open your **ABAP environment** service instance (the one that backs ADT / development).
4. Open the **Service Keys** tab and **Create** a new key (or use an existing one).  
   The downloaded file is a single JSON object with fields such as `url`, `clientid`, `clientsecret`, `certificate`, etc.

Keep this file **private**. It is equivalent to a password for API access.

## 2. Put secrets on disk (never commit them)

From the repository root:

```bash
mkdir -p .secrets
```

Copy your downloaded key into the repo **only inside** `.secrets/` (this path is gitignored), for example:

```text
.secrets/service-key.json
```

Create the **auth env file** used by MCP, scripts, and the parcel monitor:

```bash
npm install
npm run btp:auth -- --key .secrets/service-key.json -o .secrets/btp-abap.env
```

What this does:

- Opens a browser (or prints a URL) for SAP login / consent.
- Writes **`.secrets/btp-abap.env`** with a short-lived **JWT** and connection details (for example `SAP_URL`, token fields—exact names depend on the auth store version).

Re-run the same command when the token expires. Use `--force` if you need a fresh login while an old token is still present:

```bash
npm run btp:auth -- --key .secrets/service-key.json -o .secrets/btp-abap.env --force
```

Optional: use `--browser none` if you prefer to copy the URL manually.

## 3. Environment variables for transports and scripts

Several scripts default transports in `parcel-monitor/src/config.js`. Override with env vars when yours differ:

| Variable | Purpose |
|----------|---------|
| `BTP_ADT_TRANSPORT` | Transport request (e.g. `H01K900032`) |
| `BTP_ADT_TASK` | Transport task |
| `BTP_ADT_TRANSPORT_OWNER` | **ABAP user** that owns the transport (e.g. `CB9980000010`), **not** your BTP email |
| `BTP_ADT_PACKAGE` | Package name (default `ZPARCEL` for parcel tooling) |
| `BTP_ADT_ENV` | Optional path to env file (default: `.secrets/btp-abap.env` from repo root) |

You can export these in your shell or add them to a **local** file you source; do **not** commit real transport numbers if they are sensitive.

## 4. Cursor: MCP (ABAP ADT)

This repo includes **`.cursor/mcp.json`**, which starts the ABAP ADT MCP with:

```text
--env-path .secrets/btp-abap.env
--exposition=readonly,high
```

After `btp:auth` succeeds:

1. Confirm **`.secrets/btp-abap.env`** exists next to the workspace root you opened in Cursor.
2. **Reload** the Cursor window (MCP servers read env at startup).

If MCP fails to connect, re-run `btp:auth` and reload again.

## 5. Sync the local ABAP mirror

```bash
npm run btp:sync-package -- ZPARCEL
# or another package, e.g. ZZSD
```

Other useful scripts: `btp:push-class`, `btp:push-table`, `btp:push-ddls`, `btp:push-parcel`, `parcel:monitor` (see `package.json`).

## 6. Parcel monitor (local UI)

```bash
npm run parcel:monitor
```

Then open **http://127.0.0.1:4010** (defaults; override with `PARCEL_MONITOR_HOST` / `PARCEL_MONITOR_PORT`).

## ABAP syntax highlighting in Cursor

Yes, this repo includes workspace settings for colouring **ABAP** and **CDS** mirror files:

- **`.vscode/extensions.json`** recommends:
  - **ABAP:** [vscode-abap](https://marketplace.visualstudio.com/items?itemName=larshp.vscode-abap) (`larshp.vscode-abap`)
  - **CDS:** [CDS](https://marketplace.visualstudio.com/items?itemName=hudakf.cds) (`hudakf.cds`)
- **`.vscode/settings.json`** maps mirror suffixes (`.clas.abap`, `.tabl.abap`, `.asddls`, `.asbdef`, etc.) to the `abap` / `abap_cds` languages.

When you open the folder, Cursor should prompt to **install recommended extensions**. If not: Command Palette → “Extensions: Show Recommended Extensions”.

If a file is still plain text, check that the extension is installed and that the file extension matches one of the patterns in `.vscode/settings.json`.

## Security checklist

- Never commit **`.secrets/`**, service keys, or env files containing JWTs.
- Treat **GitHub** and backups like production secrets if keys were ever committed by mistake.

## Further reading

- Agent skill: `.cursor/skills/sap-abap-adt-develop/SKILL.md` (ADT MCP workflow and mirror rules).
