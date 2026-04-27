{ config, lib, pkgs, ... }:

let
  cfg = config.modules.networking.sysfsTuning;
in
{
  options.modules.networking.sysfsTuning = {
    enable = lib.mkEnableOption "sysfs network tuning (RPS/XPS)";
    interfaces = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule {
        options = {
          rps_cpus = lib.mkOption { type = lib.types.nullOr lib.types.str; default = null; };
          xps_cpus = lib.mkOption { type = lib.types.nullOr lib.types.str; default = null; };
        };
      });
      default = {};
      description = "Map of interface names to their CPU masks for RPS and XPS.";
    };
  };

  config = lib.mkIf cfg.enable {
    boot.kernel.sysfs = 
      let
        tuneIface = iface: tunings: 
          let
            rx = if tunings.rps_cpus != null then lib.setAttrByPath ["class" "net" iface "queues" "rx-0" "rps_cpus"] tunings.rps_cpus else {};
            tx = if tunings.xps_cpus != null then lib.setAttrByPath ["class" "net" iface "queues" "tx-0" "xps_cpus"] tunings.xps_cpus else {};
          in lib.recursiveUpdate rx tx;
      in
        lib.foldr lib.recursiveUpdate {} (lib.mapAttrsToList tuneIface cfg.interfaces);
  };
}
