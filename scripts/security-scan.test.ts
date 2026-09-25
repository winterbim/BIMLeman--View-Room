import { expect, test } from "bun:test";
import { readdirSync, readFileSync, statSync } from "node:fs";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const root = resolve(dirname(fileURLToPath(import.meta.url)), "..");

function walk(directory: string, extension: string): string[] {
  const entries = readdirSync(directory);
  const files: string[] = [];
  for (const entry of entries) {
    if (entry === "node_modules" || entry === "target" || entry === "dist") continue;
    const path = join(directory, entry);
    const info = statSync(path);
    if (info.isDirectory()) files.push(...walk(path, extension));
    else if (entry.endsWith(extension) && !entry.endsWith(".test.ts")) files.push(path);
  }
  return files;
}

test("deploy scripts avoid the reserved host variable and keep key roles apart", () => {
  const scripts = walk(join(root, "deploy"), ".ps1");
  expect(scripts.length).toBeGreaterThanOrEqual(6);
  for (const script of scripts) {
    const source = readFileSync(script, "utf8");
    expect(source, script).not.toMatch(/\$host\b/);
    expect(source, script).not.toContain("authkeys export \"$KeyName/private\"");
    expect(source, script).not.toContain("authkeys export \"teacher/private\"");
  }
  const client = readFileSync(join(root, "deploy/client/Install-Client.ps1"), "utf8");
  expect(client).toContain("/S /NoMaster /ApplyConfig=");
  expect(client).toContain("authkeys import \"$KeyName/public\"");
  expect(client).toContain("Clé privée détectée");
  const teacher = readFileSync(join(root, "deploy/teacher/Install-Teacher.ps1"), "utf8");
  expect(teacher).toContain("authkeys export \"$KeyName/public\"");
  expect(teacher).toContain("HttpServerEnabled true");
  expect(teacher).toContain("déjà présente");
  const probe = readFileSync(join(root, "deploy/common/Test-AllComputers.ps1"), "utf8");
  expect(probe).toContain("11100");
  expect(probe).toContain("Export-Csv");
  expect(probe).toContain("exit 2");
});

test("frontend and scripts do not embed a private key", () => {
  const files = [
    ...walk(join(root, "apps/desktop/src"), ".ts"),
    ...walk(join(root, "apps/desktop/src"), ".tsx"),
    ...walk(join(root, "packages"), ".ts")
  ];
  for (const file of files) {
    const source = readFileSync(file, "utf8");
    expect(source, file).not.toContain("BEGIN PRIVATE KEY");
    expect(source, file).not.toContain("keydata");
  }
});

test("brand assets exist for the app and the Windows installer", () => {
  const logo = readFileSync(join(root, "apps/desktop/public/logo.png"));
  const icon = readFileSync(join(root, "apps/desktop/src-tauri/icons/icon.ico"));
  const small = readFileSync(join(root, "apps/desktop/src-tauri/icons/32x32.png"));
  expect(logo.subarray(0, 8).toString("hex")).toBe("89504e470d0a1a0a");
  expect(small.subarray(0, 8).toString("hex")).toBe("89504e470d0a1a0a");
  expect(icon.subarray(0, 4).toString("hex")).toBe("00000100");
  const config = readFileSync(join(root, "apps/desktop/src-tauri/tauri.conf.json"), "utf8");
  expect(config).toContain("icon.ico");
  expect(config).toContain("nsis");
});
