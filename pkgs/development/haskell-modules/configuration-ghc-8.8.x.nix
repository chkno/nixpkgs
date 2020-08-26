{ pkgs, haskellLib }:

with haskellLib;

final: prev: {

  # This compiler version needs llvm 7.x.
  llvmPackages = pkgs.llvmPackages_7;

  # Disable GHC 8.8.x core libraries.
  array = null;
  base = null;
  binary = null;
  bytestring = null;
  Cabal = null;
  containers = null;
  deepseq = null;
  directory = null;
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

  # GHC 8.8.x can build haddock version 2.23.*
  haddock = final.haddock_2_23_1;
  haddock-api = final.haddock-api_2_23_1;

  # These builds need Cabal 3.2.x.
  cabal2spec = prev.cabal2spec.override { Cabal = final.Cabal_3_2_0_0; };
  cabal-install = prev.cabal-install.overrideScope (final: prev: { Cabal = final.Cabal_3_2_0_0; });

  # Ignore overly restrictive upper version bounds.
  aeson-diff = doJailbreak prev.aeson-diff;
  async = doJailbreak prev.async;
  ChasingBottoms = doJailbreak prev.ChasingBottoms;
  chell = doJailbreak prev.chell;
  Diff = dontCheck prev.Diff;
  doctest = doJailbreak prev.doctest;
  hashable = doJailbreak prev.hashable;
  hashable-time = doJailbreak prev.hashable-time;
  hledger-lib = doJailbreak prev.hledger-lib;  # base >=4.8 && <4.13, easytest >=0.2.1 && <0.3
  integer-logarithms = doJailbreak prev.integer-logarithms;
  lucid = doJailbreak prev.lucid;
  parallel = doJailbreak prev.parallel;
  quickcheck-instances = doJailbreak prev.quickcheck-instances;
  setlocale = doJailbreak prev.setlocale;
  split = doJailbreak prev.split;
  system-fileio = doJailbreak prev.system-fileio;
  tasty-expected-failure = doJailbreak prev.tasty-expected-failure;
  tasty-hedgehog = doJailbreak prev.tasty-hedgehog;
  test-framework = doJailbreak prev.test-framework;
  th-expand-syns = doJailbreak prev.th-expand-syns;
  # TODO: remove when upstream accepts https://github.com/snapframework/io-streams-haproxy/pull/17
  io-streams-haproxy = doJailbreak prev.io-streams-haproxy; # base >=4.5 && <4.13
  snap-server = doJailbreak prev.snap-server;
  exact-pi = doJailbreak prev.exact-pi;
  time-compat = doJailbreak prev.time-compat;
  http-media = doJailbreak prev.http-media;
  servant-server = doJailbreak prev.servant-server;
  foundation = dontCheck prev.foundation;
  vault = dontHaddock prev.vault;

  # https://github.com/snapframework/snap-core/issues/288
  snap-core = overrideCabal prev.snap-core (drv: { prePatch = "substituteInPlace src/Snap/Internal/Core.hs --replace 'fail   = Fail.fail' ''"; });

  # Upstream ships a broken Setup.hs file.
  csv = overrideCabal prev.csv (drv: { prePatch = "rm Setup.hs"; });

  # https://github.com/kowainik/relude/issues/241
  relude = dontCheck prev.relude;

  # The tests for semver-range need to be updated for the MonadFail change in
  # ghc-8.8:
  # https://github.com/adnelson/semver-range/issues/15
  semver-range = dontCheck prev.semver-range;

  # The current version 2.14.2 does not compile with ghc-8.8.x or newer because
  # of issues with Cabal 3.x.
  darcs = dontDistribute prev.darcs;

  # Only 0.7 is compatible with ghc 8.7 https://hackage.haskell.org/package/apply-refact/changelog
  apply-refact = prev.apply-refact_0_7_0_0;

  # The package needs the latest Cabal version.
  cabal-install-parsers = prev.cabal-install-parsers.overrideScope (final: prev: { Cabal = final.Cabal_3_2_0_0; });

  # cabal-fmt requires Cabal3
  cabal-fmt = prev.cabal-fmt.override { Cabal = final.Cabal_3_2_0_0; };

}
