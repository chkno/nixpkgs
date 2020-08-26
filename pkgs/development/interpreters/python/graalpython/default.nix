{ pkgs
, lib
, graalvm8
, passthruFun
, packageOverrides ? (final: prev: {})
, final
}:

let
  passthru = passthruFun {
    inherit final packageOverrides;
    implementation = "graal";
    sourceVersion = graalvm8.version;
    pythonVersion = "3.7";
    libPrefix = "graalvm";
    sitePackages = "jre/languages/python/lib-python/3/site-packages";
    executable = "graalpython";
    hasDistutilsCxxPatch = false;
    pythonForBuild = pkgs.buildPackages.pythonInterpreters.graalpython37;
  };
in lib.extendDerivation true passthru graalvm8
