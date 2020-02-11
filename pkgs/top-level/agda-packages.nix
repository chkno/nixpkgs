{ pkgs, lib, callPackage, newScope, Agda }:

let
  mkAgdaPackages = Agda: lib.makeScope newScope (mkAgdaPackages' Agda);
  mkAgdaPackages' = Agda: self: let
    callPackage = self.callPackage;
  in {
    inherit Agda;
    inherit (callPackage ../build-support/agda {
      inherit Agda self;
      inherit (pkgs.haskellPackages) ghcWithPackages;
    }) withPackages mkDerivation;

    standard-library = callPackage ../development/libraries/agda/standard-library {
      inherit (pkgs.haskellPackages) ghcWithPackages;
      version = "1.2";
      sha256 = "01v4dy0ckir9skrn118ca4mzjnwdas70q9a9lncawjblwzikg4hq";
    };

    iowa-stdlib = callPackage ../development/libraries/agda/iowa-stdlib {
      version = "1.5.0";
      sha256 = "0dlis6v6nzbscf713cmwlx8h9n2gxghci8y21qak3hp18gkxdp0g";
    };

    agda-prelude = callPackage ../development/libraries/agda/agda-prelude {
      version = "compat-2.6.0";
      sha256 = "16pysyq6nf37zk9js4l5gfd2yxgf2dh074r9507vqkg6vfhdj2w6";
    };

    agda-categories = callPackage ../development/libraries/agda/agda-categories {
      version = "0.1";
      sha256 = "0m4pjy92jg6zfziyv0bxv5if03g8k4413ld8c3ii2xa8bzfn04m2";
    };
  };
in mkAgdaPackages Agda
