{ lib, mkDerivation, fetchFromGitHub, standard-library, version, sha256 }:

mkDerivation {
  inherit version;
  pname = "agda-categories";

  src = fetchFromGitHub {
    owner = "agda";
    repo = "agda-categories";
    rev = "release/v${version}";
    inherit sha256;
  };

  # Does not work with standard-library 1.2
  buildInputsAgda = [ (standard-library.override {
    version = "1.1";
    sha256 = "190bxsy92ffmvwpmyyg3lxs91vyss2z25rqz1w79gkj56484cy64";
  }) ];

  meta = with lib; {
    inherit (src.meta) homepage;
    description = "A new Categories library";
    license = licenses.bsd3;
    platforms = platforms.unix;
    # agda categories takes a lot of memory to build.
    # This can be removed if this is eventually fixed upstream.
    hydraPlatforms = [];
    maintainers = with maintainers; [ alexarice ];
  };
}
