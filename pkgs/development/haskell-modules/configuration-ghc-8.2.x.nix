{ pkgs, haskellLib }:

with haskellLib;

final: prev: {

  # Suitable LLVM version.
  llvmPackages = pkgs.llvmPackages;

  # Disable GHC 8.2.x core libraries.
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
  hoopl = null;
  hpc = null;
  integer-gmp = null;
  pretty = null;
  process = null;
  rts = null;
  template-haskell = null;
  terminfo = null;
  time = null;
  transformers = null;
  unix = null;
  xhtml = null;

  # These are now core libraries in GHC 8.4.x.
  mtl = final.mtl_2_2_2;
  parsec = final.parsec_3_1_14_0;
  stm = final.stm_2_5_0_0;
  text = final.text_1_2_4_0;

  # Needs Cabal 3.0.x.
  jailbreak-cabal = prev.jailbreak-cabal.override { Cabal = final.Cabal_3_2_0_0; };

  # https://github.com/bmillwood/applicative-quoters/issues/6
  applicative-quoters = appendPatch prev.applicative-quoters (pkgs.fetchpatch {
    url = "https://patch-diff.githubusercontent.com/raw/bmillwood/applicative-quoters/pull/7.patch";
    sha256 = "026vv2k3ks73jngwifszv8l59clg88pcdr4mz0wr0gamivkfa1zy";
  });

  # https://github.com/nominolo/ghc-syb/issues/20
  ghc-syb-utils = dontCheck prev.ghc-syb-utils;

  # Upstream failed to distribute the testsuite for 8.2
  # https://github.com/alanz/ghc-exactprint/pull/60
  ghc-exactprint = dontCheck prev.ghc-exactprint;

  # Reduction stack overflow; size = 38
  # https://github.com/jystic/hadoop-tools/issues/31
  hadoop-rpc =
    let patch = pkgs.fetchpatch
          { url = "https://github.com/shlevy/hadoop-tools/commit/f03a46cd15ce3796932c3382e48bcbb04a6ee102.patch";
            sha256 = "09ls54zy6gx84fmzwgvx18ssgm740cwq6ds70p0p125phi54agcp";
            stripLen = 1;
          };
    in appendPatch prev.hadoop-rpc patch;

  # Custom Setup.hs breaks with Cabal 2
  # https://github.com/NICTA/coordinate/pull/4
  coordinate =
    let patch = pkgs.fetchpatch
          { url = "https://github.com/NICTA/coordinate/pull/4.patch";
            sha256 = "06sfxk5cyd8nqgjyb95jkihxxk8m6dw9m3mlv94sm2qwylj86gqy";
          };
    in appendPatch prev.coordinate patch;

  # https://github.com/purescript/purescript/issues/3189
  purescript = doJailbreak (prev.purescript);

  # These packages need Cabal 2.2.x, which is not the default.
  cabal2nix = prev.cabal2nix.overrideScope (final: prev: { Cabal = final.Cabal_2_2_0_1; });
  cabal2spec = prev.cabal2spec.overrideScope (final: prev: { Cabal = final.Cabal_2_2_0_1; });
  distribution-nixpkgs = prev.distribution-nixpkgs.overrideScope (final: prev: { Cabal = final.Cabal_2_2_0_1; });
  stack = prev.stack.overrideScope (final: prev: { Cabal = final.Cabal_2_2_0_1; });

  # Older GHC versions need these additional dependencies.
  ListLike = addBuildDepend prev.ListLike final.semigroups;
  base-compat-batteries = addBuildDepend prev.base-compat-batteries final.contravariant;

  # ghc versions prior to 8.8.x needs additional dependency to compile successfully.
  ghc-lib-parser-ex = addBuildDepend prev.ghc-lib-parser-ex final.ghc-lib-parser;

}
