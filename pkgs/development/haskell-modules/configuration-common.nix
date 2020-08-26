# COMMON OVERRIDES FOR THE HASKELL PACKAGE SET IN NIXPKGS
#
# This file contains haskell package overrides that are shared by all
# haskell package sets provided by nixpkgs and distributed via the official
# NixOS hydra instance.
#
# Overrides that would also make sense for custom haskell package sets not provided
# as part of nixpkgs and that are specific to Nix should go in configuration-nix.nix
#
# See comment at the top of configuration-nix.nix for more information about this
# distinction.
{ pkgs, haskellLib }:

with haskellLib;

final: prev: {

  # Arion's test suite needs a Nixpkgs, which is cumbersome to do from Nixpkgs
  # itself. For instance, pkgs.path has dirty sources and puts a huge .git in the
  # store. Testing is done upstream.
  arion-compose = dontCheck prev.arion-compose;

  # This used to be a core package provided by GHC, but then the compiler
  # dropped it. We define the name here to make sure that old packages which
  # depend on this library still evaluate (even though they won't compile
  # successfully with recent versions of the compiler).
  bin-package-db = null;

  # waiting for release: https://github.com/jwiegley/c2hsc/issues/41
  c2hsc = appendPatch prev.c2hsc (pkgs.fetchpatch {
    url = "https://github.com/jwiegley/c2hsc/commit/490ecab202e0de7fc995eedf744ad3cb408b53cc.patch";
    sha256 = "1c7knpvxr7p8c159jkyk6w29653z5yzgjjqj11130bbb8mk9qhq7";
  });

  # Some Hackage packages reference this attribute, which exists only in the
  # GHCJS package set. We provide a dummy version here to fix potential
  # evaluation errors.
  ghcjs-base = null;
  ghcjs-prim = null;

  # Some packages add this (non-existent) dependency to express that they
  # cannot compile in a given configuration. Win32 does this, for example, when
  # compiled on Linux. We provide the name to avoid evaluation errors.
  unbuildable = throw "package depends on meta package 'unbuildable'";

  # enable using a local hoogle with extra packagages in the database
  # nix-shell -p "haskellPackages.hoogleLocal { packages = with haskellPackages; [ mtl lens ]; }"
  # $ hoogle server
  hoogleLocal = { packages ? [] }: final.callPackage ./hoogle.nix { inherit packages; };

  # Needs older QuickCheck version
  attoparsec-varword = dontCheck prev.attoparsec-varword;

  # These packages (and their reverse deps) cannot be built with profiling enabled.
  ghc-heap-view = disableLibraryProfiling prev.ghc-heap-view;
  ghc-datasize = disableLibraryProfiling prev.ghc-datasize;

  # This test keeps being aborted because it runs too quietly for too long
  Lazy-Pbkdf2 = if pkgs.stdenv.isi686 then dontCheck prev.Lazy-Pbkdf2 else prev.Lazy-Pbkdf2;

  # check requires mysql server
  mysql-simple = dontCheck prev.mysql-simple;
  mysql-haskell = dontCheck prev.mysql-haskell;

  # The Hackage tarball is purposefully broken, because it's not intended to be, like, useful.
  # https://git-annex.branchable.com/bugs/bash_completion_file_is_missing_in_the_6.20160527_tarball_on_hackage/
  git-annex = (overrideSrc prev.git-annex {
    src = pkgs.fetchgit {
      name = "git-annex-${prev.git-annex.version}-src";
      url = "git://git-annex.branchable.com/";
      rev = "refs/tags/" + prev.git-annex.version;
      sha256 = "1d24080xh7gl197i0y5bkn3j94hvh8zqyg9gfcnx2qdlxfca1knb";
    };
  }).override {
    dbus = if pkgs.stdenv.isLinux then final.dbus else null;
    fdo-notify = if pkgs.stdenv.isLinux then final.fdo-notify else null;
    hinotify = if pkgs.stdenv.isLinux then final.hinotify else final.fsnotify;
  };

  # Fix test trying to access /home directory
  shell-conduit = overrideCabal prev.shell-conduit (drv: {
    postPatch = "sed -i s/home/tmp/ test/Spec.hs";

    # the tests for shell-conduit on Darwin illegitimatey assume non-GNU echo
    # see: https://github.com/psibi/shell-conduit/issues/12
    doCheck = !pkgs.stdenv.isDarwin;
  });

  # https://github.com/froozen/kademlia/issues/2
  kademlia = dontCheck prev.kademlia;

  # Tests require older tasty
  hzk = dontCheck prev.hzk;

  # Tests require a Kafka broker running locally
  haskakafka = dontCheck prev.haskakafka;

  # Depends on broken "lss" package.
  snaplet-lss = dontDistribute prev.snaplet-lss;

  # Depends on broken "NewBinary" package.
  ASN1 = dontDistribute prev.ASN1;

  # Depends on broken "frame" package.
  frame-markdown = dontDistribute prev.frame-markdown;

  # Depends on broken "Elm" package.
  hakyll-elm = dontDistribute prev.hakyll-elm;
  haskelm = dontDistribute prev.haskelm;
  snap-elm = dontDistribute prev.snap-elm;

  # Depends on broken "hails" package.
  hails-bin = dontDistribute prev.hails-bin;

  bindings-levmar = overrideCabal prev.bindings-levmar (drv: {
    extraLibraries = [ pkgs.blas ];
  });

  # The Haddock phase fails for one reason or another.
  deepseq-magic = dontHaddock prev.deepseq-magic;
  feldspar-signal = dontHaddock prev.feldspar-signal; # https://github.com/markus-git/feldspar-signal/issues/1
  hoodle-core = dontHaddock prev.hoodle-core;
  hsc3-db = dontHaddock prev.hsc3-db;

  # https://github.com/techtangents/ablist/issues/1
  ABList = dontCheck prev.ABList;

  # sse2 flag due to https://github.com/haskell/vector/issues/47.
  vector = if pkgs.stdenv.isi686 then appendConfigureFlag prev.vector "--ghc-options=-msse2" else prev.vector;

  conduit-extra = if pkgs.stdenv.isDarwin
    then prev.conduit-extra.overrideAttrs (drv: { __darwinAllowLocalNetworking = true; })
    else prev.conduit-extra;

  # Fix Darwin build.
  halive = if pkgs.stdenv.isDarwin
    then addBuildDepend prev.halive pkgs.darwin.apple_sdk.frameworks.AppKit
    else prev.halive;

  barbly = addBuildDepend prev.barbly pkgs.darwin.apple_sdk.frameworks.AppKit;

  # Hakyll's tests are broken on Darwin (3 failures); and they require util-linux
  hakyll = if pkgs.stdenv.isDarwin
    then dontCheck (overrideCabal prev.hakyll (drv: {
      testToolDepends = [];
    }))
    else prev.hakyll;

  double-conversion = if !pkgs.stdenv.isDarwin
    then prev.double-conversion
    else addExtraLibrary prev.double-conversion pkgs.libcxx;

  inline-c-cpp = overrideCabal prev.inline-c-cpp (drv: {
    postPatch = (drv.postPatch or "") + ''
      substituteInPlace inline-c-cpp.cabal --replace "-optc-std=c++11" ""
    '';
  });

  inline-java = addBuildDepend prev.inline-java pkgs.jdk;

  # Upstream notified by e-mail.
  permutation = dontCheck prev.permutation;

  # https://github.com/jputcu/serialport/issues/25
  serialport = dontCheck prev.serialport;

  # Test suite build depends on ancient tasty 0.11.x.
  cryptohash-sha512 = dontCheck prev.cryptohash-sha512;

  # Test suite depends on source code being available
  simple-affine-space = dontCheck prev.simple-affine-space;

  # Fails no apparent reason. Upstream has been notified by e-mail.
  assertions = dontCheck prev.assertions;

  # These packages try to execute non-existent external programs.
  cmaes = dontCheck prev.cmaes;                        # http://hydra.cryp.to/build/498725/log/raw
  dbmigrations = dontCheck prev.dbmigrations;
  filestore = dontCheck prev.filestore;
  graceful = dontCheck prev.graceful;
  HList = dontCheck prev.HList;
  ide-backend = dontCheck prev.ide-backend;
  marquise = dontCheck prev.marquise;                  # https://github.com/anchor/marquise/issues/69
  memcached-binary = dontCheck prev.memcached-binary;
  msgpack-rpc = dontCheck prev.msgpack-rpc;
  persistent-zookeeper = dontCheck prev.persistent-zookeeper;
  pocket-dns = dontCheck prev.pocket-dns;
  postgresql-simple = dontCheck prev.postgresql-simple;
  postgrest = dontCheck prev.postgrest;
  postgrest-ws = dontCheck prev.postgrest-ws;
  snowball = dontCheck prev.snowball;
  sophia = dontCheck prev.sophia;
  test-sandbox = dontCheck prev.test-sandbox;
  texrunner = dontCheck prev.texrunner;
  users-postgresql-simple = dontCheck prev.users-postgresql-simple;
  wai-middleware-hmac = dontCheck prev.wai-middleware-hmac;
  xkbcommon = dontCheck prev.xkbcommon;
  xmlgen = dontCheck prev.xmlgen;
  HerbiePlugin = dontCheck prev.HerbiePlugin;
  wai-cors = dontCheck prev.wai-cors;

  # base bound
  digit = doJailbreak prev.digit;

  # 2020-06-05: HACK: does not pass own build suite - `dontCheck` We should
  # generate optparse-applicative completions for the hnix executable.  Sadly
  # building of the executable has been disabled for ghc < 8.10 in hnix.
  # Generating the completions should be activated again, once we default to
  # ghc 8.10.
  hnix = dontCheck (prev.hnix.override {
    # The neat-interpolation package from stack is to old for hnix.
    # https://github.com/haskell-nix/hnix/issues/676
    # Once neat-interpolation >= 0.4 is in our stack release,
    # (which should happen soon), we can remove this override
    neat-interpolation = final.neat-interpolation_0_5_1_1;
  });

  # Fails for non-obvious reasons while attempting to use doctest.
  search = dontCheck prev.search;

  # see https://github.com/LumiGuide/haskell-opencv/commit/cd613e200aa20887ded83256cf67d6903c207a60
  opencv = dontCheck (appendPatch prev.opencv ./patches/opencv-fix-116.patch);
  opencv-extra = dontCheck (appendPatch prev.opencv-extra ./patches/opencv-fix-116.patch);

  # https://github.com/ekmett/structures/issues/3
  structures = dontCheck prev.structures;

  # Disable test suites to fix the build.
  acme-year = dontCheck prev.acme-year;                # http://hydra.cryp.to/build/497858/log/raw
  aeson-lens = dontCheck prev.aeson-lens;              # http://hydra.cryp.to/build/496769/log/raw
  aeson-schema = dontCheck prev.aeson-schema;          # https://github.com/timjb/aeson-schema/issues/9
  angel = dontCheck prev.angel;
  apache-md5 = dontCheck prev.apache-md5;              # http://hydra.cryp.to/build/498709/nixlog/1/raw
  app-settings = dontCheck prev.app-settings;          # http://hydra.cryp.to/build/497327/log/raw
  aws = dontCheck prev.aws;                            # needs aws credentials
  aws-kinesis = dontCheck prev.aws-kinesis;            # needs aws credentials for testing
  binary-protocol = dontCheck prev.binary-protocol;    # http://hydra.cryp.to/build/499749/log/raw
  binary-search = dontCheck prev.binary-search;
  bits = dontCheck prev.bits;                          # http://hydra.cryp.to/build/500239/log/raw
  bloodhound = dontCheck prev.bloodhound;
  buildwrapper = dontCheck prev.buildwrapper;
  burst-detection = dontCheck prev.burst-detection;    # http://hydra.cryp.to/build/496948/log/raw
  cabal-meta = dontCheck prev.cabal-meta;              # http://hydra.cryp.to/build/497892/log/raw
  camfort = dontCheck prev.camfort;
  cjk = dontCheck prev.cjk;
  CLI = dontCheck prev.CLI;                            # Upstream has no issue tracker.
  command-qq = dontCheck prev.command-qq;              # http://hydra.cryp.to/build/499042/log/raw
  conduit-connection = dontCheck prev.conduit-connection;
  craftwerk = dontCheck prev.craftwerk;
  css-text = dontCheck prev.css-text;
  damnpacket = dontCheck prev.damnpacket;              # http://hydra.cryp.to/build/496923/log
  data-hash = dontCheck prev.data-hash;
  Deadpan-DDP = dontCheck prev.Deadpan-DDP;            # http://hydra.cryp.to/build/496418/log/raw
  DigitalOcean = dontCheck prev.DigitalOcean;
  direct-sqlite = dontCheck prev.direct-sqlite;
  directory-layout = dontCheck prev.directory-layout;
  dlist = dontCheck prev.dlist;
  docopt = dontCheck prev.docopt;                      # http://hydra.cryp.to/build/499172/log/raw
  dom-selector = dontCheck prev.dom-selector;          # http://hydra.cryp.to/build/497670/log/raw
  dotenv = dontCheck prev.dotenv;                      # Tests fail because of missing test file on version 0.8.0.2 fixed on version 0.8.0.4
  dotfs = dontCheck prev.dotfs;                        # http://hydra.cryp.to/build/498599/log/raw
  DRBG = dontCheck prev.DRBG;                          # http://hydra.cryp.to/build/498245/nixlog/1/raw
  ed25519 = dontCheck prev.ed25519;
  etcd = dontCheck prev.etcd;
  fb = dontCheck prev.fb;                              # needs credentials for Facebook
  fptest = dontCheck prev.fptest;                      # http://hydra.cryp.to/build/499124/log/raw
  friday-juicypixels = dontCheck prev.friday-juicypixels; #tarball missing test/rgba8.png
  ghc-events = dontCheck prev.ghc-events;              # http://hydra.cryp.to/build/498226/log/raw
  ghc-events-parallel = dontCheck prev.ghc-events-parallel;    # http://hydra.cryp.to/build/496828/log/raw
  ghc-imported-from = dontCheck prev.ghc-imported-from;
  ghc-parmake = dontCheck prev.ghc-parmake;
  ghcid = dontCheck prev.ghcid;
  git-vogue = dontCheck prev.git-vogue;
  github-rest = dontCheck prev.github-rest;  # test suite needs the network
  gitlib-cmdline = dontCheck prev.gitlib-cmdline;
  GLFW-b = dontCheck prev.GLFW-b;                      # https://github.com/bsl/GLFW-b/issues/50
  hackport = dontCheck prev.hackport;
  hadoop-formats = dontCheck prev.hadoop-formats;
  haeredes = dontCheck prev.haeredes;
  hashed-storage = dontCheck prev.hashed-storage;
  hashring = dontCheck prev.hashring;
  hath = dontCheck prev.hath;
  haxl = dontCheck prev.haxl;                          # non-deterministic failure https://github.com/facebook/Haxl/issues/85
  haxl-facebook = dontCheck prev.haxl-facebook;        # needs facebook credentials for testing
  hdbi-postgresql = dontCheck prev.hdbi-postgresql;
  hedis = dontCheck prev.hedis;
  hedis-pile = dontCheck prev.hedis-pile;
  hedis-tags = dontCheck prev.hedis-tags;
  hedn = dontCheck prev.hedn;
  hgdbmi = dontCheck prev.hgdbmi;
  hi = dontCheck prev.hi;
  hierarchical-clustering = dontCheck prev.hierarchical-clustering;
  hlibgit2 = disableHardening prev.hlibgit2 [ "format" ];
  hmatrix-tests = dontCheck prev.hmatrix-tests;
  hquery = dontCheck prev.hquery;
  hs2048 = dontCheck prev.hs2048;
  hsbencher = dontCheck prev.hsbencher;
  hsexif = dontCheck prev.hsexif;
  hspec-server = dontCheck prev.hspec-server;
  HTF = dontCheck prev.HTF;
  htsn = dontCheck prev.htsn;
  htsn-import = dontCheck prev.htsn-import;
  http-link-header = dontCheck prev.http-link-header; # non deterministic failure https://hydra.nixos.org/build/75041105
  ihaskell = dontCheck prev.ihaskell;
  influxdb = dontCheck prev.influxdb;
  itanium-abi = dontCheck prev.itanium-abi;
  katt = dontCheck prev.katt;
  language-nix = if (pkgs.stdenv.hostPlatform.isAarch64 || pkgs.stdenv.hostPlatform.isi686) then dontCheck prev.language-nix else prev.language-nix; # aarch64: https://ghc.haskell.org/trac/ghc/ticket/15275
  language-slice = dontCheck prev.language-slice;
  ldap-client = dontCheck prev.ldap-client;
  lensref = dontCheck prev.lensref;
  lvmrun = disableHardening (dontCheck prev.lvmrun) ["format"];
  math-functions = if pkgs.stdenv.isDarwin
    then dontCheck prev.math-functions # "erf table" test fails on Darwin https://github.com/bos/math-functions/issues/63
    else prev.math-functions;
  matplotlib = dontCheck prev.matplotlib;

  # Needs the latest version of vty and brick.
  matterhorn = prev.matterhorn.overrideScope (final: prev: {
    brick = final.brick_0_55;
    vty = final.vty_5_30;
  });

  memcache = dontCheck prev.memcache;
  metrics = dontCheck prev.metrics;
  milena = dontCheck prev.milena;
  mockery = if pkgs.stdenv.isDarwin
    then overrideCabal prev.mockery (drv: { preCheck = "export TRAVIS=true"; }) # darwin doesn't have sub-second resolution https://github.com/hspec/mockery/issues/11
    else prev.mockery;
  modular-arithmetic = dontCheck prev.modular-arithmetic; # tests require a very old Glob (0.7.*)
  nats-queue = dontCheck prev.nats-queue;
  netpbm = dontCheck prev.netpbm;
  network = dontCheck prev.network;
  network_2_6_3_1 = dontCheck prev.network_2_6_3_1;
  network-dbus = dontCheck prev.network-dbus;
  notcpp = dontCheck prev.notcpp;
  ntp-control = dontCheck prev.ntp-control;
  numerals = dontCheck prev.numerals;
  odpic-raw = dontCheck prev.odpic-raw; # needs a running oracle database server
  opaleye = dontCheck prev.opaleye;
  openpgp = dontCheck prev.openpgp;
  optional = dontCheck prev.optional;
  orgmode-parse = dontCheck prev.orgmode-parse;
  os-release = dontCheck prev.os-release;
  persistent-redis = dontCheck prev.persistent-redis;
  pipes-extra = dontCheck prev.pipes-extra;
  pipes-websockets = dontCheck prev.pipes-websockets;
  posix-pty = dontCheck prev.posix-pty; # https://github.com/merijn/posix-pty/issues/12
  postgresql-binary = dontCheck prev.postgresql-binary; # needs a running postgresql server
  postgresql-simple-migration = dontCheck prev.postgresql-simple-migration;
  process-streaming = dontCheck prev.process-streaming;
  punycode = dontCheck prev.punycode;
  pwstore-cli = dontCheck prev.pwstore-cli;
  quantities = dontCheck prev.quantities;
  redis-io = dontCheck prev.redis-io;
  rethinkdb = dontCheck prev.rethinkdb;
  Rlang-QQ = dontCheck prev.Rlang-QQ;
  safecopy = dontCheck prev.safecopy;
  sai-shape-syb = dontCheck prev.sai-shape-syb;
  saltine = dontCheck prev.saltine; # https://github.com/tel/saltine/pull/56
  scp-streams = dontCheck prev.scp-streams;
  sdl2 = dontCheck prev.sdl2; # the test suite needs an x server
  sdl2-ttf = dontCheck prev.sdl2-ttf; # as of version 0.2.1, the test suite requires user intervention
  separated = dontCheck prev.separated;
  shadowsocks = dontCheck prev.shadowsocks;
  shake-language-c = dontCheck prev.shake-language-c;
  snap-core = dontCheck prev.snap-core;
  sourcemap = dontCheck prev.sourcemap;
  static-resources = dontCheck prev.static-resources;
  strive = dontCheck prev.strive;                      # fails its own hlint test with tons of warnings
  svndump = dontCheck prev.svndump;
  tar = dontCheck prev.tar; #https://hydra.nixos.org/build/25088435/nixlog/2 (fails only on 32-bit)
  th-printf = dontCheck prev.th-printf;
  thumbnail-plus = dontCheck prev.thumbnail-plus;
  tickle = dontCheck prev.tickle;
  tpdb = dontCheck prev.tpdb;
  translatable-intset = dontCheck prev.translatable-intset;
  ua-parser = dontCheck prev.ua-parser;
  unagi-chan = dontCheck prev.unagi-chan;
  wai-logger = dontCheck prev.wai-logger;
  WebBits = dontCheck prev.WebBits;                    # http://hydra.cryp.to/build/499604/log/raw
  webdriver = dontCheck prev.webdriver;
  webdriver-angular = dontCheck prev.webdriver-angular;
  xsd = dontCheck prev.xsd;
  zip-archive = dontCheck prev.zip-archive;  # https://github.com/jgm/zip-archive/issues/57

  # These test suites run for ages, even on a fast machine. This is nuts.
  Random123 = dontCheck prev.Random123;
  systemd = dontCheck prev.systemd;

  # https://github.com/eli-frey/cmdtheline/issues/28
  cmdtheline = dontCheck prev.cmdtheline;

  # https://github.com/bos/snappy/issues/1
  snappy = dontCheck prev.snappy;

  # https://ghc.haskell.org/trac/ghc/ticket/9625
  vty = dontCheck prev.vty;

  # https://github.com/vincenthz/hs-crypto-pubkey/issues/20
  crypto-pubkey = dontCheck prev.crypto-pubkey;

  # https://github.com/Philonous/xml-picklers/issues/5
  xml-picklers = dontCheck prev.xml-picklers;

  # https://github.com/joeyadams/haskell-stm-delay/issues/3
  stm-delay = dontCheck prev.stm-delay;

  # https://github.com/pixbi/duplo/issues/25
  duplo = dontCheck prev.duplo;

  # https://github.com/evanrinehart/mikmod/issues/1
  mikmod = addExtraLibrary prev.mikmod pkgs.libmikmod;

  # https://github.com/basvandijk/threads/issues/10
  threads = dontCheck prev.threads;

  # Missing module.
  rematch = dontCheck prev.rematch;            # https://github.com/tcrayford/rematch/issues/5
  rematch-text = dontCheck prev.rematch-text;  # https://github.com/tcrayford/rematch/issues/6

  # Should not appear in nixpkgs yet (broken anyway)
  yarn2nix = throw "yarn2nix is not yet packaged for nixpkgs. See https://github.com/Profpatsch/yarn2nix#yarn2nix";

  # no haddock since this is an umbrella package.
  cloud-haskell = dontHaddock prev.cloud-haskell;

  # This packages compiles 4+ hours on a fast machine. That's just unreasonable.
  CHXHtml = dontDistribute prev.CHXHtml;

  # https://github.com/NixOS/nixpkgs/issues/6350
  paypal-adaptive-hoops = overrideCabal prev.paypal-adaptive-hoops (drv: { testTarget = "local"; });

  # Avoid "QuickCheck >=2.3 && <2.10" dependency we cannot fulfill in lts-11.x.
  test-framework = dontCheck prev.test-framework;

  # Depends on broken test-framework-quickcheck.
  apiary = dontCheck prev.apiary;
  apiary-authenticate = dontCheck prev.apiary-authenticate;
  apiary-clientsession = dontCheck prev.apiary-clientsession;
  apiary-cookie = dontCheck prev.apiary-cookie;
  apiary-eventsource = dontCheck prev.apiary-eventsource;
  apiary-logger = dontCheck prev.apiary-logger;
  apiary-memcached = dontCheck prev.apiary-memcached;
  apiary-mongoDB = dontCheck prev.apiary-mongoDB;
  apiary-persistent = dontCheck prev.apiary-persistent;
  apiary-purescript = dontCheck prev.apiary-purescript;
  apiary-session = dontCheck prev.apiary-session;
  apiary-websockets = dontCheck prev.apiary-websockets;

  # https://github.com/junjihashimoto/test-sandbox-compose/issues/2
  test-sandbox-compose = dontCheck prev.test-sandbox-compose;

  # Waiting on language-python 0.5.8 https://github.com/bjpop/language-python/issues/60
  xcffib = dontCheck prev.xcffib;

  # https://github.com/afcowie/locators/issues/1
  locators = dontCheck prev.locators;

  # Test suite won't compile against tasty-hunit 0.9.x.
  zlib = dontCheck prev.zlib;

  # Test suite won't compile against tasty-hunit 0.10.x.
  binary-parser = dontCheck prev.binary-parser;
  binary-parsers = dontCheck prev.binary-parsers;
  bytestring-strict-builder = dontCheck prev.bytestring-strict-builder;
  bytestring-tree-builder = dontCheck prev.bytestring-tree-builder;

  # https://github.com/byteverse/bytebuild/issues/19
  bytebuild = dontCheck prev.bytebuild;

  # https://github.com/andrewthad/haskell-ip/issues/67
  ip = dontCheck prev.ip;

  # https://github.com/ndmitchell/shake/issues/206
  # https://github.com/ndmitchell/shake/issues/267
  shake = overrideCabal prev.shake (drv: { doCheck = !pkgs.stdenv.isDarwin && false; });

  # https://github.com/nushio3/doctest-prop/issues/1
  doctest-prop = dontCheck prev.doctest-prop;

  # Missing file in source distribution:
  # - https://github.com/karun012/doctest-discover/issues/22
  # - https://github.com/karun012/doctest-discover/issues/23
  #
  # When these are fixed the following needs to be enabled again:
  #
  # # Depends on itself for testing
  # doctest-discover = addBuildTool prev.doctest-discover
  #   (if pkgs.buildPlatform != pkgs.hostPlatform
  #    then final.buildHaskellPackages.doctest-discover
  #    else dontCheck prev.doctest-discover);
  doctest-discover = dontCheck prev.doctest-discover;

  # Depends on itself for testing
  tasty-discover = addBuildTool prev.tasty-discover
    (if pkgs.buildPlatform != pkgs.hostPlatform
     then final.buildHaskellPackages.tasty-discover
     else dontCheck prev.tasty-discover);

  # Waiting on https://github.com/RaphaelJ/friday/pull/36
  friday = doJailbreak prev.friday;

  # Won't compile with recent versions of QuickCheck.
  inilist = dontCheck prev.inilist;

  # https://github.com/yaccz/saturnin/issues/3
  Saturnin = dontCheck prev.Saturnin;

  # https://github.com/kkardzis/curlhs/issues/6
  curlhs = dontCheck prev.curlhs;

  # https://github.com/hvr/token-bucket/issues/3
  token-bucket = dontCheck prev.token-bucket;

  # https://github.com/alphaHeavy/lzma-enumerator/issues/3
  lzma-enumerator = dontCheck prev.lzma-enumerator;

  # FPCO's fork of Cabal won't succeed its test suite.
  Cabal-ide-backend = dontCheck prev.Cabal-ide-backend;

  # QuickCheck version, also set in cabal2nix
  websockets = dontCheck prev.websockets;

  # Avoid spurious test suite failures.
  fft = dontCheck prev.fft;

  # This package can't be built on non-Windows systems.
  Win32 = overrideCabal prev.Win32 (drv: { broken = !pkgs.stdenv.isCygwin; });
  inline-c-win32 = dontDistribute prev.inline-c-win32;
  Southpaw = dontDistribute prev.Southpaw;

  # Hydra no longer allows building texlive packages.
  lhs2tex = dontDistribute prev.lhs2tex;

  # https://ghc.haskell.org/trac/ghc/ticket/9825
  vimus = overrideCabal prev.vimus (drv: { broken = pkgs.stdenv.isLinux && pkgs.stdenv.isi686; });

  # https://github.com/kazu-yamamoto/logger/issues/42
  logger = dontCheck prev.logger;

  # vector dependency < 0.12
  imagemagick = doJailbreak prev.imagemagick;

  # https://github.com/liyang/thyme/issues/36
  thyme = dontCheck prev.thyme;

  # https://github.com/k0ral/hbro-contrib/issues/1
  hbro-contrib = dontDistribute prev.hbro-contrib;

  # Elm is no longer actively maintained on Hackage: https://github.com/NixOS/nixpkgs/pull/9233.
  Elm = markBroken prev.Elm;
  elm-build-lib = markBroken prev.elm-build-lib;
  elm-compiler = markBroken prev.elm-compiler;
  elm-get = markBroken prev.elm-get;
  elm-make = markBroken prev.elm-make;
  elm-package = markBroken prev.elm-package;
  elm-reactor = markBroken prev.elm-reactor;
  elm-repl = markBroken prev.elm-repl;
  elm-server = markBroken prev.elm-server;
  elm-yesod = markBroken prev.elm-yesod;

  # https://github.com/Euterpea/Euterpea2/issues/40
  Euterpea = appendPatch prev.Euterpea (pkgs.fetchpatch {
    url = "https://github.com/Euterpea/Euterpea2/pull/38.patch";
    sha256 = "13g462qmj8c7if797gnyvf8h0cddmm3xy0pjldw48w8f8sr4qsj0";
  });

  # Install icons, metadata and cli program.
  bustle = overrideCabal prev.bustle (drv: {
    buildDepends = [ pkgs.libpcap ];
    buildTools = with pkgs.buildPackages; [ gettext perl help2man ];
    postInstall = ''
      make install PREFIX=$out
    '';
  });

  # Byte-compile elisp code for Emacs.
  ghc-mod = overrideCabal prev.ghc-mod (drv: {
    preCheck = "export HOME=$TMPDIR";
    testToolDepends = drv.testToolDepends or [] ++ [final.cabal-install];
    doCheck = false;            # https://github.com/kazu-yamamoto/ghc-mod/issues/335
    executableToolDepends = drv.executableToolDepends or [] ++ [pkgs.emacs];
    postInstall = ''
      local lispdir=( "$data/share/${final.ghc.name}/*/${drv.pname}-${drv.version}/elisp" )
      make -C $lispdir
      mkdir -p $data/share/emacs/site-lisp
      ln -s "$lispdir/"*.el{,c} $data/share/emacs/site-lisp/
    '';
  });

  # Build the latest git version instead of the official release. This isn't
  # ideal, but Chris doesn't seem to make official releases any more.
  structured-haskell-mode = overrideCabal prev.structured-haskell-mode (drv: {
    src = pkgs.fetchFromGitHub {
      owner = "projectional-haskell";
      repo = "structured-haskell-mode";
      rev = "7f9df73f45d107017c18ce4835bbc190dfe6782e";
      sha256 = "1jcc30048j369jgsbbmkb63whs4wb37bq21jrm3r6ry22izndsqa";
    };
    version = "20170205-git";
    editedCabalFile = null;
    # Make elisp files available at a location where people expect it. We
    # cannot easily byte-compile these files, unfortunately, because they
    # depend on a new version of haskell-mode that we don't have yet.
    postInstall = ''
      local lispdir=( "$data/share/${final.ghc.name}/"*"/${drv.pname}-"*"/elisp" )
      mkdir -p $data/share/emacs
      ln -s $lispdir $data/share/emacs/site-lisp
    '';
  });

  # Make elisp files available at a location where people expect it.
  hindent = (overrideCabal prev.hindent (drv: {
    # We cannot easily byte-compile these files, unfortunately, because they
    # depend on a new version of haskell-mode that we don't have yet.
    postInstall = ''
      local lispdir=( "$data/share/${final.ghc.name}/"*"/${drv.pname}-"*"/elisp" )
      mkdir -p $data/share/emacs
      ln -s $lispdir $data/share/emacs/site-lisp
    '';
    doCheck = false; # https://github.com/chrisdone/hindent/issues/299
  }));

  # https://github.com/bos/configurator/issues/22
  configurator = dontCheck prev.configurator;

  # https://github.com/basvandijk/concurrent-extra/issues/12
  concurrent-extra = dontCheck prev.concurrent-extra;

  # https://github.com/bos/bloomfilter/issues/7
  bloomfilter = appendPatch prev.bloomfilter ./patches/bloomfilter-fix-on-32bit.patch;

  # https://github.com/ashutoshrishi/hunspell-hs/pull/3
  hunspell-hs = addPkgconfigDepend (dontCheck (appendPatch prev.hunspell-hs ./patches/hunspell.patch)) pkgs.hunspell;

  # https://github.com/pxqr/base32-bytestring/issues/4
  base32-bytestring = dontCheck prev.base32-bytestring;

  # Djinn's last release was 2014, incompatible with Semigroup-Monoid Proposal
  # https://github.com/augustss/djinn/pull/8
  djinn = appendPatch prev.djinn (pkgs.fetchpatch {
    url = "https://github.com/augustss/djinn/commit/6cb9433a137fb6b5194afe41d616bd8b62b95630.patch";
    sha256 = "0s021y5nzrh74gfp8xpxpxm11ivzfs3jwg6mkrlyry3iy584xqil";
  });

  # We cannot build this package w/o the C library from <http://www.phash.org/>.
  phash = markBroken prev.phash;

  # https://github.com/Philonous/hs-stun/pull/1
  # Remove if a version > 0.1.0.1 ever gets released.
  stunclient = overrideCabal prev.stunclient (drv: {
    postPatch = (drv.postPatch or "") + ''
      substituteInPlace source/Network/Stun/MappedAddress.hs --replace "import Network.Endian" ""
    '';
  });

  # The standard libraries are compiled separately.
  idris = generateOptparseApplicativeCompletion "idris" (dontCheck prev.idris);

  # build servant docs from the repository
  servant =
    let
      ver = prev.servant.version;
      docs = pkgs.stdenv.mkDerivation {
        name = "servant-sphinx-documentation-${ver}";
        src = "${pkgs.fetchFromGitHub {
          owner = "haskell-servant";
          repo = "servant";
          rev = "v${ver}";
          sha256 = "0xk3czk3jhqjxhy0g8r2248m8yxgvmqhgn955k92z0h7p02lfs89";
        }}/doc";
        # Needed after sphinx 1.7.9 -> 1.8.3
        postPatch = ''
          substituteInPlace conf.py --replace "'.md': CommonMarkParser," ""
        '';
        nativeBuildInputs = with pkgs.buildPackages.pythonPackages; [ sphinx recommonmark sphinx_rtd_theme ];
        makeFlags = [ "html" ];
        installPhase = ''
          mv _build/html $out
        '';
      };
    in overrideCabal prev.servant (old: {
      postInstall = old.postInstall or "" + ''
        ln -s ${docs} ''${!outputDoc}/share/doc/servant
      '';
    });

  # https://github.com/pontarius/pontarius-xmpp/issues/105
  pontarius-xmpp = dontCheck prev.pontarius-xmpp;

  # fails with sandbox
  yi-keymap-vim = dontCheck prev.yi-keymap-vim;

  # https://github.com/bmillwood/applicative-quoters/issues/6
  applicative-quoters = doJailbreak prev.applicative-quoters;

  # https://hydra.nixos.org/build/42769611/nixlog/1/raw
  # note: the library is unmaintained, no upstream issue
  dataenc = doJailbreak prev.dataenc;

  # https://github.com/divipp/ActiveHs-misc/issues/10
  data-pprint = doJailbreak prev.data-pprint;

  # horribly outdated (X11 interface changed a lot)
  sindre = markBroken prev.sindre;

  # Test suite occasionally runs for 1+ days on Hydra.
  distributed-process-tests = dontCheck prev.distributed-process-tests;

  # https://github.com/mulby/diff-parse/issues/9
  diff-parse = doJailbreak prev.diff-parse;

  # https://github.com/josefs/STMonadTrans/issues/4
  STMonadTrans = dontCheck prev.STMonadTrans;

  # No upstream issue tracker
  hspec-expectations-pretty-diff = dontCheck prev.hspec-expectations-pretty-diff;

  # Don't depend on chell-quickcheck, which doesn't compile due to restricting
  # QuickCheck to versions ">=2.3 && <2.9".
  system-filepath = dontCheck prev.system-filepath;

  # https://github.com/hvr/uuid/issues/28
  uuid-types = doJailbreak prev.uuid-types;
  uuid = doJailbreak prev.uuid;

  # The tests spuriously fail
  libmpd = dontCheck prev.libmpd;

  # https://github.com/diagrams/diagrams-lib/issues/288
  diagrams-lib = overrideCabal prev.diagrams-lib (drv: { doCheck = !pkgs.stdenv.isi686; });

  # https://github.com/danidiaz/streaming-eversion/issues/1
  streaming-eversion = dontCheck prev.streaming-eversion;

  # https://github.com/danidiaz/tailfile-hinotify/issues/2
  tailfile-hinotify = dontCheck prev.tailfile-hinotify;

  # Test suite fails: https://github.com/lymar/hastache/issues/46.
  # Don't install internal mkReadme tool.
  hastache = overrideCabal prev.hastache (drv: {
    doCheck = false;
    postInstall = "rm $out/bin/mkReadme && rmdir $out/bin";
  });

  # Has a dependency on outdated versions of directory.
  cautious-file = doJailbreak (dontCheck prev.cautious-file);

  # https://github.com/diagrams/diagrams-solve/issues/4
  diagrams-solve = dontCheck prev.diagrams-solve;

  # test suite does not compile with recent versions of QuickCheck
  integer-logarithms = dontCheck (prev.integer-logarithms);

  # missing dependencies: blaze-html >=0.5 && <0.9, blaze-markup >=0.5 && <0.8
  digestive-functors-blaze = doJailbreak prev.digestive-functors-blaze;
  digestive-functors = doJailbreak prev.digestive-functors;

  # https://github.com/takano-akio/filelock/issues/5
  filelock = dontCheck prev.filelock;

  # Wrap the generated binaries to include their run-time dependencies in
  # $PATH. Also, cryptol needs a version of sbl that's newer than what we have
  # in LTS-13.x.
  cryptol = overrideCabal prev.cryptol (drv: {
    buildTools = drv.buildTools or [] ++ [ pkgs.makeWrapper ];
    postInstall = drv.postInstall or "" + ''
      for b in $out/bin/cryptol $out/bin/cryptol-html; do
        wrapProgram $b --prefix 'PATH' ':' "${pkgs.lib.getBin pkgs.z3}/bin"
      done
    '';
  });

  # Tests try to invoke external process and process == 1.4
  grakn = dontCheck (doJailbreak prev.grakn);

  # test suite requires git and does a bunch of git operations
  restless-git = dontCheck prev.restless-git;

  # Depends on broken fluid.
  fluid-idl-http-client = markBroken prev.fluid-idl-http-client;
  fluid-idl-scotty = markBroken prev.fluid-idl-scotty;

  # Work around https://github.com/haskell/c2hs/issues/192.
  c2hs = dontCheck prev.c2hs;

  # Needs pginit to function and pgrep to verify.
  tmp-postgres = overrideCabal prev.tmp-postgres (drv: {
    libraryToolDepends = drv.libraryToolDepends or [] ++ [pkgs.postgresql];
    testToolDepends = drv.testToolDepends or [] ++ [pkgs.procps];
  });

  # Needs QuickCheck <2.10, which we don't have.
  edit-distance = doJailbreak prev.edit-distance;
  blaze-html = doJailbreak prev.blaze-html;
  int-cast = doJailbreak prev.int-cast;

  # Needs QuickCheck <2.10, HUnit <1.6 and base <4.10
  pointfree = doJailbreak prev.pointfree;

  # Depends on tasty < 1.x, which we don't have.
  cryptohash-sha256 = doJailbreak prev.cryptohash-sha256;

  # Needs tasty-quickcheck ==0.8.*, which we don't have.
  cryptohash-sha1 = doJailbreak prev.cryptohash-sha1;
  cryptohash-md5 = doJailbreak prev.cryptohash-md5;
  gitHUD = dontCheck prev.gitHUD;
  githud = dontCheck prev.githud;

  # https://github.com/aisamanra/config-ini/issues/12
  config-ini = dontCheck prev.config-ini;

  # doctest >=0.9 && <0.12
  path = dontCheck prev.path;

  # Test suite fails due to trying to create directories
  path-io = dontCheck prev.path-io;

  # Duplicate instance with smallcheck.
  store = dontCheck prev.store;

  # With ghc-8.2.x haddock would time out for unknown reason
  # See https://github.com/haskell/haddock/issues/679
  language-puppet = dontHaddock prev.language-puppet;
  filecache = overrideCabal prev.filecache (drv: { doCheck = !pkgs.stdenv.isDarwin; });

  # https://github.com/alphaHeavy/protobuf/issues/34
  protobuf = dontCheck prev.protobuf;

  # https://github.com/bos/text-icu/issues/32
  text-icu = dontCheck prev.text-icu;

  # aarch64 and armv7l fixes.
  happy = if (pkgs.stdenv.hostPlatform.isAarch32 || pkgs.stdenv.hostPlatform.isAarch64) then dontCheck prev.happy else prev.happy; # Similar to https://ghc.haskell.org/trac/ghc/ticket/13062
  hashable = if (pkgs.stdenv.hostPlatform.isAarch32 || pkgs.stdenv.hostPlatform.isAarch64) then dontCheck prev.hashable else prev.hashable; # https://github.com/tibbe/hashable/issues/95
  servant-docs =
    let
      f = if (pkgs.stdenv.hostPlatform.isAarch32 || pkgs.stdenv.hostPlatform.isAarch64)
          then dontCheck
          else pkgs.lib.id;
    in doJailbreak (f prev.servant-docs); # jailbreak tasty < 1.2 until servant-docs > 0.11.3 is on hackage.
  snap-templates = doJailbreak prev.snap-templates; # https://github.com/snapframework/snap-templates/issues/22
  swagger2 = if (pkgs.stdenv.hostPlatform.isAarch32 || pkgs.stdenv.hostPlatform.isAarch64) then dontHaddock (dontCheck prev.swagger2) else prev.swagger2;

  # Copy hledger man pages from data directory into the proper place. This code
  # should be moved into the cabal2nix generator.
  hledger = overrideCabal prev.hledger (drv: {
    postInstall = ''
      # Don't install files that don't belong into this package to avoid
      # conflicts when hledger and hledger-ui end up in the same profile.
      rm embeddedfiles/hledger-{api,ui,web}.*
      for i in $(seq 1 9); do
        for j in embeddedfiles/*.$i; do
          mkdir -p $out/share/man/man$i
          cp -v $j $out/share/man/man$i/
        done
      done
      mkdir -p $out/share/info
      cp -v embeddedfiles/*.info* $out/share/info/
    '';
  });
  hledger-ui = overrideCabal prev.hledger-ui (drv: {
    postInstall = ''
      for i in $(seq 1 9); do
        for j in *.$i; do
          mkdir -p $out/share/man/man$i
          cp -v $j $out/share/man/man$i/
        done
      done
      mkdir -p $out/share/info
      cp -v *.info* $out/share/info/
    '';
  });
  hledger-web = overrideCabal prev.hledger-web (drv: {
    postInstall = ''
      for i in $(seq 1 9); do
        for j in *.$i; do
          mkdir -p $out/share/man/man$i
          cp -v $j $out/share/man/man$i/
        done
      done
      mkdir -p $out/share/info
      cp -v *.info* $out/share/info/
    '';
  });


  # https://github.com/haskell-hvr/resolv/pull/6
  resolv_0_1_1_2 = dontCheck prev.resolv_0_1_1_2;

  # spdx 0.2.2.0 needs older tasty
  # was fixed in spdx master (4288df6e4b7840eb94d825dcd446b42fef25ef56)
  spdx = dontCheck prev.spdx;

  # The test suite does not know how to find the 'alex' binary.
  alex = overrideCabal prev.alex (drv: {
    testSystemDepends = (drv.testSystemDepends or []) ++ [pkgs.which];
    preCheck = ''export PATH="$PWD/dist/build/alex:$PATH"'';
  });

  # This package refers to the wrong library (itself in fact!)
  vulkan = prev.vulkan.override { vulkan = pkgs.vulkan-loader; };

  # Compiles some C++ source which requires these headers
  VulkanMemoryAllocator = addExtraLibrary prev.VulkanMemoryAllocator pkgs.vulkan-headers;

  # https://github.com/dmwit/encoding/pull/3
  encoding = doJailbreak (appendPatch prev.encoding ./patches/encoding-Cabal-2.0.patch);

  # Work around overspecified constraint on github ==0.18.
  github-backup = doJailbreak prev.github-backup;

  # Test suite depends on cabal-install
  doctest = dontCheck prev.doctest;

  # https://github.com/haskell-servant/servant-auth/issues/113
  servant-auth-client = dontCheck prev.servant-auth-client;

  # Generate cli completions for dhall.
  dhall = generateOptparseApplicativeCompletion "dhall" prev.dhall;
  dhall-json = generateOptparseApplicativeCompletions ["dhall-to-json" "dhall-to-yaml"] prev.dhall-json;
  dhall-nix = generateOptparseApplicativeCompletion "dhall-to-nix" (prev.dhall-nix);

  # https://github.com/haskell-hvr/netrc/pull/2#issuecomment-469526558
  netrc = doJailbreak prev.netrc;

  # https://github.com/haskell-hvr/hgettext/issues/14
  hgettext = doJailbreak prev.hgettext;

  # Generate shell completion.
  cabal2nix = generateOptparseApplicativeCompletion "cabal2nix" prev.cabal2nix;
  stack = generateOptparseApplicativeCompletion "stack" prev.stack;

  # musl fixes
  # dontCheck: use of non-standard strptime "%s" which musl doesn't support; only used in test
  unix-time = if pkgs.stdenv.hostPlatform.isMusl then dontCheck prev.unix-time else prev.unix-time;
  # dontCheck: printf double rounding behavior
  prettyprinter = if pkgs.stdenv.hostPlatform.isMusl then dontCheck prev.prettyprinter else prev.prettyprinter;

  # Fix with Cabal 2.2, https://github.com/guillaume-nargeot/hpc-coveralls/pull/73
  hpc-coveralls = appendPatch prev.hpc-coveralls (pkgs.fetchpatch {
    url = "https://github.com/guillaume-nargeot/hpc-coveralls/pull/73/commits/344217f513b7adfb9037f73026f5d928be98d07f.patch";
    sha256 = "056rk58v9h114mjx62f41x971xn9p3nhsazcf9zrcyxh1ymrdm8j";
  });

  # sexpr is old, broken and has no issue-tracker. Let's fix it the best we can.
  sexpr =
    appendPatch (overrideCabal prev.sexpr (drv: {
      isExecutable = false;
      libraryHaskellDepends = drv.libraryHaskellDepends ++ [final.QuickCheck];
    })) ./patches/sexpr-0.2.1.patch;

  # https://github.com/haskell/hoopl/issues/50
  hoopl = dontCheck prev.hoopl;

  purescript =
    let
      purescriptWithOverrides = prev.purescript.override {
        # PureScript requires an older version of happy.
        happy = final.happy_1_19_9;
      };

      # PureScript is built against LTS-13, so we need to jailbreak it to
      # accept more recent versions of the libraries it requires.
      jailBrokenPurescript = doJailbreak purescriptWithOverrides;

      # Haddocks for PureScript can't be built.
      # https://github.com/purescript/purescript/pull/3745
      dontHaddockPurescript = dontHaddock jailBrokenPurescript;
    in
    # Generate shell completions
    generateOptparseApplicativeCompletion "purs" dontHaddockPurescript;

  # Generate shell completion for spago
  spago = generateOptparseApplicativeCompletion "spago" prev.spago;

  # 2020-06-05: HACK: Package can not pass test suite,
  # Upstream Report: https://github.com/kcsongor/generic-lens/issues/83
  generic-lens = dontCheck prev.generic-lens;

  # https://github.com/danfran/cabal-macosx/issues/13
  cabal-macosx = dontCheck prev.cabal-macosx;

  # https://github.com/DanielG/cabal-helper/pull/123
  cabal-helper = doJailbreak prev.cabal-helper;

  # TODO(Profpatsch): factor out local nix store setup from
  # lib/tests/release.nix and use that for the tests of libnix
  # libnix = overrideCabal prev.libnix (old: {
  #   testToolDepends = old.testToolDepends or [] ++ [ pkgs.nix ];
  # });
  libnix = dontCheck prev.libnix;

  # dontCheck: The test suite tries to mess with ALSA, which doesn't work in the build sandbox.
  xmobar = dontCheck prev.xmobar;

  # https://github.com/mgajda/json-autotype/issues/25
  json-autotype = dontCheck prev.json-autotype;

  # Requires pg_ctl command during tests
  beam-postgres = overrideCabal prev.beam-postgres (drv: {
    testToolDepends = (drv.testToolDepends or []) ++ [pkgs.postgresql];
    });

  # Fix for base >= 4.11
  scat = overrideCabal prev.scat (drv: {
    patches = [(pkgs.fetchpatch {
      url    = "https://github.com/redelmann/scat/pull/6.diff";
      sha256 = "07nj2p0kg05livhgp1hkkdph0j0a6lb216f8x348qjasy0lzbfhl";
    })];
  });

  # 2020-06-05: HACK: In Nixpkgs currently this is
  # old pandoc version 2.7.4 to current 2.9.2.1,
  # test suite failures: https://github.com/jgm/pandoc/issues/5582
  pandoc = dontCheck prev.pandoc;

  # Fix build with attr-2.4.48 (see #53716)
  xattr = appendPatch prev.xattr ./patches/xattr-fix-build.patch;

  # Some tests depend on a postgresql instance
  esqueleto = dontCheck prev.esqueleto;

  # Requires API keys to run tests
  algolia = dontCheck prev.algolia;

  # antiope-s3's latest stackage version has a hspec < 2.6 requirement, but
  # hspec which isn't in stackage is already past that
  antiope-s3 = doJailbreak prev.antiope-s3;

  # Has tasty < 1.2 requirement, but works just fine with 1.2
  temporary-resourcet = doJailbreak prev.temporary-resourcet;

  # Requires dhall >= 1.23.0
  ats-pkg = dontCheck (prev.ats-pkg.override { dhall = final.dhall_1_29_0; });

  # fake a home dir and capture generated man page
  ats-format = overrideCabal prev.ats-format (old : {
    preConfigure = "export HOME=$PWD";
    postBuild = "mv .local/share $out";
  });

  # Test suite doesn't work with current QuickCheck
  # https://github.com/pruvisto/heap/issues/11
  heap = dontCheck prev.heap;

  # Test suite won't link for no apparent reason.
  constraints-deriving = dontCheck prev.constraints-deriving;

  # https://github.com/elliottt/hsopenid/issues/15
  openid = markBroken prev.openid;

  # The test suite needs the packages's executables in $PATH to succeed.
  arbtt = overrideCabal prev.arbtt (drv: {
    preCheck = ''
      for i in $PWD/dist/build/*; do
        export PATH="$i:$PATH"
      done
    '';
  });

  # https://github.com/erikd/hjsmin/issues/32
  hjsmin = dontCheck prev.hjsmin;

  nix-tools = prev.nix-tools.overrideScope (final: prev: {
    # Needs https://github.com/peti/hackage-db/pull/9
    hackage-db = prev.hackage-db.overrideAttrs (old: {
      src = pkgs.fetchFromGitHub {
        owner = "ElvishJerricco";
        repo = "hackage-db";
        rev = "84ca9fc75ad45a71880e938e0d93ea4bde05f5bd";
        sha256 = "0y3kw1hrxhsqmyx59sxba8npj4ya8dpgjljc21gkgdvdy9628q4c";
      };
    });
  });

  # upstream issue: https://github.com/vmchale/atspkg/issues/12
  language-ats = dontCheck prev.language-ats;

  # Remove for hail > 0.2.0.0
  hail = overrideCabal prev.hail (drv: {
    patches = [
      (pkgs.fetchpatch {
        # Relax dependency constraints,
        # upstream PR: https://github.com/james-preston/hail/pull/13
        url = "https://patch-diff.githubusercontent.com/raw/james-preston/hail/pull/13.patch";
        sha256 = "039p5mqgicbhld2z44cbvsmam3pz0py3ybaifwrjsn1y69ldsmkx";
      })
      (pkgs.fetchpatch {
        # Relax dependency constraints,
        # upstream PR: https://github.com/james-preston/hail/pull/15
        url = "https://patch-diff.githubusercontent.com/raw/james-preston/hail/pull/15.patch";
        sha256 = "03kdvr8hxi6isb8yxp5rgcmz855n19m1yacn3d56a4i58j2mldjw";
      })
    ];
  });

  # https://github.com/kazu-yamamoto/dns/issues/150
  dns = dontCheck prev.dns;

  # apply patches from https://github.com/snapframework/snap-server/pull/126
  # manually until they are accepted upstream
  snap-server = overrideCabal prev.snap-server (drv: {
    patches = [(pkgs.fetchpatch {
      # allow compilation with network >= 3
      url = "https://github.com/snapframework/snap-server/pull/126/commits/4338fe15d68e11e3c7fd0f9862f818864adc1d45.patch";
      sha256 = "1nlw9lckm3flzkmhkzwc7zxhdh9ns33w8p8ds8nf574nqr5cr8bv";
    })
    (pkgs.fetchpatch {
      # prefer fdSocket over unsafeFdSocket
      url = "https://github.com/snapframework/snap-server/pull/126/commits/410de2df123b1d56b3093720e9c6a1ad79fe9de6.patch";
      sha256 = "08psvw0xny64q4bw1nwg01pkzh01ak542lw6k1ps7cdcwaxk0n94";
    })];
  });

  # https://github.com/haskell-servant/servant-blaze/issues/17
  servant-blaze = doJailbreak prev.servant-blaze;

  # https://github.com/haskell-servant/servant-ekg/issues/15
  servant-ekg = doJailbreak prev.servant-ekg;

  # the test suite has an overly tight restriction on doctest
  # See https://github.com/ekmett/perhaps/pull/5
  perhaps = doJailbreak prev.perhaps;

  # it wants to build a statically linked binary by default
  hledger-flow = overrideCabal prev.hledger-flow ( drv: {
    postPatch = (drv.postPatch or "") + ''
      substituteInPlace hledger-flow.cabal --replace "-static" ""
    '';
  });

  # gtk/gtk3 needs to be told on Darwin to use the Quartz
  # rather than X11 backend (see eg https://github.com/gtk2hs/gtk2hs/issues/249).
  gtk3 = appendConfigureFlags prev.gtk3 (pkgs.lib.optional pkgs.stdenv.isDarwin "-f have-quartz-gtk");
  gtk = appendConfigureFlags prev.gtk (pkgs.lib.optional pkgs.stdenv.isDarwin "-f have-quartz-gtk");

  # Chart-tests needs and compiles some modules from Chart itself
  Chart-tests = (addExtraLibrary prev.Chart-tests final.QuickCheck).overrideAttrs (old: {
    preCheck = old.postPatch or "" + ''
      tar --one-top-level=../chart --strip-components=1 -xf ${final.Chart.src}
    '';
  });

  # This breaks because of version bounds, but compiles and runs fine.
  # Last commit is 5 years ago, so we likely won't get upstream fixed soon.
  # https://bitbucket.org/rvlm/hakyll-contrib-hyphenation/src/master/
  # Therefore we jailbreak it.
  hakyll-contrib-hyphenation = doJailbreak prev.hakyll-contrib-hyphenation;

  # 2020-06-22: NOTE: > 0.4.0 => rm Jailbreak: https://github.com/serokell/nixfmt/issues/71
  nixfmt = doJailbreak prev.nixfmt;

  # 2020-06-22: NOTE: QuickCheck upstreamed https://github.com/phadej/binary-instances/issues/7
  binary-instances = dontCheck prev.binary-instances;

  # Disabling the test suite lets the build succeed on older CPUs
  # that are unable to run the generated library because they
  # lack support for AES-NI, like some of our Hydra build slaves
  # do. See https://github.com/NixOS/nixpkgs/issues/81915 for
  # details.
  cryptonite = dontCheck prev.cryptonite;

  # The test suite depends on an impure cabal-install installation in
  # $HOME, which we don't have in our build sandbox.
  cabal-install-parsers = dontCheck prev.cabal-install-parsers;

  # gitit is unbroken in the latest release
  gitit = markUnbroken prev.gitit;

  # Test suite requires database
  persistent-mysql = dontCheck prev.persistent-mysql;
  persistent-postgresql = dontCheck prev.persistent-postgresql;

  # Fix EdisonAPI and EdisonCore for GHC 8.8:
  # https://github.com/robdockins/edison/pull/16
  EdisonAPI = appendPatch prev.EdisonAPI (pkgs.fetchpatch {
    url = "https://github.com/robdockins/edison/pull/16/commits/8da6c0f7d8666766e2f0693425c347c0adb492dc.patch";
    postFetch = ''
      ${pkgs.patchutils}/bin/filterdiff --include='a/edison-api/*' --strip=1 "$out" > "$tmpfile"
      mv "$tmpfile" "$out"
    '';
    sha256 = "0yi5pz039lcm4pl9xnl6krqxyqq5rgb5b6m09w0sfy06x0n4x213";
  });

  EdisonCore = appendPatch prev.EdisonCore (pkgs.fetchpatch {
    url = "https://github.com/robdockins/edison/pull/16/commits/8da6c0f7d8666766e2f0693425c347c0adb492dc.patch";
    postFetch = ''
      ${pkgs.patchutils}/bin/filterdiff --include='a/edison-core/*' --strip=1 "$out" > "$tmpfile"
      mv "$tmpfile" "$out"
    '';
    sha256 = "097wqn8hxsr50b9mhndg5pjim5jma2ym4ylpibakmmb5m98n17zp";
  });

  # polysemy-plugin 0.2.5.0 has constraint ghc-tcplugins-extra (==0.3.*)
  # This upstream issue is relevant:
  # https://github.com/polysemy-research/polysemy/issues/322
  polysemy-plugin = prev.polysemy-plugin.override {
    ghc-tcplugins-extra = final.ghc-tcplugins-extra_0_3_2;
  };

  # Test suite requires running a database server. Testing is done upstream.
  hasql-notifications = dontCheck prev.hasql-notifications;
  hasql-pool = dontCheck prev.hasql-pool;

  # This bumps optparse-applicative to <0.16 in the cabal file, as otherwise
  # the version bounds are not satisfied.  This can be removed if the PR at
  # https://github.com/ananthakumaran/webify/pull/27 is merged and a new
  # release of webify is published.
  webify = appendPatch prev.webify (pkgs.fetchpatch {
    url = "https://github.com/ananthakumaran/webify/pull/27/commits/6d653e7bdc1ffda75ead46851b5db45e87cb2aa0.patch";
    sha256 = "0xbfhzhzg94b4r5qy5dg1c40liswwpqarrc2chcwgfbfnrmwkfc2";
  });

  # this will probably need to get updated with every ghcide update,
  # we need an override because ghcide is tracking haskell-lsp closely.
  ghcide = dontCheck (prev.ghcide.override { ghc-check = final.ghc-check_0_3_0_1; });

  # hasn‘t bumped upper bounds
  # upstream: https://github.com/obsidiansystems/which/pull/6
  which = doJailbreak prev.which;

  # the test suite attempts to run the binaries built in this package
  # through $PATH but they aren't in $PATH
  dhall-lsp-server = dontCheck prev.dhall-lsp-server;

  # https://github.com/ocharles/weeder/issues/15
  weeder = doJailbreak prev.weeder;

  # Requested version bump on upstream https://github.com/obsidiansystems/constraints-extras/issues/32
  constraints-extras = doJailbreak prev.constraints-extras;

  # Necessary for stack
  # x509-validation test suite hangs: upstream https://github.com/vincenthz/hs-certificate/issues/120
  # tls test suite fails: upstream https://github.com/vincenthz/hs-tls/issues/434
  x509-validation = dontCheck prev.x509-validation;
  tls = dontCheck prev.tls;

  # Upstream PR: https://github.com/bgamari/monoidal-containers/pull/62
  # Bump these version bound
  monoidal-containers = appendPatch prev.monoidal-containers (pkgs.fetchpatch {
    url = "https://github.com/bgamari/monoidal-containers/commit/715093b22a015398a1390f636be6f39a0de83254.patch";
    sha256="1lfxvwp8g55ljxvj50acsb0wjhrvp2hvir8y0j5pfjkd1kq628ng";
  });

  patch = appendPatches prev.patch [
    # Upstream PR: https://github.com/reflex-frp/patch/pull/20
    # Makes tests work with hlint 3
    (pkgs.fetchpatch {
      url = "https://github.com/reflex-frp/patch/commit/3ed23a4e4049ee17e64a1a5bbebf1990cdbe033a.patch";
      sha256 ="1hfa980wln8kzbqw1lr8ddszgcibw25xf12ki2jb9xkl464aynzf";
    })
    # Upstream PR: https://github.com/reflex-frp/patch/pull/17
    # Bumps version dependencies
    (pkgs.fetchpatch {
      url = "https://github.com/reflex-frp/patch/commit/a191ed9ded708ed7ff0cf53ad6dafaf54db5b95a.patch";
      sha256 ="1x9w5fimhk3a0l2aa5z91nqaa6s2irz1775iidd0191m6w25vszp";
    })
  ];

  reflex = appendPatches prev.reflex [
    # Upstream PR: https://github.com/reflex-frp/reflex/pull/434
    # Bump version bounds
    (pkgs.fetchpatch {
      url = "https://github.com/reflex-frp/reflex/commit/e6104bdfd7f664f524b6765275490722e376df4d.patch";
      sha256 ="1awp5p4640cnhfd50dplsvp0kzy6h8r0hpbw1s40blni74r3dhzr";
    })
    # Upstream PR: https://github.com/reflex-frp/reflex/pull/436
    # Fix build with newest dependent-map version
    (pkgs.fetchpatch {
      url = "https://github.com/reflex-frp/reflex/commit/dc3bf44d822d70594e3c474fe3869261776c3554.patch";
      sha256 ="0rbjfj9b8p6zkvd5j4pak5kpgard6cyfvzk750s4xwpc1v84iiqd";
    })
    # Upstream PR: https://github.com/reflex-frp/reflex/pull/437
    # Fix tests with newer dep versions
    (pkgs.fetchpatch {
      url = "https://github.com/reflex-frp/reflex/commit/87c74a1b9d9098eae8a56148c59ed4963a5232c2.patch";
      sha256 ="0qhjjgd6n4fms1hpbblny78c95bfh74izhx9dvrdlnhz6q7xlm9q";
    })
  ];

  # Tests disabled and broken override needed because of missing lib chrome-test-utils: https://github.com/reflex-frp/reflex-dom/issues/392
  # Tests disabled because of very old dep: https://github.com/reflex-frp/reflex-dom/issues/393
  reflex-dom-core = doDistribute (unmarkBroken (dontCheck (appendPatches prev.reflex-dom-core [
    # Upstream PR: https://github.com/reflex-frp/reflex-dom/pull/388
    # Fix upper bounds
    (pkgs.fetchpatch {
      url = "https://github.com/reflex-frp/reflex-dom/commit/5ef04d8e478f410d2c63603b84af052c9273a533.patch";
      sha256 ="0d0b819yh8mqw8ih5asdi9qcca2kmggfsi8gf22akfw1n7xvmavi";
      stripLen = 2;
      extraPrefix = "";
    })
    # Upstream PR: https://github.com/reflex-frp/reflex-dom/pull/394
    # Bump dependent-map
    (pkgs.fetchpatch {
      url = "https://github.com/reflex-frp/reflex-dom/commit/695bd17d5dcdb1bf321ee8858670731637f651db.patch";
      sha256 ="0llky3i37rakgsw9vqaqmwryv7s91w8ph8xjkh83nxjs14p5zfyk";
      stripLen = 2;
      extraPrefix = "";
    })
  ])));

  # add unreleased commit fixing version constraint as a patch
  # Can be removed if https://github.com/lpeterse/haskell-utc/issues/8 is resolved
  utc = appendPatch prev.utc (pkgs.fetchpatch {
    url = "https://github.com/lpeterse/haskell-utc/commit/e4502c08591e80d411129bb7c0414539f6302aaf.diff";
    sha256 = "0v6kv1d4syjzgzc2s7a76c6k4vminlcq62n7jg3nn9xd00gwmmv7";
  });

  # Tests disabled because they assume to run in the whole jsaddle repo and not the hackage tarbal of jsaddle-warp.
  jsaddle-warp = dontCheck prev.jsaddle-warp;

  # 2020-06-24: Jailbreaking because of restrictive test dep bounds
  # Upstream issue: https://github.com/kowainik/trial/issues/62
  trial = doJailbreak prev.trial;

  # 2020-06-24: Tests are broken in hackage distribution.
  # See: https://github.com/kowainik/stan/issues/316
  stan = dontCheck prev.stan;

  # 2020-06-24: Tests are broken in hackage distribution.
  # See: https://github.com/robstewart57/rdf4h/issues/39
  rdf4h = dontCheck prev.rdf4h;

  # hasn't bumped upper bounds
  # test fails: "floskell-test: styles/base.md: openBinaryFile: does not exist (No such file or directory)"
  # https://github.com/ennocramer/floskell/issues/48
  floskell = dontCheck (doJailbreak prev.floskell);

  # hasn't bumped upper bounds
  # test fails because of a "Warning: Unused LANGUAGE pragma"
  # https://github.com/ennocramer/monad-dijkstra/issues/4
  monad-dijkstra = dontCheck (doJailbreak prev.monad-dijkstra);

  # https://github.com/kowainik/policeman/issues/57
  policeman = doJailbreak prev.policeman;

  # 2020-08-14: gi-pango from stackage is to old for the C libs it links against in nixpkgs.
  # That's why we need to bump a ton of dependency versions to unbreak them.
  gi-pango = assert prev.gi-pango.version == "1.0.22"; final.gi-pango_1_0_23;
  haskell-gi-base = assert prev.haskell-gi-base.version == "0.23.0"; addBuildDepends (final.haskell-gi-base_0_24_2) [ pkgs.gobject-introspection ];
  haskell-gi = assert prev.haskell-gi.version == "0.23.1"; final.haskell-gi_0_24_4;
  gi-cairo = assert prev.gi-cairo.version == "1.0.23"; final.gi-cairo_1_0_24;
  gi-glib = assert prev.gi-glib.version == "2.0.23"; final.gi-glib_2_0_24;
  gi-gobject = assert prev.gi-gobject.version == "2.0.22"; final.gi-gobject_2_0_24;
  gi-atk = assert prev.gi-atk.version == "2.0.21"; final.gi-atk_2_0_22;
  gi-gio = assert prev.gi-gio.version == "2.0.26"; final.gi-gio_2_0_27;
  gi-gdk = assert prev.gi-gdk.version == "3.0.22"; final.gi-gdk_3_0_23;
  gi-gtk = assert prev.gi-gtk.version == "3.0.33"; final.gi-gtk_3_0_35;
  gi-gdkpixbuf = assert prev.gi-gdkpixbuf.version == "2.0.23"; final.gi-gdkpixbuf_2_0_24;

  # 2020-08-14: Needs some manual patching to be compatible with haskell-gi-base 0.24
  # Created upstream PR @ https://github.com/ghcjs/jsaddle/pull/119
  jsaddle-webkit2gtk = appendPatch prev.jsaddle-webkit2gtk (pkgs.fetchpatch {
    url = "https://github.com/ghcjs/jsaddle/compare/9727365...f842748.patch";
    sha256 = "07l4l999lmlx7sqxf7v4f70rmxhx9r0cjblkgc4n0y6jin4iv1cb";
    stripLen = 2;
    extraPrefix = "";
  });

  # Missing -Iinclude parameter to doc-tests (pull has been accepted, so should be resolved when 0.5.3 released)
  # https://github.com/lehins/massiv/pull/104
  massiv = dontCheck prev.massiv;

  # Upstream PR: https://github.com/jkff/splot/pull/9
  splot = appendPatch prev.splot (pkgs.fetchpatch {
    url = "https://github.com/jkff/splot/commit/a6710b05470d25cb5373481cf1cfc1febd686407.patch";
    sha256 = "1c5ck2ibag2gcyag6rjivmlwdlp5k0dmr8nhk7wlkzq2vh7zgw63";
  });

  # Version bumps have not been merged by upstream yet.
  # https://github.com/obsidiansystems/dependent-sum-aeson-orphans/pull/5
  dependent-sum-aeson-orphans = appendPatch prev.dependent-sum-aeson-orphans (pkgs.fetchpatch {
    url = "https://github.com/obsidiansystems/dependent-sum-aeson-orphans/commit/5a369e433ad7e3eef54c7c3725d34270f6aa48cc.patch";
    sha256 = "1lzrcicvdg77hd8j2fg37z19amp5yna5xmw1fc06zi0j95csll4r";
  });

  # Tests are broken because of missing files in hackage tarball.
  # https://github.com/jgm/commonmark-hs/issues/55
  commonmark-extensions = dontCheck prev.commonmark-extensions;

  # The overrides in the following lines all have the following causes:
  # * neuron needs commonmark-pandoc
  # * which needs a newer pandoc-types (>= 1.21)
  # * which means we need a newer pandoc (>= 2.10)
  # * which needs a newer hslua (1.1.2) and a newer jira-wiki-markup (1.3.2)
  # Then we need to apply those overrides to all transitive dependencies
  # All of this will be obsolete, when pandoc 2.10 hits stack lts.
  commonmark-pandoc = prev.commonmark-pandoc.override {
    pandoc-types = final.pandoc-types_1_21;
  };
  reflex-dom-pandoc = prev.reflex-dom-pandoc.override {
    pandoc-types = final.pandoc-types_1_21;
  };
  pandoc_2_10_1 = prev.pandoc_2_10_1.overrideScope (final: prev: {
    pandoc-types = final.pandoc-types_1_21;
    hslua = final.hslua_1_1_2;
    jira-wiki-markup = final.jira-wiki-markup_1_3_2;
  });

  # Apply version-bump patch that is not contained in released version yet.
  # Upstream PR: https://github.com/srid/neuron/pull/304
  neuron = (appendPatch prev.neuron (pkgs.fetchpatch {
    url= "https://github.com/srid/neuron/commit/9ddcb7e9d63b8266d1372ef7c14c13b6b5277990.patch";
    sha256 = "01f9v3jnl05fnpd624wv3a0j5prcbnf62ysa16fbc0vabw19zv1b";
    excludes = [ "commonmark-hs/github.json" ];
    stripLen = 2;
    extraPrefix = "";
  }))
    # See comment about overrides above commonmark-pandoc
    .overrideScope (final: prev: {
    pandoc = final.pandoc_2_10_1;
    pandoc-types = final.pandoc-types_1_21;
  });

  # Testsuite trying to run `which haskeline-examples-Test`
  haskeline_0_8_0_0 = dontCheck prev.haskeline_0_8_0_0;

  # Requires repline 0.4 which is the default only for ghc8101, override for the rest
  zre = prev.zre.override {
    repline = final.repline_0_4_0_0.override {
      haskeline = final.haskeline_0_8_0_0;
    };
  };

  # https://github.com/bos/statistics/issues/170
  statistics = dontCheck prev.statistics;

  hcoord = overrideCabal prev.hcoord (drv: {
    # Remove when https://github.com/danfran/hcoord/pull/8 is merged.
    patches = [
      (pkgs.fetchpatch {
        url = "https://github.com/danfran/hcoord/pull/8/commits/762738b9e4284139f5c21f553667a9975bad688e.patch";
        sha256 = "03r4jg9a6xh7w3jz3g4bs7ff35wa4rrmjgcggq51y0jc1sjqvhyz";
      })
    ];
    # Remove when https://github.com/danfran/hcoord/issues/9 is closed.
    doCheck = false;
  });

  # Tests rely on `Int` being 64-bit: https://github.com/hspec/hspec/issues/431.
  # Also, we need QuickCheck-2.14.x to build the test suite, which isn't easy in LTS-16.x.
  # So let's not go there any just disable the tests altogether.
  hspec-core = dontCheck prev.hspec-core;

  # INSERT NEW OVERRIDES ABOVE THIS LINE

} // (let
  hlsScopeOverride = final: prev: {
    # haskell-language-server uses its own fork of ghcide
    # Test disabled: it seems to freeze (is it just that it takes a long time ?)
    ghcide = dontCheck final.hls-ghcide;
    # we are faster than stack here
    hie-bios = dontCheck final.hie-bios_0_6_2;
    lsp-test = dontCheck final.lsp-test_0_11_0_4;
    # fourmolu can‘t compile with an older aeson
    aeson = dontCheck prev.aeson_1_5_2_0;
    # brittany has an aeson upper bound of 1.5
    brittany = doJailbreak prev.brittany;
  };
  in {
    haskell-language-server = dontCheck (prev.haskell-language-server.overrideScope hlsScopeOverride);
    hls-ghcide = dontCheck (prev.hls-ghcide.overrideScope hlsScopeOverride);
    fourmolu = prev.fourmolu.overrideScope hlsScopeOverride;
  }
)  // import ./configuration-tensorflow.nix {inherit pkgs haskellLib;} final prev
