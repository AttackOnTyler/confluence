#!/usr/bin/env bash
# Build backend/StdbModule.csproj to wasm offline, inside the dev shell.
#
# The .NET 8 `wasi-experimental` workload cannot be installed into the
# read-only Nix SDK (`dotnet workload install` wants a writable store). This
# script downloads the four workload packs as plain NuGet packages and a
# wasi-sdk 24 toolchain into a gitignored cache, points the SDK at them with
# DOTNETSDK_WORKLOAD_PACK_ROOTS / WASI_SDK_PATH, and runs `dotnet restore` +
# `dotnet publish` directly (never `spacetime build`, which insists on
# running `dotnet workload install` against the same read-only store).
#
# Recorded in glacialis docs/research/backend-build.md (2026-09-28 probe).
# Run via `just backend` (enters the dev shell itself) or
# `direnv exec . tools/backend/build.sh`.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CACHE="$REPO_ROOT/.cache/backend-toolchain"
PACKROOT="$CACHE/packroot"
WASI_SDK_DIR="$CACHE/wasi-sdk-24.0-x86_64-linux"
NUGET_PACKAGES_DIR="$CACHE/nuget-packages"
BACKEND_CSPROJ="$REPO_ROOT/backend/StdbModule.csproj"

MANIFEST_VERSION="8.0.31"
WASI_SDK_RELEASE="wasi-sdk-24"
WASI_SDK_TARBALL="wasi-sdk-24.0-x86_64-linux.tar.gz"
WASI_SDK_URL="https://github.com/WebAssembly/wasi-sdk/releases/download/${WASI_SDK_RELEASE}/${WASI_SDK_TARBALL}"

PACKS=(
  "Microsoft.NET.Runtime.WebAssembly.Wasi.Sdk"
  "Microsoft.NETCore.App.Runtime.Mono.wasi-wasm"
  "Microsoft.NET.Runtime.MonoAOTCompiler.Task"
  "Microsoft.NET.Runtime.MonoTargets.Sdk"
)

mkdir -p "$PACKROOT/packs" "$NUGET_PACKAGES_DIR"

echo "== workload packs (${MANIFEST_VERSION}) =="
for id in "${PACKS[@]}"; do
  dest="$PACKROOT/packs/$id/${MANIFEST_VERSION}"
  if [ -f "$dest/$id.nuspec" ]; then
    echo "  $id already unpacked"
    continue
  fi
  rm -rf "$dest"
  tmp="$(mktemp -d)"
  nupkg="$tmp/$id.nupkg"
  url="https://www.nuget.org/api/v2/package/$id/${MANIFEST_VERSION}"
  echo "  fetching $id -> $url"
  curl -sSL -f -o "$nupkg" "$url"
  mkdir -p "$dest"
  (cd "$dest" && unzip -q -o "$nupkg" -x '_rels/*' 'package/*' '\[Content_Types\].xml' '*.signature.p7s')
  rm -rf "$tmp"
done

echo "== wasi-sdk 24 =="
if [ ! -x "$WASI_SDK_DIR/bin/clang-18" ]; then
  tmp="$(mktemp -d)"
  tarball="$tmp/$WASI_SDK_TARBALL"
  echo "  fetching $WASI_SDK_URL"
  curl -sSL -o "$tarball" "$WASI_SDK_URL"
  mkdir -p "$CACHE"
  tar -xzf "$tarball" -C "$CACHE"
  rm -rf "$tmp"

  # wasi-sdk's clang-18/lld are prebuilt for a generic glibc host; patchelf
  # them to run under NixOS, borrowing the interpreter and rpath of the
  # dotnet binary already in this dev shell (also glibc + libgcc linked).
  REF_ELF="$(command -v dotnet)"
  INTERP="$(patchelf --print-interpreter "$REF_ELF")"
  RPATH="$(patchelf --print-rpath "$REF_ELF")"
  echo "  patchelf reference: $REF_ELF"
  echo "  interpreter: $INTERP"
  echo "  rpath: $RPATH"
  for bin in "$WASI_SDK_DIR/bin/clang-18" "$WASI_SDK_DIR/bin/lld"; do
    if [ -f "$bin" ]; then
      patchelf --set-interpreter "$INTERP" --set-rpath "$RPATH:$WASI_SDK_DIR/lib" "$bin"
    fi
  done
else
  echo "  wasi-sdk already patched"
fi

echo "== restore + publish =="
export DOTNETSDK_WORKLOAD_PACK_ROOTS="$PACKROOT"
export WASI_SDK_PATH="$WASI_SDK_DIR"
export NUGET_PACKAGES="$NUGET_PACKAGES_DIR"
export DOTNET_SKIP_FIRST_TIME_EXPERIENCE=1
export DOTNET_CLI_WORKLOAD_UPDATE_NOTIFY_DISABLE=1
export DOTNET_SKIP_WORKLOAD_INTEGRITY_CHECK=1
export DOTNET_NOLOGO=1
export DOTNET_CLI_TELEMETRY_OPTOUT=1
unset EXPERIMENTAL_WASM_AOT || true

# The dev shell's PATH resolves a second, older `dotnet` (godot-mono's own
# closure) ahead of DOTNET_ROOT; use DOTNET_ROOT explicitly so restore and
# publish run against the SDK whose manifest matches the packs above.
DOTNET="$DOTNET_ROOT/dotnet"

rm -rf "$REPO_ROOT/backend/obj" "$REPO_ROOT/backend/bin"
"$DOTNET" restore "$BACKEND_CSPROJ" --force -p:TargetFrameworks=net8.0
"$DOTNET" publish "$BACKEND_CSPROJ" -c Release -f net8.0 --no-restore --force -p:TargetFrameworks=net8.0

WASM="$REPO_ROOT/backend/bin/Release/net8.0/wasi-wasm/AppBundle/StdbModule.wasm"
if [ ! -f "$WASM" ]; then
  echo "publish did not produce $WASM" >&2
  exit 1
fi

echo "== wasm-opt =="
# nixpkgs' binaryen 132 `wasm-opt -all -g -O2` on this module produces a
# wasm that wasmtime (inside `spacetime start` 2.10.1) refuses to load
# ("invalid leading byte (0x7e) for external kind") -- probed 2026-09-30.
# `spacetime build` treats a failing wasm-opt as non-fatal and publishes
# the unoptimised file (mod.rs); this script does the same, but since the
# corruption here is silent (wasm-opt exits 0), skip it outright until the
# binaryen/module mismatch is understood, and publish the plain wasm.
echo "  skipping: nixpkgs binaryen 132's -O2 output failed to load in spacetime start 2.10.1 (see tools/backend/build.sh)"

echo "$WASM"
