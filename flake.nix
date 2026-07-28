{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    systems.url = "github:nix-systems/default";

    eeprom-programmer = {
      url = "github:Grazen0/eeprom-programmer";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    inputs@{
      self,
      flake-parts,
      ...
    }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = import inputs.systems;

      perSystem =
        {
          self',
          pkgs,
          system,
          inputs',
          ...
        }:
        {
          devShells.default = pkgs.mkShell {
            packages = with pkgs; [
              inputs'.eeprom-programmer.packages.default
              screen
              xxd
              sjasmplus
            ];
          };
        };
    };

}
