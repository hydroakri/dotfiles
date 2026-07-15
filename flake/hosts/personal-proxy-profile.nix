# Shared personal proxy identity, imported by any host that wants hydroakri's
# own proxy setup (currently rpi4-side-gateway, omen15). Which backends are
# actually active is each host's own decision via modules.proxy.*.enable —
# this file only supplies the extension-point data those backends consume.
{ config, ... }:
{
  config = {
    sops.secrets = {
      zerotrust = { };
      doh_stamp = { };
      sing-box-endpoints = { };
      sing-box-outbounds = { };
      oracle_domain = { };
      oracle_ip = { };
    };
    modules.proxy = {
      dnscrypt-proxy.extraStaticStamps = {
        flymc-doh.stamp = "sdns://AgQAAAAAAAAADjQzLjE1NC4xNTQuMTYyAAxkbnMuZmx5bWMuY2MKL2Rucy1xdWVyeQ";
        flymc-doh-8443.stamp = "sdns://AgQAAAAAAAAADjQzLjE1NC4xNTQuMTYyABFkbnMuZmx5bWMuY2M6ODQ0MwovZG5zLXF1ZXJ5";
        zerotrust.stamp = config.sops.placeholder.doh_stamp;
      };
      singbox = {
        # NOT config.sops.placeholder.zerotrust: this value is spliced into
        # services.sing-box.settings (a real Nix attrset the sing-box module
        # renders and injects secrets into itself), not a sops.templates
        # string — sops-nix's own placeholder substitution never runs on it.
        # sing-box's native `_secret` marker is the mechanism that actually
        # works here (see proxy.nix's dohServerName option docs).
        dohServerName = {
          _secret = config.sops.secrets.zerotrust.path;
        };
        # Whole-block JSON import via sing-box's _secret mechanism with
        # quote = false (parses file content as JSON, not a string).
        # These contain WireGuard/Tailscale endpoint definitions and the
        # isp/proxy/manual outbound selectors respectively, as opaque JSON
        # arrays from secrets.yaml — the sing-box native substitution
        # (not sops.placeholder) handles injection at activation time.
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
        # tailscaleDirectIps needs the full CIDR (prefix included) in the
        # secret's own stored value now — the old design appended "/32" in
        # Nix code, which can't run on a value only known at activation time.
        # If oracle_ip's stored content is still just the bare IP, update it
        # via `sops` to "<ip>/32" before relying on this.
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
