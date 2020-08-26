# An overlay that download sources on remote builder.
# This is useful when the evaluating machine has a slow
# upload while the builder can fetch faster directly from the source.
# Usage: Put the following snippet in your usual overlay definition:
#
#   final: prev:
#     (prev.prefer-remote-fetch final prev)
# Full configuration example for your own account:
#
# $ mkdir ~/.config/nixpkgs/overlays/
# $ echo 'final: prev: prev.prefer-remote-fetch final prev' > ~/.config/nixpkgs/overlays/prefer-remote-fetch.nix
#
final: prev: {
  fetchurl = args: prev.fetchurl (args // { preferLocalBuild = false; });
  fetchgit = args: prev.fetchgit (args // { preferLocalBuild = false; });
  fetchhg = args: prev.fetchhg (args // { preferLocalBuild = false; });
  fetchsvn = args: prev.fetchsvn (args // { preferLocalBuild = false; });
  fetchipfs = args: prev.fetchipfs (args // { preferLocalBuild = false; });
}
