{ pkgs,  ... }:
final: prev:
with prev;
{
  ##########################################3
  #### manual fixes for generated packages
  ##########################################3
  bit32 = prev.bit32.override({
    # Small patch in order to no longer redefine a Lua 5.2 function that Luajit
    # 2.1 also provides, see https://github.com/LuaJIT/LuaJIT/issues/325 for
    # more
    patches = [
      ./bit32.patch
    ];
  });

  busted = prev.busted.override({
    postConfigure = ''
      substituteInPlace ''${rockspecFilename} \
        --replace "'lua_cliargs = 3.0-1'," "'lua_cliargs >= 3.0-1',"
    '';
    postInstall = ''
      install -D completions/zsh/_busted $out/share/zsh/site-functions/_busted
      install -D completions/bash/busted.bash $out/share/bash-completion/completions/busted
    '';
  });

  cqueues = prev.cqueues.override(rec {
    # Parse out a version number without the Lua version inserted
    version = with pkgs.lib; let
      version' = prev.cqueues.version;
      rel = splitVersion version';
      date = head rel;
      rev = last (splitString "-" (last rel));
    in "${date}-${rev}";
    nativeBuildInputs = [
      pkgs.gnum4
    ];
    externalDeps = [
      { name = "CRYPTO"; dep = pkgs.openssl; }
      { name = "OPENSSL"; dep = pkgs.openssl; }
    ];
    disabled = luaOlder "5.1" || luaAtLeast "5.4";
    # Upstream rockspec is pointlessly broken into separate rockspecs, per Lua
    # version, which doesn't work well for us, so modify it
    postConfigure = let inherit (prev.cqueues) pname; in ''
      # 'all' target auto-detects correct Lua version, which is fine for us as
      # we only have the right one available :)
      sed -Ei ''${rockspecFilename} \
        -e 's|lua == 5.[[:digit:]]|lua >= 5.1, <= 5.3|' \
        -e 's|build_target = "[^"]+"|build_target = "all"|' \
        -e 's|version = "[^"]+"|version = "${version}"|'
      specDir=$(dirname ''${rockspecFilename})
      cp ''${rockspecFilename} "$specDir/${pname}-${version}.rockspec"
      rockspecFilename="$specDir/${pname}-${version}.rockspec"
    '';
  });

  cyrussasl = prev.cyrussasl.override({
    externalDeps = [
      { name = "LIBSASL"; dep = pkgs.cyrus_sasl; }
    ];
  });

  http = prev.http.override({
    patches = [
      (pkgs.fetchpatch {
        name = "invalid-state-progression.patch";
        url = "https://github.com/daurnimator/lua-http/commit/cb7b59474a.diff";
        sha256 = "1vmx039n3nqfx50faqhs3wgiw28ws416rhw6vh6srmh9i826dac7";
      })
    ];
    /* TODO: separate docs derivation? (pandoc is heavy)
    nativeBuildInputs = [ pandoc ];
    makeFlags = [ "-C doc" "lua-http.html" "lua-http.3" ];
    */
  });

  ldbus = prev.ldbus.override({
    extraVariables = {
      DBUS_DIR="${pkgs.dbus.lib}";
      DBUS_ARCH_INCDIR="${pkgs.dbus.lib}/lib/dbus-1.0/include";
      DBUS_INCDIR="${pkgs.dbus.dev}/include/dbus-1.0";
    };
    buildInputs = with pkgs; [
      dbus
    ];
  });

  ljsyscall = prev.ljsyscall.override(rec {
    version = "unstable-20180515";
    # package hasn't seen any release for a long time
    src = pkgs.fetchFromGitHub {
      owner = "justincormack";
      repo = "ljsyscall";
      rev = "e587f8c55aad3955dddab3a4fa6c1968037b5c6e";
      sha256 = "06v52agqyziwnbp2my3r7liv245ddmb217zmyqakh0ldjdsr8lz4";
    };
    knownRockspec = "rockspec/ljsyscall-scm-1.rockspec";
    # actually library works fine with lua 5.2
    preConfigure = ''
      sed -i 's/lua == 5.1/lua >= 5.1, < 5.3/' ${knownRockspec}
    '';
    disabled = luaOlder "5.1" || luaAtLeast "5.3";

    propagatedBuildInputs = with pkgs.lib; optional (!isLuaJIT) luaffi;
  });

  lgi = prev.lgi.override({
    nativeBuildInputs = [
      pkgs.pkgconfig
    ];
    buildInputs = [
      pkgs.glib
      pkgs.gobject-introspection
    ];
    patches = [
      (pkgs.fetchpatch {
        name = "lgi-find-cairo-through-typelib.patch";
        url = "https://github.com/psychon/lgi/commit/46a163d9925e7877faf8a4f73996a20d7cf9202a.patch";
        sha256 = "0gfvvbri9kyzhvq3bvdbj2l6mwvlz040dk4mrd5m9gz79f7w109c";
      })
    ];
  });

  lrexlib-gnu = prev.lrexlib-gnu.override({
    buildInputs = [
      pkgs.gnulib
    ];
  });

  lrexlib-pcre = prev.lrexlib-pcre.override({
    externalDeps = [
      { name = "PCRE"; dep = pkgs.pcre; }
    ];
  });

  lrexlib-posix = prev.lrexlib-posix.override({
    buildInputs = [
      pkgs.glibc.dev
    ];
  });

  ltermbox = prev.ltermbox.override( {
    disabled = !isLua51 || isLuaJIT;
  });

  lua-iconv = prev.lua-iconv.override({
    buildInputs = [
      pkgs.libiconv
    ];
  });

  lua-lsp = prev.lua-lsp.override({
    # until Alloyed/lua-lsp#28
    postConfigure = ''
      substituteInPlace ''${rockspecFilename} \
        --replace '"lpeglabel ~> 1.5",' '"lpeglabel >= 1.5",'
    '';
  });

  lua-zlib = prev.lua-zlib.override({
    buildInputs = [
      pkgs.zlib.dev
    ];
    disabled = luaOlder "5.1" || luaAtLeast "5.4";
  });

  luadbi-mysql = prev.luadbi-mysql.override({
    extraVariables = {
      # Can't just be /include and /lib, unfortunately needs the trailing 'mysql'
      MYSQL_INCDIR="${pkgs.libmysqlclient}/include/mysql";
      MYSQL_LIBDIR="${pkgs.libmysqlclient}/lib/mysql";
    };
    buildInputs = [
      pkgs.mysql.client
      pkgs.libmysqlclient
    ];
  });

  luadbi-postgresql = prev.luadbi-postgresql.override({
    buildInputs = [
      pkgs.postgresql
    ];
  });

  luadbi-sqlite3 = prev.luadbi-sqlite3.override({
    externalDeps = [
      { name = "SQLITE"; dep = pkgs.sqlite; }
    ];
  });

  luaevent = prev.luaevent.override({
    propagatedBuildInputs = [
      luasocket
    ];
    externalDeps = [
      { name = "EVENT"; dep = pkgs.libevent; }
    ];
    disabled = luaOlder "5.1" || luaAtLeast "5.4";
  });

  luaexpat = prev.luaexpat.override({
    externalDeps = [
      { name = "EXPAT"; dep = pkgs.expat; }
    ];
    patches = [
      ./luaexpat.patch
    ];
  });

  # TODO Somehow automatically amend buildInputs for things that need luaffi
  # but are in luajitPackages?
  luaffi = prev.luaffi.override({
    # The packaged .src.rock version is pretty old, and doesn't work with Lua 5.3
    src = pkgs.fetchFromGitHub {
      owner = "facebook"; repo = "luaffifb";
      rev = "532c757e51c86f546a85730b71c9fef15ffa633d";
      sha256 = "1nwx6sh56zfq99rcs7sph0296jf6a9z72mxknn0ysw9fd7m1r8ig";
    };
    knownRockspec = with prev.luaffi; "${pname}-${version}.rockspec";
    disabled = luaOlder "5.1" || luaAtLeast "5.4" || isLuaJIT;
  });

  luaossl = prev.luaossl.override({
    externalDeps = [
      { name = "CRYPTO"; dep = pkgs.openssl; }
      { name = "OPENSSL"; dep = pkgs.openssl; }
    ];
  });

  luasec = prev.luasec.override({
    externalDeps = [
      { name = "OPENSSL"; dep = pkgs.openssl; }
    ];
  });

  luasql-sqlite3 = prev.luasql-sqlite3.override({
    externalDeps = [
      { name = "SQLITE"; dep = pkgs.sqlite; }
    ];
  });

  luasystem = prev.luasystem.override({
    buildInputs = pkgs.lib.optionals pkgs.stdenv.isLinux [
      pkgs.glibc
    ];
  });

  luazip = prev.luazip.override({
    buildInputs = [
      pkgs.zziplib
    ];
  });

  lua-yajl = prev.lua-yajl.override({
    buildInputs = [
      pkgs.yajl
    ];
  });

  luuid = prev.luuid.override(old: {
    externalDeps = [
      { name = "LIBUUID"; dep = pkgs.libuuid; }
    ];
    meta = old.meta // {
      platforms = pkgs.lib.platforms.linux;
    };
    # Trivial patch to make it work in both 5.1 and 5.2.  Basically just the
    # tiny diff between the two upstream versions placed behind an #if.
    # Upstreams:
    # 5.1: http://webserver2.tecgraf.puc-rio.br/~lhf/ftp/lua/5.1/luuid.tar.gz
    # 5.2: http://webserver2.tecgraf.puc-rio.br/~lhf/ftp/lua/5.2/luuid.tar.gz
    patchFlags = [ "-p2" ];
    patches = [
      ./luuid.patch
    ];
    postConfigure = let inherit (prev.luuid) version pname; in ''
      sed -Ei ''${rockspecFilename} -e 's|lua >= 5.2|lua >= 5.1,|'
    '';
    disabled = luaOlder "5.1" || (luaAtLeast "5.4");
  });

  luv = prev.luv.override({
    # Use system libuv instead of building local and statically linking
    # This is a hacky way to specify -DWITH_SHARED_LIBUV=ON which
    # is not possible with luarocks and the current luv rockspec
    # While at it, remove bundled libuv source entirely to be sure.
    # We may wish to drop bundled lua submodules too...
    preBuild = ''
     sed -i 's,\(option(WITH_SHARED_LIBUV.*\)OFF,\1ON,' CMakeLists.txt
     rm -rf deps/libuv
    '';

    buildInputs = [ pkgs.libuv ];

    passthru = {
      libluv = final.luv.override ({
        preBuild = final.luv.preBuild + ''
          sed -i 's,\(option(BUILD_MODULE.*\)ON,\1OFF,' CMakeLists.txt
          sed -i 's,\(option(BUILD_SHARED_LIBS.*\)OFF,\1ON,' CMakeLists.txt
          sed -i 's,${"\${INSTALL_INC_DIR}"},${placeholder "out"}/include/luv,' CMakeLists.txt
        '';

        nativeBuildInputs = [ pkgs.fixDarwinDylibNames ];

        # Fixup linking libluv.dylib, for some reason it's not linked against lua correctly.
        NIX_LDFLAGS = pkgs.lib.optionalString pkgs.stdenv.isDarwin
          (if isLuaJIT then "-lluajit-${lua.luaversion}" else "-llua");
      });
    };
  });

  lyaml = prev.lyaml.override({
    buildInputs = [
      pkgs.libyaml
    ];
  });

  mpack = prev.mpack.override({
    buildInputs = [ pkgs.libmpack ];
    # the rockspec doesn't use the makefile so you may need to export more flags
    USE_SYSTEM_LUA = "yes";
    USE_SYSTEM_MPACK = "yes";
  });

  rapidjson = prev.rapidjson.override({
    preBuild = ''
      sed -i '/set(CMAKE_CXX_FLAGS/d' CMakeLists.txt
      sed -i '/set(CMAKE_C_FLAGS/d' CMakeLists.txt
    '';
  });

  readline = (prev.readline.override ({
    unpackCmd = ''
      unzip "$curSrc"
      tar xf *.tar.gz
    '';
    propagatedBuildInputs = prev.readline.propagatedBuildInputs ++ [ pkgs.readline ];
    extraVariables = rec {
      READLINE_INCDIR = "${pkgs.readline.dev}/include";
      HISTORY_INCDIR = READLINE_INCDIR;
    };
  })).overrideAttrs (old: {
    # Without this, source root is wrongly set to ./readline-2.6/doc
    setSourceRoot = ''
      sourceRoot=./readline-2.6
    '';
  });
}
