{ lib, mkDerivation, fetchFromGitHub, standard-library }:

mkDerivation rec {
  version = "0.1";
  pname = "agda-categories";

  src = fetchFromGitHub {
    owner = "agda";
    repo = "agda-categories";
    rev = "release/v${version}";
    sha256 = "0m4pjy92jg6zfziyv0bxv5if03g8k4413ld8c3ii2xa8bzfn04m2";
  };

  buildInputsAgda = [ standard-library ];

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
