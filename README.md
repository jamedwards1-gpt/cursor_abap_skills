# SAP BTP ABAP sandbox (steampunk)

Local **Node.js tooling**, **ADT MCP**, **transport-ui** (CTS / push helpers), and a tiny **sample ABAP class** in `ZPARCEL` (`ZCL_TRANSPORT_UI_STATIC_JSON`) for HTTP smoke tests. Your own application ABAP can live in other packages or repos; sync them with `npm run btp:sync-package -- <PACKAGE>`.

Auth uses a JWT stored in a **gitignored** `.secrets/btp-abap.env` file (see below).

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

Create the **auth env file** used by MCP, scripts, and transport-ui:

```bash
npm install
npm run btp:auth
```

(`btp:auth` passes `-k .secrets/service-key.json` by default in `package.json`.)

What this does:

- Opens a browser (or prints a URL) for SAP login / consent.
- Writes **`.secrets/btp-abap.env`** with a short-lived **JWT** and connection details (for example `SAP_URL`, token fields—exact names depend on the auth store version).

Re-run the same command when the token expires. Use `--force` if you need a fresh login while an old token is still present:

```bash
npm run btp:auth -- --force
```

Optional: use `--browser none` if you prefer to copy the URL manually.

## 3. Environment variables for transports and scripts

Set these in your shell or in `.secrets/btp-abap.env` (values only you should know):

| Variable | Purpose |
|----------|---------|
| `BTP_ADT_TRANSPORT` | Transport **request** (e.g. `H01K900032`) or, in ADT, the **task** number you see in the list (e.g. `H01K900033`); scripts resolve the parent request when needed |
| `BTP_ADT_TASK` | Optional explicit transport **task** / `corrNr` (e.g. `H01K900033`) |
| `BTP_ADT_TRANSPORT_OWNER` | **ABAP user** that owns the transport (e.g. `CB9980000010`), **not** your BTP email |
| `SAP_USERNAME` | Same intent as transport owner for CTS inbox APIs when the JWT `user_name` is an email |
| `BTP_ADT_PACKAGE` | Default package for some push scripts (often `ZPARCEL` for the sample class, or set per command) |
| `BTP_ADT_ENV` | Optional path to env file (default: `.secrets/btp-abap.env` from repo root) |
| `BTP_ADT_TASK_TYPE` | Optional `tm:type` when creating a **new transport task** (default `Development/Correction`). `Workbench` is not a valid task `tm:type` in ADT (Workbench = request type **K**); scripts map it to `Development/Correction`. |

**Adding a task with JWT:** If `npm run btp:transport-task` fails with “User does not exist” / `SCTS_ADT_MSG`, add the task in **ADT Transport Organizer**, or run **`npm run btp:transport-request -- "description"`** to create a new **Workbench** request (includes an initial task).

**Pushes without a fixed transport:** `node scripts/push-abap-class.mjs … --auto-transport` can pick an inbox request or create a Workbench request when the inbox is empty (see script help text).

Do **not** commit real transport numbers if they are sensitive.

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

For **`ZPARCEL`**, this repository intentionally tracks only **`ZCL_TRANSPORT_UI_STATIC_JSON`**. Other objects may still exist on BTP; `.gitignore` hides the usual mirror paths so a full-package sync does not create noisy untracked files here.

Other useful scripts: `btp:push-class`, `btp:push-table`, `btp:push-ddls`, `btp:push-qad`, `transport-ui` (see `package.json`).

## 6. Transport UI (local)

```bash
npm run transport-ui
```

Small Express app that shells the repo’s ADT/CTS scripts and exposes a browser UI. Configure env the same way as for CLI scripts.

## ABAP syntax highlighting in Cursor

This repo can include workspace settings for colouring **ABAP** and **CDS** mirror files:

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
