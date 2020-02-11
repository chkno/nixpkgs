{ stdenv, mkDerivation, fetchFromGitHub, ghcWithPackages, version, sha256 , rev ? "v${version}" }:

mkDerivation {
  pname = "standard-library";
  inherit version;

  src = fetchFromGitHub {
    repo = "agda-stdlib";
    owner = "agda";
    inherit sha256 rev;
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
