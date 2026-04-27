{ config, lib, pkgs, inputs, ... }: {

  imports = [
    # Hardware modules
    ./disko-config.nix
    # ./hardware-configuration.nix

    # Core system modules
    ../../modules/core.nix
    ../../modules/server.nix

    # Feature modules
    ../../modules/features/performance.nix
    ../../modules/features/secrets/secrets.nix
    ../../modules/features/security.nix
    ../../modules/features/utils.nix

    # External modules
    inputs.sops-nix.nixosModules.sops
    inputs.disko.nixosModules.disko
    inputs.nix-minecraft.nixosModules.minecraft-servers
  ];

  config = {
    nixpkgs.overlays = [ inputs.nix-minecraft.overlay ];
    sops = {
      secrets = {
        vault_token = { };
        cf_oracle = { };
        r2_access_key_id = { };
        r2_secret_access_key = { };
        r2_endpoint = { };
        r2_bucket = { };
        webdav_htpasswd = { };
        attic_jwt_secret = { };
        searx_secret_key = { };
      };
      templates."vaultwarden.env" = {
        owner = config.users.users.vaultwarden.name;
        content = ''
          ADMIN_TOKEN=${config.sops.placeholder.vault_token}
        '';
      };
      templates."cf_oracle.env" = {
        owner = config.users.users.acme.name;
        content = ''
          CLOUDFLARE_DNS_API_TOKEN=${config.sops.placeholder.cf_oracle}
        '';
      };
      templates."rclone-r2.env" = {
        owner = "nginx";
        content = ''
          RCLONE_CONFIG_R2_TYPE=s3
          RCLONE_CONFIG_R2_PROVIDER=Cloudflare
          RCLONE_CONFIG_R2_ACCESS_KEY_ID=${config.sops.placeholder.r2_access_key_id}
          RCLONE_CONFIG_R2_SECRET_ACCESS_KEY=${config.sops.placeholder.r2_secret_access_key}
          RCLONE_CONFIG_R2_ENDPOINT=${config.sops.placeholder.r2_endpoint}
          R2_BUCKET_NAME=${config.sops.placeholder.r2_bucket}
          RCLONE_CONFIG_R2_ACL=private
        '';
      };
      templates."webdav-auth" = {
        owner = config.services.nginx.user;
        content = config.sops.placeholder.webdav_htpasswd;
      };
      templates."attic-env" = {
        content = ''
          ATTIC_SERVER_TOKEN_HS256_SECRET_BASE64=${config.sops.placeholder.attic_jwt_secret}
          AWS_ACCESS_KEY_ID=${config.sops.placeholder.r2_access_key_id}
          AWS_SECRET_ACCESS_KEY=${config.sops.placeholder.r2_secret_access_key}
        '';
      };
      # 渲染完整的 TOML 配置文件
      templates."attic-server.toml" = {
        owner = "atticd";
        group = "atticd";
        restartUnits = [ "atticd.service" ];
        content = ''
          listen = "127.0.0.1:8088"
          allowed-hosts =["cache.hydroakri.cc"]

          [database]
          url = "postgresql:///atticd?host=/run/postgresql"

          [storage]
          type = "s3"
          region = "us-east-1"
          bucket = "${config.sops.placeholder.r2_bucket}"
          endpoint = "${config.sops.placeholder.r2_endpoint}"

          [chunking]
          nar-size-threshold = 65536
          min-size = 16384
          avg-size = 65536
          max-size = 262144
        '';
      };

    };
    disko.devices.disk.main.device = "/dev/sda";
    modules = {
      utils = {
        enable = true;
        enableGlance = true;
        enableUptime = true;
        enableGrafana = false;
        enablePrometheus = false;
        enableGraphicTools = false;
      };
    };

    networking.hostName = "oci";
    nixpkgs.hostPlatform = "aarch64-linux";
    # Boot loader configuration for RPi4
    boot.loader = {
      systemd-boot.enable = true;
      efi.canTouchEfiVariables = false;
    };
    boot.plymouth.enable = false;
    boot.kernelPackages = lib.mkForce pkgs.linuxPackages;
    # boot.kernelPackages = lib.mkForce pkgs.linuxPackages;
    boot.initrd.supportedFilesystems = [ "vfat" "ext4" "xfs" ];
    boot.initrd.availableKernelModules = [
      "virtio_pci"
      "virtio_scsi"
      "virtio_blk"
      "virtio_net"
      "nvme"
      "sd_mod"
      "sr_mod"
      "xhci_pci"
      "usbhid"
    ];
    console.font = lib.mkForce "ter-v16n";
    boot.kernel.sysctl = {
      "net.ipv4.ip_forward" = 1;
      "net.ipv6.conf.all.forwarding" = 1;
      "net.ipv6.conf.default.forwarding" = 1;

      # optimize bufferbloat
      "net.core.netdev_max_backlog" = lib.mkForce 2000;
      "net.core.rmem_max" = lib.mkForce 4194304;
      "net.core.wmem_max" = lib.mkForce 4194304;
      "net.ipv4.tcp_rmem" = lib.mkForce "4096 87380 4194304";
      "net.ipv4.tcp_wmem" = lib.mkForce "4096 87380 4194304";
      "net.ipv4.tcp_mem" = lib.mkForce "4194304 4194304 4194304";
    };
    # boot.kernel.sysfs = {
    #   # enable net card RPS & XPS
    #   class.net.enp0s6.queues."rx-0".rps_cpus = "f";
    # };
    powerManagement.cpuFreqGovernor = "performance";
    environment.etc."tuned/active_profile".text = lib.mkForce "network-latency";
    services.irqbalance.enable = lib.mkForce false; # 禁用自动平衡
    networking.interfaces.enp0s6.mtu = 1492;
    networking.networkmanager.insertNameservers = [ "127.0.0.1" ];
    networking.firewall = {
      allowedTCPPorts = [ 80 443 ];
      checkReversePath = false; # For dae transparent netgate, let date pass
      extraCommands = ''
        # 确保 SS-2022 加密后的包不会撑爆 MTU
        iptables -t mangle -D POSTROUTING -o enp0s6 -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --set-mss 1412 2>/dev/null || true
        iptables -t mangle -A POSTROUTING -o enp0s6 -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --set-mss 1412
      '';
    };

    environment.systemPackages = with pkgs; [
      ethtool
      rclone
      apacheHttpd # 为了方便以后在命令行生成 htpasswd
    ];
    services.smartd.enable = lib.mkForce false;
    services.journald.extraConfig = ''
      Storage=volatile
      SystemMaxUse=64M
      MaxRetentionSec=1week
    '';

    users.users.${config.mainUser} = {
      shell = pkgs.zsh;
      isNormalUser = true;
      description = "${config.mainUser}";
      extraGroups = [ "networkmanager" "wheel" ];
    };

    services.tailscale.enable = true;
    services.headscale = {
      enable = true;
      address = "127.0.0.1";
      port = 6313;
      settings = {
        server_url = "https://headscale.hydroakri.cc";
        dns = {
          magic_dns = true;
          base_domain = "ts.hydroakri.cc";
          nameservers.global = [ "172.64.36.2" "149.112.112.11" ];
        };
        prefixes = {
          v4 = "100.64.0.0/10";
          v6 = "fd7a:115c:a1e0::/48";
        };
      };
    };

    services.cloudflare-warp.enable = true;
    services.searx = {
      enable = true;
      package = pkgs.searxng;
      redisCreateLocally = true;
      settings = {
        outgoing = {
          proxies = {
            http = "socks5h://127.0.0.1:40000";
            https = "socks5h://127.0.0.1:40000";
          };
          request_timeout = 5.0;
          pool_connections = 100;
          pool_maxsize = 10;
        };
        server = {
          port = 8888;
          bind_address = "127.0.0.1";
          secret_key = config.sops.placeholder.searx_secret_key;
          base_url = "https://searx.hydroakri.cc";
          method = "POST";
          image_proxy = true;
        };
        search = {
          safe_search = 0;
          autocomplete = "duckduckgo";
          favicon_resolver = "duckduckgo";
          autocomplete_min_chars = 1;
          formats = [ "html" "json" "rss" ];
        };
        ui = {
          hotkeys = "default";
          contact_url = "null";
          show_thumbnails = true;
          infinite_scroll = true;
          query_in_title = false;
          results_on_new_tab = true;
          theme_args = {
            simple_style = "auto";
            center_alignment = false;
          };
        };
        enabled_plugins =
          [ "Tracker Protection" "Hostnames replace" "Favicons" ];
        engines = [
          {
            name = "google";
            disabled = true;
          }
          {
            name = "bing";
            disabled = true;
          }
          {
            name = "yahoo";
            disabled = true;
          }
          {
            name = "yandex";
            disabled = true;
          }
          {
            name = "duckduckgo";
            disabled = false;
            weight = 2;
          }
          {
            name = "startpage";
            disabled = false;
            weight = 2;
          }
          {
            name = "brave";
            disabled = false;
            weight = 2;
          }
          {
            name = "mojeek";
            disabled = true;
          }
          {
            name = "qwant";
            disabled = true;
          }
          {
            name = "ecosia";
            disabled = true;
          }
          {
            name = "karmasearch";
            disabled = true;
          }
        ];
      };
    };

    services.filebrowser = {
      enable = true;
      settings = {
        port = 8082;
        address = "127.0.0.1";
        database = "/var/lib/filebrowser/filebrowser.db";
        root = "/var/lib/filebrowser/my-files";
        noauth = false;
      };
    };

    services.vaultwarden = {
      enable = true;
      dbBackend = "sqlite";
      environmentFile = config.sops.templates."vaultwarden.env".path;
      config = {
        DOMAIN = "https://vault.hydroakri.cc";
        SIGNUPS_ALLOWED = false; # 建议直接关掉，或者注册完就关掉
        ROCKET_ADDRESS = "127.0.0.1";
        ROCKET_PORT = 8222;
      };
    };

    services.stirling-pdf = {
      enable = true;
      environment = {
        SERVER_PORT = 8081;
        SECURITY_ENABLE_LOGIN = "true";
        INSTALLATION_NAME = "Private PDF Station";
        APP_LOCALE = "zh_CN";
      };
    };

    systemd.services.rclone-webdav = {
      after = [ "network.target" "sops-nix.service" ]; # 确保在 sops 渲染后启动
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        EnvironmentFile = config.sops.templates."rclone-r2.env".path;
        CacheDirectory = "rclone-webdav";
        User = "nginx";
        Group = "nginx";
        Restart = "always";
      };
      script = ''
        ${pkgs.rclone}/bin/rclone serve webdav r2:$R2_BUCKET_NAME/webdav \
          --addr 127.0.0.1:8083 \
          --vfs-cache-mode full \
          --cache-dir /var/cache/rclone-webdav \
          --vfs-read-chunk-size 128M \
          --vfs-read-chunk-size-limit off \
          --buffer-size 64M \
          --transfers 8 \
          --s3-upload-concurrency 8 \
          --s3-chunk-size 16M \
          --dir-cache-time 10m \
          --vfs-cache-max-age 24h
      '';
    };

    services.atticd = {
      enable = true;
      environmentFile = config.sops.templates."attic-env".path;
    };
    users.users.atticd = {
      isSystemUser = true;
      group = "atticd";
    };
    users.groups.atticd = { };
    systemd.services.atticd = {
      after = [ "sops-nix.service" ];
      wants = [ "sops-nix.service" ];
      restartTriggers = [
        config.sops.templates."attic-server.toml".path
        config.sops.templates."attic-env".path
      ];

      serviceConfig = {
        DynamicUser = lib.mkForce false;
        EnvironmentFile = config.sops.templates."attic-env".path;
        ExecStart = lib.mkForce
          "${config.services.atticd.package}/bin/atticd -f ${
            config.sops.templates."attic-server.toml".path
          } --mode monolithic";
      };
    };
    services.postgresql = {
      enable = true;
      ensureDatabases = [ "atticd" ];
      ensureUsers = [{
        name = "atticd";
        ensureDBOwnership = true;
      }];
    };

    services.minecraft-servers = {
      enable = true;
      eula = true;
      openFirewall = true;
      servers.myserver = {
        enable = true;
        package = pkgs.neoforgeServers.neoforge-1_21_1-21_1_219;
        jvmOpts = toString [
          "-Xms8G"
          "-Xmx8G"
          "-XX:+UseZGC"
          "-XX:+ZGenerational"
          "-XX:+UnlockExperimentalVMOptions"
          "-XX:+UnlockDiagnosticVMOptions"
          "-XX:+AlwaysActAsServerClassMachine"
          "-XX:+AlwaysPreTouch"
          "-XX:+DisableExplicitGC"
          "-XX:+UseNUMA"
          "-XX:NmethodSweepActivity=1"
          "-XX:ReservedCodeCacheSize=400M"
          "-XX:NonNMethodCodeHeapSize=12M"
          "-XX:ProfiledCodeHeapSize=194M"
          "-XX:NonProfiledCodeHeapSize=194M"
          "-XX:-DontCompileHugeMethods"
          "-XX:MaxNodeLimit=240000"
          "-XX:NodeLimitFudgeFactor=8000"
          "-XX:+UseVectorCmov"
          "-XX:+PerfDisableSharedMem"
          "-XX:+UseFastUnorderedTimeStamps"
          "-XX:+UseCriticalJavaThreadPriority"
          "-XX:ThreadPriorityPolicy=1"
          "-XX:AllocatePrefetchStyle=3"
        ];
        serverProperties = {
          server-port = 25565;
          motd = ":3";
          difficulty = "normal";
          gamemode = "survival";
          max-players = 10;
          view-distance = 12;
          simulation-distance = 8;
          online-mode = false;
        };
      };
    };

    security.acme = {
      acceptTerms = true;
      defaults.email = "admin@hydroakri.cc";

      certs."hydroakri.cc" = {
        domain = "*.hydroakri.cc";
        dnsProvider = "cloudflare";
        # 记得将 Cloudflare API Token 放在这个文件里，并设置权限 600
        environmentFile = config.sops.templates."cf_oracle.env".path;
        reloadServices = [ "nginx.service" ];
      };
    };
    users.users.nginx.extraGroups = [ "acme" ];
    services.nginx = {
      enable = true;
      recommendedProxySettings = true;
      recommendedTlsSettings = true;
      recommendedGzipSettings = true;
      recommendedOptimisation = true;
      commonHttpConfig = ''
        client_header_buffer_size 128k;
        large_client_header_buffers 8 128k;
        http2_max_header_size 128k;
        http2_max_field_size 128k;
        proxy_headers_hash_max_size 4096;
        proxy_headers_hash_bucket_size 256;

        map $http_destination $webdav_dest {
            ~^https://(.*)$ http://$1;
            default $http_destination;
        }
      '';

      virtualHosts."headscale.hydroakri.cc" = {
        useACMEHost = "hydroakri.cc";
        acmeRoot = null;
        forceSSL = true;
        locations."/" = {
          proxyPass = "http://127.0.0.1:6313";
          proxyWebsockets = true;
        };
      };
      virtualHosts."searx.hydroakri.cc" = {
        useACMEHost = "hydroakri.cc";
        acmeRoot = null;
        forceSSL = true;
        locations."/" = {
          proxyPass = "http://127.0.0.1:8888";
          proxyWebsockets = true;
          extraConfig = ''
            proxy_cookie_path / "/; secure; SameSite=Lax";
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-Proto $scheme;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header Host $host;
          '';
        };
      };

      virtualHosts."file.hydroakri.cc" = {
        useACMEHost = "hydroakri.cc";
        forceSSL = true;
        extraConfig = ''
          allow 100.64.0.0/10;
          allow fd7a:115c:a1e0::/48;
          deny all;
        '';
        locations."/" = { proxyPass = "http://127.0.0.1:8082"; };
      };

      virtualHosts."vault.hydroakri.cc" = {
        # enableACME = true;
        useACMEHost = "hydroakri.cc";
        acmeRoot = null;
        forceSSL = true;
        locations."/" = {
          proxyPass = "http://127.0.0.1:8222";
          proxyWebsockets = true;
        };
      };

      virtualHosts."pdf.hydroakri.cc" = {
        useACMEHost = "hydroakri.cc";
        forceSSL = true;
        extraConfig = ''
          allow 100.64.0.0/10;
          allow fd7a:115c:a1e0::/48;
          deny all;
        '';
        locations."/" = {
          proxyPass = "http://127.0.0.1:8081";
          proxyWebsockets = true;
        };
      };

      virtualHosts."tools.hydroakri.cc" = {
        useACMEHost = "hydroakri.cc";
        forceSSL = true;
        root = "${pkgs.it-tools}/lib";
        locations."/" = {
          index = "index.html";
          tryFiles = "$uri $uri/ /index.html";
          extraConfig = ''
            add_header X-Frame-Options "SAMEORIGIN";
            add_header X-Content-Type-Options "nosniff";
          '';
        };
      };

      virtualHosts."glance.hydroakri.cc" = {
        useACMEHost = "hydroakri.cc";
        acmeRoot = null;
        forceSSL = true;
        locations."/" = {
          proxyPass = "http://127.0.0.1:8080";
          proxyWebsockets = true;
        };
        extraConfig = ''
          allow 100.64.0.0/10;
          allow fd7a:115c:a1e0::/48;
          deny all;
        '';
      };

      virtualHosts."status.hydroakri.cc" = {
        useACMEHost = "hydroakri.cc";
        acmeRoot = null;
        forceSSL = true;
        locations."/" = {
          proxyPass = "http://127.0.0.1:3001";
          proxyWebsockets = true;
        };
      };

      virtualHosts."dav.hydroakri.cc" = {
        useACMEHost = "hydroakri.cc";
        forceSSL = true;
        locations."/" = {
          proxyPass = "http://127.0.0.1:8083";
          basicAuthFile = config.sops.templates."webdav-auth".path;

          extraConfig = ''
            client_max_body_size 0;
            client_body_buffer_size 512k;

            proxy_http_version 1.1;
            proxy_set_header Connection "";
            proxy_set_header Expect "";

            proxy_set_header Destination $webdav_dest;
            proxy_set_header Authorization "";

            proxy_buffering off;
            proxy_request_buffering off;

            proxy_buffer_size 128k;
            proxy_buffers 4 256k;
            proxy_busy_buffers_size 256k;
          '';
        };
      };

      virtualHosts."cache.hydroakri.cc" = {
        useACMEHost = "hydroakri.cc";
        forceSSL = true;
        locations."/" = {
          proxyPass = "http://127.0.0.1:8088";
          extraConfig = ''
            client_max_body_size 0;
            proxy_set_header Authorization $http_authorization;
            proxy_pass_header Authorization;
            proxy_buffer_size 128k;
            proxy_buffers 4 256k;
            proxy_busy_buffers_size 256k;
            proxy_request_buffering off;
          '';
        };
      };

    };

    system.stateVersion = "25.11";

  };

}
