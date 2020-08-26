{ pkgs ? import <nixpkgs> { }
, lib ? pkgs.lib
, stdenv ? pkgs.stdenv
}:

final: prev:

{
  automat = prev.automat.overridePythonAttrs (
    old: rec {
      propagatedBuildInputs = old.propagatedBuildInputs ++ [ final.m2r ];
    }
  );

  ansible = prev.ansible.overridePythonAttrs (
    old: {

      prePatch = pkgs.python.pkgs.ansible.prePatch or "";

      postInstall = pkgs.python.pkgs.ansible.postInstall or "";

      # Inputs copied from nixpkgs as ansible doesn't specify it's dependencies
      # in a correct manner.
      propagatedBuildInputs = old.propagatedBuildInputs ++ [
        final.pycrypto
        final.paramiko
        final.jinja2
        final.pyyaml
        final.httplib2
        final.six
        final.netaddr
        final.dnspython
        final.jmespath
        final.dopy
        final.ncclient
      ];
    }
  );

  ansible-lint = prev.ansible-lint.overridePythonAttrs (
    old: {
      buildInputs = old.buildInputs ++ [ final.setuptools-scm-git-archive ];
      preBuild = ''
        export HOME=$(mktemp -d)
      '';
    }
  );

  astroid = prev.astroid.overridePythonAttrs (
    old: rec {
      buildInputs = old.buildInputs ++ [ final.pytest-runner ];
      doCheck = false;
    }
  );

  av = prev.av.overridePythonAttrs (
    old: {
      nativeBuildInputs = old.nativeBuildInputs ++ [
        pkgs.pkgconfig
      ];
      buildInputs = old.buildInputs ++ [ pkgs.ffmpeg_4 ];
    }
  );

  bcrypt = prev.bcrypt.overridePythonAttrs (
    old: {
      buildInputs = old.buildInputs ++ [ pkgs.libffi ];
    }
  );

  cffi =
    # cffi is bundled with pypy
    if final.python.implementation == "pypy" then null else (
      prev.cffi.overridePythonAttrs (
        old: {
          buildInputs = old.buildInputs ++ [ pkgs.libffi ];
        }
      )
    );

  cftime = prev.cftime.overridePythonAttrs (
    old: {
      buildInputs = old.buildInputs ++ [
        final.cython
      ];
    }
  );

  configparser = prev.configparser.overridePythonAttrs (
    old: {
      buildInputs = old.buildInputs ++ [
        final.toml
      ];

      postPatch = ''
        substituteInPlace setup.py --replace 'setuptools.setup()' 'setuptools.setup(version="${old.version}")'
      '';
    }
  );

  cryptography = prev.cryptography.overridePythonAttrs (
    old: {
      buildInputs = old.buildInputs ++ [ pkgs.openssl ];
    }
  );

  django = (
    prev.django.overridePythonAttrs (
      old: {
        propagatedNativeBuildInputs = (old.propagatedNativeBuildInputs or [ ])
          ++ [ pkgs.gettext ];
      }
    )
  );

  django-bakery = prev.django-bakery.overridePythonAttrs (
    old: {
      configurePhase = ''
        if ! test -e LICENSE; then
          touch LICENSE
        fi
      '' + (old.configurePhase or "");
    }
  );

  dlib = prev.dlib.overridePythonAttrs (
    old: {
      # Parallel building enabled
      inherit (pkgs.python.pkgs.dlib) patches;

      enableParallelBuilding = true;
      dontUseCmakeConfigure = true;

      nativeBuildInputs = old.nativeBuildInputs ++ pkgs.dlib.nativeBuildInputs;
      buildInputs = old.buildInputs ++ pkgs.dlib.buildInputs;
    }
  );

  # Environment markers are not always included (depending on how a dep was defined)
  enum34 = if final.pythonAtLeast "3.4" then null else prev.enum34;

  faker = prev.faker.overridePythonAttrs (
    old: {
      buildInputs = old.buildInputs ++ [ final.pytest-runner ];
      doCheck = false;
    }
  );

  fancycompleter = prev.fancycompleter.overridePythonAttrs (
    old: {
      postPatch = ''
        substituteInPlace setup.py \
          --replace 'setup_requires="setupmeta"' 'setup_requires=[]' \
          --replace 'versioning="devcommit"' 'version="${old.version}"'
      '';
    }
  );

  fastparquet = prev.fastparquet.overridePythonAttrs (
    old: {
      buildInputs = old.buildInputs ++ [ final.pytest-runner ];
    }
  );

  grandalf = prev.grandalf.overridePythonAttrs (
    old: {
      buildInputs = old.buildInputs ++ [ final.pytest-runner ];
      doCheck = false;
    }
  );

  h3 = prev.h3.overridePythonAttrs (
    old: {
      preBuild = (old.preBuild or "") + ''
        substituteInPlace h3/h3.py \
          --replace "'{}/{}'.format(_dirname, libh3_path)" '"${pkgs.h3}/lib/libh3${pkgs.stdenv.hostPlatform.extensions.sharedLibrary}"'
      '';
    }
  );

  h5py = prev.h5py.overridePythonAttrs (
    old:
    if old.format != "wheel" then rec {
      nativeBuildInputs = old.nativeBuildInputs ++ [ pkgs.pkgconfig ];
      buildInputs = old.buildInputs ++ [ pkgs.hdf5 final.pkgconfig final.cython ];
      configure_flags = "--hdf5=${pkgs.hdf5}";
      postConfigure = ''
        ${final.python.executable} setup.py configure ${configure_flags}
      '';
    } else old
  );

  horovod = prev.horovod.overridePythonAttrs (
    old: {
      propagatedBuildInputs = old.propagatedBuildInputs ++ [ pkgs.openmpi ];
    }
  );

  imagecodecs = prev.imagecodecs.overridePythonAttrs (
    old: {
      patchPhase = ''
        substituteInPlace setup.py \
          --replace "/usr/include/openjpeg-2.3" \
                    "${pkgs.openjpeg.dev}/include/openjpeg-2.3"
        substituteInPlace setup.py \
          --replace "/usr/include/jxrlib" \
                    "$out/include/libjxr"
        substituteInPlace imagecodecs/_zopfli.c \
          --replace '"zopfli/zopfli.h"' \
                    '<zopfli.h>'
        substituteInPlace imagecodecs/_zopfli.c \
          --replace '"zopfli/zlib_container.h"' \
                    '<zlib_container.h>'
        substituteInPlace imagecodecs/_zopfli.c \
          --replace '"zopfli/gzip_container.h"' \
                    '<gzip_container.h>'
      '';

      preBuild = ''
        mkdir -p $out/include/libjxr
        ln -s ${pkgs.jxrlib}/include/libjxr/**/* $out/include/libjxr

      '';

      buildInputs = old.buildInputs ++ [
        # Commented out packages are declared required, but not actually
        # needed to build. They are not yet packaged for nixpkgs.
        # bitshuffle
        pkgs.brotli
        # brunsli
        pkgs.bzip2
        pkgs.c-blosc
        # charls
        pkgs.giflib
        pkgs.jxrlib
        pkgs.lcms
        pkgs.libaec
        pkgs.libaec
        pkgs.libjpeg_turbo
        # liblzf
        # liblzma
        pkgs.libpng
        pkgs.libtiff
        pkgs.libwebp
        pkgs.lz4
        pkgs.openjpeg
        pkgs.snappy
        # zfp
        pkgs.zopfli
        pkgs.zstd
        pkgs.zlib
      ];
    }
  );

  # importlib-metadata has an incomplete dependency specification
  importlib-metadata = prev.importlib-metadata.overridePythonAttrs (
    old: {
      propagatedBuildInputs = old.propagatedBuildInputs ++ lib.optional final.python.isPy2 final.pathlib2;
    }
  );

  intreehooks = prev.intreehooks.overridePythonAttrs (
    old: {
      doCheck = false;
    }
  );

  isort = prev.isort.overridePythonAttrs (
    old: {
      propagatedBuildInputs = old.propagatedBuildInputs ++ [ final.setuptools ];
    }
  );

  jupyter = prev.jupyter.overridePythonAttrs (
    old: rec {
      # jupyter is a meta-package. Everything relevant comes from the
      # dependencies. It does however have a jupyter.py file that conflicts
      # with jupyter-core so this meta solves this conflict.
      meta.priority = 100;
    }
  );

  kiwisolver = prev.kiwisolver.overridePythonAttrs (
    old: {
      buildInputs = old.buildInputs ++ [
        final.cppy
      ];
    }
  );

  lap = prev.lap.overridePythonAttrs (
    old: {
      propagatedBuildInputs = old.propagatedBuildInputs ++ [
        final.numpy
      ];
    }
  );

  libvirt-python = prev.libvirt-python.overridePythonAttrs ({ nativeBuildInputs ? [ ], ... }: {
    nativeBuildInputs = nativeBuildInputs ++ [ pkgs.pkgconfig ];
    propagatedBuildInputs = [ pkgs.libvirt ];
  });

  llvmlite = prev.llvmlite.overridePythonAttrs (
    old: {
      nativeBuildInputs = old.nativeBuildInputs ++ [ pkgs.llvm ];

      # Disable static linking
      # https://github.com/numba/llvmlite/issues/93
      postPatch = ''
        substituteInPlace ffi/Makefile.linux --replace "-static-libstdc++" ""

        substituteInPlace llvmlite/tests/test_binding.py --replace "test_linux" "nope"
      '';

      # Set directory containing llvm-config binary
      preConfigure = ''
        export LLVM_CONFIG=${pkgs.llvm}/bin/llvm-config
      '';

      __impureHostDeps = pkgs.stdenv.lib.optionals pkgs.stdenv.isDarwin [ "/usr/lib/libm.dylib" ];

      passthru = old.passthru // { llvm = pkgs.llvm; };
    }
  );

  lockfile = prev.lockfile.overridePythonAttrs (
    old: {
      propagatedBuildInputs = old.propagatedBuildInputs ++ [ final.pbr ];
    }
  );

  lxml = prev.lxml.overridePythonAttrs (
    old: {
      nativeBuildInputs = with pkgs; old.nativeBuildInputs ++ [ pkgconfig libxml2.dev libxslt.dev ];
      buildInputs = with pkgs; old.buildInputs ++ [ libxml2 libxslt ];
    }
  );

  markupsafe = prev.markupsafe.overridePythonAttrs (
    old: {
      src = old.src.override { pname = builtins.replaceStrings [ "markupsafe" ] [ "MarkupSafe" ] old.pname; };
    }
  );

  matplotlib = prev.matplotlib.overridePythonAttrs (
    old:
    let
      enableGhostscript = old.passthru.enableGhostscript or false;
      enableGtk3 = old.passthru.enableTk or false;
      enableQt = old.passthru.enableQt or false;
      enableTk = old.passthru.enableTk or false;

      inherit (pkgs.darwin.apple_sdk.frameworks) Cocoa;
    in
    {
      NIX_CFLAGS_COMPILE = stdenv.lib.optionalString stdenv.isDarwin "-I${pkgs.libcxx}/include/c++/v1";

      XDG_RUNTIME_DIR = "/tmp";

      buildInputs = old.buildInputs
        ++ lib.optional enableGhostscript pkgs.ghostscript
        ++ lib.optional stdenv.isDarwin [ Cocoa ];

      nativeBuildInputs = old.nativeBuildInputs ++ [
        pkgs.pkgconfig
      ];

      postPatch = ''
        cat > setup.cfg <<EOF
        [libs]
        system_freetype = True
        EOF
      '';

      propagatedBuildInputs = old.propagatedBuildInputs ++ [
        pkgs.libpng
        pkgs.freetype
      ]
        ++ stdenv.lib.optionals enableGtk3 [ pkgs.cairo final.pycairo pkgs.gtk3 pkgs.gobject-introspection final.pygobject3 ]
        ++ stdenv.lib.optionals enableTk [ pkgs.tcl pkgs.tk final.tkinter pkgs.libX11 ]
        ++ stdenv.lib.optionals enableQt [ final.pyqt5 ]
      ;

      inherit (prev.matplotlib) patches;
    }
  );

  # Calls Cargo at build time for source builds and is really tricky to package
  maturin = prev.maturin.override {
    preferWheel = true;
  };

  mccabe = prev.mccabe.overridePythonAttrs (
    old: {
      buildInputs = old.buildInputs ++ [ final.pytest-runner ];
      doCheck = false;
    }
  );

  mip = prev.mip.overridePythonAttrs (
    old: {
      nativeBuildInputs = old.nativeBuildInputs ++ [ pkgs.autoPatchelfHook ];

      buildInputs = old.buildInputs ++ [ pkgs.zlib final.cppy ];
    }
  );

  molecule =
    if lib.versionOlder prev.molecule.version "3.0.0" then (prev.molecule.overridePythonAttrs (
      old: {
        patches = (old.patches or [ ]) ++ [
          # Fix build with more recent setuptools versions
          (pkgs.fetchpatch {
            url = "https://github.com/ansible-community/molecule/commit/c9fee498646a702c77b5aecf6497cff324acd056.patch";
            sha256 = "1g1n45izdz0a3c9akgxx14zhdw6c3dkb48j8pq64n82fa6ndl1b7";
            excludes = [ "pyproject.toml" ];
          })
        ];
        buildInputs = old.buildInputs ++ [ final.setuptools-scm-git-archive ];
      }
    )) else prev.molecule.overridePythonAttrs (old: {
      buildInputs = old.buildInputs ++ [ final.setuptools-scm-git-archive ];
    });

  netcdf4 = prev.netcdf4.overridePythonAttrs (
    old: {
      buildInputs = old.buildInputs ++ [
        final.cython
      ];

      propagatedBuildInputs = old.propagatedBuildInputs ++ [
        pkgs.zlib
        pkgs.netcdf
        pkgs.hdf5
        pkgs.curl
        pkgs.libjpeg
      ];

      # Variables used to configure the build process
      USE_NCCONFIG = "0";
      HDF5_DIR = lib.getDev pkgs.hdf5;
      NETCDF4_DIR = pkgs.netcdf;
      CURL_DIR = pkgs.curl.dev;
      JPEG_DIR = pkgs.libjpeg.dev;
    }
  );

  numpy = prev.numpy.overridePythonAttrs (
    old:
    let
      blas = old.passthru.args.blas or pkgs.openblasCompat;
      blasImplementation = lib.nameFromURL blas.name "-";
      cfg = pkgs.writeTextFile {
        name = "site.cfg";
        text = (
          lib.generators.toINI
            { } {
            ${blasImplementation} = {
              include_dirs = "${blas}/include";
              library_dirs = "${blas}/lib";
            } // lib.optionalAttrs (blasImplementation == "mkl") {
              mkl_libs = "mkl_rt";
              lapack_libs = "";
            };
          }
        );
      };
    in
    {
      nativeBuildInputs = old.nativeBuildInputs ++ [ pkgs.gfortran ];
      buildInputs = old.buildInputs ++ [ blas final.cython ];
      enableParallelBuilding = true;
      preBuild = ''
        ln -s ${cfg} site.cfg
      '';
      passthru = old.passthru // {
        blas = blas;
        inherit blasImplementation cfg;
      };
    }
  );

  openexr = prev.openexr.overridePythonAttrs (
    old: rec {
      buildInputs = old.buildInputs ++ [ pkgs.openexr pkgs.ilmbase ];
      NIX_CFLAGS_COMPILE = [ "-I${pkgs.openexr.dev}/include/OpenEXR" "-I${pkgs.ilmbase.dev}/include/OpenEXR" ];
    }
  );

  parsel = prev.parsel.overridePythonAttrs (
    old: rec {
      nativeBuildInputs = old.nativeBuildInputs ++ [ final.pytest-runner ];
    }
  );

  peewee = prev.peewee.overridePythonAttrs (
    old:
    let
      withPostgres = old.passthru.withPostgres or false;
      withMysql = old.passthru.withMysql or false;
    in
    {
      buildInputs = old.buildInputs ++ [ final.cython pkgs.sqlite ];
      propagatedBuildInputs = old.propagatedBuildInputs
        ++ lib.optional withPostgres final.psycopg2
        ++ lib.optional withMysql final.mysql-connector;
    }
  );

  pillow = prev.pillow.overridePythonAttrs (
    old: {
      nativeBuildInputs = [ pkgs.pkgconfig ] ++ old.nativeBuildInputs;
      buildInputs = with pkgs; [ freetype libjpeg zlib libtiff libwebp tcl lcms2 ] ++ old.buildInputs;
    }
  );

  psycopg2 = prev.psycopg2.overridePythonAttrs (
    old: {
      buildInputs = old.buildInputs
        ++ lib.optional stdenv.isDarwin pkgs.openssl;
      nativeBuildInputs = old.nativeBuildInputs ++ [ pkgs.postgresql ];
    }
  );

  psycopg2-binary = prev.psycopg2-binary.overridePythonAttrs (
    old: {
      buildInputs = old.buildInputs
        ++ lib.optional stdenv.isDarwin pkgs.openssl;
      nativeBuildInputs = old.nativeBuildInputs ++ [ pkgs.postgresql ];
    }
  );

  pyarrow =
    if lib.versionAtLeast prev.pyarrow.version "0.16.0" then prev.pyarrow.overridePythonAttrs (
      old:
      let
        parseMinor = drv: lib.concatStringsSep "." (lib.take 2 (lib.splitVersion drv.version));

        # Starting with nixpkgs revision f149c7030a7, pyarrow takes "python3" as an argument
        # instead of "python". Below we inspect function arguments to maintain compatibilitiy.
        _arrow-cpp = pkgs.arrow-cpp.override (
          builtins.intersectAttrs
            (lib.functionArgs pkgs.arrow-cpp.override) { python = final.python; python3 = final.python; }
        );

        ARROW_HOME = _arrow-cpp;
        arrowCppVersion = parseMinor pkgs.arrow-cpp;
        pyArrowVersion = parseMinor prev.pyarrow;
        errorMessage = "arrow-cpp version (${arrowCppVersion}) mismatches pyarrow version (${pyArrowVersion})";
      in
      if arrowCppVersion != pyArrowVersion then throw errorMessage else {

        nativeBuildInputs = old.nativeBuildInputs ++ [
          final.cython
          pkgs.pkgconfig
          pkgs.cmake
        ];

        preBuild = ''
          export PYARROW_PARALLEL=$NIX_BUILD_CORES
        '';

        PARQUET_HOME = _arrow-cpp;
        inherit ARROW_HOME;

        buildInputs = old.buildInputs ++ [
          pkgs.arrow-cpp
        ];

        PYARROW_BUILD_TYPE = "release";
        PYARROW_WITH_PARQUET = true;
        PYARROW_CMAKE_OPTIONS = [
          "-DCMAKE_INSTALL_RPATH=${ARROW_HOME}/lib"

          # This doesn't use setup hook to call cmake so we need to workaround #54606
          # ourselves
          "-DCMAKE_POLICY_DEFAULT_CMP0025=NEW"
        ];

        dontUseCmakeConfigure = true;
      }
    ) else prev.pyarrow.overridePythonAttrs (
      old: {
        nativeBuildInputs = old.nativeBuildInputs ++ [
          final.cython
        ];
      }
    );

  pycairo = (
    drv: (
      drv.overridePythonAttrs (
        _: {
          format = "other";
        }
      )
    ).overridePythonAttrs (
      old: {

        nativeBuildInputs = old.nativeBuildInputs ++ [
          pkgs.meson
          pkgs.ninja
          pkgs.pkgconfig
        ];

        propagatedBuildInputs = old.propagatedBuildInputs ++ [
          pkgs.cairo
          pkgs.xlibsWrapper
        ];

        mesonFlags = [ "-Dpython=${if final.isPy3k then "python3" else "python"}" ];
      }
    )
  )
    prev.pycairo;

  pycocotools = prev.pycocotools.overridePythonAttrs (
    old: {
      buildInputs = old.buildInputs ++ [
        final.cython
        final.numpy
      ];
    }
  );

  pygame = prev.pygame.overridePythonAttrs (
    old: rec {
      nativeBuildInputs = [
        pkgs.pkg-config
        pkgs.SDL
      ];

      buildInputs = [
        pkgs.SDL
        pkgs.SDL_image
        pkgs.SDL_mixer
        pkgs.SDL_ttf
        pkgs.libpng
        pkgs.libjpeg
        pkgs.portmidi
        pkgs.xorg.libX11
        pkgs.freetype
      ];

      # Tests fail because of no audio device and display.
      doCheck = false;
      preConfigure = ''
        sed \
          -e "s/origincdirs = .*/origincdirs = []/" \
          -e "s/origlibdirs = .*/origlibdirs = []/" \
          -e "/'\/lib\/i386-linux-gnu', '\/lib\/x86_64-linux-gnu']/d" \
          -e "/\/include\/smpeg/d" \
          -i buildconfig/config_unix.py
        ${lib.concatMapStrings (dep: ''
          sed \
            -e "/origincdirs =/a\        origincdirs += ['${lib.getDev dep}/include']" \
            -e "/origlibdirs =/a\        origlibdirs += ['${lib.getLib dep}/lib']" \
            -i buildconfig/config_unix.py
        '') buildInputs
        }
        LOCALBASE=/ ${final.python.interpreter} buildconfig/config.py
      '';
    }
  );

  pygobject = prev.pygobject.overridePythonAttrs (
    old: {
      nativeBuildInputs = old.nativeBuildInputs ++ [ pkgs.pkgconfig ];
      buildInputs = old.buildInputs ++ [ pkgs.glib pkgs.gobject-introspection ];
    }
  );

  pylint = prev.pylint.overridePythonAttrs (
    old: {
      buildInputs = old.buildInputs ++ [ final.pytest-runner ];
      doCheck = false;
    }
  );

  pyopenssl = prev.pyopenssl.overridePythonAttrs (
    old: {
      buildInputs = old.buildInputs ++ [ pkgs.openssl ];
    }
  );

  python-ldap = prev.python-ldap.overridePythonAttrs (
    old: {
      buildInputs = old.buildInputs ++ [ pkgs.openldap pkgs.cyrus_sasl ];
    }
  );

  pytoml = prev.pytoml.overridePythonAttrs (
    old: {
      doCheck = false;
    }
  );

  pyqt5 =
    let
      drv = prev.pyqt5;
      withConnectivity = drv.passthru.args.withConnectivity or false;
      withMultimedia = drv.passthru.args.withMultimedia or false;
      withWebKit = drv.passthru.args.withWebKit or false;
      withWebSockets = drv.passthru.args.withWebSockets or false;
    in
    prev.pyqt5.overridePythonAttrs (
      old: {
        format = "other";

        nativeBuildInputs = old.nativeBuildInputs ++ [
          pkgs.pkgconfig
          pkgs.qt5.qmake
          pkgs.xorg.lndir
          pkgs.qt5.qtbase
          pkgs.qt5.qtsvg
          pkgs.qt5.qtdeclarative
          pkgs.qt5.qtwebchannel
          # final.pyqt5-sip
          final.sip
        ]
          ++ lib.optional withConnectivity pkgs.qt5.qtconnectivity
          ++ lib.optional withMultimedia pkgs.qt5.qtmultimedia
          ++ lib.optional withWebKit pkgs.qt5.qtwebkit
          ++ lib.optional withWebSockets pkgs.qt5.qtwebsockets
        ;

        buildInputs = old.buildInputs ++ [
          pkgs.dbus
          pkgs.qt5.qtbase
          pkgs.qt5.qtsvg
          pkgs.qt5.qtdeclarative
          final.sip
        ]
          ++ lib.optional withConnectivity pkgs.qt5.qtconnectivity
          ++ lib.optional withWebKit pkgs.qt5.qtwebkit
          ++ lib.optional withWebSockets pkgs.qt5.qtwebsockets
        ;

        # Fix dbus mainloop
        patches = pkgs.python3.pkgs.pyqt5.patches or [ ];

        configurePhase = ''
          runHook preConfigure

          export PYTHONPATH=$PYTHONPATH:$out/${final.python.sitePackages}

          mkdir -p $out/${final.python.sitePackages}/dbus/mainloop
          ${final.python.executable} configure.py  -w \
            --confirm-license \
            --no-qml-plugin \
            --bindir=$out/bin \
            --destdir=$out/${final.python.sitePackages} \
            --stubsdir=$out/${final.python.sitePackages}/PyQt5 \
            --sipdir=$out/share/sip/PyQt5 \
            --designer-plugindir=$out/plugins/designer

          runHook postConfigure
        '';

        postInstall = ''
          ln -s ${final.pyqt5-sip}/${final.python.sitePackages}/PyQt5/sip.* $out/${final.python.sitePackages}/PyQt5/
          for i in $out/bin/*; do
            wrapProgram $i --prefix PYTHONPATH : "$PYTHONPATH"
          done

          # Let's make it a namespace package
          cat << EOF > $out/${final.python.sitePackages}/PyQt5/__init__.py
          from pkgutil import extend_path
          __path__ = extend_path(__path__, __name__)
          EOF
        '';

        installCheckPhase =
          let
            modules = [
              "PyQt5"
              "PyQt5.QtCore"
              "PyQt5.QtQml"
              "PyQt5.QtWidgets"
              "PyQt5.QtGui"
            ]
            ++ lib.optional withWebSockets "PyQt5.QtWebSockets"
            ++ lib.optional withWebKit "PyQt5.QtWebKit"
            ++ lib.optional withMultimedia "PyQt5.QtMultimedia"
            ++ lib.optional withConnectivity "PyQt5.QtConnectivity"
            ;
            imports = lib.concatMapStrings (module: "import ${module};") modules;
          in
          ''
            echo "Checking whether modules can be imported..."
            ${final.python.interpreter} -c "${imports}"
          '';

        doCheck = true;

        enableParallelBuilding = true;
      }
    );

  pytest-datadir = prev.pytest-datadir.overridePythonAttrs (
    old: {
      postInstall = ''
        rm -f $out/LICENSE
      '';
    }
  );

  pytest = prev.pytest.overridePythonAttrs (
    old: {
      doCheck = false;
    }
  );

  pytest-runner = prev.pytest-runner or prev.pytestrunner;

  python-jose = prev.python-jose.overridePythonAttrs (
    old: {
      postPath = ''
        substituteInPlace setup.py --replace "'pytest-runner'," ""
        substituteInPlace setup.py --replace "'pytest-runner'" ""
      '';
    }
  );

  ffmpeg-python = prev.ffmpeg-python.overridePythonAttrs (
    old: {
      buildInputs = old.buildInputs ++ [ final.pytest-runner ];
    }
  );

  python-prctl = prev.python-prctl.overridePythonAttrs (
    old: {
      buildInputs = old.buildInputs ++ [
        pkgs.libcap
      ];
    }
  );

  pyzmq = prev.pyzmq.overridePythonAttrs (
    old: {
      nativeBuildInputs = old.nativeBuildInputs ++ [ pkgs.pkgconfig ];
      propagatedBuildInputs = old.propagatedBuildInputs ++ [ pkgs.zeromq ];
    }
  );

  rockset = prev.rockset.overridePythonAttrs (
    old: rec {
      postPatch = ''
        cp ./setup_rockset.py ./setup.py
      '';
    }
  );

  scaleapi = prev.scaleapi.overridePythonAttrs (
    old: {
      postPatch = ''
        substituteInPlace setup.py --replace "install_requires = ['requests>=2.4.2', 'enum34']" "install_requires = ['requests>=2.4.2']" || true
      '';
    }
  );

  pandas = prev.pandas.overridePythonAttrs (
    old: {
      nativeBuildInputs = old.nativeBuildInputs ++ [ final.cython ];
    }
  );

  panel = prev.panel.overridePythonAttrs (
    old: {
      nativeBuildInputs = old.nativeBuildInputs ++ [ pkgs.nodejs ];
    }
  );

  # Pybind11 is an undeclared dependency of scipy that we need to pick from nixpkgs
  # Make it not fail with infinite recursion
  pybind11 = prev.pybind11.overridePythonAttrs (
    old: {
      cmakeFlags = (old.cmakeFlags or [ ]) ++ [
        "-DPYBIND11_TEST=off"
      ];
      doCheck = false; # Circular test dependency
    }
  );

  scipy = prev.scipy.overridePythonAttrs (
    old:
    if old.format != "wheel" then {
      nativeBuildInputs = old.nativeBuildInputs ++ [ pkgs.gfortran ];
      propagatedBuildInputs = old.propagatedBuildInputs ++ [ final.pybind11 ];
      setupPyBuildFlags = [ "--fcompiler='gnu95'" ];
      enableParallelBuilding = true;
      buildInputs = old.buildInputs ++ [ final.numpy.blas ];
      preConfigure = ''
        sed -i '0,/from numpy.distutils.core/s//import setuptools;from numpy.distutils.core/' setup.py
        export NPY_NUM_BUILD_JOBS=$NIX_BUILD_CORES
      '';
      preBuild = ''
        ln -s ${final.numpy.cfg} site.cfg
      '';
    } else old
  );

  scikit-learn = prev.scikit-learn.overridePythonAttrs (
    old: {
      buildInputs = old.buildInputs ++ [
        pkgs.gfortran
        pkgs.glibcLocales
      ] ++ lib.optionals stdenv.cc.isClang [
        pkgs.llvmPackages.openmp
      ];

      nativeBuildInputs = old.nativeBuildInputs ++ [
        final.cython
      ];

      enableParallelBuilding = true;
    }
  );

  shapely = prev.shapely.overridePythonAttrs (
    old: {
      buildInputs = old.buildInputs ++ [ pkgs.geos final.cython ];
      inherit (pkgs.python3.pkgs.shapely) patches GEOS_LIBRARY_PATH;
    }
  );

  shellingham =
    if lib.versionAtLeast prev.shellingham.version "1.3.2" then (
      prev.shellingham.overridePythonAttrs (
        old: {
          format = "pyproject";
        }
      )
    ) else prev.shellingham;

  tables = prev.tables.overridePythonAttrs (
    old: {
      HDF5_DIR = "${pkgs.hdf5}";
      nativeBuildInputs = old.nativeBuildInputs ++ [ pkgs.pkgconfig ];
      propagatedBuildInputs = old.nativeBuildInputs ++ [ pkgs.hdf5 final.numpy final.numexpr ];
    }
  );

  tensorflow = prev.tensorflow.overridePythonAttrs (
    old: {
      postInstall = ''
        rm $out/bin/tensorboard
      '';
    }
  );

  tensorpack = prev.tensorpack.overridePythonAttrs (
    old: {
      postPatch = ''
        substituteInPlace setup.cfg --replace "# will call find_packages()" ""
      '';
    }
  );

  # nix uses a dash, poetry uses an underscore
  typing_extensions = prev.typing_extensions or final.typing-extensions;

  urwidtrees = prev.urwidtrees.overridePythonAttrs (
    old: {
      propagatedBuildInputs = old.propagatedBuildInputs ++ [
        final.urwid
      ];
    }
  );

  vose-alias-method = prev.vose-alias-method.overridePythonAttrs (
    old: {
      postInstall = ''
        rm -f $out/LICENSE
      '';
    }
  );

  vispy = prev.vispy.overrideAttrs (
    old: {
      inherit (pkgs.python3.pkgs.vispy) patches;
      nativeBuildInputs = old.nativeBuildInputs ++ [
        final.cython
        final.setuptools-scm-git-archive
      ];
    }
  );

  uvloop = prev.uvloop.overridePythonAttrs (
    old: {
      buildInputs = old.buildInputs ++ lib.optionals stdenv.isDarwin [
        pkgs.darwin.apple_sdk.frameworks.ApplicationServices
        pkgs.darwin.apple_sdk.frameworks.CoreServices
      ];
    }
  );


  # Stop infinite recursion by using bootstrapped pkg from nixpkgs
  bootstrapped-pip = prev.bootstrapped-pip.override {
    wheel = (pkgs.python3.pkgs.override {
      python = final.python;
    }).wheel;
  };
  wheel =
    let
      isWheel = prev.wheel.src.isWheel or false;
      # If "wheel" is a pre-built binary wheel
      wheelPackage = prev.buildPythonPackage {
        inherit (prev.wheel) pname name version src;
        inherit (pkgs.python3.pkgs.wheel) meta;
        format = "wheel";
      };
      # If "wheel" is built from source
      sourcePackage = (
        pkgs.python3.pkgs.override {
          python = final.python;
        }
      ).wheel.overridePythonAttrs (
        old: {
          inherit (prev.wheel) pname name version src;
        }
      );
    in
    if isWheel then wheelPackage else sourcePackage;

  zipp =
    (
      if lib.versionAtLeast prev.zipp.version "2.0.0" then (
        prev.zipp.overridePythonAttrs (
          old: {
            prePatch = ''
              substituteInPlace setup.py --replace \
              'setuptools.setup()' \
              'setuptools.setup(version="${prev.zipp.version}")'
            '';
          }
        )
      ) else prev.zipp
    ).overridePythonAttrs (
      old: {
        propagatedBuildInputs = old.propagatedBuildInputs ++ [
          final.toml
        ];
      }
    );

}
