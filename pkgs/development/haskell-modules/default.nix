{ pkgs, stdenv, lib, haskellLib, ghc, all-cabal-hashes
, buildHaskellPackages
, compilerConfig ? (final: prev: {})
, packageSetConfig ? (final: prev: {})
, overrides ? (final: prev: {})
, initialPackages ? import ./initial-packages.nix
, nonHackagePackages ? import ./non-hackage-packages.nix
, configurationCommon ? import ./configuration-common.nix
, configurationNix ? import ./configuration-nix.nix
}:

let

  inherit (lib) extends makeExtensible;
  inherit (haskellLib) makePackageSet;

  haskellPackages = pkgs.callPackage makePackageSet {
    package-set = initialPackages;
    inherit stdenv haskellLib ghc buildHaskellPackages extensible-final all-cabal-hashes;
  };

  commonConfiguration = configurationCommon { inherit pkgs haskellLib; };
  nixConfiguration = configurationNix { inherit pkgs haskellLib; };

  extensible-final = makeExtensible
    (extends overrides
      (extends packageSetConfig
        (extends compilerConfig
          (extends commonConfiguration
            (extends nixConfiguration
              (extends nonHackagePackages
                haskellPackages))))));

in

  extensible-final
