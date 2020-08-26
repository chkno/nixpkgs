/* This file composes a single bootstrapping stage of the Nix Packages
   collection. That is, it imports the functions that build the various
   packages, and calls them with appropriate arguments. The result is a set of
   all the packages in the Nix Packages collection for some particular platform
   for some particular stage.

   Default arguments are only provided for bootstrapping
   arguments. Normal users should not import this directly but instead
   import `pkgs/default.nix` or `default.nix`. */


{ ## Misc parameters kept the same for all stages
  ##

  # Utility functions, could just import but passing in for efficiency
  lib

, # Use to reevaluate Nixpkgs; a dirty hack that should be removed
  nixpkgsFun

  ## Other parameters
  ##

, # Either null or an object in the form:
  #
  #   {
  #     pkgsBuildBuild = ...;
  #     pkgsBuildHost = ...;
  #     pkgsBuildTarget = ...;
  #     pkgsHostHost = ...;
  #     # pkgsHostTarget skipped on purpose.
  #     pkgsTargetTarget ...;
  #   }
  #
  # These are references to adjacent bootstrapping stages. The more familiar
  # `buildPackages` and `targetPackages` are defined in terms of them. If null,
  # they are instead defined internally as the current stage. This allows us to
  # avoid expensive splicing. `pkgsHostTarget` is skipped because it is always
  # defined as the current stage.
  adjacentPackages

, # The standard environment to use for building packages.
  stdenv

, # This is used because stdenv replacement and the stdenvCross do benefit from
  # the overridden configuration provided by the user, as opposed to the normal
  # bootstrapping stdenvs.
  allowCustomOverrides

, # Non-GNU/Linux OSes are currently "impure" platforms, with their libc
  # outside of the store.  Thus, GCC, GFortran, & co. must always look for files
  # in standard system directories (/usr/include, etc.)
  noSysDirs ? stdenv.buildPlatform.system != "x86_64-freebsd"
           && stdenv.buildPlatform.system != "i686-freebsd"
           && stdenv.buildPlatform.system != "x86_64-solaris"
           && stdenv.buildPlatform.system != "x86_64-kfreebsd-gnu"

, # The configuration attribute set
  config

, # A list of overlays (Additional `final: prev: { .. }` customization
  # functions) to be fixed together in the produced package set
  overlays
} @args:

