{ lib, mkDerivation, fetchFromGitHub, ghcWithPackages }:

mkDerivation rec {
  pname = "standard-library";
  version = "1.4";

  src = fetchFromGitHub {
    repo = "agda-stdlib";
    owner = "agda";
    rev = "v${version}";
    sha256 = "1asjbisb7pfkgzqy7gf9b23z63bba8l8p1wqfd6ff5ddgqwj3dhp";
  };

  nativeBuildInputs = [ (ghcWithPackages (self : [ self.filemanip ])) ];
  preConfigure = ''
    runhaskell GenerateEverything.hs
    # We will only build/consider Everything.agda, in particular we don't want Everything*.agda
    # do be copied to the store.
    rm EverythingSafe.agda EverythingSafeGuardedness.agda EverythingSafeSizedTypes.agda
  '';

  meta = with lib; {
    homepage = "https://wiki.portal.chalmers.se/agda/pmwiki.php?n=Libraries.StandardLibrary";
    description = "A standard library for use with the Agda compiler";
    license = lib.licenses.mit;
    platforms = lib.platforms.unix;
    maintainers = with maintainers; [ jwiegley mudri alexarice turion ];
  };
}
