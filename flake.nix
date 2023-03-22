{
  inputs = {
    opam-nix.url = "github:tweag/opam-nix";
    flake-utils.url = "github:numtide/flake-utils";
    # we pin opam-nix's nixpkgs to follow the flakes, avoiding using two different instances
    opam-nix.inputs.nixpkgs.follows = "nixpkgs";

    # maintain a different opam-repository to those pinned upstream
    opam-repository = {
      url = "github:ocaml/opam-repository";
      flake = false;
    };
    opam-nix.inputs.opam-repository.follows = "opam-repository";

    # deduplicate flakes
    opam-nix.inputs.flake-utils.follows = "flake-utils";
  };
  outputs = { self, nixpkgs, flake-utils, opam-nix, ... }@inputs:
    # create outputs for each default system
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        opam-nix-lib = opam-nix.lib.${system};
        devPackagesQuery = {
          ocaml-lsp-server = "*";
          ocamlformat = "*";
          # 1.9.6 fails to build
          ocamlfind = "1.9.5";
        };
        query = {
          ocaml-base-compiler = "*";
        };
        resolved-scope =
          # recursive finds vendored dependancies in duniverse
          opam-nix-lib.buildOpamProject' { recursive = true; } ./. (query // devPackagesQuery);
        materialized-scope =
          # to generate:
          #   nix shell github:tweag/opam-nix#opam-nix-gen -c opam-nix-gen -p ocaml-lsp-server -p ocamlformat -p ocaml-base-compiler -p hex aeon . package-defs.json
          # NB this is broken for now, see https://github.com/tweag/opam-nix/issues/37
          opam-nix-lib.materializedDefsToScope { sourceMap.aeon = ./.; sourceMap.aeon-client = ./.; } ./package-defs.json;
      in rec {
        packages = rec {
          resolved = resolved-scope;
          materialized = materialized-scope;
          default = resolved.aeon;
        };
        defaultPackage = packages.default;

        devShells =
          let
            mkDevShell = scope:
              let
                devPackages = builtins.attrValues
                  (pkgs.lib.getAttrs (builtins.attrNames devPackagesQuery) scope);
              in pkgs.mkShell {
                inputsFrom = [ scope.aeon scope.aeon-client ];
                buildInputs = devPackages;
              };
            dev-scope =
              # don't pick up duniverse deps
              # it can be slow to build vendored dependancies in a deriviation before getting an error
              opam-nix-lib.buildOpamProject' { } ./. (query // devPackagesQuery);
          in rec {
            resolved = mkDevShell resolved-scope;
            materialized = mkDevShell materialized-scope;
            # use for fast development as it doesn't building vendored sources in seperate derivations
            # however might not build the same result as `nix build .`,
            # like `nix develop .#devShells.x86_64-linux.resolved -c dune build` should do
            dev = mkDevShell dev-scope;
            default = dev;
          };
      }) // {
    nixosModules.default = {
      imports = [ ./module.nix ];
    };
  };
}
