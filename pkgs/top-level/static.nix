# Overlay that builds static packages.

# Not all packages will build but support is done on a
# best effort basic.
#
# Note on Darwin/macOS: Apple does not provide a static libc
# so any attempts at static binaries are going to be very
# unsupported.
#
# Basic things like pkgsStatic.hello should work out of the box. More
# complicated things will need to be fixed with overrides.

final: prev: let
  inherit (prev.stdenvAdapters) makeStaticBinaries
                                 makeStaticLibraries
                                 propagateBuildInputs;
  inherit (prev.lib) foldl optional flip id composeExtensions optionalAttrs;
  inherit (prev) makeSetupHook;

  # Best effort static binaries. Will still be linked to libSystem,
  # but more portable than Nix store binaries.
  makeStaticDarwin = stdenv: stdenv // {
    mkDerivation = args: stdenv.mkDerivation (args // {
      NIX_CFLAGS_LINK = toString (args.NIX_CFLAGS_LINK or "")
                      + " -static-libgcc";
      nativeBuildInputs = (args.nativeBuildInputs or []) ++ [ (makeSetupHook {
        substitutions = {
          libsystem = "${stdenv.cc.libc}/lib/libSystem.B.dylib";
        };
      } ../stdenv/darwin/portable-libsystem.sh) ];
    });
  };

  staticAdapters = [ makeStaticLibraries propagateBuildInputs ]

    # Apple does not provide a static version of libSystem or crt0.o
    # So we can’t build static binaries without extensive hacks.
    ++ optional (!prev.stdenv.hostPlatform.isDarwin) makeStaticBinaries

    ++ optional prev.stdenv.hostPlatform.isDarwin makeStaticDarwin

    # Glibc doesn’t come with static runtimes by default.
    # ++ optional (prev.stdenv.hostPlatform.libc == "glibc") ((flip overrideInStdenv) [ final.stdenv.glibc.static ])
  ;

  # Force everything to link statically.
  haskellStaticAdapter = final: prev: {
    mkDerivation = attrs: prev.mkDerivation (attrs // {
      enableSharedLibraries = false;
      enableSharedExecutables = false;
      enableStaticLibraries = true;
    });
  };

  removeUnknownConfigureFlags = f: with final.lib;
    remove "--disable-shared"
    (remove "--enable-static" f);

  ocamlFixPackage = b:
    b.overrideAttrs (o: {
      configurePlatforms = [ ];
      configureFlags = removeUnknownConfigureFlags (o.configureFlags or [ ]);
      buildInputs = o.buildInputs ++ o.nativeBuildInputs or [ ];
      propagatedNativeBuildInputs = o.propagatedBuildInputs or [ ];
    });

  ocamlStaticAdapter = _: prev:
    final.lib.mapAttrs
      (_: p: if p ? overrideAttrs then ocamlFixPackage p else p)
      prev
    // {
      lablgtk = null; # Currently xlibs cause infinite recursion
      ocaml = ((prev.ocaml.override { useX11 = false; }).overrideAttrs (o: {
        configurePlatforms = [ ];
        dontUpdateAutotoolsGnuConfigScripts = true;
      })).overrideDerivation (o: {
        preConfigure = ''
          configureFlagsArray+=("-cc" "$CC" "-as" "$AS" "-partialld" "$LD -r")
        '';
        configureFlags = (removeUnknownConfigureFlags o.configureFlags) ++ [
          "--no-shared-libs"
          "-host ${o.stdenv.hostPlatform.config}"
          "-target ${o.stdenv.targetPlatform.config}"
        ];
      });
    };