let
  stdenvAdapters = final: prev:
    let res = import ../stdenv/adapters.nix final; in res // {
      stdenvAdapters = res;
    };

  trivialBuilders = final: prev:
    import ../build-support/trivial-builders.nix {
      inherit lib; inherit (final) stdenv stdenvNoCC; inherit (final.pkgsBuildHost.xorg) lndir;
      inherit (final) runtimeShell;
    };

  stdenvBootstappingAndPlatforms = final: prev: let
    withFallback = thisPkgs:
      (if adjacentPackages == null then final else thisPkgs)
      // { recurseForDerivations = false; };
  in {
    # Here are package sets of from related stages. They are all in the form
    # `pkgs{theirHost}{theirTarget}`. For example, `pkgsBuildHost` means their
    # host platform is our build platform, and their target platform is our host
    # platform. We only care about their host/target platforms, not their build
    # platform, because the the former two alone affect the interface of the
    # final package; the build platform is just an implementation detail that
    # should not leak.
    pkgsBuildBuild = withFallback adjacentPackages.pkgsBuildBuild;
    pkgsBuildHost = withFallback adjacentPackages.pkgsBuildHost;
    pkgsBuildTarget = withFallback adjacentPackages.pkgsBuildTarget;
    pkgsHostHost = withFallback adjacentPackages.pkgsHostHost;
    pkgsHostTarget = final // { recurseForDerivations = false; }; # always `final`
    pkgsTargetTarget = withFallback adjacentPackages.pkgsTargetTarget;

    # Older names for package sets. Use these when only the host platform of the
    # package set matter (i.e. use `buildPackages` where any of `pkgsBuild*`
    # would do, and `targetPackages` when any of `pkgsTarget*` would do (if we
    # had more than just `pkgsTargetTarget`).)
    buildPackages = final.pkgsBuildHost;
    pkgs = final.pkgsHostTarget;
    targetPackages = final.pkgsTargetTarget;

    inherit stdenv;
  };

  # The old identifiers for cross-compiling. These should eventually be removed,
  # and the packages that rely on them refactored accordingly.
  platformCompat = final: prev: let
    inherit (prev.stdenv) buildPlatform hostPlatform targetPlatform;
  in {
    inherit buildPlatform hostPlatform targetPlatform;
    inherit (hostPlatform) system;
  };

  splice = final: prev: import ./splice.nix lib final (adjacentPackages != null);

  allPackages = final: prev:
    let res = import ./all-packages.nix
      { inherit lib noSysDirs config overlays; }
      res final prev;
    in res;

  aliases = final: prev: lib.optionalAttrs (config.allowAliases or true) (import ./aliases.nix lib final prev);

  # stdenvOverrides is used to avoid having multiple of versions
  # of certain dependencies that were used in bootstrapping the
  # standard environment.
  stdenvOverrides = final: prev:
    (prev.stdenv.overrides or (_: _: {})) final prev;

  # Allow packages to be overridden globally via the `packageOverrides'
  # configuration option, which must be a function that takes `pkgs'
  # as an argument and returns a set of new or overridden packages.
  # The `packageOverrides' function is called with the *original*
  # (un-overridden) set of packages, allowing packageOverrides
  # attributes to refer to the original attributes (e.g. "foo =
  # ... pkgs.foo ...").
  configOverrides = final: prev:
    lib.optionalAttrs allowCustomOverrides
      ((config.packageOverrides or (prev: {})) prev);

  # Convenience attributes for instantitating package sets. Each of
  # these will instantiate a new version of allPackages. Currently the
  # following package sets are provided:
  #
  # - pkgsCross.<system> where system is a member of lib.systems.examples
  # - pkgsMusl
  # - pkgsi686Linux
  otherPackageSets = final: prev: {
    # This maps each entry in lib.systems.examples to its own package
    # set. Each of these will contain all packages cross compiled for
    # that target system. For instance, pkgsCross.rasberryPi.hello,
    # will refer to the "hello" package built for the ARM6-based
    # Raspberry Pi.
    pkgsCross = lib.mapAttrs (n: crossSystem:
                              nixpkgsFun { inherit crossSystem; })
                              lib.systems.examples;

    # All packages built with the Musl libc. This will override the
    # default GNU libc on Linux systems. Non-Linux systems are not
    # supported.
    pkgsMusl = if stdenv.hostPlatform.isLinux then nixpkgsFun {
      overlays = [ (final': prev': {
        pkgsMusl = prev';
      })] ++ overlays;
      ${if stdenv.hostPlatform == stdenv.buildPlatform
        then "localSystem" else "crossSystem"} = {
        parsed = stdenv.hostPlatform.parsed // {
          abi = {
            gnu = lib.systems.parse.abis.musl;
            gnueabi = lib.systems.parse.abis.musleabi;
            gnueabihf = lib.systems.parse.abis.musleabihf;
          }.${stdenv.hostPlatform.parsed.abi.name}
            or lib.systems.parse.abis.musl;
        };
      };
    } else throw "Musl libc only supports Linux systems.";

    # All packages built for i686 Linux.
    # Used by wine, firefox with debugging version of Flash, ...
    pkgsi686Linux = if stdenv.hostPlatform.isLinux && stdenv.hostPlatform.isx86 then nixpkgsFun {
      overlays = [ (final': prev': {
        pkgsi686Linux = prev';
      })] ++ overlays;
      ${if stdenv.hostPlatform == stdenv.buildPlatform
        then "localSystem" else "crossSystem"} = {
        parsed = stdenv.hostPlatform.parsed // {
          cpu = lib.systems.parse.cpuTypes.i686;
        };
      };
    } else throw "i686 Linux package set can only be used with the x86 family.";

    # Extend the package set with zero or more overlays. This preserves
    # preexisting overlays. Prefer to initialize with the right overlays
    # in one go when calling Nixpkgs, for performance and simplicity.
    appendOverlays = extraOverlays:
      if extraOverlays == []
      then final
      else import ./stage.nix (args // { overlays = args.overlays ++ extraOverlays; });

    # Extend the package set with a single overlay. This preserves
    # preexisting overlays. Prefer to initialize with the right overlays
    # in one go when calling Nixpkgs, for performance and simplicity.
    # Prefer appendOverlays if used repeatedly.
    extend = f: final.appendOverlays [f];

    # Fully static packages.
    # Currently uses Musl on Linux (couldn’t get static glibc to work).
    pkgsStatic = nixpkgsFun ({
      overlays = [ (final': prev': {
        pkgsStatic = prev';
      })] ++ overlays;
      crossOverlays = [ (import ./static.nix) ];
    } // lib.optionalAttrs stdenv.hostPlatform.isLinux {
      crossSystem = {
        parsed = stdenv.hostPlatform.parsed // {
          abi = {
            gnu = lib.systems.parse.abis.musl;
            gnueabi = lib.systems.parse.abis.musleabi;
            gnueabihf = lib.systems.parse.abis.musleabihf;
          }.${stdenv.hostPlatform.parsed.abi.name}
            or lib.systems.parse.abis.musl;
        };
      };
    });
  };

  # The complete chain of package set builders, applied from top to bottom.
  # stdenvOverlays must be last as it brings package forward from the
  # previous bootstrapping phases which have already been overlayed.
  toFix = lib.foldl' (lib.flip lib.extends) (final: {}) ([
    stdenvBootstappingAndPlatforms
    platformCompat
    stdenvAdapters
    trivialBuilders
    splice
    allPackages
    otherPackageSets
    aliases
    configOverrides
  ] ++ overlays ++ [
    stdenvOverrides ]);

in
  # Return the complete set of packages.
  lib.fix toFix
