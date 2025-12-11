{ config, lib, pkgs, ... }:
let
  skKey =
    "sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAIF31MN4S2Z4OlWgIXeuacwfUxDcNApQUkcS7kOTwyV3/AAAABHNzaDo= ${config.mainUser}";
  bakKey =
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHf4CJVym33NvIXKx7/W9Ga+Qbp22a86PvelLvjLup3u";
in {
  boot.kernelParams = [
    "mitigations=auto"
    "random.trust_cpu=0"
    "page_alloc.shuffle=1"
    "init_on_alloc=1"
    "init_on_free=1"
  ];
  boot.kernel.sysctl = {
    # Security (common)
    "kernel.core_pattern" = "|/bin/false";
    "kernel.unprivileged_bpf_disabled" = 1;
    "module.sig_enforce" = 1;
    "kernel.printk_devkmsg" = "off";
    "kernel.yama.ptrace_scope" = 1;
    "kernel.kptr_restrict" = 2;
    "kernel.dmesg_restrict" = 1;
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
    pam_u2f
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
  # plug u2f device & use `pamu2fcfg -n`
  environment.etc."u2f_mappings".text = ''
    ${config.mainUser}:8dACAhhnTEKOE88R+/IKyki9JEy+5rinQaCn/Mz/hJppc39O+8lE1X6hCPTQSYGxJqMsdd79r8VR3Sic7S/0goaTACdusvsFwFDenCVc7U6eoMiaSkDf7MoqJaoOh5L7n+I32NeiJnaAXm8Wp8COn8vQY0J6Y9iLUbzWtI9Ugst0bEDbSiOsHK/CWQfK9sf4Df4ONaGvcUFmhgKIyMmRO5aNMTOsqbiEKcRB+vl4kXp8KWzy,ebgHE/SJ/q1P3xk64KI8x560mq76bZJYQtc3YNJoio6zJUkMIXtNvXhcJt9MN2Fu6gB2MWgRsRXQKBZqWmutGg==,es256,+presence
  '';

  # ===========================================================================
  # who can login in THIS machine
  # initialze security key: `ssh-keygen -t ed25519-sk -O resident -O verify-required`
  # add sk: `ssh-add -K`
  # get public key from sk: `ssh-keygen -K`
  # set password: `ssh-keygen -p -f <file name>`
  services.pcscd.enable = true;
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false; # XXX INSTALLATION: set true temporarily
      KbdInteractiveAuthentication = false;
      PermitRootLogin =
        "prohibit-password"; # XXX INSTALLATION: set "yes" temporarily
    };
  };
  users.users.root.openssh.authorizedKeys.keys = [
    skKey
    "${bakKey} ${config.sops.placeholder.email}" # 如果你想要那个 email 占位符
  ];
  # =============================================================================
  # This machine can signing/control key from WHERE?
  programs.git.config = {

    # GIT Signing
    # DISABLE Verified Signing by default
    # non-root User should use `git config --global commit.gpgsign true`
    # signing need user's email dont't foget `git config --global user.email "THE EMAIL"`
    # and add public key for each repo `git config --global user.signingkey "THE PUBLIC KEY"`
    commit.gpgsign = false;
    gpg.format = "ssh";

    # GIT VERIFING
    "gpg \"ssh\"".allowedSignersFile =
      config.sops.templates."ssh/allowed_signers".path;
  };
  # GIT VERIFING
  sops.templates."ssh/allowed_signers" = {
    content = ''
      # 格式: <email> <public_key>
      24475059+hydroakri@users.noreply.github.com ${skKey}
      24475059+hydroakri@users.noreply.github.com ${bakKey} ${config.sops.placeholder.email}
    '';
    mode = "0444";
  };
  programs.ssh = {
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
