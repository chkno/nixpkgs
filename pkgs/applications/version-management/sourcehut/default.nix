{ python37, openssl
, callPackage, recurseIntoAttrs }:

# To expose the *srht modules, they have to be a python module so we use `buildPythonModule`
# Then we expose them through all-packages.nix as an application through `toPythonApplication`
# https://github.com/NixOS/nixpkgs/pull/54425#discussion_r250688781

let
  fetchNodeModules = callPackage ./fetchNodeModules.nix { };

  python = python37.override {
    packageOverrides = final: prev: {
      srht = final.callPackage ./core.nix { inherit fetchNodeModules; };

      buildsrht = final.callPackage ./builds.nix { };
      dispatchsrht = final.callPackage ./dispatch.nix { };
      gitsrht = final.callPackage ./git.nix { };
      hgsrht = final.callPackage ./hg.nix { };
      listssrht = final.callPackage ./lists.nix { };
      mansrht = final.callPackage ./man.nix { };
      metasrht = final.callPackage ./meta.nix { };
      pastesrht = final.callPackage ./paste.nix { };
      todosrht = final.callPackage ./todo.nix { };

      scmsrht = final.callPackage ./scm.nix { };
    };
  };
in with python.pkgs; recurseIntoAttrs {
  inherit python;
  buildsrht = toPythonApplication buildsrht;
  dispatchsrht = toPythonApplication dispatchsrht;
  gitsrht = toPythonApplication gitsrht;
  hgsrht = toPythonApplication hgsrht;
  listssrht = toPythonApplication listssrht;
  mansrht = toPythonApplication mansrht;
  metasrht = toPythonApplication metasrht;
  pastesrht = toPythonApplication pastesrht;
  todosrht = toPythonApplication todosrht;
}
