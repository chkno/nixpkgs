{ pkgs, haskellLib }:

with haskellLib;

final: prev: {

  # This compiler version needs llvm 9.x.
  llvmPackages = pkgs.llvmPackages_9;

  # Disable GHC 8.10.x core libraries.
  array = null;
  base = null;
  binary = null;
  bytestring = null;
  Cabal = null;
  containers = null;
  deepseq = null;
  directory = null;
  exceptions = null;
  filepath = null;
  ghc-boot = null;
  ghc-boot-th = null;
  ghc-compact = null;
  ghc-heap = null;
  ghc-prim = null;
  ghci = null;
  haskeline = null;
  hpc = null;
  integer-gmp = null;
  libiserv = null;
  mtl = null;
  parsec = null;
  pretty = null;
  process = null;
  rts = null;
  stm = null;
  template-haskell = null;
  terminfo = null;
  text = null;
  time = null;
  transformers = null;
  unix = null;
  xhtml = null;

  # The proper 3.2.0.0 release does not compile with ghc-8.10.1, so we take the
  # hitherto unreleased next version from the '3.2' branch of the upstream git
  # repository for the time being.
  cabal-install = assert prev.cabal-install.version == "3.2.0.0";
                  overrideCabal prev.cabal-install (drv: {
    postUnpack = "sourceRoot+=/cabal-install; echo source root reset to $sourceRoot";
    version = "3.2.0.0-git";
    editedCabalFile = null;
    src = pkgs.fetchgit {
      url = "git://github.com/haskell/cabal.git";
      rev = "9bd4cc0591616aeae78e17167338371a2542a475";
      sha256 = "005q1shh7vqgykkp72hhmswmrfpz761x0q0jqfnl3wqim4xd9dg0";
    };
  });

  # Deviate from Stackage LTS-15.x to fix the build.
  haddock-library = final.haddock-library_1_9_0;

  # Jailbreak to fix the build.
  base-noprelude = doJailbreak prev.base-noprelude;
  pandoc = doJailbreak prev.pandoc;
  system-fileio = doJailbreak prev.system-fileio;
  unliftio-core = doJailbreak prev.unliftio-core;

  # Use the latest version to fix the build.
  dhall = final.dhall_1_34_0;
  lens = final.lens_4_19_2;
  optics-core = final.optics-core_0_3_0_1;
  repline = final.repline_0_4_0_0;
  singletons = final.singletons_2_7;
  th-desugar = final.th-desugar_1_11;

  # `ghc-lib-parser-ex` (see conditionals in its `.cabal` file) does not need
  # the `ghc-lib-parser` dependency on GHC >= 8.8. However, because we have
  # multiple verions of `ghc-lib-parser(-ex)` available, and the default ones
  # are older ones, those older ones will complain. Because we have a newer
  # GHC, we can just set the dependency to `null` as it is not used.
  ghc-lib-parser-ex = prev.ghc-lib-parser-ex.override { ghc-lib-parser = null; };

  # Jailbreak to fix the build.
  brick = doJailbreak prev.brick;
  exact-pi = doJailbreak prev.exact-pi;
  serialise = doJailbreak prev.serialise;
  setlocale = doJailbreak prev.setlocale;
  shellmet = doJailbreak prev.shellmet;
  shower = doJailbreak prev.shower;

  # The shipped Setup.hs file is broken.
  csv = overrideCabal prev.csv (drv: { preCompileBuildDriver = "rm Setup.hs"; });

  # Apply patch from https://github.com/finnsson/template-helper/issues/12#issuecomment-611795375 to fix the build.
  language-haskell-extract = appendPatch (doJailbreak prev.language-haskell-extract) (pkgs.fetchpatch {
    name = "language-haskell-extract-0.2.4.patch";
    url = "https://gitlab.haskell.org/ghc/head.hackage/-/raw/e48738ee1be774507887a90a0d67ad1319456afc/patches/language-haskell-extract-0.2.4.patch?inline=false";
    sha256 = "0rgzrq0513nlc1vw7nw4km4bcwn4ivxcgi33jly4a7n3c1r32v1f";
  });

  # Only 0.8 is compatible with ghc 8.10 https://hackage.haskell.org/package/apply-refact/changelog
  apply-refact = prev.apply-refact_0_8_0_0;

  # https://github.com/commercialhaskell/pantry/issues/21
  pantry = appendPatch prev.pantry (pkgs.fetchpatch {
    name = "add-cabal-3.2.x-support.patch";
    url = "https://patch-diff.githubusercontent.com/raw/commercialhaskell/pantry/pull/22.patch";
    sha256 = "198hsfjsy83s7rp71llf05cwa3vkm74g73djg5p4sk4awm9s6vf2";
    excludes = ["package.yaml"];
  });

  # hnix 0.9.0 does not provide an executable for ghc < 8.10, so define completions here for now.
  hnix = generateOptparseApplicativeCompletion "hnix"
    (overrideCabal prev.hnix (drv: {
      # executable is allowed for ghc >= 8.10 and needs repline
      executableHaskellDepends = drv.executableToolDepends or [] ++ [ final.repline ];
    }));

}
