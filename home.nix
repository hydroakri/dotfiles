{ config, pkgs, ... }:

{
  # 注意修改这里的用户名与用户目录
  home.username = "hydroakri";
  home.homeDirectory = "/home/hydroakri";

  # 直接将当前文件夹的配置文件，链接到 Home 目录下的指定位置
  # home.file.".config/i3/wallpaper.jpg".source = ./wallpaper.jpg;

  # 递归将某个文件夹中的文件，链接到 Home 目录下的指定位置
  # home.file.".config/i3/scripts" = {
  #   source = ./scripts;
  #   recursive = true;   # 递归整个文件夹
  #   executable = true;  # 将其中所有文件添加「执行」权限
  # };

  # 直接以 text 的方式，在 nix 配置文件中硬编码文件内容
  # home.file.".xxx".text = ''
  #     xxx
  # '';

  # 设置鼠标指针大小以及字体 DPI（适用于 4K 显示器）
  xresources.properties = {
    "Xcursor.size" = 16;
    "Xft.dpi" = 172;
  };

  # 通过 home.packages 安装一些常用的软件
  # 这些软件将仅在当前用户下可用，不会影响系统级别的配置
  # 建议将所有 GUI 软件，以及与 OS 关系不大的 CLI 软件，都通过 home.packages 安装
  home.packages = with pkgs;[
    # 终端相关
    zsh
    fish
    fastfetch
    yazi
    wezterm
    kitty
    foot
    alacritty
    zellij

    # 输入法
    fcitx5
    fcitx5-rime

    # 窗口管理器相关
    sway
    swaylock
    waybar
    wofi
    mako
    niri
    hyprland

    # 主题相关
    qt6ct
    qt5ct
    gtk3
    gtk4

    # 音频
    cava

    # 编辑器
    neovim

    # 其他工具
    atuin

    # archives
    zip
    xz
    unzip
    p7zip

    # utils
    ripgrep
    jq
    yq-go
    eza
    fzf

    dnsutils

    # misc
    cowsay
    file
    which
    tree
    gnused
    gnutar
    gawk
    zstd
    gnupg

    # nix related
    nix-output-monitor

    btop

    # system call monitoring
    lsof

    # system tools
    sysstat
    lm_sensors
    ethtool
    pciutils
    usbutils
  ];

  # 启用 starship
  programs.starship = {
    enable = true;
    settings = {
      add_newline = false;
      aws.disabled = true;
      gcloud.disabled = true;
      line_break.disabled = true;
    };
  };

  # 配置 fish
  programs.fish = {
    enable = true;
    interactiveShellInit = ''
      set -U fish_greeting ""
    '';
  };

  # 配置 zsh
  programs.zsh = {
    enable = true;
    enableCompletion = true;
    enableAutosuggestions = true;
    enableSyntaxHighlighting = true;
    shellAliases = {
      k = "kubectl";
      urldecode = "python3 -c 'import sys, urllib.parse as ul; print(ul.unquote_plus(sys.stdin.read()))'";
      urlencode = "python3 -c 'import sys, urllib.parse as ul; print(ul.quote_plus(sys.stdin.read()))'";
    };
  };

  # 配置 git
  programs.git = {
    enable = true;
    userName = "hydroakri";
    userEmail = "hydroakri@example.com";  # 请修改为您的邮箱
  };

  # 配置 alacritty
  programs.alacritty = {
    enable = true;
    settings = {
      env.TERM = "xterm-256color";
      font = {
        size = 12;
        draw_bold_text_with_bright_colors = true;
      };
      scrolling.multiplier = 5;
      selection.save_to_clipboard = true;
    };
  };

  # 配置 gtk
  gtk = {
    enable = true;
    theme = {
      name = "Adwaita-dark";
      package = pkgs.gnome.gnome-themes-extra;
    };
    iconTheme = {
      name = "Adwaita";
      package = pkgs.gnome.adwaita-icon-theme;
    };
    gtk3.extraConfig = {
      gtk-application-prefer-dark-theme = true;
    };
    gtk4.extraConfig = {
      gtk-application-prefer-dark-theme = true;
    };
  };

  # 配置 qt
  qt = {
    enable = true;
    platformTheme = "gtk";
    style = {
      name = "adwaita-dark";
      package = pkgs.adwaita-qt;
    };
  };

  # 配置字体
  fonts.fontconfig.enable = true;

  # 配置 sway
  wayland.windowManager.sway = {
    enable = true;
    config = {
      modifier = "Mod4";
      terminal = "alacritty";
    };
  };

  # 配置 waybar
  programs.waybar = {
    enable = true;
    settings = {
      mainBar = {
        layer = "top";
        position = "top";
        height = 30;
        spacing = 4;
        margin-top = 0;
        margin-bottom = 0;
        margin-left = 0;
        margin-right = 0;
      };
    };
  };

  # 配置 mako
  services.mako = {
    enable = true;
    backgroundColor = "#1e1e2e";
    textColor = "#cdd6f4";
    borderColor = "#89b4fa";
  };

  # 配置 swaylock
  programs.swaylock = {
    enable = true;
    settings = {
      color = "1e1e2e";
      show-failed-attempts = true;
    };
  };

  # 配置 wofi
  programs.wofi = {
    enable = true;
    settings = {
      width = 400;
      height = 300;
    };
  };

  # 配置 kitty
  programs.kitty = {
    enable = true;
    settings = {
      font_size = 12;
      background_opacity = "0.8";
    };
  };

  # 配置 foot
  programs.foot = {
    enable = true;
    settings = {
      main = {
        font = "monospace:size=12";
        dpi-aware = "yes";
      };
    };
  };

  # 配置 zellij
  programs.zellij = {
    enable = true;
  };

  # 配置 neovim
  programs.neovim = {
    enable = true;
    viAlias = true;
    vimAlias = true;
  };

  # 配置 atuin
  programs.atuin = {
    enable = true;
    enableBashIntegration = true;
    enableZshIntegration = true;
    enableFishIntegration = true;
  };

  # 配置 cava
  programs.cava = {
    enable = true;
  };

  # 配置 wezterm
  programs.wezterm = {
    enable = true;
    extraConfig = ''
      return {
        font_size = 12.0,
        color_scheme = "Catppuccin Mocha",
      }
    '';
  };

  # 配置 hyprland
  wayland.windowManager.hyprland = {
    enable = true;
    settings = {
      monitor = ",preferred,auto,1";
      exec-once = [
        "waybar"
        "mako"
      ];
    };
  };

  # 配置 niri
  programs.niri = {
    enable = true;
  };

  # 配置 bash
  programs.bash = {
    enable = true;
    enableCompletion = true;
    bashrcExtra = ''
      export PATH="$PATH:$HOME/bin:$HOME/.local/bin:$HOME/go/bin"
    '';
    shellAliases = {
      k = "kubectl";
      urldecode = "python3 -c 'import sys, urllib.parse as ul; print(ul.unquote_plus(sys.stdin.read()))'";
      urlencode = "python3 -c 'import sys, urllib.parse as ul; print(ul.quote_plus(sys.stdin.read()))'";
    };
  };

  # This value determines the Home Manager release that your
  # configuration is compatible with. This helps avoid breakage
  # when a new Home Manager release introduces backwards
  # incompatible changes.
  #
  # You can update Home Manager without changing this value. See
  # the Home Manager release notes for a list of state version
  # changes in each release.
  home.stateVersion = "24.11";

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;
}
