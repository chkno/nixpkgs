{ stdenv, mkDerivation, fetchFromGitHub, version, sha256 }:

mkDerivation {
  inherit version;
  pname = "agda-prelude";

  src = fetchFromGitHub {
    owner = "UlfNorell";
    repo = "agda-prelude";
    rev = version;
    inherit sha256;
  };

  preConfigure = ''
    cd test
    make everything
    mv Everything.agda ..
    cd ..
  '';

  everythingFile = "./Everything.agda";

  meta = with stdenv.lib; {
    homepage = https://github.com/UlfNorell/agda-prelude;
    description = "Programming library for Agda";
    license = stdenv.lib.licenses.mit;
    platforms = stdenv.lib.platforms.unix;
    maintainers = with maintainers; [ mudri alexarice ];
  };
}
