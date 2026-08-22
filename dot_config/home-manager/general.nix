{
  config,
  pkgs,
  lib,
  inputs,
  ...
}:
{
  home.username = builtins.getEnv "USER";
  home.homeDirectory = builtins.getEnv "HOME";
  home.stateVersion = "26.05";

  nix.package = pkgs.lix;
  nix.registry.nixpkgs.flake = inputs.nixpkgs;
  nix.settings = {
    experimental-features = [
      "nix-command"
      "flakes"
    ];
    max-jobs = "auto";
    cores = 0;
    extra-substituters = [
      "https://nix-community.cachix.org"
      "https://cache.hydroakri.cc/cachix"
      "https://attic.xuyh0120.win/lantian"
    ];
    extra-trusted-public-keys = [
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      "cachix:eBckug6/bGXXnIC+i6fms40KxCbstV+wJYV4JMwAvZ4="
      "lantian:EeAUQ+W+6r7EtwnmYjeVwx5kOGEBpjlBfPlzGlTNvHc="
    ];
  };

  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 14d";
  };

  # osFlake/homeFlake left unset: dot_zshrc already exports NH_OS_FLAKE/NH_HOME_FLAKE
  programs.nh.enable = true;
  programs.nix-index.enable = true;
  programs.nix-index-database.comma.enable = true;

  # bare packages, not programs.*: home-manager's programs.zsh/git/neovim
  # would fight chezmoi for ~/.zshrc, ~/.config/git, ~/.config/nvim
  home.packages = with pkgs; [
    # baseline utils any distro already ships — here only for the pinned nixpkgs version
    git
    wget
    curl
    unar
    _7zz
    # net utils
    lsof
    iputils
    dnsutils
    nettools
    # file utils
    file

    # our picks (not distro defaults)
    zsh
    (neovim.override {
      viAlias = true;
      vimAlias = true;
      withNodeJs = true;
      withPython3 = true;
    })
    tmux
    # modern CLI tools
    fzf
    bat
    gdu
    nawk
    btop
    yazi
    atuin
    zoxide
    chezmoi
    lazygit
    ripgrep
    starship
    attic-client
    sqlite # backs `sqlite3 ~/.local/share/atuin/history.db`
    # nix utils
    nix-tree
    nix-output-monitor
    (lib.hiPrio uutils-coreutils-noprefix)
    # glyphs the prompt/file-manager/multiplexer configs expect (Nerd Font icons)
    nerd-fonts.symbols-only
  ];
  fonts.fontconfig.enable = true;

  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
    enableZshIntegration = false; # zsh is a bare package here, not programs.zsh — this flag has nothing to hook into
  };

  programs.home-manager.enable = true;
}
