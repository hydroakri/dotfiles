{ config, lib, pkgs, ... }:
let
  skKey =
    "sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAIF31MN4S2Z4OlWgIXeuacwfUxDcNApQUkcS7kOTwyV3/AAAABHNzaDo= ${config.mainUser}";
  bakKey =
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHf4CJVym33NvIXKx7/W9Ga+Qbp22a86PvelLvjLup3u ${config.userEmail}";
in {
  boot.kernelParams = [
    "mitigations=auto"
    "random.trust_cpu=0"
    "lsm=landlock,lockdown,yama,integrity,apparmor,bpf"
    "lockdown=integrity"
  ];
  boot.kernel.sysctl = {
    # Security (common)
    "kernel.core_pattern" = "|/bin/false";
    "kernel.unprivileged_bpf_disabled" = 1;
    "module.sig_enforce" = 1;
    "kernel.printk_devkmsg" = "off";
  };
  environment.systemPackages = with pkgs; [
    ssh-copy-id
    # keepassxc # installed in flatpak

    # For sops-nix
    age
    sops
    ssh-to-age
    age-plugin-fido2-hmac

    # For fido2 security keys
    libfido2
    yubikey-manager
  ];
  security = {
    sudo-rs.enable = true;
    sudo.enable = false;
    apparmor.enable = true;
  };
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [ 22 ];
  };
  # ===========================================================================
  #PAM
  services.pcscd.enable = true;
  security.pam = {
    u2f = {
      enable = true; # XXX INSTALLATION: Disable u2f.enable temporarily.
      settings.cue = true;
    };
    services = {
      # XXX INSTALLATION: Disable sudo.u2fAuth, login.u2fAuth temporarily. 
      sudo.u2fAuth = true;
      login.u2fAuth = true;
      sddm.u2fAuth = true;
      cosmic-greeter.u2fAuth = true;
    };
    u2f.settings.authfile = "/etc/u2f_mappings";
  };
  environment.etc."u2f_mappings".text = ''
    ${config.mainUser}:8dACAvMEkhb0fSGpcJD0rZi+FEEdEWBcWOcs32b9oqc6RkIE0TVKT8bxduk9+k7vUzKTEZblGlumH6ivLW2gjjKIIEGM5Xe9ADlJfYAe4z++Os/sy7Zv73CaAYkECSSmTXrTUm5C345FweMWe60jfTsAelEomy+IkZ9aYVGqVUuE+I6jyXDZXOwZUfg3049kXlS4VPL09N90pUOW6mUbjJPAzHRC+hAkJsIY4gAKZuw6zw3L,QTlBZ9jkot2oHrxSvHDIKJPFe/Jg+af/EmD4ljs47Qf3kscQl6tQnmv9WODTxVENx+WMPXFzm8YQEGiNfZw1DA==,es256,+presence
  '';

  # ===========================================================================
  # who can login in THIS machine
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false; # XXX INSTALLATION: set true temporarily
      KbdInteractiveAuthentication = false;
      PermitRootLogin =
        "prohibit-password"; # XXX INSTALLATION: set "yes" temporarily
    };
  };
  users.users.root.openssh.authorizedKeys.keys = [ skKey bakKey ];
  # =============================================================================
  # This machine can signing/control key from WHERE?
  programs.git.config = {

    # GIT Signing
    # DISABLE Verified Signing by default
    # non-root User should use `git config --global commit.gpgsign true`
    # signing need user's email dont't foget ``
    commit.gpgsign = false;
    gpg.format = "ssh";
    user.signingkey = skKey;

    # GIT VERIFING
    "gpg \"ssh\"".allowedSignersFile = "/etc/ssh/allowed_signers";
  };
  # GIT VERIFING
  environment.etc."ssh/allowed_signers".text = ''
    # 格式: <email> <public_key>
    ${config.userEmail} ${skKey}
  '';
  programs.ssh = {
    startAgent = true;
    extraConfig = ''
      Host *
        # ForwardAgent yes # open only in trusted machine
        AddKeysToAgent yes
        ControlMaster auto
        ControlPath /tmp/ssh_mux_%u_%C
        ControlPersist 10m

        IdentitiesOnly no # let ssh-agent auto find keys
        # To use specific keys, try `ssh -o IdentitiesOnly=yes -i ~/.ssh/id_ed25519 user@host`
    '';
  };

}
