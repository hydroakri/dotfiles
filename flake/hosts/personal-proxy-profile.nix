# Shared personal proxy identity, imported by any host that wants hydroakri's
# own proxy setup (currently rpi4-side-gateway, omen15). Which backends are
# actually active is each host's own decision via modules.proxy.*.enable —
# this file only supplies the extension-point data those backends consume.
{ config, ... }:
{
  config = {
    # sopsFile: these live in their own file (recipients: hydroakri + omen15 +
    # rpi4 only, no oci) so a host that never imports this profile can't also
    # decrypt secrets it doesn't use — see .sops.yaml's proxy-secrets.yaml$ rule.
    sops.secrets = {
      zerotrust.sopsFile = ../modules/features/secrets/proxy-secrets.yaml;
      sing-box-endpoints.sopsFile = ../modules/features/secrets/proxy-secrets.yaml;
      sing-box-outbounds.sopsFile = ../modules/features/secrets/proxy-secrets.yaml;
      oracle_domain.sopsFile = ../modules/features/secrets/proxy-secrets.yaml;
      oracle_ip.sopsFile = ../modules/features/secrets/proxy-secrets.yaml;
    };
    modules.proxy = {
      singbox = {
        # Not sops.placeholder — this splices into a Nix attrset sing-box
        # renders itself, so sops-nix's placeholder substitution never runs
        # on it. sing-box's native `_secret` marker is what works here.
        dohServerName = {
          _secret = config.sops.secrets.zerotrust.path;
        };
        # Whole-block JSON import via sing-box's _secret with quote = false
        # (parses as JSON, not a string); opaque JSON arrays from secrets.yaml.
        endpointsFile = {
          _secret = config.sops.secrets.sing-box-endpoints.path;
          quote = false;
        };
        outboundsFile = {
          _secret = config.sops.secrets.sing-box-outbounds.path;
          quote = false;
        };
        adblockRulesetUrl = "https://cdn.jsdelivr.net/gh/hydroakri/dnscrypt-proxy-blocklist@release/blocklist.srs";
        localDomains = [
          "file.hydroakri.cc"
          "glance.hydroakri.cc"
          "pdf.hydroakri.cc"
        ];
        forceOverseasDomains = [ "tradingview.com" ];
        # tailscaleDirectIps needs the full CIDR in the secret itself (e.g.
        # "<ip>/32") — can't be appended in Nix since the value is only
        # known at activation time.
        tailscaleDirectDomains = [ { _secret = config.sops.secrets.oracle_domain.path; } ];
        tailscaleDirectIps = [ { _secret = config.sops.secrets.oracle_ip.path; } ];
      };
      dae = {
        extraDnsUpstreams.flymc = "quic://dns.flymc.cc:853";
        extraOverseasDomains = [ "tradingview.com" ];
      };
    };
  };
}
