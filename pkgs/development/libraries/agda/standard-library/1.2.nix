{ stdenv, mkDerivation, fetchFromGitHub, ghcWithPackages }:

mkDerivation rec {
  pname = "standard-library";
  version = "1.2";

  src = fetchFromGitHub {
    repo = "agda-stdlib";
    owner = "agda";
    rev = "v${version}";
    sha256 = "01v4dy0ckir9skrn118ca4mzjnwdas70q9a9lncawjblwzikg4hq";
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
    maintainers = with maintainers; [ jwiegley mudri alexarice ];
  };
}
