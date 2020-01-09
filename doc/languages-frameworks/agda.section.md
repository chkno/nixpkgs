---
title: Agda
author: Alex Rice (alexarice)
date: 2020-01-06
---
# Agda

## How to use Agda

Agda can be installed with `agda.Agda`. For example:
```
$ nix-env -iA agda.Agda
```

To use agda with libraries, the `withPackages` function can be used. This function either takes:
+ A list of packages,
+ or a function which returns a list of packages when given the `agda` attribute set.

For example, suppose we wanted a version of agda which has access to the standard library. This can be obtained with the expressions:

```
agda.withPackages [ agda.standard-library ]
```

or

```
agda.withPackages (p: [ p.standard-library ])
```

If you want to use a library in your home directory (for instance if it doesn't have a nix derivation or is a development version) then `agda.withPackages'` can be used, which also allows you to input the paths of extra libraries as follows:

```
agda.withPackages' [ agda.standard-library ] "path/to/my/package.agda-lib"
```

Agda will not by default use these libraries. To tell agda to use the library we have some options:
- Call `agda` with the library flag:
```
$ agda -l standard-library -i . MyFile.agda
```
- Write a `.agda-lib` file for the project you are working on which may look like:
```
name: my-library
include: .
depends: standard-library
```
- Create the file `~/.agda/defaults` and add any libraries you want to use by default.

More information can be found [here](https://agda.readthedocs.io/en/v2.6.0.1/tools/package-system.html).

## Compiling Agda
Agda modules can be compiled with the `--compile` flag. This will require `ghc` to be available. Further, some parts of the standard library require that the haskell library `ieee` be available.

## Writing Agda packages
To write a nix derivation for an agda library, first check that the library has a `*.agda-lib` file.

A derivation can then be written using `agda.mkDerivation`. This has similar arguments to `stdenv.mkDerivation` with the following exceptions:
+ The `buildInputsAgda` should be used for agda library dependencies.
+ `everythingFile` can be used to specify the location of the `Everything.agda` file, defaulting to `./Everything.agda`.
+ `libraryName` should be the name that appears in the `*.agda-lib` file, defaulting to `pname`.
+ `libraryFile` should be the file name of the `*.agda-lib` file, defaulting to `${libraryName}.agda-lib`.

The build phase for `agda.mkDerivation` simply runs `agda` on the `Everything.agda` file. If something else is needed to build the package (e.g. `make`) then the buildPhase should be overriden (or a `preBuild` or `configurePhase` can be used if there are steps that need to be done prior to checking the `Everything.agda` file). A version of `agda` with the libraries `buildInputsAgda` is available during the build phase. The install phase simply copies all `.agda`, `.agdai` and `.agda-lib` files to the output directory. Again, this can be overriden.

To add an agda package to `nixpkgs`, the derivation should be written to `pkgs/development/libraries/agda/${library-name}/` and an entry should be added to `pkgs/top-level/agda-packages.nix`. Here it is called in a scope with access to all other agda libraries, so the top line of the `default.nix` can look like:
```
{ mkDerivation, standard-library, fetchFromGitHub }:
```