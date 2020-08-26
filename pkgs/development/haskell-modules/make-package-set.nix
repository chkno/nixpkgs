# This expression takes a file like `hackage-packages.nix` and constructs
# a full package set out of that.

{ # package-set used for build tools (all of nixpkgs)
  buildPackages

, # A haskell package set for Setup.hs, compiler plugins, and similar
  # build-time uses.
  buildHaskellPackages

, # package-set used for non-haskell dependencies (all of nixpkgs)
  pkgs

, # stdenv to use for building haskell packages
  stdenv

, haskellLib

, # hashes for downloading Hackage packages
  all-cabal-hashes

, # compiler to use
  ghc

, # A function that takes `{ pkgs, stdenv, callPackage }` as the first arg and
  # `final` as second, and returns a set of haskell packages
  package-set

, # The final, fully overriden package set usable with the nixpkgs fixpoint
  # overriding functionality
  extensible-final
}:

# return value: a function from final to the package set
final:

let
  inherit (stdenv) buildPlatform hostPlatform;

  inherit (stdenv.lib) fix' extends makeOverridable;
  inherit (haskellLib) overrideCabal;

  mkDerivationImpl = pkgs.callPackage ./generic-builder.nix {
    inherit stdenv;
    nodejs = buildPackages.nodejs-slim;
    inherit (final) buildHaskellPackages ghc ghcWithHoogle ghcWithPackages;
    inherit (final.buildHaskellPackages) jailbreak-cabal;
    hscolour = overrideCabal final.buildHaskellPackages.hscolour (drv: {
      isLibrary = false;
      doHaddock = false;
      hyperlinkSource = false;      # Avoid depending on hscolour for this build.
      postFixup = "rm -rf $out/lib $out/share $out/nix-support";
    });
    cpphs = overrideCabal (final.cpphs.overrideScope (final: prev: {
      mkDerivation = drv: prev.mkDerivation (drv // {
        enableSharedExecutables = false;
        enableSharedLibraries = false;
        doHaddock = false;
        useCpphs = false;
      });
    })) (drv: {
        isLibrary = false;
        postFixup = "rm -rf $out/lib $out/share $out/nix-support";
    });
  };

  mkDerivation = makeOverridable mkDerivationImpl;

  # manualArgs are the arguments that were explictly passed to `callPackage`, like:
  #
  # callPackage foo { bar = null; };
  #
  # here `bar` is a manual argument.
  callPackageWithScope = scope: fn: manualArgs:
    let
      # this code is copied from callPackage in lib/customisation.nix
      #
      # we cannot use `callPackage` here because we want to call `makeOverridable`
      # on `drvScope` (we cannot add `overrideScope` after calling `callPackage` because then it is
      # lost on `.override`) but determine the auto-args based on `drv` (the problem here
      # is that nix has no way to "passthrough" args while preserving the reflection
      # info that callPackage uses to determine the arguments).
      drv = if stdenv.lib.isFunction fn then fn else import fn;
      auto = builtins.intersectAttrs (stdenv.lib.functionArgs drv) scope;

      # this wraps the `drv` function to add a `overrideScope` function to the result.
      drvScope = allArgs: drv allArgs // {
        overrideScope = f:
          let newScope = mkScope (fix' (extends f scope.__unfix__));
          # note that we have to be careful here: `allArgs` includes the auto-arguments that
          # weren't manually specified. If we would just pass `allArgs` to the recursive call here,
          # then we wouldn't look up any packages in the scope in the next interation, because it
          # appears as if all arguments were already manually passed, so the scope change would do
          # nothing.
          in callPackageWithScope newScope drv manualArgs;
      };
    in stdenv.lib.makeOverridable drvScope (auto // manualArgs);

  mkScope = scope: let
      ps = pkgs.__splicedPackages;
      scopeSpliced = pkgs.splicePackages {
        pkgsBuildBuild = scope.buildHaskellPackages.buildHaskellPackages;
        pkgsBuildHost = scope.buildHaskellPackages;
        pkgsBuildTarget = {};
        pkgsHostHost = {};
        pkgsHostTarget = scope;
        pkgsTargetTarget = {};
      } // {
        # Don't splice these
        inherit (scope) ghc buildHaskellPackages;
      };
    in ps // ps.xorg // ps.gnome2 // { inherit stdenv; } // scopeSpliced;
  defaultScope = mkScope final;
  callPackage = drv: args: callPackageWithScope defaultScope drv args;

  withPackages = packages: buildPackages.callPackage ./with-packages-wrapper.nix {
    inherit (final) ghc llvmPackages;
    inherit packages;
  };

  # Use cabal2nix to create a default.nix for the package sources found at 'src'.
  haskellSrc2nix = { name, src, sha256 ? null, extraCabal2nixOptions ? "" }:
    let
      sha256Arg = if sha256 == null then "--sha256=" else ''--sha256="${sha256}"'';
    in buildPackages.stdenv.mkDerivation {
      name = "cabal2nix-${name}";
      nativeBuildInputs = [ buildPackages.cabal2nix-unwrapped ];
      preferLocalBuild = true;
      allowSubstitutes = false;
      phases = ["installPhase"];
      LANG = "en_US.UTF-8";
      LOCALE_ARCHIVE = pkgs.lib.optionalString (buildPlatform.libc == "glibc") "${buildPackages.glibcLocales}/lib/locale/locale-archive";
      installPhase = ''
        export HOME="$TMP"
        mkdir -p "$out"
        cabal2nix --compiler=${final.ghc.haskellCompilerName} --system=${hostPlatform.config} ${sha256Arg} "${src}" ${extraCabal2nixOptions} > "$out/default.nix"
      '';
  };

  all-cabal-hashes-component = name: version: buildPackages.runCommand "all-cabal-hashes-component-${name}-${version}" {} ''
    tar --wildcards -xzvf ${all-cabal-hashes} \*/${name}/${version}/${name}.{json,cabal}
    mkdir -p $out
    mv */${name}/${version}/${name}.{json,cabal} $out
  '';

  hackage2nix = name: version: let component = all-cabal-hashes-component name version; in final.haskellSrc2nix {
    name   = "${name}-${version}";
    sha256 = ''$(sed -e 's/.*"SHA256":"//' -e 's/".*$//' "${component}/${name}.json")'';
    src    = "${component}/${name}.cabal";
  };

  # Adds a nix file as an input to the haskell derivation it
  # produces. This is useful for callHackage / callCabal2nix to
  # prevent the generated default.nix from being garbage collected
  # (requiring it to be frequently rebuilt), which can be an
  # annoyance.
  callPackageKeepDeriver = src: args:
    overrideCabal (final.callPackage src args) (orig: {
      preConfigure = ''
        # Generated from ${src}
        ${orig.preConfigure or ""}
      '';
      passthru = orig.passthru or {} // {
        # When using callCabal2nix or callHackage, it is often useful
        # to debug a failure by inspecting the Nix expression
        # generated by cabal2nix. This can be accessed via this
        # cabal2nixDeriver field.
        cabal2nixDeriver = src;
      };
    });

