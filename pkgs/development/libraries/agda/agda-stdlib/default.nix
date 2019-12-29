{ stdenv, agda, fetchFromGitHub, ghcWithPackages }:

agda.mkDerivation rec {
  pname = "agda-stdlib";
  version = "1.1";

  libraryName = "standard-library";

  src = fetchFromGitHub {
    repo = "agda-stdlib";
    owner = "agda";
    rev = "v${version}";
    sha256 = "190bxsy92ffmvwpmyyg3lxs91vyss2z25rqz1w79gkj56484cy64";
  };

  nativeBuildInputs = [ (ghcWithPackages (self : [ self.filemanip ])) ];
  preConfigure = ''
    runhaskell GenerateEverything.hs
  '';

  meta = with stdenv.lib; {
    homepage = http://wiki.portal.chalmers.se/agda/pmwiki.php?n=Libraries.StandardLibrary;
    description = "A standard library for use with the Agda compiler";
    license = stdenv.lib.licenses.mit;
    platforms = stdenv.lib.platforms.unix;
    maintainers = with maintainers; [ jwiegley mudri ];
  };
}
