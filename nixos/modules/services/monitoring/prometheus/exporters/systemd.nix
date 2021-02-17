{ config, pkgs, lib, ... }:

with lib;

let
  cfg = config.services.prometheus.exporters.systemd;

  opts = {
    unitWhitelist = {
      description =
        "Regexp of systemd units to whitelist. Units must both match whitelist and not match blacklist to be included.";
      type = types.str;
      default = ".+";
      flagName = "collector.unit-whitelist";
    };
    unitBlacklist = {
      description =
        "Regexp of systemd units to blacklist. Units must both match whitelist and not match blacklist to be included.";
      type = types.str;
      default = ".+\\.(device)";
      flagName = "collector.unit-blacklist";
    };
    private = {
      description =
        "Establish a private, direct connection to systemd without dbus.";
      type = types.bool;
      default = false;
      flagName = "collector.private";
    };
    procfsPath = {
      description = "procfs mountpoint";
      type = types.str;
      default = "/proc";
      flagName = "path.procfs";
    };
    enableRestartCount = {
      description = "Enables service restart count metrics.";
      type = types.bool;
      default = false;
      flagName = "collector.enable-restart-count";
    };
    enableFileDescriptorSize = {
      description =
        "Enables file descriptor size metrics. Systemd Exporter needs access to /proc/X/fd for this to work.";
      type = types.bool;
      default = false;
      flagName = "collector.enable-file-descriptor-size";
    };
    enableIPAccounting = {
      description = "Enables service ip accounting metrics.";
      type = types.bool;
      default = false;
      flagName = "collector.enable-ip-accounting";
    };
    telemetryPath = {
      description = "Path under which to expose metrics.";
      type = types.str;
      default = "/metrics";
      flagName = "web.telemetry-path";
    };
    disableExporterMetrics = {
      description =
        "Exclude metrics about the exporter itself (promhttp_*, process_*, go_*).";
      type = types.bool;
      default = false;
      flagName = "web.disable-exporter-metrics";
    };
    maxRequests = {
      description =
        "Maximum number of parallel scrape requests. Use 0 to disable.";
      flagName = "web.max-requests";
      type = types.int;
      default = 40;
    };
    logLevel = {
      description = "Only log messages with the given severity or above.";
      type = types.enum [ "debug" "info" "warn" "error" "fatal" ];
      default = "info";
      flagName = "log.level";
    };
    logFormat = {
      description = "Set the log target and format.";
      type = types.str;
      default = "logger:stderr";
      example = "logger:syslog?appname=bob&local=7";
      flagName = "log.format";
    };
  };

  removeFlagName = filterAttrs (k: _: k != "flagName");

  flags = mapAttrs' (k: v: nameValuePair v.flagName cfg."${k}") opts;

in {
  port = 9558;

  extraOpts = mapAttrs (_: v: mkOption (removeFlagName v)) opts;

  serviceOpts = {
    serviceConfig = {
      ExecStart = ''
        ${pkgs.prometheus-systemd-exporter}/bin/systemd_exporter \
          --web.listen-address ${cfg.listenAddress}:${toString cfg.port} \
          ${cli.toGNUCommandLineShell { } flags}
      '';
    };
  };
}
