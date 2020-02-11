{ pkgs, lib, callPackage, newScope, Agda }:

let
  mkAgdaPackages = Agda: lib.makeScope newScope (mkAgdaPackages' Agda);
  mkAgdaPackages' = Agda: self: let
    callPackage = self.callPackage;
  in rec {
    inherit Agda;
    inherit (callPackage ../build-support/agda {
      inherit Agda self;
      inherit (pkgs.haskellPackages) ghcWithPackages;
    }) withPackages mkDerivation;

    standard-library_1_1 = callPackage ../development/libraries/agda/standard-library/1.1.nix {
      inherit (pkgs.haskellPackages) ghcWithPackages;
    };

    standard-library_1_2 = callPackage ../development/libraries/agda/standard-library/1.2.nix {
      inherit (pkgs.haskellPackages) ghcWithPackages;
    };

    standard-library = standard-library_1_2;

    iowa-stdlib = callPackage ../development/libraries/agda/iowa-stdlib { };

    agda-prelude = callPackage ../development/libraries/agda/agda-prelude { };

    agda-categories = callPackage ../development/libraries/agda/agda-categories { };
  };
in mkAgdaPackages Agda
