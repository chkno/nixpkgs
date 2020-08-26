# GHCJS package fixes
#
# Please insert new packages *alphabetically*
# in the OTHER PACKAGES section.
{ pkgs, haskellLib }:

let
  removeLibraryHaskellDepends = pnames: depends:
    builtins.filter (e: !(builtins.elem (e.pname or "") pnames)) depends;
in

with haskellLib;

final: prev:

## GENERAL SETUP BASE PACKAGES

  let # The stage 1 packages
      stage1 = pkgs.lib.genAttrs prev.ghc.stage1Packages (pkg: null);
      # The stage 2 packages. Regenerate with ../compilers/ghcjs/gen-stage2.rb
      stage2 = prev.ghc.mkStage2 {
        inherit (final) callPackage;
      };
  in stage1 // stage2 // {

  # GHCJS does not ship with the same core packages as GHC.
  # https://github.com/ghcjs/ghcjs/issues/676
  stm = final.stm_2_5_0_0;
  ghc-compact = final.ghc-compact_0_1_0_0;

  network = addBuildTools prev.network (pkgs.lib.optional pkgs.buildPlatform.isDarwin pkgs.buildPackages.darwin.libiconv);
  zlib = addBuildTools prev.zlib (pkgs.lib.optional pkgs.buildPlatform.isDarwin pkgs.buildPackages.darwin.libiconv);
  unix-compat = addBuildTools prev.unix-compat (pkgs.lib.optional pkgs.buildPlatform.isDarwin pkgs.buildPackages.darwin.libiconv);

  # LLVM is not supported on this GHC; use the latest one.
  inherit (pkgs) llvmPackages;

  inherit (final.ghc.bootPkgs)
    jailbreak-cabal alex happy gtk2hs-buildtools rehoo hoogle;

  # Don't set integer-simple to null!
  # GHCJS uses integer-gmp, so any package expression that depends on
  # integer-simple is wrong.
  #integer-simple = null;

  # These packages are core libraries in GHC 8.6..x, but not here.
  bin-package-db = null;
  haskeline = final.haskeline_0_7_5_0;
  hpc = final.hpc_0_6_0_3;
  terminfo = final.terminfo_0_4_1_4;
  xhtml = final.xhtml_3000_2_2_1;

