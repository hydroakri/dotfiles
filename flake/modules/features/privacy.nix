{
  config,
  lib,
  pkgs,
  ...
}:
{
  imports = [ ../options.nix ];

  config =
    let
      bravePolicy = pkgs.writeText "castration.json" (
        builtins.toJSON {
          # ======= 1. Shields (护盾 - 对应 PG 清单第一部分) =======
          "DefaultBraveAdblockSetting" = 2; # Trackers & ads: Aggressive
          "DefaultBraveHttpsUpgradeSetting" = 2; # Upgrade connections: Strict
          "DefaultBraveFingerprintingV2Setting" = 2; # Block fingerprinting: Strict
          "BlockThirdPartyCookies" = true; # Block third-party cookies
          "DefaultBraveReferrersSetting" = 2; # 引荐来源保护
          "BraveDebouncingEnabled" = true; # 自动跳过中间追踪链接
          "BraveGlobalPrivacyControlEnabled" = true; # 开启 GPC (Global Privacy Control)

          # ======= 2. 隐私与安全 (对应 PG 清单第二部分) =======
          "DefaultJavaScriptOptimizersSetting" = 2; # Don’t allow JS optimizer compilers
          "WebRtcIPHandling" = "disable_non_proxied_udp"; # WebRTC IP Policy: Disable non-proxied UDP
          "BraveDeAmpEnabled" = true; # Auto-redirect AMP pages
          "BraveTrackingQueryParametersFilteringEnabled" = true; # Auto-redirect tracking URLs
          "BraveReduceLanguageEnabled" = true; # Language preferences fingerprinting protection
          "HttpsOnlyMode" = "force_enabled"; # 硬性拒绝 HTTP（vs. DefaultBraveHttpsUpgradeSetting 仅尝试升级）
          "OriginKeyedProcessesEnabled" = true; # 每 origin 独立进程（比 SitePerProcess 按 eTLD+1 更细粒度）
          "NetworkServiceSandboxEnabled" = true; # 启用网络服务沙箱

          # ======= 3. Web3、Tor 与商业组件 (对应 PG 清单 Web3/Tor 部分) =======
          "BraveWalletDisabled" = true; # 禁用所有 Web3 (Extensions no fallback)
          "TorDisabled" = true; # 禁用内置 Tor
          "BraveAIChatEnabled" = false; # 禁用 Leo AI
          "BraveTalkDisabled" = true; # 禁用视频会议
          "BraveNewsDisabled" = true; # 禁用新闻流
          "BravePlaylistEnabled" = false; # 禁用播放列表
          "BraveRewardsDisabled" = true;
          "BraveVPNDisabled" = true;
          "PromotionsEnabled" = false; # 禁用 Promotions
          "BraveSpeedreaderEnabled" = false; # Speedreader 会向 Brave 服务器发网络请求
          "BraveWaybackMachineEnabled" = false; # 集成 IA 会把当前 URL 发送到外部
          # IPFSEnabled 已在 brave-core policy_definitions 中标记 deprecated: true，不添加

          # ======= 4. 数据收集 (对应 PG 清单数据收集部分) =======
          "BraveP3AEnabled" = false; # Uncheck P3A
          "BraveStatsPingEnabled" = false; # Uncheck daily usage ping
          "MetricsReportingEnabled" = false; # Uncheck diagnostic reports
          "BraveWebDiscoveryEnabled" = false; # 彻底禁掉 WDP 采集
          "UrlKeyedAnonymizedDataCollectionEnabled" = false; # 禁止 URL 键值匿名数据上报

          # ======= 5. 系统与搜索 (对应 PG 清单最后部分) =======
          "SearchSuggestEnabled" = false; # Uncheck search suggestions
          "BackgroundModeEnabled" = false; # Uncheck background apps
          "SafeBrowsingExtendedReportingEnabled" = false;
          "SpellCheckServiceEnabled" = false;
          "EnableMediaRouter" = false; # 彻底禁用 Chromecast 相关的 Media Router
          "PasswordManagerEnabled" = false; # 完全禁用密码管理器（含保存提示）
          "AutofillAddressEnabled" = false; # 禁用地址自动填充（减少本地数据留存）
          "AutofillCreditCardEnabled" = false; # 禁用信用卡自动填充
          "TranslateEnabled" = false; # 翻译功能将页面内容发送至第三方服务器
          "DefaultBrowserSettingEnabled" = false; # 禁止默认浏览器提示弹窗
          "BlockExternalExtensions" = true; # 阻止安装来自 Web Store 之外的外部扩展
        }
      );
      # nixpkgs 的 kloak 包只打了二进制，没带上游（Whonix/kloak）那套 systemd 单元和
      # find_wl_compositor 探测脚本，且上游脚本认的 compositor 名单里没有 niri，没法
      # 直接抄。这里写一个只认 niri 的简化版：这台机器只有 mainUser 一个会话，不需要
      # 像上游那样扫全部 VT 找 compositor，直接看 mainUser 的 /run/user/<uid> 下有
      # 没有 wayland-* socket。
      kloakWaylandEnv = pkgs.writeShellScript "kloak-find-wayland" ''
        set -euo pipefail
        # mainUser 的 uid 在这个仓库里从没显式钉死过（users.users.<name>.uid 默认是
        # null，真正的 uid 是激活时 useradd 才分配的，Nix 求值期根本不知道），所以不能
        # 直接 toString config.users.users.${config.mainUser}.uid，得在脚本运行时用
        # id -u 现查。
        uid="$(${pkgs.coreutils}/bin/id -u ${lib.escapeShellArg config.mainUser})"
        runtime_dir="/run/user/$uid"
        wayland_display=""
        for sock in "$runtime_dir"/wayland-*; do
          if [ -S "$sock" ]; then
            wayland_display="$(basename "$sock")"
            break
          fi
        done
        if [ -z "$wayland_display" ]; then
          echo "kloak-find-wayland: no wayland-* socket in $runtime_dir yet" >&2
          exit 1
        fi
        {
          echo "XDG_RUNTIME_DIR=$runtime_dir"
          echo "WAYLAND_DISPLAY=$wayland_display"
        } > /run/kloak_env
      '';
    in
    {
      boot.kernelModules = [
        "uinput" # virtual input device, required by kloak
      ];

      # IPv6 隐私扩展：生成随机临时地址，保护本机真实 MAC 地址不被追踪
      boot.kernel.sysctl = {
        "net.ipv6.conf.all.use_tempaddr" = lib.mkDefault 2;
        "net.ipv6.conf.default.use_tempaddr" = lib.mkDefault 2;
      };

      networking.networkmanager = {
        settings.connection."dhcp-send-hostname" = false;
        wifi.macAddress = lib.mkDefault "random";
        wifi.scanRandMacAddress = lib.mkDefault true;
        # 以太网 MAC 随机化仅对桌面机有意义；服务器固定 MAC 以避免 DHCP 绑定失败
        ethernet.macAddress = lib.mkIf config.services.displayManager.enable (lib.mkDefault "random");
      };

      # kloak 硬编码检查非 root 就 FATAL ERROR 退出，所以是 system service、不设
      # User——root 天然有 /dev/input/event*、/dev/uinput 访问权。ExecStartPre 跑
      # kloakWaylandEnv 探测 Wayland socket，失败就 exit 1，交给 Restart=on-failure 重试。
      #
      # 不设 wantedBy：kloak 独占抓取真实键盘，niri 自身的全局快捷键和 fcitx5 的
      # Ctrl+Space 切输入法都要靠直接读原始 libinput 事件，收不到经
      # zwp_virtual_keyboard_v1（只转发给当前焦点应用）转发出来的事件，因此这两者在
      # kloak 运行时会系统性失效，不能常驻。只在需要防击键/鼠标指纹追踪时手动
      # `doas systemctl start kloak`，用完 `doas systemctl stop kloak`。没有
      # WantedBy，`systemctl enable` 不会创建任何符号链接。
      systemd.services.kloak = lib.mkIf config.i18n.inputMethod.enable {
        description = "Keystroke and mouse timing anonymization";
        after = [ "graphical.target" ];
        serviceConfig = {
          Type = "simple";
          ExecStartPre = "${kloakWaylandEnv}";
          EnvironmentFile = "-/run/kloak_env";
          ExecStart = "${pkgs.kloak}/bin/kloak";
          Restart = "on-failure";
          RestartSec = 3;
        };
      };

      # 用 environment.etc 而非 systemd.tmpfiles C（C 只在文件不存在时复制一次，
      # 导致策略更新后不会自动同步；environment.etc 每次 rebuild 都更新符号链接）
      environment.etc."brave/policies/managed/castration.json" = {
        source = bravePolicy;
        mode = "0644";
      };
    };
}
