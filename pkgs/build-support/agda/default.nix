# Builder for Agda packages.

{ stdenv, lib, self, Agda, runCommand, makeWrapper, writeText, mkShell }:

with lib.strings;

let
  withPackages = pkgsFunc: let
    pkgs = if builtins.isList pkgsFunc then pkgsFunc else pkgsFunc self;
    library-file = writeText "libraries"
    (concatMapStringsSep "\n" (p: "${p}/${p.libraryFile}") pkgs);
    libraries = concatMapStringsSep "\n" (p: "-l ${p.libraryName}") pkgs;
    pname = "agdaWithPackages";
    version = Agda.version;
  in runCommand "${pname}-${version}" {
    inherit pname version;
    nativeBuildInputs = [ makeWrapper ];
  } ''
    mkdir -p $out/bin
    makeWrapper ${Agda}/bin/agda $out/bin/agda \
      --add-flags "--library-file=${library-file}"
  '';

  defaults =
    { pname
    , buildInputs ? []
    , buildInputsAgda ? []
    , everythingFile ? "./Everything.agda"
    , libraryName ? pname
    , libraryFile ? "${libraryName}.agda-lib"
    , buildPhase ? ""
    , installPhase ? ""
    , ...
    }: let
      agdaWithArgs = withPackages buildInputsAgda;
    in
      {
        inherit libraryName libraryFile;

        buildInputs = buildInputs ++ [ agdaWithArgs ];

        buildPhase = if buildPhase != "" then buildPhase else ''
          runHook preBuild
          agda -i ${dirOf everythingFile} ${everythingFile}
          runHook postBuild
        '';

        installPhase = if installPhase != "" then installPhase else ''
          runHook preInstall
          mkdir -p $out
          find \( -name '*.agda' -or -name '*.agdai' -or -name '*.agda-lib' \) -exec cp -p --parents -t "$out" {} +
          runHook postInstall
        '';
      };
in
{
  mkDerivation = args: stdenv.mkDerivation (args // defaults args);

  inherit withPackages;
}
