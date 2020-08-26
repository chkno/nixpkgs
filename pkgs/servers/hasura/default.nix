{ haskell }:

with haskell.lib;

let
  # version in cabal file is invalid
  version = "1.2.1";

  pkgs = haskell.packages.ghc865.override {
    overrides = final: prev: {
      # cabal2nix  --subpath server --maintainer offline --no-check --revision 1.2.1 https://github.com/hasura/graphql-engine.git
      hasura-graphql-engine = justStaticExecutables
        ((final.callPackage ./graphql-engine.nix { }).overrideDerivation (d: {
          name = "graphql-engine-${version}";

          inherit version;

          # hasura needs VERSION env exported during build
          preBuild = "export VERSION=${version}";
        }));

      hasura-cli = final.callPackage ./cli.nix {
        hasura-graphql-engine = final.hasura-graphql-engine // {
          inherit version;
        };
      };

      # internal dependencies, non published on hackage (find revisions in cabal.project file)
      # cabal2nix --revision <rev> https://github.com/hasura/ci-info-hs.git
      ci-info = final.callPackage ./ci-info.nix { };
      # cabal2nix --revision <rev> https://github.com/hasura/graphql-parser-hs.git
      graphql-parser = final.callPackage ./graphql-parser.nix { };
      # cabal2nix --revision <rev> https://github.com/hasura/pg-client-hs.git
      pg-client = final.callPackage ./pg-client.nix { };

      # version constrained dependencies, without these hasura will not build,
      # find versions in graphql-engine.cabal
      # cabal2nix cabal://dependent-map-0.2.4.0
      dependent-map = final.callPackage ./dependent-map.nix { };
      # cabal2nix cabal://dependent-sum-0.4
      dependent-sum = final.callPackage ./dependent-sum.nix { };
      # cabal2nix cabal://these-0.7.6
      these = doJailbreak (final.callPackage ./these.nix { });
      # cabal2nix cabal://immortal-0.2.2.1
      immortal = final.callPackage ./immortal.nix { };
      # cabal2nix cabal://network-uri-2.6.1.0
      network-uri = final.callPackage ./network-uri.nix { };
      # cabal2nix cabal://ghc-heap-view-0.6.0
      ghc-heap-view = disableLibraryProfiling (final.callPackage ./ghc-heap-view.nix { });

      # unmark broewn packages and do required modifications
      stm-hamt = doJailbreak (unmarkBroken prev.stm-hamt);
      superbuffer = dontCheck (doJailbreak (unmarkBroken prev.superbuffer));
      Spock-core = dontCheck (unmarkBroken prev.Spock-core);
      stm-containers = dontCheck (unmarkBroken prev.stm-containers);
      ekg-json = unmarkBroken prev.ekg-json;
      list-t = dontCheck (unmarkBroken prev.list-t);
      primitive-extras = unmarkBroken prev.primitive-extras;
    };
  };
in {
  inherit (pkgs) hasura-graphql-engine hasura-cli;
}
