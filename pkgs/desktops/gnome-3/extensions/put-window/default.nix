{ stdenv, fetchFromGitHub, glib, libwnck3 }:

stdenv.mkDerivation rec {
  pname = "gnome-shell-extension-put-window";
  version = "26";

  src = fetchFromGitHub {
    owner = "negesti";
    repo = "gnome-shell-extensions-negesti";
    rev = "v${version}";
    sha256 = "0a67k096dl0j3q4hkq6n6354mzqd3mkia3zvw2bp0q79hgg6750l";
  };

  uuid = "putWindow@clemens.lab21.org";

  nativeBuildInputs = [
    glib
  ];

  postUnpack = ''
    rm source/schemas/gschemas.compiled
    sed -i "1iimports.gi.GIRepository.Repository.prepend_search_path('${libwnck3}/lib/girepository-1.0');" source/extension.js source/prefs.js
  '';

  buildPhase = ''
    make -C schemas
  '';

  installPhase = ''
    mkdir -p $out/share/gnome-shell/extensions/${uuid}
    cp -r * schemas $out/share/gnome-shell/extensions/${uuid}
  '';

  meta = with stdenv.lib; {
    description = "An gnome-shell extension that makes window movement a lot easier";
    license = licenses.gpl3Plus;
    maintainers = with maintainers; [ chkno ];
    homepage = https://github.com/negesti/gnome-shell-extensions-negesti;
  };
}
