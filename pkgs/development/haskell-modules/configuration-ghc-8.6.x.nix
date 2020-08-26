{ pkgs, haskellLib }:

with haskellLib;

final: prev: {

  # This compiler version needs llvm 6.x.
  llvmPackages = pkgs.llvmPackages_6;

  # Disable GHC 8.6.x core libraries.
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

  # Needs Cabal 3.0.x.
  cabal-install = prev.cabal-install.overrideScope (final: prev: { Cabal = final.Cabal_3_2_0_0; });
  jailbreak-cabal = prev.jailbreak-cabal.override { Cabal = final.Cabal_3_2_0_0; };

  # https://github.com/tibbe/unordered-containers/issues/214
  unordered-containers = dontCheck prev.unordered-containers;

  # Test suite does not compile.
  data-clist = doJailbreak prev.data-clist;  # won't cope with QuickCheck 2.12.x
  dates = doJailbreak prev.dates; # base >=4.9 && <4.12
  Diff = dontCheck prev.Diff;
  equivalence = dontCheck prev.equivalence; # test suite doesn't compile https://github.com/pa-ba/equivalence/issues/5
  HaTeX = doJailbreak prev.HaTeX; # containers >=0.4 && <0.6 is too tight; https://github.com/Daniel-Diaz/HaTeX/issues/126
  hpc-coveralls = doJailbreak prev.hpc-coveralls; # https://github.com/guillaume-nargeot/hpc-coveralls/issues/82
  http-api-data = doJailbreak prev.http-api-data;
  persistent-sqlite = dontCheck prev.persistent-sqlite;
  system-fileio = dontCheck prev.system-fileio;  # avoid dependency on broken "patience"
  unicode-transforms = dontCheck prev.unicode-transforms;
  wl-pprint-extras = doJailbreak prev.wl-pprint-extras; # containers >=0.4 && <0.6 is too tight; https://github.com/ekmett/wl-pprint-extras/issues/17
  RSA = dontCheck prev.RSA; # https://github.com/GaloisInc/RSA/issues/14
  monad-par = dontCheck prev.monad-par;  # https://github.com/simonmar/monad-par/issues/66
  github = dontCheck prev.github; # hspec upper bound exceeded; https://github.com/phadej/github/pull/341
  binary-orphans = dontCheck prev.binary-orphans; # tasty upper bound exceeded; https://github.com/phadej/binary-orphans/commit/8ce857226595dd520236ff4c51fa1a45d8387b33
  rebase = doJailbreak prev.rebase; # time ==1.9.* is too low

  # https://github.com/jgm/skylighting/issues/55
  skylighting-core = dontCheck prev.skylighting-core;

  # Break out of "yaml >=0.10.4.0 && <0.11": https://github.com/commercialhaskell/stack/issues/4485
  stack = doJailbreak prev.stack;

  # Newer versions don't compile.
  resolv = final.resolv_0_1_1_2;

  # cabal2nix needs the latest version of Cabal, and the one
  # hackage-db uses must match, so take the latest
  cabal2nix = prev.cabal2nix.overrideScope (final: prev: { Cabal = final.Cabal_3_2_0_0; });

  # cabal2spec needs a recent version of Cabal
  cabal2spec = prev.cabal2spec.overrideScope (final: prev: { Cabal = final.Cabal_3_2_0_0; });

  # Builds only with ghc-8.8.x and beyond.
  policeman = markBroken prev.policeman;

  # https://github.com/pikajude/stylish-cabal/issues/12
  stylish-cabal = doDistribute (markUnbroken (prev.stylish-cabal.override { haddock-library = final.haddock-library_1_7_0; }));
  haddock-library_1_7_0 = dontCheck prev.haddock-library_1_7_0;

  # ghc versions prior to 8.8.x needs additional dependency to compile successfully.
  ghc-lib-parser-ex = addBuildDepend prev.ghc-lib-parser-ex final.ghc-lib-parser;

  # Only 0.6 is compatible with ghc 8.6 https://hackage.haskell.org/package/apply-refact/changelog
  apply-refact = prev.apply-refact_0_6_0_0;
}
