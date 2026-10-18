#!/usr/bin/env node
// PreToolUse hook: keeps secrets away from Claude and out of the app bundle.
// Exit 2 blocks the tool call; the stderr message is shown to Claude.
// Plain Node with no dependencies, so it runs the same on Windows, macOS and Linux.

const path = require("path");

const ENV_FILE = /^\.env(\..+)?$/i; // .env, .env.local, .env.production ...
const ALLOWED_ENV = /^\.env\.(example|sample|template)$/i;

// Secret values that must never be written into a file.
const SECRET_VALUES = [
  [/sb_secret_[A-Za-z0-9_-]{16,}/, "a Supabase secret key"],
  [/\b[sr]k_(live|test)_[A-Za-z0-9]{16,}/, "a Stripe secret or restricted key"],
  [/\bwhsec_[A-Za-z0-9]{16,}/, "a webhook signing secret"],
  [/-----BEGIN [A-Z ]*PRIVATE KEY-----/, "a private key"],
];

// Names that mean "a secret is about to ship inside the app".
const PUBLIC_SECRET_NAME = /EXPO_PUBLIC_[A-Z0-9_]*(SECRET|SERVICE_ROLE|PRIVATE|WEBHOOK|SK_)/;
const SERVICE_ROLE_NAME = /SERVICE_ROLE/;

function block(msg) {
  process.stderr.write(`Blocked by guard-secrets: ${msg}\n`);
  process.exit(2);
}

// Windows ignores trailing dots and spaces, and ".env::$DATA" reads the file's main stream.
function normalizeName(n) {
  return path.basename(String(n).replace(/\\/g, "/")).replace(/:.*$/, "").replace(/[. ]+$/, "");
}

function isEnvFile(p) {
  if (!p) return false;
  // Check the name as given and, when the file exists, the real file behind any symlink.
  const names = [String(p)];
  try { names.push(require("fs").realpathSync.native(String(p))); } catch {}
  return names.some((n) => {
    const base = normalizeName(n);
    return ENV_FILE.test(base) && !ALLOWED_ENV.test(base);
  });
}

// A JWT whose payload says role=service_role is the legacy Supabase service-role key.
function hasServiceRoleJwt(text) {
  const jwts = text.match(/eyJ[A-Za-z0-9_-]{10,}\.eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}/g) || [];
  return jwts.some((t) => {
    try {
      const payload = Buffer.from(t.split(".")[1], "base64url").toString("utf8");
      return /"role"\s*:\s*"service_role"/.test(payload);
    } catch {
      return false;
    }
  });
}

const ENV_NAMES = [".env", ".env.local", ".env.development", ".env.production", ".env.test"];

