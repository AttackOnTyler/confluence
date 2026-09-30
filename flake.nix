# PROTOTYPE (glacialis #185): the studio seat of ADR 0025 in a scratch clone laid out per ADR 0027.
{
  description = "confluence scratch: the studio seat";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { nixpkgs, ... }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
      godot = pkgs.godotPackages_4_7;
    in
    {
      devShells.${system}.default = pkgs.mkShell {
        packages = [
          pkgs.blender
          godot.godot-mono
          godot.export-templates-mono-bin
          pkgs.dotnetCorePackages.sdk_8_0
          pkgs.uv
          pkgs.python312
          pkgs.nodejs
          pkgs.xvfb-run
          pkgs.just
        ];
        GODOT_PATH = "${godot.godot-mono}/bin/godot-mono";
        BLENDER_PATH = "${pkgs.blender}/bin/blender";
        DOTNET_ROOT = "${pkgs.dotnetCorePackages.sdk_8_0}/share/dotnet";
        DOTNET_CLI_TELEMETRY_OPTOUT = "1";
        UV_PYTHON_PREFERENCE = "only-system";
        UV_PYTHON = "${pkgs.python312}/bin/python3";
      };
    };
}
