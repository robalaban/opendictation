{
  description = "Node.js development environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };
  };

  outputs = inputs:
    inputs.flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ];

      perSystem = { pkgs, lib, config, ... }:
        let
          # Use the latest LTS Node.js version
          nodejs = pkgs.nodejs_22;
        in
        {
          packages = {
            default = nodejs;
          };

          devShells.default = pkgs.mkShell {
            packages = with pkgs; [
              # Node.js and package managers (pnpm as primary)
              nodejs
              nodePackages.pnpm
              yarn

              # Development tools
              nodePackages.typescript
              nodePackages.typescript-language-server
              nodePackages.eslint
              nodePackages.prettier
              nodePackages.nodemon
            ];

            shellHook = ''
              echo "Node.js development environment activated!"
            '';
          };

          apps = {
            default = {
              program = "${nodejs}/bin/node";
              type = "app";
            };
          };
        };
    };
}
