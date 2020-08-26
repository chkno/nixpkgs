{ haskellLib }:

let inherit (haskellLib) doJailbreak dontHaddock;
in final: prev: {
  ghc-api-ghcjs = prev.ghc-api-ghcjs.override
  {
    happy = final.happy_1_19_5;
  };
  haddock-library-ghcjs = doJailbreak prev.haddock-library-ghcjs;
  haddock-api-ghcjs = doJailbreak (dontHaddock prev.haddock-api-ghcjs);
}
