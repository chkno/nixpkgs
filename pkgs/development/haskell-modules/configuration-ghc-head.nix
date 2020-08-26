##
## Caveat: a copy of configuration-ghc-8.6.x.nix with minor changes:
##
##  1. "8.7" strings
##  2. llvm 6
##  3. disabled library update: parallel
##
{ pkgs, haskellLib }:

with haskellLib;

final: prev: {

  # This compiler version needs llvm 6.x.
  llvmPackages = pkgs.llvmPackages_6;

  # Disable GHC 8.7.x core libraries.
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
  ghc-bignum = null;
  ghc-compact = null;
  ghc-heap = null;
  ghci = null;
  ghc-prim = null;
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
  exceptions = null;

  # https://github.com/tibbe/unordered-containers/issues/214
  unordered-containers = dontCheck prev.unordered-containers;

  # Test suite does not compile.
  data-clist = doJailbreak prev.data-clist;  # won't cope with QuickCheck 2.12.x
  dates = doJailbreak prev.dates; # base >=4.9 && <4.12
  Diff = dontCheck prev.Diff;
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

  # https://github.com/jgm/skylighting/issues/55
  skylighting-core = dontCheck prev.skylighting-core;

  # Break out of "yaml >=0.10.4.0 && <0.11": https://github.com/commercialhaskell/stack/issues/4485
  stack = doJailbreak prev.stack;

  # Fix build with ghc 8.6.x.
  git-annex = appendPatch prev.git-annex ./patches/git-annex-fix-ghc-8.6.x-build.patch;

}
