final: prev: {

    periods = prev.callPackage ./ext/periods.nix { };

    postgis = prev.callPackage ./ext/postgis.nix {
        gdal = final.gdal.override {
            postgresql = final.postgresql;
            poppler = final.poppler_0_61;
        };
    };

    pg_auto_failover = prev.callPackage ./ext/pg_auto_failover.nix { };

    pg_bigm = prev.callPackage ./ext/pg_bigm.nix { };

    pg_ed25519 = prev.callPackage ./ext/pg_ed25519.nix { };

    pg_repack = prev.callPackage ./ext/pg_repack.nix { };

    pg_similarity = prev.callPackage ./ext/pg_similarity.nix { };

    pgroonga = prev.callPackage ./ext/pgroonga.nix { };

    plpgsql_check = prev.callPackage ./ext/plpgsql_check.nix { };

    plv8 = prev.callPackage ./ext/plv8.nix {
        v8 = prev.callPackage ../../../development/libraries/v8/plv8_6_x.nix {
            python = final.python2;
        };
    };

    pgjwt = prev.callPackage ./ext/pgjwt.nix { };

    cstore_fdw = prev.callPackage ./ext/cstore_fdw.nix { };

    pg_hll = prev.callPackage ./ext/pg_hll.nix { };

    pg_cron = prev.callPackage ./ext/pg_cron.nix { };

    pg_topn = prev.callPackage ./ext/pg_topn.nix { };

    pgtap = prev.callPackage ./ext/pgtap.nix { };

    pipelinedb = prev.callPackage ./ext/pipelinedb.nix { };

    smlar = prev.callPackage ./ext/smlar.nix { };

    temporal_tables = prev.callPackage ./ext/temporal_tables.nix { };

    timescaledb = prev.callPackage ./ext/timescaledb.nix { };

    tsearch_extras = prev.callPackage ./ext/tsearch_extras.nix { };

    tds_fdw = prev.callPackage ./ext/tds_fdw.nix { };

    pgrouting = prev.callPackage ./ext/pgrouting.nix { };

    pg_partman = prev.callPackage ./ext/pg_partman.nix { };

    pg_safeupdate = prev.callPackage ./ext/pg_safeupdate.nix { };

    repmgr = prev.callPackage ./ext/repmgr.nix { };
}
