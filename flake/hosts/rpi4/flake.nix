{ config, pkgs, ... }: {
  networking.hostName = "hostB";
  # hostB-specific adjustments
  services.httpd.enable = true;
  services.httpd.adminAddr = "admin@example.com";
}
