{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
{

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
    ../../modules/features/privacy.nix
    ../../modules/features/utils.nix

    # External modules
    inputs.sops-nix.nixosModules.sops
    inputs.disko.nixosModules.disko
    inputs.nix-minecraft.nixosModules.minecraft-servers
  ];

  config = {
    mainUser = "hydroakri";
    modules.core = {
      extraSubstituters = [ "https://attic.xuyh0120.win/lantian" ];
      extraTrustedPublicKeys = [ "lantian:EeAUQ+W+6r7EtwnmYjeVwx5kOGEBpjlBfPlzGlTNvHc=" ];
    };
    modules.security.authorizedKeys = [
      "sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAIORKNKURAriDLXiBpCKeuc3aBcIkQJy32I+sOpwMaWUmAAAABHNzaDo= hydroakri"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPYQdA9KBa2n2xrSk4cr5dYhbLgsUl3vPtc+qjdcIotE"
    ];
    modules.utils = {
      enable = true;
      enableUptime = true;
    };

    nixpkgs.overlays = [
      inputs.nix-minecraft.overlay
      (_final: prev: {
        # musl + libressl + clang: all three apply here — already off binary cache, so clang costs nothing extra
        nginx = prev.pkgsMusl.nginx.override {
          openssl = prev.pkgsMusl.libressl;
          stdenv = prev.pkgsMusl.clangStdenv;
        };
      })
    ];
    sops = {
      secrets = {
        vault_token = { };
        cf_oracle = { };
        # owner = "ente"：museum 的 s3 配置也读这三个文件，见 README
        r2_access_key_id = {
          owner = "ente";
        };
        r2_secret_access_key = {
          owner = "ente";
        };
        r2_endpoint = {
          owner = "ente";
        };
        r2_bucket = { };
        webdav_htpasswd = { };
        attic_jwt_secret = { };
        searx_secret_key = { };
        pds_jwt_secret = { };
        pds_admin_password = { };
        pds_plc_rotation_key = { };
        cloudflared_tunnel_credentials = { }; # `cloudflared tunnel create` 在本机生成的经典 credentials.json 原文
        restic_vaultwarden_password = { }; # restic 仓库加密密码
        r2_bucket_attic = { }; # atticd 独立 bucket
        # owner = "ente"：museum preStart 直接读文件，非 root 默认读不到，见 README
        ente_key_encryption = {
          owner = "ente";
        }; # museum local.yaml 的 key.encryption，建号后不可更换
        ente_key_hash = {
          owner = "ente";
        }; # museum local.yaml 的 key.hash，建号后不可更换
        ente_jwt_secret = {
          owner = "ente";
        };
        r2_bucket_ente = {
          owner = "ente";
        }; # ente 独立 bucket，S3 存 blob（照片/视频/缩图）
        stalwart_admin_password = { }; # Stalwart fallback-admin，用来登录 /admin 做域名/邮箱/DKIM 设置
        oci_email_delivery_username = {
          owner = "ente";
        };
        oci_email_delivery_password = {
          owner = "ente";
        };
        restic_stalwart_password = { }; # 邮件数据 restic 仓库加密密码
        restic_pds_password = { }; # bluesky-pds restic 仓库加密密码
        restic_ente_password = { }; # ente 数据库（E2EE 加密密钥材料所在）restic 仓库加密密码
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
      templates."pds.env" = {
        owner = "pds";
        content = ''
          PDS_JWT_SECRET=${config.sops.placeholder.pds_jwt_secret}
          PDS_ADMIN_PASSWORD=${config.sops.placeholder.pds_admin_password}
          PDS_PLC_ROTATION_KEY_K256_PRIVATE_KEY_HEX=${config.sops.placeholder.pds_plc_rotation_key}
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
      templates."vaultwarden-backup.env" = {
        content = ''
          AWS_ACCESS_KEY_ID=${config.sops.placeholder.r2_access_key_id}
          AWS_SECRET_ACCESS_KEY=${config.sops.placeholder.r2_secret_access_key}
          RESTIC_REPOSITORY=s3:${config.sops.placeholder.r2_endpoint}/${config.sops.placeholder.r2_bucket}/vaultwarden-backup
        '';
      };
      templates."stalwart-mail-backup.env" = {
        content = ''
          AWS_ACCESS_KEY_ID=${config.sops.placeholder.r2_access_key_id}
          AWS_SECRET_ACCESS_KEY=${config.sops.placeholder.r2_secret_access_key}
          RESTIC_REPOSITORY=s3:${config.sops.placeholder.r2_endpoint}/${config.sops.placeholder.r2_bucket}/stalwart-mail-backup
        '';
      };
      templates."pds-backup.env" = {
        content = ''
          AWS_ACCESS_KEY_ID=${config.sops.placeholder.r2_access_key_id}
          AWS_SECRET_ACCESS_KEY=${config.sops.placeholder.r2_secret_access_key}
          RESTIC_REPOSITORY=s3:${config.sops.placeholder.r2_endpoint}/${config.sops.placeholder.r2_bucket}/pds-backup
        '';
      };
      templates."ente-db-backup.env" = {
        content = ''
          AWS_ACCESS_KEY_ID=${config.sops.placeholder.r2_access_key_id}
          AWS_SECRET_ACCESS_KEY=${config.sops.placeholder.r2_secret_access_key}
          RESTIC_REPOSITORY=s3:${config.sops.placeholder.r2_endpoint}/${config.sops.placeholder.r2_bucket}/ente-db-backup
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
          url = "postgresql:///atticd?host=/run/postgresql&user=atticd"

          [storage]
          type = "s3"
          region = "us-east-1"
          bucket = "${config.sops.placeholder.r2_bucket_attic}"
          endpoint = "${config.sops.placeholder.r2_endpoint}"

          [chunking]
          nar-size-threshold = 262144
          min-size = 262144
          avg-size = 2097152
          max-size = 4194304

          [garbage-collection]
          interval = "12 hours"
          default-retention-period = "21 days"
        '';
      };

    };
    disko.devices.disk.main.device = "/dev/sda";

    networking.hostName = "oci";
    # OCI 虚拟盘(virtio-blk)不支持 SMART，smartd 会一直探测失败
    services.smartd.enable = false;
    environment.etc."tuned/active_profile".text = lib.mkForce "virtual-guest";
    nixpkgs.hostPlatform = "aarch64-linux";
    # Boot loader configuration for RPi4
    boot.loader = {
      systemd-boot.enable = true;
      efi.canTouchEfiVariables = false;
    };
    boot.plymouth.enable = false;

    # boot.kernelPackages = lib.mkForce pkgs.linuxPackages;
    boot.initrd.supportedFilesystems = [
      "vfat"
      "ext4"
      "xfs"
    ];
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
    networking.firewall = {
      allowedTCPPorts = [
        80
        443
      ];
    };

    environment.systemPackages = [
      pkgs.pkgsMusl.rclone
      pkgs.apacheHttpd # 为了方便以后在命令行生成 htpasswd
    ];

    # CrowdSec：解析 sshd/nginx 日志判定攻击，firewall bouncer 落地成 nftables/iptables
    # 丢包规则。跟 stalwart 自带的 auto-ban（见下方注释）分工——那边管
    # 25/587/465/993，这边管 sshd 爆破和仍公网直连的 headscale.hydroakri.cc vhost。
    services.crowdsec = {
      enable = true;
      hub.collections = [
        "crowdsecurity/linux"
        "crowdsecurity/sshd"
        "crowdsecurity/nginx"
      ];
      settings = {
        general.api.server = {
          enable = true;
          # 默认 127.0.0.1:8080 跟 stalwart 的 JMAP/webadmin 监听端口撞车
          listen_uri = "127.0.0.1:8081";
        };
        lapi.credentialsFile = "/etc/crowdsec/local_api_credentials.yaml";
        capi.credentialsFile = "/etc/crowdsec/online_api_credentials.yaml";
      };
      localConfig.acquisitions = [
        {
          source = "journalctl";
          journalctl_filter = [ "_SYSTEMD_UNIT=sshd.service" ];
          labels.type = "syslog";
        }
        {
          # nginx access/error log 都走 nixos 默认的 stdout/stderr → journal，
          # 没有落文件，只能从这边的 journalctl 拿
          source = "journalctl";
          journalctl_filter = [ "_SYSTEMD_UNIT=nginx.service" ];
          labels.type = "nginx";
        }
      ];
    };
    # crowdsec-firewall-bouncer-register.service 的 StateDirectory 也声明了
    # "crowdsec"，会让 systemd 把该路径建成符号链接，跟 crowdsec.service 自己用
    # ReadWritePaths 认领的所有权冲突。两边统一改走 ReadWritePaths。
    systemd.services.crowdsec-firewall-bouncer-register.serviceConfig = {
      StateDirectory = lib.mkForce "crowdsec-firewall-bouncer-register";
      ReadWritePaths = [ "/var/lib/crowdsec" ];
    };
    # register 脚本调用裸 cscli（不带 -c），走 cscli 默认路径
    # /etc/crowdsec/config.yaml；crowdsec.service 自己的配置只写在 nix store 里，
    # 从没落到这个默认路径上，镜像一份过去让裸 cscli 也能找到同一份配置
    environment.etc."crowdsec/config.yaml".source =
      (pkgs.formats.yaml { }).generate "crowdsec.yaml"
        config.services.crowdsec.settings.general;
    services.crowdsec-firewall-bouncer = {
      enable = true;
      registerBouncer = {
        enable = true;
        bouncerName = "oci-firewall-bouncer";
      };
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
          nameservers.global = [
            "172.64.36.2"
            "149.112.112.11"
          ];
        };
        prefixes = {
          v4 = "100.64.0.0/10";
          v6 = "fd7a:115c:a1e0::/48";
        };
      };
    };

    services.cloudflare-warp.enable = true;
    # sops-nix places secrets as symlinks; warp-svc opens its MDM policy file
    # with O_NOFOLLOW, so a symlinked mdm.xml fails with ELOOP and the client
    # never registers. Copy the secret into a real file before each start.
    sops.secrets."warp_mdm" = {
      owner = "root";
      group = "root";
      mode = "0400";
      restartUnits = [ "cloudflare-warp.service" ];
    };
    systemd.services.cloudflare-warp.preStart = ''
      install -m 0400 -o root -g root /run/secrets/warp_mdm /var/lib/cloudflare-warp/mdm.xml.tmp
      mv -f /var/lib/cloudflare-warp/mdm.xml.tmp /var/lib/cloudflare-warp/mdm.xml
    '';

    services.redis.package = pkgs.valkey;
    systemd.services.redis-searx.serviceConfig.BindReadOnlyPaths = [
      "/dev/null:/etc/ld-nix.so.preload"
    ];
    services.searx = {
      enable = true;
      package = pkgs.searxng;
      redisCreateLocally = true;
      # 只信任 nginx 自己（同机 loopback）转发过来的身份判断；nginx 那边已经用
      # realip 模块把 $remote_addr 纠正成 Cloudflare 上报的真实访客 IP 了（见
      # nginx commonHttpConfig），所以这里认 127.0.0.1 是安全的。
      limiterSettings = {
        botdetection = {
          trusted_proxies = [
            "127.0.0.0/8"
            "::1"
          ];
        };
      };
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
          bind_address = "0.0.0.0";
          secret_key = config.sops.placeholder.searx_secret_key;
          base_url = "https://searx.hydroakri.cc";
          method = "POST";
          image_proxy = true;
          limiter = true;
        };
        search = {
          safe_search = 0;
          autocomplete = "";
          favicon_resolver = "duckduckgo";
          formats = [
            "html"
            "json"
            "rss"
          ];
          suspended_times = {
            SearxEngineAccessDenied = 86400;
            SearxEngineCaptcha = 86400;
            SearxEngineTooManyRequests = 3600;
          };
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
        enabled_plugins = [
          "Tracker Protection"
          "Hostnames replace"
          "Favicons"
        ];
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
            disabled = false;
            weight = 2;
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
          {
            name = "yacy";
            disabled = false;
          }
        ];
      };
    };

    services.vaultwarden = {
      enable = true;
      dbBackend = "sqlite";
      environmentFile = config.sops.templates."vaultwarden.env".path;
      # 模块自带 backup-vaultwarden.service/.timer（每天 23:00），用 sqlite
      # .backup 拿一致性快照到这里，再由下面的 restic job 加密备份到 R2
      backupDir = "/var/backup/vaultwarden";
      config = {
        DOMAIN = "https://vault.hydroakri.cc";
        SIGNUPS_ALLOWED = false; # 建议直接关掉，或者注册完就关掉
        ROCKET_ADDRESS = "127.0.0.1";
        ROCKET_PORT = 8222;
      };
    };

    services.restic.backups.vaultwarden = {
      # 强制先跑一次 vaultwarden 自己的快照 service，不依赖时间表交错
      backupPrepareCommand = "systemctl start backup-vaultwarden.service";
      paths = [ "/var/backup/vaultwarden" ];
      exclude = [ "icon_cache" ]; # favicon 缓存，可重建，没必要备份
      environmentFile = config.sops.templates."vaultwarden-backup.env".path;
      passwordFile = config.sops.secrets.restic_vaultwarden_password.path;
      initialize = true;
      timerConfig = {
        OnCalendar = "04:00";
        Persistent = true;
      };
      pruneOpts = [
        "--keep-daily 7"
        "--keep-weekly 4"
        "--keep-monthly 6"
      ];
    };

    # RocksDB 没有像 vaultwarden 那种一致性快照命令，靠 WAL 理论上能撑过热备份，
    # 但邮件数据比较要紧，保险起见备份前后直接停/启服务，换几秒收信空窗期换绝对一致
    services.restic.backups.stalwart-mail = {
      backupPrepareCommand = "systemctl stop stalwart.service";
      backupCleanupCommand = "systemctl start stalwart.service";
      paths = [ "/var/lib/stalwart-mail" ];
      environmentFile = config.sops.templates."stalwart-mail-backup.env".path;
      passwordFile = config.sops.secrets.restic_stalwart_password.path;
      initialize = true;
      timerConfig = {
        OnCalendar = "04:30";
        Persistent = true;
      };
      pruneOpts = [
        "--keep-daily 7"
        "--keep-weekly 4"
        "--keep-monthly 6"
      ];
    };

    services.restic.backups.bluesky-pds = {
      backupPrepareCommand = "systemctl stop bluesky-pds.service";
      backupCleanupCommand = "systemctl start bluesky-pds.service";
      paths = [ "/var/lib/pds" ]; # PDS_DATA_DIRECTORY 默认值，包含 blob 存储（PDS_BLOBSTORE_DISK_LOCATION 是它的子目录）
      environmentFile = config.sops.templates."pds-backup.env".path;
      passwordFile = config.sops.secrets.restic_pds_password.path;
      initialize = true;
      timerConfig = {
        OnCalendar = "05:00";
        Persistent = true;
      };
      pruneOpts = [
        "--keep-daily 7"
        "--keep-weekly 4"
        "--keep-monthly 6"
      ];
    };

    # ente 数据库存的是 E2EE 主密钥/单文件密钥这类加密后的密钥材料——不是可重建数据，
    # 丢了这份 R2 里的照片全部解不开，跟 atticd 那种纯 cache 不是一回事
    systemd.services.backup-ente-db = {
      after = [ "postgresql.service" ];
      requires = [ "postgresql.service" ];
      serviceConfig = {
        Type = "oneshot";
        User = "postgres";
        StateDirectory = "ente-db-backup";
      };
      script = ''
        ${config.services.postgresql.package}/bin/pg_dump ente > /var/lib/ente-db-backup/ente.sql
      '';
    };

    services.restic.backups.ente-db = {
      backupPrepareCommand = "systemctl start backup-ente-db.service";
      paths = [ "/var/lib/ente-db-backup" ];
      environmentFile = config.sops.templates."ente-db-backup.env".path;
      passwordFile = config.sops.secrets.restic_ente_password.path;
      initialize = true;
      timerConfig = {
        OnCalendar = "05:30";
        Persistent = true;
      };
      pruneOpts = [
        "--keep-daily 7"
        "--keep-weekly 4"
        "--keep-monthly 6"
      ];
    };

    services.bluesky-pds = {
      enable = true;
      pdsadmin.enable = true;
      environmentFiles = [ config.sops.templates."pds.env".path ];
      settings = {
        PDS_HOSTNAME = "bsky.hydroakri.cc";
        PDS_INVITE_REQUIRED = "true"; # 个人账号，关闭开放注册
        PDS_CRAWLERS = "https://bsky.network"; # 让官方 relay 抓取，账号才能被搜索/展示
      };
    };

    # Museum（API server）+ web 前端（Photos/Accounts/Cast/Albums）。四个 web 子域名
    services.ente.api = {
      enable = true;
      nginx.enable = false; # 跟 stalwart JMAP 撞 127.0.0.1:8080，见 README
      domain = "ente-api.hydroakri.cc";
      enableLocalDB = true;
      settings = {
        http.port = 8082;
        # key.encryption/key.hash/jwt.secret 建号后不可更换，见 sops secrets 里的注释
        key.encryption._secret = config.sops.secrets.ente_key_encryption.path;
        key.hash._secret = config.sops.secrets.ente_key_hash.path;
        jwt.secret._secret = config.sops.secrets.ente_jwt_secret.path;

        # "b2-eu-cen" 是 museum 写死要找的 bucket key 名字，跟 Backblaze 无关，见 README
        s3.b2-eu-cen = {
          are_local_buckets = false;
          use_path_style_urls = true;
          region = "auto";
          key._secret = config.sops.secrets.r2_access_key_id.path;
          secret._secret = config.sops.secrets.r2_secret_access_key.path;
          endpoint._secret = config.sops.secrets.r2_endpoint.path;
          bucket._secret = config.sops.secrets.r2_bucket_ente.path;
        };

        # ente 的登录流程不依赖这台机器另一个服务的配置/可用性
        smtp = {
          # 值不一样，别直接照抄到别的账号上
          host = "smtp.email.ap-singapore-2.oci.oraclecloud.com";
          port = 587; # STARTTLS，不能设 encryption=tls（那是 465 那种隐式 TLS），见 README
          email = "me@hydroakri.cc"; # OCI Email Delivery 控制台里已验证过的 Approved Sender，跟 stalwart 主信箱共用
          username._secret = config.sops.secrets.oci_email_delivery_username.path;
          password._secret = config.sops.secrets.oci_email_delivery_password.path;
        };

        # 单人自架，注册完就关掉
        internal = {
          disable-registration = true;
          admin = 1580559962386438; # 唯一账号的 user_id
        };
      };
    };

    services.ente.web = {
      enable = true;
      domains = {
        photos = "ente-photos.hydroakri.cc";
        accounts = "ente-accounts.hydroakri.cc";
        cast = "ente-cast.hydroakri.cc";
        albums = "ente-albums.hydroakri.cc";
        # domains.api 由 module 自动接管（api + web 都开时），不用手动设
      };
    };

    # mail.hydroakri.cc：SMTP/IMAP 没法走 Cloudflare Tunnel（它只代理 HTTP/HTTPS），
    # 这个域名的 DNS 直接指向 oci 真实公网 IP（DNS-only，不走橘色云朵代理）。
    #
    # Stalwart 把 domain/账号/DKIM/outbound route/outbound strategy 这类「资源」存
    # 数据库，不是这份 TOML 文件——即使在这里声明了同名 key，运行时也会被数据库那份
    # 覆盖/忽略。这些一律不写在 nix 里，改用 Stalwart 自己的 web admin
    # （fallback-admin 登录）设置，完整的手动步骤见 flake/hosts/oci/README.md。
    #
    # 25/587/465/993 直连真实 IP，没有 nginx/tunnel 挡在前面，靠 Stalwart 自带的
    # auto-ban（web admin › Settings › Security › Settings，同样是数据库管理）按
    # IP+账号追踪认证失败/RCPT 探测/端口扫描并丢连接。默认阈值（如 authBanRate
    # 100 次/天）对个人域名偏松，建议登进 admin 收紧。
    # TODO: nixpkgs 钉死 services.stalwart 在 0.15.5，stalwart_0_16 存在但官方标注
    # 不兼容这个 module（0.16 管理层破坏性更新，邮件数据不受影响）。等 module 跟上
    # 0.16 再评估升级
    services.stalwart = {
      enable = true;
      stateVersion = config.system.stateVersion; # 首次启用，跟系统本身对齐
      openFirewall = true; # 自动开放 settings.server.listener 里声明的端口
      credentials = {
        admin_password = config.sops.secrets.stalwart_admin_password.path;
      };
      settings = {
        server = {
          hostname = "mail.hydroakri.cc";
          tls.certificate = "default";
          listener = {
            smtp = {
              bind = [ "0.0.0.0:25" ];
              protocol = "smtp";
            };
            submission = {
              bind = [ "0.0.0.0:587" ];
              protocol = "smtp";
            };
            submissions = {
              bind = [ "0.0.0.0:465" ];
              protocol = "smtp";
              tls.implicit = true;
            };
            imaps = {
              bind = [ "0.0.0.0:993" ];
              protocol = "imap";
              tls.implicit = true;
            };
            # JMAP/管理 API（webadmin）只绑本机，nginx（stalwart.hydroakri.cc）代理进来，不直接对外开放
            jmap = {
              bind = [ "127.0.0.1:8080" ];
              protocol = "http";
              url = "https://mail.hydroakri.cc";
            };
          };
        };

        certificate.default = {
          cert = "%{file:/var/lib/acme/hydroakri.cc/fullchain.pem}%";
          private-key = "%{file:/var/lib/acme/hydroakri.cc/key.pem}%";
          default = true;
        };

        authentication.fallback-admin = {
          user = "admin";
          secret = "%{file:/run/credentials/stalwart.service/admin_password}%";
        };
      };
    };

    # cloudflared tunnel：统一藏住 oci 的源站 IP
    # tunnel 是 `cloudflared tunnel create` 在本机建的（经典 credentials.json + 宣告式 ingress）
    services.cloudflared = {
      enable = true;
      tunnels."901e5935-3f36-4609-9bb3-9a204bf7f79a" = {
        credentialsFile = config.sops.secrets.cloudflared_tunnel_credentials.path;
        default = "http_status:404";
        # 全部转给本机 nginx 443（不是 80）：nginx vhost 都设了 forceSSL，转 80 会被 301 回
        # https，cloudflared 再用 http 转一次会死循环；originServerName 带对 SNI/Host 让
        # nginx（同一个 IP、多个 vhost）选到正确的 server block 和证书
        ingress = {
          "searx.hydroakri.cc" = {
            service = "https://127.0.0.1:443";
            originRequest.originServerName = "searx.hydroakri.cc";
          };
          "vault.hydroakri.cc" = {
            service = "https://127.0.0.1:443";
            originRequest.originServerName = "vault.hydroakri.cc";
          };
          "ente-photos.hydroakri.cc" = {
            service = "https://127.0.0.1:443";
            originRequest.originServerName = "ente-photos.hydroakri.cc";
          };
          "ente-accounts.hydroakri.cc" = {
            service = "https://127.0.0.1:443";
            originRequest.originServerName = "ente-accounts.hydroakri.cc";
          };
          "ente-cast.hydroakri.cc" = {
            service = "https://127.0.0.1:443";
            originRequest.originServerName = "ente-cast.hydroakri.cc";
          };
          "ente-albums.hydroakri.cc" = {
            service = "https://127.0.0.1:443";
            originRequest.originServerName = "ente-albums.hydroakri.cc";
          };
          "ente-api.hydroakri.cc" = {
            service = "https://127.0.0.1:443";
            originRequest.originServerName = "ente-api.hydroakri.cc";
          };
          "stalwart.hydroakri.cc" = {
            service = "https://127.0.0.1:443";
            originRequest.originServerName = "stalwart.hydroakri.cc";
          };
          "mta-sts.hydroakri.cc" = {
            service = "https://127.0.0.1:443";
            originRequest.originServerName = "mta-sts.hydroakri.cc";
          };
          "tools.hydroakri.cc" = {
            service = "https://127.0.0.1:443";
            originRequest.originServerName = "tools.hydroakri.cc";
          };
          "dav.hydroakri.cc" = {
            service = "https://127.0.0.1:443";
            originRequest.originServerName = "dav.hydroakri.cc";
          };
          "cache.hydroakri.cc" = {
            service = "https://127.0.0.1:443";
            originRequest.originServerName = "cache.hydroakri.cc";
          };
          "ntfy.hydroakri.cc" = {
            service = "https://127.0.0.1:443";
            originRequest.originServerName = "ntfy.hydroakri.cc";
          };
          "bsky.hydroakri.cc" = {
            service = "https://127.0.0.1:443";
            originRequest.originServerName = "bsky.hydroakri.cc";
          };
          "uptime.hydroakri.cc" = {
            service = "https://127.0.0.1:443";
            originRequest.originServerName = "uptime.hydroakri.cc";
          };
          "map.hydroakri.cc" = {
            service = "https://127.0.0.1:443";
            originRequest.originServerName = "map.hydroakri.cc";
          };
          # *.bsky.hydroakri.cc（未来多用户子网域 handle）先不加：originServerName 不能是
          # 字面量的 wildcard SNI，等真的开放注册、有第二个账号时再处理
        };
      };
    };

    # WebDAV 本地優先：真實資料存在本機磁盤，R2 只當異步備份目標（見下方 rclone-webdav-backup）
    systemd.services.rclone-webdav = {
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        User = "nginx";
        Group = "nginx";
        Restart = "always";
        ExecStart = "${pkgs.pkgsMusl.rclone}/bin/rclone serve webdav /var/lib/dav-storage --addr 127.0.0.1:8083";
      };
    };

    # 本地資料單向同步回 R2 當備份，跟本地 serve 完全解耦
    systemd.services.rclone-webdav-backup = {
      after = [
        "network.target"
        "sops-nix.service"
      ];
      serviceConfig = {
        Type = "oneshot";
        EnvironmentFile = config.sops.templates."rclone-r2.env".path;
        User = "nginx";
        Group = "nginx";
      };
      script = ''
        ${pkgs.pkgsMusl.rclone}/bin/rclone sync /var/lib/dav-storage r2:$R2_BUCKET_NAME/webdav-backup \
          --transfers 8 \
          --s3-upload-concurrency 8 \
          --s3-chunk-size 16M
      '';
    };
    systemd.timers.rclone-webdav-backup = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "daily";
        Persistent = true;
      };
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
        ExecStart = lib.mkForce "${config.services.atticd.package}/bin/atticd -f ${
          config.sops.templates."attic-server.toml".path
        } --mode monolithic";
      };
    };
    services.postgresql = {
      enable = true;
      ensureDatabases = [ "atticd" ];
      ensureUsers = [
        {
          name = "atticd";
          ensureDBOwnership = true;
        }
      ];
    };

    services.ntfy-sh = {
      enable = true;
      settings = {
        listen-http = "127.0.0.1:8084";
        base-url = "https://ntfy.hydroakri.cc";
        auth-file = "/var/lib/ntfy-sh/user.db";
        auth-default-access = "deny-all";
        cache-file = "/var/lib/ntfy-sh/cache.db";
        cache-duration = "12h";
        attachment-cache-dir = "/var/lib/ntfy-sh/attachments";
        attachment-total-size-limit = "100M";
        attachment-file-size-limit = "10M";
      };
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
        reloadServices = [
          "nginx.service"
          "stalwart.service"
        ];
        # 续期时复用同一把私钥（只换证书本身），这样 mail.hydroakri.cc 的 DANE/TLSA
        # 记录绑死这把公钥指纹后就永远不用跟着换证书更新
        extraLegoRenewFlags = [ "--reuse-key" ];
      };
      # 独立签发：PDS 账号 handle 未来要支持 <user>.bsky.hydroakri.cc 这种二级子域，
      # 现有的 *.hydroakri.cc 只覆盖一层，盖不到这个深度
      certs."bsky.hydroakri.cc" = {
        domain = "*.bsky.hydroakri.cc";
        extraDomainNames = [ "bsky.hydroakri.cc" ];
        dnsProvider = "cloudflare";
        environmentFile = config.sops.templates."cf_oracle.env".path;
        reloadServices = [ "nginx.service" ];
      };
    };
    users.users.nginx.extraGroups = [ "acme" ];
    # module 的默认使用者名字跟 stateVersion 挂钩：25.11 < 26.05，实际是 "stalwart-mail"
    # 不是 "stalwart"
    users.users.stalwart-mail.extraGroups = [ "acme" ]; # 复用现有 *.hydroakri.cc 证书，不用 Stalwart 自己再走一次 ACME
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

        set_real_ip_from 127.0.0.1;
        set_real_ip_from ::1;
        real_ip_header CF-Connecting-IP;

        map $http_destination $webdav_dest {
            ~^https://(.*)$ http://$1;
            default $http_destination;
        }

        proxy_cache_path /var/cache/nginx/attic
          levels=1:2
          keys_zone=attic_cache:500m
          max_size=15g
          inactive=30d
          use_temp_path=off;
      '';

      # 故意不走 cloudflared tunnel：Cloudflare 边缘会剥掉 POST 请求的 Upgrade 头，
      # 而 TS2021 握手就是靠 POST 带 Upgrade，会导致节点全部掉线（headscale#3287，
      # 官方确认无解）。DNS 必须是直连真实 IP 的 A 记录
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
        # 只走 cloudflared tunnel（连本机 127.0.0.1:443）；真实 IP 已经因为
        # mail/headscale 的 DNS-only 记录暴露，绑死 loopback 避免有人拿真实 IP + 正确
        # SNI 直接打到这个 vhost，绕过 Cloudflare 的隐藏/WAF/限速
        listenAddresses = [ "127.0.0.1" ];
        locations."/" = {
          proxyPass = "http://127.0.0.1:8888";
          proxyWebsockets = true;
          extraConfig = ''
            proxy_cookie_path / "/; secure; SameSite=Lax";
          '';
        };
      };

      virtualHosts."vault.hydroakri.cc" = {
        # enableACME = true;
        useACMEHost = "hydroakri.cc";
        acmeRoot = null;
        forceSSL = true;
        listenAddresses = [ "127.0.0.1" ]; # 只走 tunnel，见 searx vhost 注释
        locations."/" = {
          proxyPass = "http://127.0.0.1:8222";
          proxyWebsockets = true;
        };
      };

      virtualHosts."map.hydroakri.cc" = {
        useACMEHost = "hydroakri.cc";
        forceSSL = true;
        listenAddresses = [ "127.0.0.1" ]; # 只走 tunnel，见 searx vhost 注释
        locations."/" = {
          proxyPass = "http://127.0.0.1:3417";
          proxyWebsockets = true;
        };
      };

      virtualHosts."ente-photos.hydroakri.cc" = {
        useACMEHost = "hydroakri.cc"; # 已覆盖 *.hydroakri.cc，不用另开证书
        listenAddresses = [ "127.0.0.1" ]; # 只走 tunnel，见 searx vhost 注释
      };
      virtualHosts."ente-accounts.hydroakri.cc" = {
        useACMEHost = "hydroakri.cc";
        listenAddresses = [ "127.0.0.1" ];
      };
      virtualHosts."ente-cast.hydroakri.cc" = {
        useACMEHost = "hydroakri.cc";
        listenAddresses = [ "127.0.0.1" ];
      };
      virtualHosts."ente-albums.hydroakri.cc" = {
        useACMEHost = "hydroakri.cc";
        listenAddresses = [ "127.0.0.1" ];
      };
      virtualHosts."ente-api.hydroakri.cc" = {
        useACMEHost = "hydroakri.cc";
        forceSSL = true;
        listenAddresses = [ "127.0.0.1" ];
        locations."/" = {
          proxyPass = "http://127.0.0.1:8082";
          extraConfig = ''
            client_max_body_size 4M;
          '';
        };
      };

      # Stalwart 自己的 /admin（建域名/DKIM/catch-all/建信箱用）；纯 HTTP(S)，
      # 走 cloudflared tunnel 藏起来，不像 SMTP/IMAP 那样必须直连真实 IP
      virtualHosts."stalwart.hydroakri.cc" = {
        useACMEHost = "hydroakri.cc";
        forceSSL = true;
        listenAddresses = [ "127.0.0.1" ]; # 只走 tunnel，见 searx vhost 注释
        locations."/" = {
          proxyPass = "http://127.0.0.1:8080";
          proxyWebsockets = true;
        };
      };

      # MTA-STS policy 必须放在 mta-sts.<domain> 这个固定路径，纯 HTTPS，走 tunnel
      # 就行，不需要跟 mail.hydroakri.cc 一样直连真实 IP。改这里的 mode 之后，记得
      # 同步换 DNS 那条 _mta-sts TXT 的 id 值，不然缓存了旧 policy 的发信方不会重新抓取
      virtualHosts."mta-sts.hydroakri.cc" = {
        useACMEHost = "hydroakri.cc";
        forceSSL = true;
        listenAddresses = [ "127.0.0.1" ]; # 只走 tunnel，见 searx vhost 注释
        locations."/.well-known/mta-sts.txt" = {
          extraConfig = ''
            default_type "text/plain";
            return 200 "version: STSv1\nmode: enforce\nmx: mail.hydroakri.cc\nmax_age: 604800\n";
          '';
        };
      };

      virtualHosts."tools.hydroakri.cc" = {
        useACMEHost = "hydroakri.cc";
        forceSSL = true;
        listenAddresses = [ "127.0.0.1" ]; # 只走 tunnel，见 searx vhost 注释
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

      virtualHosts."dav.hydroakri.cc" = {
        useACMEHost = "hydroakri.cc";
        forceSSL = true;
        listenAddresses = [ "127.0.0.1" ]; # 只走 tunnel，见 searx vhost 注释
        locations."/" = {
          proxyPass = "http://127.0.0.1:8083";
          basicAuthFile = config.sops.templates."webdav-auth".path;

          extraConfig = ''
            gzip off;

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
        listenAddresses = [ "127.0.0.1" ]; # 只走 tunnel，见 searx vhost 注释
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

            proxy_cache attic_cache;
            proxy_cache_key $scheme$proxy_host$uri$is_args$args;
            proxy_cache_valid 200 30d;
            proxy_cache_use_stale error timeout updating http_500 http_502 http_503 http_504;
            proxy_cache_lock on;
            proxy_cache_background_update on;
            proxy_no_cache $http_x_attic_no_cache;
            proxy_cache_bypass $http_x_attic_no_cache;
          '';
        };
      };

      virtualHosts."ntfy.hydroakri.cc" = {
        useACMEHost = "hydroakri.cc";
        acmeRoot = null;
        forceSSL = true;
        listenAddresses = [ "127.0.0.1" ]; # 只走 tunnel，见 searx vhost 注释
        locations."/" = {
          proxyPass = "http://127.0.0.1:8084";
          proxyWebsockets = true;
          extraConfig = ''
            proxy_buffering off;
            proxy_request_buffering off;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection "upgrade";
          '';
        };
      };

      virtualHosts."bsky.hydroakri.cc" = {
        useACMEHost = "bsky.hydroakri.cc";
        serverAliases = [ "*.bsky.hydroakri.cc" ]; # 为未来的 <user>.bsky.hydroakri.cc 账号 handle 预留
        forceSSL = true;
        listenAddresses = [ "127.0.0.1" ]; # 只走 tunnel，见 searx vhost 注释
        locations."/" = {
          proxyPass = "http://127.0.0.1:3000";
          proxyWebsockets = true; # AT Proto firehose 是长连接 websocket
          extraConfig = ''
            client_max_body_size 0;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            proxy_set_header Host $host;
          '';
        };
      };

      virtualHosts."uptime.hydroakri.cc" = {
        useACMEHost = "hydroakri.cc";
        forceSSL = true;
        listenAddresses = [ "127.0.0.1" ]; # 只走 tunnel，见 searx vhost 注释
        locations."/" = {
          proxyPass = "http://127.0.0.1:3001";
          proxyWebsockets = true;
        };
      };

    };

    systemd.tmpfiles.rules = [
      "d /var/cache/nginx/attic 0750 nginx nginx -"
      "d /var/lib/dav-storage 0750 nginx nginx -"
      # cscli machine add 启动时会读取 capi credentials 文件本身（不只是检查存不
      # 存在），空文件也能解析。先占位一个空文件，后面 cscli capi register 再把
      # 真实内容写进去覆盖——"f" 类型只在文件不存在时创建，不会覆盖已写好的内容
      "f /etc/crowdsec/online_api_credentials.yaml 0600 crowdsec crowdsec -"
    ];

    system.stateVersion = "25.11";

  };

}