in package-set { inherit pkgs stdenv callPackage; } final // {

    inherit mkDerivation callPackage haskellSrc2nix hackage2nix buildHaskellPackages;

    inherit (haskellLib) packageSourceOverrides;

    # callHackage :: Text -> Text -> AttrSet -> HaskellPackage
    #
    # e.g., while overriding a package set:
    #    '... foo = final.callHackage "foo" "1.5.3" {}; ...'
    callHackage = name: version: callPackageKeepDeriver (final.hackage2nix name version);

    # callHackageDirect
    #   :: { pkg :: Text, ver :: Text, sha256 :: Text }
    #   -> AttrSet
    #   -> HaskellPackage
    #
    # This function does not depend on all-cabal-hashes and therefore will work
    # for any version that has been released on hackage as opposed to only
    # versions released before whatever version of all-cabal-hashes you happen
    # to be currently using.
    callHackageDirect = {pkg, ver, sha256}:
      let pkgver = "${pkg}-${ver}";
      in final.callCabal2nix pkg (pkgs.fetchzip {
           url = "mirror://hackage/${pkgver}/${pkgver}.tar.gz";
           inherit sha256;
         });

    # Creates a Haskell package from a source package by calling cabal2nix on the source.
    callCabal2nixWithOptions = name: src: extraCabal2nixOptions: args:
      let
        filter = path: type:
                   pkgs.lib.hasSuffix "${name}.cabal" path ||
                   baseNameOf path == "package.yaml";
        expr = final.haskellSrc2nix {
          inherit name extraCabal2nixOptions;
          src = if pkgs.lib.canCleanSource src
                  then pkgs.lib.cleanSourceWith { inherit src filter; }
                else src;
        };
      in overrideCabal (callPackageKeepDeriver expr args) (orig: {
           inherit src;
         });

    callCabal2nix = name: src: args: final.callCabal2nixWithOptions name src "" args;

    # : { root : Path
    #   , name : Defaulted String
    #   , source-overrides : Defaulted (Either Path VersionNumber)
    #   , overrides : Defaulted (HaskellPackageOverrideSet)
    #   , modifier : Defaulted
    #   , returnShellEnv : Defaulted
    #   } -> NixShellAwareDerivation
    # Given a path to a haskell package directory, an optional package name
    # which defaults to the base name of the path, an optional set of source
    # overrides as appropriate for the 'packageSourceOverrides' function, an
    # optional set of arbitrary overrides, and an optional haskell package
    # modifier, return a derivation appropriate for nix-build or nix-shell to
    # build that package.
    developPackage =
      { root
      , name ? builtins.baseNameOf root
      , source-overrides ? {}
      , overrides ? final: prev: {}
      , modifier ? drv: drv
      , returnShellEnv ? pkgs.lib.inNixShell }:
      let drv =
        (extensible-final.extend
           (pkgs.lib.composeExtensions
              (final.packageSourceOverrides source-overrides)
              overrides))
        .callCabal2nix name root {};
      in if returnShellEnv then (modifier drv).env else modifier drv;

    ghcWithPackages = selectFrom: withPackages (selectFrom final);

    ghcWithHoogle = selectFrom:
      let
        packages = selectFrom final;
        hoogle = callPackage ./hoogle.nix {
          inherit packages;
        };
      in withPackages (packages ++ [ hoogle ]);

    # Returns a derivation whose environment contains a GHC with only
    # the dependencies of packages listed in `packages`, not the
    # packages themselves. Using nix-shell on this derivation will
    # give you an environment suitable for developing the listed
    # packages with an incremental tool like cabal-install.
    # In addition to the "packages" arg and "withHoogle" arg, anything that
    # can be passed into stdenv.mkDerivation can be included in the input attrset
    #
    #     # default.nix
    #     with import <nixpkgs> {};
    #     haskellPackages.extend (haskell.lib.packageSourceOverrides {
    #       frontend = ./frontend;
    #       backend = ./backend;
    #       common = ./common;
    #     })
    #
    #     # shell.nix
    #     let pkgs = import <nixpkgs> {} in
    #     (import ./.).shellFor {
    #       packages = p: [p.frontend p.backend p.common];
    #       withHoogle = true;
    #       buildInputs = [ pkgs.python ];
    #     }
    #
    #     -- cabal.project
    #     packages:
    #       frontend/
    #       backend/
    #       common/
    #
    #     bash$ nix-shell --run "cabal new-build all"
    #     bash$ nix-shell --run "python"
    shellFor = { packages, withHoogle ? false, ... } @ args:
      let
        combinedPackageFor = packages:
          let
            selected = packages final;

            pname = if pkgs.lib.length selected == 1
              then (pkgs.lib.head selected).name
              else "packages";

            # If `packages = [ a b ]` and `a` depends on `b`, don't build `b`,
            # because cabal will end up ignoring that built version, assuming
            # new-style commands.
            combinedPackages = pkgs.lib.filter
              (input: pkgs.lib.all (p: input.outPath or null != p.outPath) selected);

            # Returns an attrset containing a combined list packages' inputs for each
            # stage of the build process
            packageInputs = pkgs.lib.zipAttrsWith
              (_: pkgs.lib.concatMap combinedPackages)
              (map (p: p.getCabalDeps) selected);

            genericBuilderArgs = {
              inherit pname;
              version = "0";
              license = null;
            } // packageInputs;

          in final.mkDerivation genericBuilderArgs;

        mkDerivationArgs = builtins.removeAttrs args [ "packages" "withHoogle" ];
      in ((combinedPackageFor packages).envFunc { inherit withHoogle; }).overrideAttrs (old: mkDerivationArgs // {
        nativeBuildInputs = old.nativeBuildInputs ++ mkDerivationArgs.nativeBuildInputs or [];
        buildInputs = old.buildInputs ++ mkDerivationArgs.buildInputs or [];
      });

    ghc = ghc // {
      withPackages = final.ghcWithPackages;
      withHoogle = final.ghcWithHoogle;
    };

  }