// Could a wildcard such as *env*, *v or *.e* match a .env file name? Used where a leading
// wildcard also matches dotfiles. Anything this translator can't read exactly counts as a match.
function globCouldMatchEnv(glob) {
  if (/[@+!*?]\(|\[[!^]?\]|\[:|\\/.test(glob)) return true;
  let re = "^";
  for (let i = 0; i < glob.length; i++) {
    const c = glob[i];
    if (c === "*") re += ".*";
    else if (c === "?") re += ".";
    else if (c === "[") {
      const j = glob.indexOf("]", i + 1);
      if (j < 0) return true;
      re += "[" + glob.slice(i + 1, j).replace(/^!/, "^") + "]";
      i = j;
    } else if (c === "{") re += "(";
    else if (c === "}") re += ")";
    else if (c === ",") re += "|";
    else re += c.replace(/[.+^$()|\]\\]/g, "\\$&");
  }
  try {
    const r = new RegExp(re + "$", "i");
    return ENV_NAMES.some((n) => r.test(n));
  } catch {
    return true;
  }
}

function checkContent(text, filePath) {
  if (!text) return;
  for (const [re, what] of SECRET_VALUES) {
    if (re.test(text)) block(`this would write ${what} into ${filePath || "a file"}. Reference it by env var name and keep the value in Edge Function secrets.`);
  }
  if (hasServiceRoleJwt(text)) block(`this would write the Supabase service-role key into ${filePath || "a file"}.`);
  if (PUBLIC_SECRET_NAME.test(text)) block("EXPO_PUBLIC_ variables are bundled into the app, so they can't hold secrets. Move this to an Edge Function secret.");
  const p = String(filePath || "").replace(/\\/g, "/");
  const serverSide = /(^|\/)supabase\/(functions|migrations|seed)/.test(p) || /(^|\/)\.github\//.test(p);
  if (!serverSide && /\.(m?[jt]sx?|json)$/.test(p) && SERVICE_ROLE_NAME.test(text)) {
    block(`${p} is app code; the service-role key may only be used inside supabase/functions/.`);
  }
}

let raw = "";
process.stdin.setEncoding("utf8");
process.stdin.on("data", (c) => (raw += c));
process.stdin.on("end", () => {
  let input;
  try {
    input = JSON.parse(raw);
  } catch {
    block("hook input was not valid JSON.");
  }
  const tool = input.tool_name || "";
  const ti = input.tool_input || {};
  const filePath = ti.file_path || ti.notebook_path || ti.path || "";

  if (["Read", "Edit", "Write", "MultiEdit", "NotebookEdit", "Grep"].includes(tool)) {
    if (isEnvFile(filePath)) block(`${path.basename(filePath)} holds secrets. Ask Danny for the variable name you need instead of reading the file.`);
    if (tool === "Grep" && ti.glob && /(^|\/)\.env/i.test(String(ti.glob)) && !ALLOWED_ENV.test(path.basename(String(ti.glob)))) block("searching .env files is not allowed.");
  }

  if (tool === "Write") checkContent(ti.content, filePath);
  if (tool === "Edit") checkContent(ti.new_string, filePath);
  if (tool === "MultiEdit") checkContent((ti.edits || []).map((e) => e.new_string).join("\n"), filePath);
  if (tool === "NotebookEdit") checkContent(ti.new_source, filePath);

  if (tool === "Bash" || tool === "PowerShell") {
    const raw = String(ti.command || "");
    // Two readings: backslashes as path separators (C:\app\.env), and with quotes,
    // escapes and PowerShell backticks dropped (.e"nv", .e\nv, .e`nv all read as .env).
    const readings = [raw.replace(/\\/g, "/"), raw.replace(/['"`\\]/g, "")];
    for (const cmd of readings) {
      // Any wildcard word that could expand to a .env file. Shells skip dotfiles for a leading
      // wildcard, but find -name, PowerShell and dotglob don't, so those are checked strictly.
      const strict = tool === "PowerShell" || /\b(dotglob|GLOBIGNORE|find|pwsh|powershell|Get-\w+|gci|gc|dir|ls\s+-\S*a)\b/i.test(cmd);
      for (const word of cmd.split(/[\s=<>|;&'"`]+/)) {
        const last = word.split("/").pop();
        // Fail closed: a dotfile name anywhere in the word (start, after / ( { , |) whose own
        // path segment carries glob, brace or extglob syntax: .e*, {x,.e*}, @(.e*), {.e,}nv.
        const dotGlob = /(^|[({,|\/])\.(?![\/.])[^\/\s]*?([*?[{},]|[@+!*?]\()/.test(word);
        if (dotGlob || (strict && /[*?[{]|[@+!*?]\(/.test(last) && globCouldMatchEnv(last))) {
          block("shell commands may not use a wildcard that could match a .env file. Name the file you need.");
        }
      }
      // A .env path as its own word, normalized like a Windows file name: not process.env, not .env.example.
      const envRef = /(^|[\s'"=<>|;&(\/,`{])(\.env(\.[A-Za-z0-9_-]+)?[. ]*(:[^\s'"|;&)]*)?)(?=$|[\s'"|;&)<>,`}])/gi;
      for (const m of cmd.matchAll(envRef)) {
        if (!ALLOWED_ENV.test(normalizeName(m[2]))) {
          block("shell commands may not touch .env files. Refer to variables by name.");
        }
      }
    }
    const cmd = raw;
    checkContent(cmd, "a shell command");
  }
  process.exit(0);
});
