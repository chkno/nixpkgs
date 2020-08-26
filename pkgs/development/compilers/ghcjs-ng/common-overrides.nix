{ haskellLib }:

let inherit (haskellLib) addBuildTools appendConfigureFlag dontHaddock doJailbreak;
in final: prev: {
  ghcjs = dontHaddock (appendConfigureFlag (doJailbreak prev.ghcjs) "-fno-wrapper-install");
  haddock-library-ghcjs = dontHaddock prev.haddock-library-ghcjs;
  system-fileio = doJailbreak prev.system-fileio;
}
