{ pkgs, haskellLib }:

with haskellLib;

final: prev:
let
  # This contains updates to the dependencies, without which it would
  # be even more work to get it to build.
  # As of 2020-04, there's no new release in sight, which is why we're
  # pulling from Github.
  tensorflow-haskell = pkgs.fetchFromGitHub {
    owner = "tensorflow";
    repo = "haskell";
    rev = "568c9b6f03e5d66a25685a776386e2ff50b61aa9";
    sha256 = "0v58zhqipa441hzdvp9pwgv6srir2fm7cp0bq2pb5jl1imwyd37h";
    fetchSubmodules = true;
  };

  setTensorflowSourceRoot = dir: drv:
    (overrideCabal drv (drv: { src = tensorflow-haskell; }))
      .overrideAttrs (_oldAttrs: {sourceRoot = "source/${dir}";});
in
{
  tensorflow-proto = doJailbreak (setTensorflowSourceRoot "tensorflow-proto" prev.tensorflow-proto);

  tensorflow = (setTensorflowSourceRoot "tensorflow" prev.tensorflow).override {
    # the "regular" Python package does not seem to include the binary library
    libtensorflow = pkgs.libtensorflow-bin;
  };

  tensorflow-core-ops = setTensorflowSourceRoot "tensorflow-core-ops" prev.tensorflow-core-ops;

  tensorflow-logging = setTensorflowSourceRoot "tensorflow-logging" prev.tensorflow-logging;

  tensorflow-opgen = setTensorflowSourceRoot "tensorflow-opgen" prev.tensorflow-opgen;

  tensorflow-ops = setTensorflowSourceRoot "tensorflow-ops" prev.tensorflow-ops;
}