## OTHER PACKAGES

  # haddock throws the error: No input file(s).
  fail = dontHaddock prev.fail;

  cereal = addBuildDepend prev.cereal [ final.fail ];

  entropy = overrideCabal prev.entropy (old: {
    postPatch = old.postPatch or "" + ''
      # cabal doesn’t find ghc in this script, since it’s in the bootPkgs
      sed -e '/Simple.Program/a import Distribution.Simple.Program.Types' \
          -e 's|mConf.*=.*$|mConf = Just $ simpleConfiguredProgram "ghc" (FoundOnSystem "${final.ghc.bootPkgs.ghc}/bin/ghc")|g' -i Setup.hs
    '';
  });

  # https://github.com/kazu-yamamoto/logger/issues/97
  fast-logger = overrideCabal prev.fast-logger (old: {
    postPatch = old.postPatch or "" + ''
      # remove the Safe extensions, since ghcjs-boot directory
      # doesn’t provide Trustworthy
      sed -ie '/LANGUAGE Safe/d' System/Log/FastLogger/*.hs
      cat System/Log/FastLogger/Date.hs
    '';
  });

  # experimental
  ghcjs-ffiqq = final.callPackage
    ({ mkDerivation, base, template-haskell, ghcjs-base, split, containers, text, ghc-prim
     }:
     mkDerivation {
       pname = "ghcjs-ffiqq";
       version = "0.1.0.0";
       src = pkgs.fetchFromGitHub {
         owner = "ghcjs";
         repo = "ghcjs-ffiqq";
         rev = "b52338c2dcd3b0707bc8aff2e171411614d4aedb";
         sha256 = "08zxfm1i6zb7n8vbz3dywdy67vkixfyw48580rwfp48rl1s2z1c7";
       };
       libraryHaskellDepends = [
         base template-haskell ghcjs-base split containers text ghc-prim
       ];
       description = "FFI QuasiQuoter for GHCJS";
       license = pkgs.stdenv.lib.licenses.mit;
     }) {};
  # experimental
  ghcjs-vdom = final.callPackage
    ({ mkDerivation, base, ghc-prim, ghcjs-ffiqq, ghcjs-base, ghcjs-prim
      , containers, split, template-haskell
    }:
    mkDerivation rec {
      pname = "ghcjs-vdom";
      version = "0.2.0.0";
      src = pkgs.fetchFromGitHub {
        owner = "ghcjs";
        repo = pname;
        rev = "1c1175ba22eca6d7efa96f42a72290ade193c148";
        sha256 = "0c6l1dk2anvz94yy5qblrfh2iv495rjq4qmhlycc24dvd02f7n9m";
      };
      libraryHaskellDepends = [
        base ghc-prim ghcjs-ffiqq ghcjs-base ghcjs-prim containers split
        template-haskell
      ];
      license = pkgs.stdenv.lib.licenses.mit;
      description = "bindings for https://github.com/Matt-Esch/virtual-dom";
    }) {};

  ghcjs-dom = overrideCabal prev.ghcjs-dom (drv: {
    libraryHaskellDepends = with final; [
      ghcjs-base ghcjs-dom-jsffi text transformers
    ];
    configureFlags = [ "-fjsffi" "-f-webkit" ];
  });

  ghcjs-dom-jsffi = overrideCabal prev.ghcjs-dom-jsffi (drv: {
    libraryHaskellDepends = (drv.libraryHaskellDepends or []) ++ [ final.ghcjs-base final.text ];
    isLibrary = true;
  });

  ghc-paths = overrideCabal prev.ghc-paths (drv: {
    patches = [ ./patches/ghc-paths-nix-ghcjs.patch ];
  });

  http2 = addBuildDepends prev.http2 [ final.aeson final.aeson-pretty final.hex final.unordered-containers final.vector final.word8 ];
  # ghcjsBoot uses async 2.0.1.6, protolude wants 2.1.*

  # These are the correct dependencies specified when calling `cabal2nix --compiler ghcjs`
  # By default, the `miso` derivation present in hackage-packages.nix
  # does not contain dependencies suitable for ghcjs
  miso = overrideCabal prev.miso (drv: {
      libraryHaskellDepends = with final; [
        BoundedChan bytestring containers ghcjs-base aeson base
        http-api-data http-types network-uri scientific servant text
        transformers unordered-containers vector
      ];
    });

  pqueue = overrideCabal prev.pqueue (drv: {
    postPatch = ''
      sed -i -e '12s|null|Data.PQueue.Internals.null|' Data/PQueue/Internals.hs
      sed -i -e '64s|null|Data.PQueue.Internals.null|' Data/PQueue/Internals.hs
      sed -i -e '32s|null|Data.PQueue.Internals.null|' Data/PQueue/Min.hs
      sed -i -e '32s|null|Data.PQueue.Max.null|' Data/PQueue/Max.hs
      sed -i -e '42s|null|Data.PQueue.Prio.Internals.null|' Data/PQueue/Prio/Min.hs
      sed -i -e '42s|null|Data.PQueue.Prio.Max.null|' Data/PQueue/Prio/Max.hs
    '';
  });

  profunctors = overrideCabal prev.profunctors (drv: {
    preConfigure = ''
      sed -i 's/^{-# ANN .* #-}//' src/Data/Profunctor/Unsafe.hs
    '';
  });

  protolude = doJailbreak prev.protolude;

  # reflex 0.3, made compatible with the newest GHCJS.
  reflex = overrideCabal prev.reflex (drv: {
    src = pkgs.fetchFromGitHub {
      owner = "ryantrinkle";
      repo = "reflex";
      rev = "cc62c11a6cde31412582758c236919d4bb766ada";
      sha256 = "1j4vw0636bkl46lj8ry16i04vgpivjc6bs3ls54ppp1wfp63q7w4";
    };
  });

  # reflex-dom 0.2, made compatible with the newest GHCJS.
  reflex-dom = overrideCabal prev.reflex-dom (drv: {
    src = pkgs.fetchFromGitHub {
      owner = "ryantrinkle";
      repo = "reflex-dom";
      rev = "639d9ca13c2def075e83344c9afca6eafaf24219";
      sha256 = "0166ihbh3dbfjiym9w561svpgvj0x4i8i8ws70xaafi0cmpsxrar";
    };
    libraryHaskellDepends =
      removeLibraryHaskellDepends [
        "glib" "gtk3" "webkitgtk3" "webkitgtk3-javascriptcore" "raw-strings-qq" "unix"
      ] drv.libraryHaskellDepends;
  });

  transformers-compat = overrideCabal prev.transformers-compat (drv: {
    configureFlags = [];
  });

  # triggers an internal pattern match failure in haddock
  # https://github.com/haskell/haddock/issues/553
  wai = dontHaddock prev.wai;

  base-orphans = dontCheck prev.base-orphans;
  distributive = dontCheck prev.distributive;

  # https://github.com/glguy/th-abstraction/issues/53
  th-abstraction = dontCheck prev.th-abstraction;
  # https://github.com/dreixel/syb/issues/21
  syb = dontCheck prev.syb;
  # https://github.com/ghcjs/ghcjs/issues/677
  hspec-core = dontCheck prev.hspec-core;
}
