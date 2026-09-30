// PROTOTYPE (glacialis #185): the one launcher every .mcp.json entry calls (ADR 0025).
// Linux: enter the repo's dev shell with direnv and, for Godot, a virtual display.
// Windows: spawn uvx.exe or npx.cmd through the shell; GODOT_PATH and BLENDER_PATH come from the seat.
import { spawn } from "node:child_process";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const repo = resolve(dirname(fileURLToPath(import.meta.url)), "../..");

const servers = {
  blender: {
    command: ["uvx", "mcp-for-blender==2.1.3"],
    env: { DISABLE_TELEMETRY: "true", BLENDERMCP_NO_UPDATE_CHECK: "1" },
    display: false,
  },
  godot: {
    command: ["npx", "-y", "godot-mcp-runtime@3.8.1"],
    env: { GODOT_MCP_DISABLE_ELICITATION: "true" },
    display: true,
  },
};

const name = process.argv[2];
const server = servers[name];
if (!server) {
  console.error(`usage: node tools/studio/mcp.mjs <${Object.keys(servers).join("|")}>`);
  process.exit(2);
}

const env = { ...process.env, ...server.env };
let argv;
if (process.platform === "win32") {
  const [bin, ...rest] = server.command;
  argv = [bin === "npx" ? "npx.cmd" : `${bin}.exe`, ...rest];
} else {
  argv = ["direnv", "exec", repo, ...(server.display ? ["xvfb-run", "-a"] : []), ...server.command];
}

const child = spawn(argv[0], argv.slice(1), {
  cwd: repo,
  env,
  stdio: "inherit",
  shell: process.platform === "win32",
  // Own process group on Linux, so a signal reaches xvfb-run's Xvfb too, not just the server.
  detached: process.platform !== "win32",
});
child.on("exit", (code, signal) => process.exit(signal ? 1 : code ?? 0));
for (const sig of ["SIGINT", "SIGTERM", "SIGHUP"]) {
  process.on(sig, () => {
    try {
      process.platform === "win32" ? child.kill(sig) : process.kill(-child.pid, sig);
    } catch {}
  });
}
