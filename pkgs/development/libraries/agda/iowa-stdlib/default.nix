{ stdenv, mkDerivation, fetchFromGitHub, version, sha256 }:

mkDerivation {
  inherit version;
  pname = "iowa-stdlib";

  src = fetchFromGitHub {
    owner = "cedille";
    repo  = "ial";
    rev = "v${version}";
    inherit sha256;
  };

  libraryFile = "";
  libraryName = "IAL-1.3";

  buildPhase = ''
    patchShebangs find-deps.sh
    make
  '';

  meta = {
    homepage = https://svn.divms.uiowa.edu/repos/clc/projects/agda/lib/;
    description = "Agda standard library developed at Iowa";
    license = stdenv.lib.licenses.free;
    platforms = stdenv.lib.platforms.unix;
    maintainers = with stdenv.lib.maintainers; [ alexarice ];
  };
}
