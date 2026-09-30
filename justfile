# PROTOTYPE (glacialis #185)
set windows-shell := ["powershell.exe", "-NoLogo", "-Command"]


# Start Blender with the vendored MCP addon: under a virtual display as a user unit on Linux, live on Windows.
[linux]
blender:
    systemctl --user is-active --quiet confluence-blender || systemd-run --user --unit=confluence-blender --collect \
      --setenv=BLENDER_USER_SCRIPTS={{justfile_directory()}}/tools/blender \
      --setenv=BLENDERMCP_NO_UPDATE_CHECK=1 \
      direnv exec {{justfile_directory()}} xvfb-run -a blender --addons blender_mcp

[windows]
blender:
    $env:BLENDER_USER_SCRIPTS = "{{justfile_directory()}}/tools/blender"; Start-Process $env:BLENDER_PATH -ArgumentList '--addons','blender_mcp'

# Stop the Linux Blender.
[linux]
blender-stop:
    systemctl --user stop confluence-blender

# Build the client's C# assembly inside the dev shell (a session's own shell is not in it).
build:
    direnv exec {{justfile_directory()}} dotnet build {{justfile_directory()}}/client

# Build the Backend to wasm, offline, into the gitignored toolchain cache.
backend:
    direnv exec {{justfile_directory()}} {{justfile_directory()}}/tools/backend/build.sh

# Start a local Backend host on 127.0.0.1:3000 with data under .cache (foreground; stop with Ctrl-C).
server:
    direnv exec {{justfile_directory()}} spacetime start --data-dir {{justfile_directory()}}/.cache/spacetime-data --listen-addr 127.0.0.1:3000

# Build the Backend and publish it to the local server as `proto`, regenerating the client bindings.
publish: backend
    direnv exec {{justfile_directory()}} spacetime publish --server local --bin-path {{justfile_directory()}}/backend/bin/Release/net8.0/wasi-wasm/AppBundle/StdbModule.wasm --yes proto
    direnv exec {{justfile_directory()}} spacetime generate --lang csharp --out-dir {{justfile_directory()}}/client/backend_bindings --bin-path {{justfile_directory()}}/backend/bin/Release/net8.0/wasi-wasm/AppBundle/StdbModule.wasm
