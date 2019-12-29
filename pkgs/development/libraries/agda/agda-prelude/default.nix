{ stdenv, mkDerivation, fetchFromGitHub }:

mkDerivation rec {
  version = "compat-2.6.0";
  pname = "agda-prelude";

  src = fetchFromGitHub {
    owner = "UlfNorell";
    repo = "agda-prelude";
    rev = version;
    sha256 = "16pysyq6nf37zk9js4l5gfd2yxgf2dh074r9507vqkg6vfhdj2w6";
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
