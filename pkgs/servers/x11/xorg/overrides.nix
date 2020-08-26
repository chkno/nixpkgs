{ abiCompat ? null,
  stdenv, makeWrapper, fetchurl, fetchpatch, fetchFromGitLab, buildPackages,
  automake, autoconf, gettext, libiconv, libtool, intltool,
  freetype, tradcpp, fontconfig, meson, ninja, ed,
  libGL, spice-protocol, zlib, libGLU, dbus, libunwind, libdrm,
  mesa, udev, bootstrap_cmds, bison, flex, clangStdenv, autoreconfHook,
  mcpp, epoxy, openssl, pkgconfig, llvm_6, python3,
  ApplicationServices, Carbon, Cocoa, Xplugin
}:

let
  inherit (stdenv) lib isDarwin;
  inherit (lib) overrideDerivation;

  malloc0ReturnsNullCrossFlag = stdenv.lib.optional
    (stdenv.hostPlatform != stdenv.buildPlatform)
    "--enable-malloc0returnsnull";
in
final: prev:
{
  bdftopcf = prev.bdftopcf.overrideAttrs (attrs: {
    buildInputs = attrs.buildInputs ++ [ final.xorgproto ];
  });

  fonttosfnt = prev.fonttosfnt.overrideAttrs (attrs: {
    # https://gitlab.freedesktop.org/xorg/app/fonttosfnt/merge_requests/6
    patches = [ ./fix-uninitialised-memory.patch ];
  });

  bitmap = prev.bitmap.overrideAttrs (attrs: {
    nativeBuildInputs = attrs.nativeBuildInputs ++ [ makeWrapper ];
    postInstall = ''
      paths=(
        "$out/share/X11/%T/%N"
        "$out/include/X11/%T/%N"
        "${final.xbitmaps}/include/X11/%T/%N"
      )
      wrapProgram "$out/bin/bitmap" \
        --suffix XFILESEARCHPATH : $(IFS=:; echo "''${paths[*]}")
      makeWrapper "$out/bin/bitmap" "$out/bin/bitmap-color" \
        --suffix XFILESEARCHPATH : "$out/share/X11/%T/%N-color"
    '';
  });

  encodings = prev.encodings.overrideAttrs (attrs: {
    buildInputs = attrs.buildInputs ++ [ final.mkfontscale ];
  });

  editres = prev.editres.overrideAttrs (attrs: {
    hardeningDisable = [ "format" ];
  });

  fontbhttf = prev.fontbhttf.overrideAttrs (attrs: {
    meta = attrs.meta // { license = lib.licenses.unfreeRedistributable; };
  });

  fontmiscmisc = prev.fontmiscmisc.overrideAttrs (attrs: {
    postInstall =
      ''
        ALIASFILE=${final.fontalias}/share/fonts/X11/misc/fonts.alias
        test -f $ALIASFILE
        cp $ALIASFILE $out/lib/X11/fonts/misc/fonts.alias
      '';
  });

  imake = prev.imake.overrideAttrs (attrs: {
    inherit (final) xorgcffiles;
    x11BuildHook = ./imake.sh;
    patches = [./imake.patch ./imake-cc-wrapper-uberhack.patch];
    setupHook = ./imake-setup-hook.sh;
    CFLAGS = "-DIMAKE_COMPILETIME_CPP='\"${if stdenv.isDarwin
      then "${tradcpp}/bin/cpp"
      else "gcc"}\"'";

    inherit tradcpp;
  });

  mkfontdir = final.mkfontscale;

  libxcb = (prev.libxcb.override {
    python = python3;
  }).overrideAttrs (attrs: {
    configureFlags = [ "--enable-xkb" "--enable-xinput" ];
    outputs = [ "out" "dev" "man" "doc" ];
  });

  libX11 = prev.libX11.overrideAttrs (attrs: {
    outputs = [ "out" "dev" "man" ];
    patches = [
      # Fixes an issue that happens when cross-compiling for us.
      (fetchpatch {
        url = "https://cgit.freedesktop.org/xorg/lib/libX11/patch/?id=0327c427d62f671eced067c6d9b69f4e216a8cac";
        sha256 = "11k2mx56hjgw886zf1cdf2nhv7052d5rggimfshg6lq20i38vpza";
      })
    ];
    configureFlags = attrs.configureFlags or []
      ++ malloc0ReturnsNullCrossFlag;
    depsBuildBuild = [ buildPackages.stdenv.cc ];
    preConfigure = ''
      sed 's,^as_dummy.*,as_dummy="\$PATH",' -i configure
    '';
    postInstall =
      ''
        # Remove useless DocBook XML files.
        rm -rf $out/share/doc
      '';
    CPP = stdenv.lib.optionalString stdenv.isDarwin "clang -E -";
    propagatedBuildInputs = attrs.propagatedBuildInputs or [] ++ [ final.xorgproto ];
  });

  libAppleWM = prev.libAppleWM.overrideAttrs (attrs: {
    buildInputs = attrs.buildInputs ++ [ ApplicationServices ];
    preConfigure = ''
      substituteInPlace src/Makefile.in --replace -F/System -F${ApplicationServices}
    '';
  });

  libXau = prev.libXau.overrideAttrs (attrs: {
    outputs = [ "out" "dev" ];
    propagatedBuildInputs = attrs.propagatedBuildInputs or [] ++ [ final.xorgproto ];
  });

  libXdmcp = prev.libXdmcp.overrideAttrs (attrs: {
    outputs = [ "out" "dev" "doc" ];
  });

  libXfont = prev.libXfont.overrideAttrs (attrs: {
    outputs = [ "out" "dev" ];
    propagatedBuildInputs = attrs.propagatedBuildInputs or [] ++ [ freetype ]; # propagate link reqs. like bzip2
    # prevents "misaligned_stack_error_entering_dyld_stub_binder"
    configureFlags = lib.optional isDarwin "CFLAGS=-O0";
  });

  libXxf86vm = prev.libXxf86vm.overrideAttrs (attrs: {
    outputs = [ "out" "dev" ];
    configureFlags = attrs.configureFlags or []
      ++ malloc0ReturnsNullCrossFlag;
  });
  libXxf86dga = prev.libXxf86dga.overrideAttrs (attrs: {
    configureFlags = attrs.configureFlags or []
      ++ malloc0ReturnsNullCrossFlag;
  });
  libXxf86misc = prev.libXxf86misc.overrideAttrs (attrs: {
    configureFlags = attrs.configureFlags or []
      ++ malloc0ReturnsNullCrossFlag;
  });
  libdmx = prev.libdmx.overrideAttrs (attrs: {
    configureFlags = attrs.configureFlags or []
      ++ malloc0ReturnsNullCrossFlag;
  });
  xdpyinfo = prev.xdpyinfo.overrideAttrs (attrs: {
    configureFlags = attrs.configureFlags or []
      ++ malloc0ReturnsNullCrossFlag;
  });

  # Propagate some build inputs because of header file dependencies.
  # Note: most of these are in Requires.private, so maybe builder.sh
  # should propagate them automatically.
  libXt = prev.libXt.overrideAttrs (attrs: {
    preConfigure = ''
      sed 's,^as_dummy.*,as_dummy="\$PATH",' -i configure
    '';
    configureFlags = attrs.configureFlags or []
      ++ malloc0ReturnsNullCrossFlag;
    propagatedBuildInputs = attrs.propagatedBuildInputs or [] ++ [ final.libSM ];
    depsBuildBuild = [ buildPackages.stdenv.cc ];
    CPP = if stdenv.isDarwin then "clang -E -" else "${stdenv.cc.targetPrefix}cc -E -";
    outputs = [ "out" "dev" "devdoc" ];
  });

  luit = prev.luit.overrideAttrs (attrs: {
    # See https://bugs.freedesktop.org/show_bug.cgi?id=47792
    # Once the bug is fixed upstream, this can be removed.
    configureFlags = [ "--disable-selective-werror" ];

    buildInputs = attrs.buildInputs ++ [libiconv];
  });

  libICE = prev.libICE.overrideAttrs (attrs: {
    outputs = [ "out" "dev" "doc" ];
  });

  libXcomposite = prev.libXcomposite.overrideAttrs (attrs: {
    outputs = [ "out" "dev" ];
    propagatedBuildInputs = attrs.propagatedBuildInputs or [] ++ [ final.libXfixes ];
  });

  libXaw = prev.libXaw.overrideAttrs (attrs: {
    outputs = [ "out" "dev" "devdoc" ];
    propagatedBuildInputs = attrs.propagatedBuildInputs or [] ++ [ final.libXmu ];
  });

  libXcursor = prev.libXcursor.overrideAttrs (attrs: {
    outputs = [ "out" "dev" ];
  });

  libXdamage = prev.libXdamage.overrideAttrs (attrs: {
    outputs = [ "out" "dev" ];
  });

  libXft = prev.libXft.overrideAttrs (attrs: {
    outputs = [ "out" "dev" ];
    propagatedBuildInputs = attrs.propagatedBuildInputs or [] ++ [ final.libXrender freetype fontconfig ];
    configureFlags = attrs.configureFlags or []
      ++ malloc0ReturnsNullCrossFlag;

    patches = [
      # Adds color emoji rendering support.
      # https://gitlab.freedesktop.org/xorg/lib/libxft/merge_requests/1
      (fetchpatch {
        url = "https://gitlab.freedesktop.org/xorg/lib/libxft/commit/fe41537b5714a2301808eed2d76b2e7631176573.patch";
        sha256 = "045lp1q50i2wlwvpsq6ycxdc6p3asm2r3bk2nbad1dwkqw2xf9jc";
      })
    ];

    # the include files need ft2build.h, and Requires.private isn't enough for us
    postInstall = ''
      sed "/^Requires:/s/$/, freetype2/" -i "$dev/lib/pkgconfig/xft.pc"
    '';
    passthru = {
      inherit freetype fontconfig;
    };
  });

  libXext = prev.libXext.overrideAttrs (attrs: {
    outputs = [ "out" "dev" "man" "doc" ];
    propagatedBuildInputs = attrs.propagatedBuildInputs or [] ++ [ final.xorgproto final.libXau ];
    configureFlags = attrs.configureFlags or []
      ++ malloc0ReturnsNullCrossFlag;
  });

  libXfixes = prev.libXfixes.overrideAttrs (attrs: {
    outputs = [ "out" "dev" ];
  });

  libXi = prev.libXi.overrideAttrs (attrs: {
    outputs = [ "out" "dev" "man" "doc" ];
    propagatedBuildInputs = attrs.propagatedBuildInputs or [] ++ [ final.libXfixes ];
    configureFlags = stdenv.lib.optional (stdenv.hostPlatform != stdenv.buildPlatform)
      "xorg_cv_malloc0_returns_null=no";
  });

  libXinerama = prev.libXinerama.overrideAttrs (attrs: {
    outputs = [ "out" "dev" ];
    configureFlags = attrs.configureFlags or []
      ++ malloc0ReturnsNullCrossFlag;
  });

  libXmu = prev.libXmu.overrideAttrs (attrs: {
    outputs = [ "out" "dev" "doc" ];
    buildFlags = [ "BITMAP_DEFINES='-DBITMAPDIR=\"/no-such-path\"'" ];
  });

  libXrandr = prev.libXrandr.overrideAttrs (attrs: {
    outputs = [ "out" "dev" ];
    configureFlags = attrs.configureFlags or []
      ++ malloc0ReturnsNullCrossFlag;
    propagatedBuildInputs = attrs.propagatedBuildInputs or [] ++ [ final.libXrender ];
  });

  libSM = prev.libSM.overrideAttrs (attrs: {
    outputs = [ "out" "dev" "doc" ];
    propagatedBuildInputs = attrs.propagatedBuildInputs or [] ++ [ final.libICE ];
  });

  libXrender = prev.libXrender.overrideAttrs (attrs: {
    outputs = [ "out" "dev" "doc" ];
    configureFlags = attrs.configureFlags or []
      ++ malloc0ReturnsNullCrossFlag;
    propagatedBuildInputs = attrs.propagatedBuildInputs or [] ++ [ final.xorgproto ];
  });

  libXres = prev.libXres.overrideAttrs (attrs: {
    outputs = [ "out" "dev" "devdoc" ];
    buildInputs = with final; attrs.buildInputs ++ [ utilmacros ];
    configureFlags = attrs.configureFlags or []
      ++ malloc0ReturnsNullCrossFlag;
  });

  libXScrnSaver = prev.libXScrnSaver.overrideAttrs (attrs: {
    buildInputs = with final; attrs.buildInputs ++ [ utilmacros ];
    configureFlags = attrs.configureFlags or []
      ++ malloc0ReturnsNullCrossFlag;
  });

  libXv = prev.libXv.overrideAttrs (attrs: {
    outputs = [ "out" "dev" "devdoc" ];
    configureFlags = attrs.configureFlags or []
      ++ malloc0ReturnsNullCrossFlag;
  });

  libXvMC = prev.libXvMC.overrideAttrs (attrs: {
    outputs = [ "out" "dev" "doc" ];
    configureFlags = attrs.configureFlags or []
      ++ malloc0ReturnsNullCrossFlag;
    buildInputs = attrs.buildInputs ++ [final.xorgproto];
  });

  libXp = prev.libXp.overrideAttrs (attrs: {
    outputs = [ "out" "dev" ];
  });

  libXpm = prev.libXpm.overrideAttrs (attrs: {
    outputs = [ "bin" "dev" "out" ]; # tiny man in $bin
    patchPhase = "sed -i '/USE_GETTEXT_TRUE/d' sxpm/Makefile.in cxpm/Makefile.in";
  });

  libXpresent = prev.libXpresent.overrideAttrs (attrs: {
    buildInputs = with final; attrs.buildInputs ++ [ libXext libXfixes libXrandr ];
  });

  libxkbfile = prev.libxkbfile.overrideAttrs (attrs: {
    outputs = [ "out" "dev" ]; # mainly to avoid propagation
  });

  libxshmfence = prev.libxshmfence.overrideAttrs (attrs: {
    name = "libxshmfence-1.3";
    src = fetchurl {
      url = "mirror://xorg/individual/lib/libxshmfence-1.3.tar.bz2";
      sha256 = "1ir0j92mnd1nk37mrv9bz5swnccqldicgszvfsh62jd14q6k115q";
    };
    outputs = [ "out" "dev" ]; # mainly to avoid propagation
  });

  libpciaccess = prev.libpciaccess.overrideAttrs (attrs: {
    meta = attrs.meta // { platforms = stdenv.lib.platforms.linux; };
  });

  setxkbmap = prev.setxkbmap.overrideAttrs (attrs: {
    postInstall =
      ''
        mkdir -p $out/share
        ln -sfn ${final.xkeyboardconfig}/etc/X11 $out/share/X11
      '';
  });

  utilmacros = prev.utilmacros.overrideAttrs (attrs: { # not needed for releases, we propagate the needed tools
    propagatedBuildInputs = attrs.propagatedBuildInputs or [] ++ [ automake autoconf libtool ];
  });

  x11perf = prev.x11perf.overrideAttrs (attrs: {
    buildInputs = attrs.buildInputs ++ [ freetype fontconfig ];
  });

  xcbproto = prev.xcbproto.override {
    python = python3;
  };

  xcbutil = prev.xcbutil.overrideAttrs (attrs: {
    outputs = [ "out" "dev" ];
  });

  xcbutilcursor = prev.xcbutilcursor.overrideAttrs (attrs: {
    outputs = [ "out" "dev" ];
    meta = attrs.meta // { maintainers = [ stdenv.lib.maintainers.lovek323 ]; };
  });

  xcbutilimage = prev.xcbutilimage.overrideAttrs (attrs: {
    outputs = [ "out" "dev" ]; # mainly to get rid of propagating others
  });

  xcbutilkeysyms = prev.xcbutilkeysyms.overrideAttrs (attrs: {
    outputs = [ "out" "dev" ]; # mainly to get rid of propagating others
  });

  xcbutilrenderutil = prev.xcbutilrenderutil.overrideAttrs (attrs: {
    outputs = [ "out" "dev" ]; # mainly to get rid of propagating others
  });

  xcbutilwm = prev.xcbutilwm.overrideAttrs (attrs: {
    outputs = [ "out" "dev" ]; # mainly to get rid of propagating others
  });

  xf86inputevdev = prev.xf86inputevdev.overrideAttrs (attrs: {
    outputs = [ "out" "dev" ]; # to get rid of xorgserver.dev; man is tiny
    preBuild = "sed -e '/motion_history_proc/d; /history_size/d;' -i src/*.c";
    installFlags = [
      "sdkdir=${placeholder ''out''}/include/xorg"
    ];
  });

  xf86inputmouse = prev.xf86inputmouse.overrideAttrs (attrs: {
    installFlags = [
      "sdkdir=${placeholder ''out''}/include/xorg"
    ];
  });

  xf86inputjoystick = prev.xf86inputjoystick.overrideAttrs (attrs: {
    installFlags = [
      "sdkdir=${placeholder ''out''}/include/xorg"
    ];
  });

  xf86inputlibinput = prev.xf86inputlibinput.overrideAttrs (attrs: {
    outputs = [ "out" "dev" ];
    installFlags = [
      "sdkdir=${placeholder ''dev''}/include/xorg"
    ];
  });

  xf86inputsynaptics = prev.xf86inputsynaptics.overrideAttrs (attrs: {
    outputs = [ "out" "dev" ]; # *.pc pulls xorgserver.dev
    installFlags = [
      "sdkdir=${placeholder ''out''}/include/xorg"
      "configdir=${placeholder ''out''}/share/X11/xorg.conf.d"
    ];
  });

  xf86inputvmmouse = prev.xf86inputvmmouse.overrideAttrs (attrs: {
    configureFlags = [
      "--sysconfdir=${placeholder ''out''}/etc"
      "--with-xorg-conf-dir=${placeholder ''out''}/share/X11/xorg.conf.d"
      "--with-udev-rules-dir=${placeholder ''out''}/lib/udev/rules.d"
    ];

    meta = attrs.meta // {
      platforms = ["i686-linux" "x86_64-linux"];
    };
  });

  # Obsolete drivers that don't compile anymore.
  xf86videoark     = prev.xf86videoark.overrideAttrs     (attrs: { meta = attrs.meta // { broken = true; }; });
  xf86videogeode   = prev.xf86videogeode.overrideAttrs   (attrs: { meta = attrs.meta // { broken = true; }; });
  xf86videoglide   = prev.xf86videoglide.overrideAttrs   (attrs: { meta = attrs.meta // { broken = true; }; });
  xf86videoi128    = prev.xf86videoi128.overrideAttrs    (attrs: { meta = attrs.meta // { broken = true; }; });
  xf86videonewport = prev.xf86videonewport.overrideAttrs (attrs: { meta = attrs.meta // { broken = true; }; });
  xf86videos3virge = prev.xf86videos3virge.overrideAttrs (attrs: { meta = attrs.meta // { broken = true; }; });
  xf86videosavage  = prev.xf86videosavage.overrideAttrs  (attrs: { meta = attrs.meta // { broken = true; }; });
  xf86videotga     = prev.xf86videotga.overrideAttrs     (attrs: { meta = attrs.meta // { broken = true; }; });
  xf86videov4l     = prev.xf86videov4l.overrideAttrs     (attrs: { meta = attrs.meta // { broken = true; }; });
  xf86videovoodoo  = prev.xf86videovoodoo.overrideAttrs  (attrs: { meta = attrs.meta // { broken = true; }; });
  xf86videowsfb    = prev.xf86videowsfb.overrideAttrs    (attrs: { meta = attrs.meta // { broken = true; }; });

  xf86videoomap    = prev.xf86videoomap.overrideAttrs (attrs: {
    NIX_CFLAGS_COMPILE = [ "-Wno-error=format-overflow" ];
  });

  xf86videoamdgpu = prev.xf86videoamdgpu.overrideAttrs (attrs: {
    configureFlags = [ "--with-xorg-conf-dir=$(out)/share/X11/xorg.conf.d" ];
  });

  xf86videoati = prev.xf86videoati.overrideAttrs (attrs: {
    NIX_CFLAGS_COMPILE = "-I${final.xorgserver.dev or final.xorgserver}/include/xorg";
  });

  xf86videovmware = prev.xf86videovmware.overrideAttrs (attrs: {
    buildInputs =  attrs.buildInputs ++ [ mesa llvm_6 ]; # for libxatracker
    meta = attrs.meta // {
      platforms = ["i686-linux" "x86_64-linux"];
    };
  });

  xf86videoqxl = prev.xf86videoqxl.overrideAttrs (attrs: {
    buildInputs =  attrs.buildInputs ++ [ spice-protocol ];
  });

  xf86videosiliconmotion = prev.xf86videosiliconmotion.overrideAttrs (attrs: {
    meta = attrs.meta // {
      platforms = ["i686-linux" "x86_64-linux"];
    };
  });

  xdriinfo = prev.xdriinfo.overrideAttrs (attrs: {
    buildInputs = attrs.buildInputs ++ [libGL];
  });

  xvinfo = prev.xvinfo.overrideAttrs (attrs: {
    buildInputs = attrs.buildInputs ++ [final.libXext];
  });

  xkbcomp = prev.xkbcomp.overrideAttrs (attrs: {
    configureFlags = [ "--with-xkb-config-root=${final.xkeyboardconfig}/share/X11/xkb" ];
  });

  xkeyboardconfig = prev.xkeyboardconfig.overrideAttrs (attrs: {
    nativeBuildInputs = attrs.nativeBuildInputs ++ [intltool];

    configureFlags = [ "--with-xkb-rules-symlink=xorg" ];

    # 1: compatibility for X11/xkb location
    # 2: I think pkgconfig/ is supposed to be in /lib/
    postInstall = ''
      ln -s share "$out/etc"
      mkdir -p "$out/lib" && ln -s ../share/pkgconfig "$out/lib/"
    '';
  });

  # xkeyboardconfig variant extensible with custom layouts.
  # See nixos/modules/services/x11/extra-layouts.nix
  xkeyboardconfig_custom = { layouts ? { } }:
  let
    patchIn = name: layout:
    with layout;
    with lib;
    ''
        # install layout files
        ${optionalString (compatFile   != null) "cp '${compatFile}'   'compat/${name}'"}
        ${optionalString (geometryFile != null) "cp '${geometryFile}' 'geometry/${name}'"}
        ${optionalString (keycodesFile != null) "cp '${keycodesFile}' 'keycodes/${name}'"}
        ${optionalString (symbolsFile  != null) "cp '${symbolsFile}'  'symbols/${name}'"}
        ${optionalString (typesFile    != null) "cp '${typesFile}'    'types/${name}'"}

        # patch makefiles
        for type in compat geometry keycodes symbols types; do
          if ! test -f "$type/${name}"; then
            continue
          fi
          test "$type" = geometry && type_name=geom || type_name=$type
          ${ed}/bin/ed -v $type/Makefile.am <<EOF
        /''${type_name}_DATA =
        a
        ${name} \\
        .
        w
        EOF
          ${ed}/bin/ed -v $type/Makefile.in <<EOF
        /''${type_name}_DATA =
        a
        ${name} \\
        .
        w
        EOF
        done

        # add model description
        ${ed}/bin/ed -v rules/base.xml <<EOF
        /<\/modelList>
        -
        a
        <model>
          <configItem>
            <name>${name}</name>
            <description>${layout.description}</description>
            <vendor>${layout.description}</vendor>
          </configItem>
        </model>
        .
        w
        EOF

        # add layout description
        ${ed}/bin/ed -v rules/base.xml <<EOF
        /<\/layoutList>
        -
        a
        <layout>
          <configItem>
            <name>${name}</name>
            <shortDescription>${name}</shortDescription>
            <description>${layout.description}</description>
            <languageList>
              ${concatMapStrings (lang: "<iso639Id>${lang}</iso639Id>\n") layout.languages}
            </languageList>
          </configItem>
          <variantList/>
        </layout>
        .
        w
        EOF
    '';
  in
    final.xkeyboardconfig.overrideAttrs (old: {
      buildInputs = old.buildInputs ++ [ automake ];
      postPatch   = with lib; concatStrings (mapAttrsToList patchIn layouts);
    });

  xload = prev.xload.overrideAttrs (attrs: {
    nativeBuildInputs = attrs.nativeBuildInputs ++ [ gettext ];
  });

  xlsfonts = prev.xlsfonts.overrideAttrs (attrs: {
    meta = attrs.meta // { license = lib.licenses.mit; };
  });

  xorgproto = prev.xorgproto.overrideAttrs (attrs: {
    buildInputs = [];
    propagatedBuildInputs = [];
    nativeBuildInputs = attrs.nativeBuildInputs ++ [ meson ninja ];
    # adds support for printproto needed for libXp
    mesonFlags = [ "-Dlegacy=true" ];
  });

  xorgserver = with final; prev.xorgserver.overrideAttrs (attrs_passed:
    # exchange attrs if abiCompat is set
    let
      version = lib.getVersion attrs_passed;
      attrs =
        if (abiCompat == null || lib.hasPrefix abiCompat version) then
          attrs_passed // {
            buildInputs = attrs_passed.buildInputs ++ [ libdrm.dev ]; patchPhase = ''
            for i in dri3/*.c
            do
              sed -i -e "s|#include <drm_fourcc.h>|#include <libdrm/drm_fourcc.h>|" $i
            done
          '';}
        else if (abiCompat == "1.17") then {
          name = "xorg-server-1.17.4";
          builder = ./builder.sh;
          src = fetchurl {
            url = "mirror://xorg/individual/xserver/xorg-server-1.17.4.tar.bz2";
            sha256 = "0mv4ilpqi5hpg182mzqn766frhi6rw48aba3xfbaj4m82v0lajqc";
          };
          nativeBuildInputs = [ pkgconfig ];
          buildInputs = [ xorgproto libdrm openssl libX11 libXau libXaw libxcb xcbutil xcbutilwm xcbutilimage xcbutilkeysyms xcbutilrenderutil libXdmcp libXfixes libxkbfile libXmu libXpm libXrender libXres libXt ];
          meta.platforms = stdenv.lib.platforms.unix;
        } else if (abiCompat == "1.18") then {
            name = "xorg-server-1.18.4";
            builder = ./builder.sh;
            src = fetchurl {
              url = "mirror://xorg/individual/xserver/xorg-server-1.18.4.tar.bz2";
              sha256 = "1j1i3n5xy1wawhk95kxqdc54h34kg7xp4nnramba2q8xqfr5k117";
            };
            nativeBuildInputs = [ pkgconfig ];
            buildInputs = [ xorgproto libdrm openssl libX11 libXau libXaw libxcb xcbutil xcbutilwm xcbutilimage xcbutilkeysyms xcbutilrenderutil libXdmcp libXfixes libxkbfile libXmu libXpm libXrender libXres libXt ];
            postPatch = stdenv.lib.optionalString stdenv.isLinux "sed '1i#include <malloc.h>' -i include/os.h";
            meta.platforms = stdenv.lib.platforms.unix;
        } else throw "unsupported xorg abiCompat ${abiCompat} for ${attrs_passed.name}";

    in attrs //
    (let
      version = lib.getVersion attrs;
      commonBuildInputs = attrs.buildInputs ++ [ xtrans ];
      commonPropagatedBuildInputs = [
        zlib libGL libGLU dbus
        xorgproto
        libXext pixman libXfont libxshmfence libunwind
        libXfont2
      ];
      # XQuartz requires two compilations: the first to get X / XQuartz,
      # and the second to get Xvfb, Xnest, etc.
      darwinOtherX = overrideDerivation xorgserver (oldAttrs: {
        configureFlags = oldAttrs.configureFlags ++ [
          "--disable-xquartz"
          "--enable-xorg"
          "--enable-xvfb"
          "--enable-xnest"
          "--enable-kdrive"
        ];
        postInstall = ":"; # prevent infinite recursion
      });
    in
      if (!isDarwin)
      then {
        outputs = [ "out" "dev" ];
        buildInputs = commonBuildInputs ++ [ libdrm mesa ];
        propagatedBuildInputs = attrs.propagatedBuildInputs or [] ++ [ libpciaccess epoxy ] ++ commonPropagatedBuildInputs ++ lib.optionals stdenv.isLinux [
          udev
        ];
        prePatch = stdenv.lib.optionalString stdenv.hostPlatform.isMusl ''
          export CFLAGS+=" -D__uid_t=uid_t -D__gid_t=gid_t"
        '';
        configureFlags = [
          "--enable-kdrive"             # not built by default
          "--enable-xephyr"
          "--enable-xcsecurity"         # enable SECURITY extension
          "--with-default-font-path="   # there were only paths containing "${prefix}",
                                        # and there are no fonts in this package anyway
          "--with-xkb-bin-directory=${final.xkbcomp}/bin"
          "--with-xkb-path=${final.xkeyboardconfig}/share/X11/xkb"
          "--with-xkb-output=$out/share/X11/xkb/compiled"
          "--enable-glamor"
        ] ++ lib.optionals stdenv.hostPlatform.isMusl [
          "--disable-tls"
        ];

        postInstall = ''
          rm -fr $out/share/X11/xkb/compiled # otherwise X will try to write in it
          ( # assert() keeps runtime reference xorgserver-dev in xf86-video-intel and others
            cd "$dev"
            for f in include/xorg/*.h; do
              sed "1i#line 1 \"${attrs.name}/$f\"" -i "$f"
            done
          )
        '';
        passthru.version = version; # needed by virtualbox guest additions
      } else {
        nativeBuildInputs = attrs.nativeBuildInputs ++ [ autoreconfHook final.utilmacros final.fontutil ];
        buildInputs = commonBuildInputs ++ [
          bootstrap_cmds automake autoconf
          Xplugin Carbon Cocoa
        ];
        propagatedBuildInputs = commonPropagatedBuildInputs ++ [
          libAppleWM xorgproto
        ];

        patches = [
          # XQuartz patchset
          (fetchpatch {
            url = "https://github.com/XQuartz/xorg-server/commit/e88fd6d785d5be477d5598e70d105ffb804771aa.patch";
            sha256 = "1q0a30m1qj6ai924afz490xhack7rg4q3iig2gxsjjh98snikr1k";
            name = "use-cppflags-not-cflags.patch";
          })
          (fetchpatch {
            url = "https://github.com/XQuartz/xorg-server/commit/75ee9649bcfe937ac08e03e82fd45d9e18110ef4.patch";
            sha256 = "1vlfylm011y00j8mig9zy6gk9bw2b4ilw2qlsc6la49zi3k0i9fg";
            name = "use-old-mitrapezoids-and-mitriangles-routines.patch";
          })
          (fetchpatch {
            url = "https://github.com/XQuartz/xorg-server/commit/c58f47415be79a6564a9b1b2a62c2bf866141e73.patch";
            sha256 = "19sisqzw8x2ml4lfrwfvavc2jfyq2bj5xcf83z89jdxg8g1gdd1i";
            name = "revert-fb-changes-1.patch";
          })
          (fetchpatch {
            url = "https://github.com/XQuartz/xorg-server/commit/56e6f1f099d2821e5002b9b05b715e7b251c0c97.patch";
            sha256 = "0zm9g0g1jvy79sgkvy0rjm6ywrdba2xjd1nsnjbxjccckbr6i396";
            name = "revert-fb-changes-2.patch";
          })
        ];

        configureFlags = [
          # note: --enable-xquartz is auto
          "CPPFLAGS=-I${./darwin/dri}"
          "--with-default-font-path="
          "--with-apple-application-name=XQuartz"
          "--with-apple-applications-dir=\${out}/Applications"
          "--with-bundle-id-prefix=org.nixos.xquartz"
          "--with-sha1=CommonCrypto"
        ];
        preConfigure = ''
          mkdir -p $out/Applications
          export NIX_CFLAGS_COMPILE="$NIX_CFLAGS_COMPILE -Wno-error"
          substituteInPlace hw/xquartz/pbproxy/Makefile.in --replace -F/System -F${ApplicationServices}
        '';
        postInstall = ''
          rm -fr $out/share/X11/xkb/compiled

          cp -rT ${darwinOtherX}/bin $out/bin
          rm -f $out/bin/X
          ln -s Xquartz $out/bin/X

          cp ${darwinOtherX}/share/man -rT $out/share/man
        '' ;
        passthru.version = version;
      }));

  lndir = prev.lndir.overrideAttrs (attrs: {
    buildInputs = [];
    preConfigure = ''
      export XPROTO_CFLAGS=" "
      export XPROTO_LIBS=" "
      substituteInPlace lndir.c \
        --replace '<X11/Xos.h>' '<string.h>' \
        --replace '<X11/Xfuncproto.h>' '<unistd.h>' \
        --replace '_X_ATTRIBUTE_PRINTF(1,2)' '__attribute__((__format__(__printf__,1,2)))' \
        --replace '_X_ATTRIBUTE_PRINTF(2,3)' '__attribute__((__format__(__printf__,2,3)))' \
        --replace '_X_NORETURN' '__attribute__((noreturn))' \
        --replace 'n_dirs--;' ""
    '';
  });

  twm = prev.twm.overrideAttrs (attrs: {
    nativeBuildInputs = attrs.nativeBuildInputs ++ [bison flex];
  });

  xauth = prev.xauth.overrideAttrs (attrs: {
    doCheck = false; # fails
  });

  xcursorthemes = prev.xcursorthemes.overrideAttrs (attrs: {
    buildInputs = attrs.buildInputs ++ [ final.xcursorgen final.xorgproto ];
    configureFlags = [ "--with-cursordir=$(out)/share/icons" ];
  });

  xinit = (prev.xinit.override {
    stdenv = if isDarwin then clangStdenv else stdenv;
  }).overrideAttrs (attrs: {
    buildInputs = attrs.buildInputs ++ lib.optional isDarwin bootstrap_cmds;
    configureFlags = [
      "--with-xserver=${final.xorgserver.out}/bin/X"
    ] ++ lib.optionals isDarwin [
      "--with-bundle-id-prefix=org.nixos.xquartz"
      "--with-launchdaemons-dir=\${out}/LaunchDaemons"
      "--with-launchagents-dir=\${out}/LaunchAgents"
    ];
    propagatedBuildInputs = attrs.propagatedBuildInputs or [] ++ [ final.xauth ]
                         ++ lib.optionals isDarwin [ final.libX11 final.xorgproto ];
    prePatch = ''
      sed -i 's|^defaultserverargs="|&-logfile \"$HOME/.xorg.log\"|p' startx.cpp
    '';
  });

  xf86videointel = prev.xf86videointel.overrideAttrs (attrs: {
    # the update script only works with released tarballs :-/
    name = "xf86-video-intel-2019-12-09";
    src = fetchFromGitLab {
      domain = "gitlab.freedesktop.org";
      group = "xorg";
      owner = "driver";
      repo = "xf86-video-intel";
      rev = "f66d39544bb8339130c96d282a80f87ca1606caf";
      sha256 = "14rwbbn06l8qpx7s5crxghn80vgcx8jmfc7qvivh72d81r0kvywl";
    };
    buildInputs = attrs.buildInputs ++ [final.libXfixes final.libXScrnSaver final.pixman];
    nativeBuildInputs = attrs.nativeBuildInputs ++ [autoreconfHook final.utilmacros];
    configureFlags = [ "--with-default-dri=3" "--enable-tools" ];

    meta = attrs.meta // {
      platforms = ["i686-linux" "x86_64-linux"];
    };
  });

  xf86videoxgi = prev.xf86videoxgi.overrideAttrs (attrs: {
    patches = [
      # fixes invalid open mode
      # https://cgit.freedesktop.org/xorg/driver/xf86-video-xgi/commit/?id=bd94c475035739b42294477cff108e0c5f15ef67
      (fetchpatch {
        url = "https://cgit.freedesktop.org/xorg/driver/xf86-video-xgi/patch/?id=bd94c475035739b42294477cff108e0c5f15ef67";
        sha256 = "0myfry07655adhrpypa9rqigd6rfx57pqagcwibxw7ab3wjay9f6";
      })
      (fetchpatch {
        url = "https://cgit.freedesktop.org/xorg/driver/xf86-video-xgi/patch/?id=78d1138dd6e214a200ca66fa9e439ee3c9270ec8";
        sha256 = "0z3643afgrync280zrp531ija0hqxc5mrwjif9nh9lcnzgnz2d6d";
      })
    ];
  });

  xorgcffiles = prev.xorgcffiles.overrideAttrs (attrs: {
    postInstall = stdenv.lib.optionalString stdenv.isDarwin ''
      substituteInPlace $out/lib/X11/config/darwin.cf --replace "/usr/bin/" ""
    '';
  });

  xwd = prev.xwd.overrideAttrs (attrs: {
    buildInputs = with final; attrs.buildInputs ++ [libXt];
  });

  xrdb = prev.xrdb.overrideAttrs (attrs: {
    configureFlags = [ "--with-cpp=${mcpp}/bin/mcpp" ];
  });

  sessreg = prev.sessreg.overrideAttrs (attrs: {
    preBuild = "sed -i 's|gcc -E|gcc -E -P|' man/Makefile";
  });

  xrandr = prev.xrandr.overrideAttrs (attrs: {
    postInstall = ''
      rm $out/bin/xkeystone
    '';
  });

  xcalc = prev.xcalc.overrideAttrs (attrs: {
    configureFlags = attrs.configureFlags or [] ++ [
      "--with-appdefaultdir=${placeholder "out"}/share/X11/app-defaults"
    ];
    nativeBuildInputs = attrs.nativeBuildInputs or [] ++ [ makeWrapper ];
    postInstall = ''
      wrapProgram $out/bin/xcalc \
        --set XAPPLRESDIR ${placeholder "out"}/share/X11/app-defaults
    '';
  });
}