in {
  stdenv = foldl (flip id) prev.stdenv staticAdapters;
  gcc49Stdenv = foldl (flip id) prev.gcc49Stdenv staticAdapters;
  gcc6Stdenv = foldl (flip id) prev.gcc6Stdenv staticAdapters;
  gcc7Stdenv = foldl (flip id) prev.gcc7Stdenv staticAdapters;
  gcc8Stdenv = foldl (flip id) prev.gcc8Stdenv staticAdapters;
  gcc9Stdenv = foldl (flip id) prev.gcc9Stdenv staticAdapters;
  clangStdenv = foldl (flip id) prev.clangStdenv staticAdapters;
  libcxxStdenv = foldl (flip id) prev.libcxxStdenv staticAdapters;

  haskell = prev.haskell // {
    packageOverrides = composeExtensions
      (prev.haskell.packageOverrides or (_: _: {}))
      haskellStaticAdapter;
  };

  nghttp2 = prev.nghttp2.override {
    enableApp = false;
  };

  ncurses = prev.ncurses.override {
    enableStatic = true;
  };
  libxml2 = prev.libxml2.override ({
    enableShared = false;
    enableStatic = true;
  } // optionalAttrs prev.stdenv.hostPlatform.isDarwin {
    pythonSupport = false;
  });
  zlib = prev.zlib.override {
    static = true;
    shared = false;
    splitStaticOutput = false;

    # Don’t use new stdenv zlib because
    # it doesn’t like the --disable-shared flag
    stdenv = prev.stdenv;
  };
  xz = prev.xz.override {
    enableStatic = true;
  };
  busybox = prev.busybox.override {
    enableStatic = true;
  };
  libiberty = prev.libiberty.override {
    staticBuild = true;
  };
  libpfm = prev.libpfm.override {
    enableShared = false;
  };
  ipmitool = prev.ipmitool.override {
    static = true;
  };
  neon = prev.neon.override {
    static = true;
    shared = false;
  };
  fmt = prev.fmt.override {
    enableShared = false;
  };
  gifsicle = prev.gifsicle.override {
    static = true;
  };
  bzip2 = prev.bzip2.override {
    linkStatic = true;
  };
  optipng = prev.optipng.override {
    static = true;
  };
  openblas = prev.openblas.override {
    enableStatic = true;
    enableShared = false;
  };
  mkl = prev.mkl.override { enableStatic = true; };
  nix = prev.nix.override { enableStatic = true; };
  openssl = (prev.openssl_1_1.override { static = true; }).overrideAttrs (o: {
    # OpenSSL doesn't like the `--enable-static` / `--disable-shared` flags.
    configureFlags = (removeUnknownConfigureFlags o.configureFlags);
  });
  arrow-cpp = prev.arrow-cpp.override {
    enableShared = false;
  };
  boost = prev.boost.override {
    enableStatic = true;
    enableShared = false;

    # Don’t use new stdenv for boost because it doesn’t like the
    # --disable-shared flag
    stdenv = prev.stdenv;
  };
  thrift = prev.thrift.override {
    static = true;
    twisted = null;
  };
  gmp = prev.gmp.override {
    withStatic = true;
  };
  gflags = prev.gflags.override {
    enableShared = false;
  };
  cdo = prev.cdo.override {
    enable_all_static = true;
  };
  gsm = prev.gsm.override {
    staticSupport = true;
  };
  parted = prev.parted.override {
    enableStatic = true;
  };
  libiconvReal = prev.libiconvReal.override {
    enableShared = false;
    enableStatic = true;
  };
  perl = prev.perl.override {
    # Don’t use new stdenv zlib because
    # it doesn’t like the --disable-shared flag
    stdenv = prev.stdenv;
  };
  woff2 = prev.woff2.override {
    static = true;
  };
  snappy = prev.snappy.override {
    static = true;
  };
  lz4 = prev.lz4.override {
    enableShared = false;
    enableStatic = true;
  };
  libressl = prev.libressl.override {
    buildShared = false;
  };
  libjpeg_turbo = prev.libjpeg_turbo.override {
    enableStatic = true;
    enableShared = false;
  };

  darwin = prev.darwin // {
    libiconv = prev.darwin.libiconv.override {
      enableShared = false;
      enableStatic = true;
    };
  };

  kmod = prev.kmod.override {
    withStatic = true;
  };

  curl = prev.curl.override {
    # a very sad story: https://bugs.debian.org/cgi-bin/bugreport.cgi?bug=439039
    gssSupport = false;
  };

  e2fsprogs = prev.e2fsprogs.override {
    shared = false;
  };

  brotli = prev.brotli.override {
    staticOnly = true;
  };

  zstd = prev.zstd.override {
    static = true;
  };

  llvmPackages_8 = prev.llvmPackages_8 // {
    libraries = prev.llvmPackages_8.libraries // rec {
      libcxxabi = prev.llvmPackages_8.libraries.libcxxabi.override {
        enableShared = false;
      };
      libcxx = prev.llvmPackages_8.libraries.libcxx.override {
        enableShared = false;
        inherit libcxxabi;
      };
      libunwind = prev.llvmPackages_8.libraries.libunwind.override {
        enableShared = false;
      };
    };
  };

  ocaml-ng = final.lib.mapAttrs (_: set:
    if set ? overrideScope' then set.overrideScope' ocamlStaticAdapter else set
  ) prev.ocaml-ng;

  python27 = prev.python27.override { static = true; };
  python36 = prev.python36.override { static = true; };
  python37 = prev.python37.override { static = true; };
  python38 = prev.python38.override { static = true; };
  python39 = prev.python39.override { static = true; };
  python3Minimal = prev.python3Minimal.override { static = true; };


  libev = prev.libev.override { static = true; };

  libexecinfo = prev.libexecinfo.override { enableShared = false; };

  xorg = prev.xorg.overrideScope' (xorgself: xorgsuper: {
    libX11 = xorgsuper.libX11.overrideAttrs (attrs: {
      depsBuildBuild = attrs.depsBuildBuild ++ [ (final.buildPackages.stdenv.cc.libc.static or null) ];
    });
    xauth = xorgsuper.xauth.overrideAttrs (attrs: {
      # missing transitive dependencies
      preConfigure = attrs.preConfigure or "" + ''
        export NIX_CFLAGS_LINK="$NIX_CFLAGS_LINK -lxcb -lXau -lXdmcp"
      '';
    });
    xdpyinfo = xorgsuper.xdpyinfo.overrideAttrs (attrs: {
      # missing transitive dependencies
      preConfigure = attrs.preConfigure or "" + ''
        export NIX_CFLAGS_LINK="$NIX_CFLAGS_LINK -lXau -lXdmcp"
      '';
    });
    libxcb = xorgsuper.libxcb.overrideAttrs (attrs: {
      configureFlags = attrs.configureFlags ++ [ "--disable-shared" ];
    });
    libXi= xorgsuper.libXi.overrideAttrs (attrs: {
      configureFlags = attrs.configureFlags ++ [ "--disable-shared" ];
    });
  });
}
