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

    # pkgs.element-web 的 wrapper 读 `config.element-web.conf`（nixpkgs 的全局 config 参数，
    # 不是 NixOS 的 config）在构建期用 jq 合并进 config.json，见 nixpkgs
    # pkgs/by-name/el/element-web/package.nix
    nixpkgs.config.element-web.conf = {
      default_server_config = {
        "m.homeserver" = {
          base_url = "https://matrix.hydroakri.cc";
          server_name = "matrix.hydroakri.cc";
        };
      };
      disable_custom_urls = true;
      disable_guests = true;
      disable_3pid_login = true;
      enable_client_well_known_lookups = false;
      show_labs_settings = false;
      default_federate = true; # 跟 homeserver 的联邦设置一致
      mobile_guide_toast = false;
      integrations_ui_url = null;
      integrations_rest_url = null;
      integrations_widgets_urls = null;
      element_call.disable = true; # 语音/视频暂不开放
      setting_defaults = {
        "UIFeature.urlPreviews" = false;
        "UIFeature.feedback" = false;
        "UIFeature.voip" = false;
        "UIFeature.widgets" = false;
        "UIFeature.identityServer" = false;
        "UIFeature.thirdPartyId" = false;
        "UIFeature.locationSharing" = false;
        "UIFeature.shareQrCode" = false;
        "UIFeature.shareSocial" = false;
        "UIFeature.registration" = false;
        "UIFeature.passwordReset" = false;
      };
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
        pds_jwt_secret = { };
        pds_admin_password = { };
        pds_plc_rotation_key = { };
        cloudflared_tunnel_credentials = { }; # `cloudflared tunnel create` 在本机生成的经典 credentials.json 原文
        restic_vaultwarden_password = { }; # restic 仓库加密密码
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
        restic_synapse_password = { }; # Matrix/Synapse 数据库 restic 仓库加密密码
        # register_new_matrix_user 用；随便生成一个强随机值即可（openssl rand -base64 32），不依赖外部服务
        synapse_registration_shared_secret = {
          owner = "matrix-synapse"; # Synapse 以 User = "matrix-synapse" 直接读文件，不是 systemd LoadCredential
        };
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
      templates."synapse-db-backup.env" = {
        content = ''
          AWS_ACCESS_KEY_ID=${config.sops.placeholder.r2_access_key_id}
          AWS_SECRET_ACCESS_KEY=${config.sops.placeholder.r2_secret_access_key}
          RESTIC_REPOSITORY=s3:${config.sops.placeholder.r2_endpoint}/${config.sops.placeholder.r2_bucket}/synapse-backup
        '';
      };
      templates."synapse-secrets.yaml" = {
        owner = "matrix-synapse";
        content = ''
          registration_shared_secret: ${config.sops.placeholder.synapse_registration_shared_secret}
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
          type = "local"
          # 落在 systemd StateDirectory=atticd（/var/lib/atticd）默认路径下，
          # 不用额外 ReadWritePaths；放弃 R2，缓存数据存本机磁盘，减少一个外部依赖
          path = "/var/lib/atticd/storage"

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
      systemd-boot = {
        enable = true;
        editor = false;
      };
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
        8448 # Matrix 联邦（fed.hydroakri.cc），走直连真实 IP，不经 cloudflared tunnel
      ];
      # Simple Voice Chat 走獨立 UDP port,跟 MC 本身的 TCP 25565 分開協商,
      # services.minecraft-servers.openFirewall 不知道這個 mod 專屬 port 的存在
      allowedUDPPorts = [
        24454
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
      # 26.05 ships 0.28.0; this host's db.sqlite was already migrated by unstable's 0.29.3
      # (added a database_versions table) before the nixpkgs pin switch — 0.28.0's schema
      # validator rejects it as unexpected. Pin forward to unstable until 26.05 catches up.
      package = inputs.unstable.legacyPackages.${pkgs.system}.headscale;
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

    # dataDir 里同时有 signing.key（丢了等于丢了联邦身份，不可重建）和媒体文件，
    # 跟 db dump 一起进同一个 restic 仓库备份
    systemd.services.backup-synapse-db = {
      after = [ "postgresql.service" ];
      requires = [ "postgresql.service" ];
      serviceConfig = {
        Type = "oneshot";
        User = "postgres";
        StateDirectory = "synapse-db-backup";
      };
      script = ''
        ${config.services.postgresql.package}/bin/pg_dump matrix-synapse > /var/lib/synapse-db-backup/matrix-synapse.sql
      '';
    };

    services.restic.backups.synapse = {
      backupPrepareCommand = "systemctl start backup-synapse-db.service";
      paths = [
        "/var/lib/synapse-db-backup"
        config.services.matrix-synapse.settings.media_store_path
        config.services.matrix-synapse.settings.signing_key_path
      ];
      environmentFile = config.sops.templates."synapse-db-backup.env".path;
      passwordFile = config.sops.secrets.restic_synapse_password.path;
      initialize = true;
      timerConfig = {
        OnCalendar = "06:00";
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
      # 26.05 ships museum 1.3.36; its bundled migrations/ dir is missing files that postgres
      # already recorded as applied by unstable's 1.3.63 before the nixpkgs pin switch —
      # golang-migrate panics "file does not exist" in m.Up(). Pin forward to unstable until
      # 26.05 catches up. Same failure class as atticd/headscale above.
      package = inputs.unstable.legacyPackages.${pkgs.system}.museum;
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
      # 26.05 钉的版本是 1.3.36，那条 fetchFromGitHub（tag photos-v1.3.36，
      # sparseCheckout + submodule）的 hash 对不上了——上游同一个 tag 指向的内容
      # 变了（nixpkgs 现在 master 已经是 1.3.61，是全新的 tag/hash，不受影响）。
      # 跟 attic-server/ntfy-sh 同一个处理方式：钉到 unstable。
      package = inputs.unstable.legacyPackages.${pkgs.system}.ente-web;
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
        # 本机 enp0s6 只有 link-local IPv6，没有公网 IPv6 出口；不强制会偶尔尝试 IPv6 边缘连接失败重试
        edgeIPVersion = "4";
        # 全部转给本机 nginx 443（不是 80）：nginx vhost 都设了 forceSSL，转 80 会被 301 回
        # https，cloudflared 再用 http 转一次会死循环；originServerName 带对 SNI/Host 让
        # nginx（同一个 IP、多个 vhost）选到正确的 server block 和证书
        ingress = {
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
          "matrix.hydroakri.cc" = {
            service = "https://127.0.0.1:443";
            originRequest.originServerName = "matrix.hydroakri.cc";
          };
          "element.hydroakri.cc" = {
            service = "https://127.0.0.1:443";
            originRequest.originServerName = "element.hydroakri.cc";
          };
          # fed.hydroakri.cc（联邦 8448）不进这里——直连真实 IP，不走 tunnel，见 oci.nix
          # 里 services.matrix-synapse 旁边的注释
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
      # 26.05 ships the 2025-09-24 snapshot; this host's postgres db already has migrations
      # applied by unstable's 2026-07-06 snapshot before the nixpkgs pin switch — the older
      # binary's embedded migrator doesn't even contain those migration files. Pin forward to
      # unstable until 26.05 catches up.
      package = inputs.unstable.legacyPackages.${pkgs.system}.attic-server;
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
        {
          # 只建角色，不建库——Synapse 要求数据库是 C collation/C ctype，
          # ensureDatabases/ensureDBOwnership 没法指定 locale/template，见下面的
          # matrix-synapse-db-bootstrap（跟 nixos matrix-synapse 模块文档给的
          # CREATE DATABASE 示例一致）
          name = "matrix-synapse";
        }
      ];
    };

    # Synapse 启动时自己检查数据库 locale，不是 C collation/C ctype 会直接拒绝跑
    # （IncorrectDatabaseSetup）。幂等：数据库已存在就跳过，不会碰现有数据
    systemd.services.matrix-synapse-db-bootstrap = {
      after = [ "postgresql.service" ];
      requires = [ "postgresql.service" ];
      before = [ "matrix-synapse.service" ];
      requiredBy = [ "matrix-synapse.service" ];
      serviceConfig = {
        Type = "oneshot";
        User = "postgres";
      };
      script = ''
        if ! ${config.services.postgresql.package}/bin/psql -tAc "SELECT 1 FROM pg_database WHERE datname='matrix-synapse'" | grep -q 1; then
          ${config.services.postgresql.package}/bin/createdb matrix-synapse \
            --owner=matrix-synapse --template=template0 --lc-collate=C --lc-ctype=C
        fi
      '';
    };

    # server_name 建号后不可更改，见 flake/hosts/oci/README.md
    #
    # 联邦：matrix.hydroakri.cc 的 443 走 cloudflared tunnel（CDN 保护客户端 API），
    # 但联邦端口 8448 是裸 TLS，Cloudflare/tunnel 都代理不了——用 .well-known/matrix/server
    # 把联邦流量委派到 fed.hydroakri.cc:8448，那个子域名单独直连真实公网 IP（灰云 A 记录，
    # 跟 mail./headscale. 同样的理由），不占用 matrix.hydroakri.cc 本身的 443
    services.matrix-synapse = {
      enable = true;
      settings = {
        server_name = "matrix.hydroakri.cc";
        public_baseurl = "https://matrix.hydroakri.cc/";
        listeners = [
          {
            port = 8008;
            bind_addresses = [ "127.0.0.1" ];
            type = "http";
            tls = false;
            x_forwarded = true;
            resources = [
              {
                names = [
                  "client"
                  "federation"
                ];
                compress = false; # 已经在 nginx 层 gzip，这里再压一次没必要
              }
            ];
          }
        ];
        enable_registration = false;
        url_preview_enabled = false; # 官方给出的漏洞规避办法，见 GHSA-98px-6486-j7qc
        report_stats = false;
        presence.enabled = false;
        max_upload_size = "50M"; # 要跟下面 nginx vhost 的 client_max_body_size 一致
      };
      extraConfigFiles = [ config.sops.templates."synapse-secrets.yaml".path ];
    };

    services.ntfy-sh = {
      enable = true;
      # 26.05 ships 2.26.0 (cache.db schema v8 reader); this host's cache.db was already
      # migrated to schema v9 by unstable's 2.28.0 before the nixpkgs pin switch — pin
      # forward to unstable until 26.05 catches up, or the service refuses to start.
      package = inputs.unstable.legacyPackages.${pkgs.system}.ntfy-sh;
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
        # Mojang 目前最新版是 26.3。NeoForge 對 26.3 只有 beta,nix-minecraft 也還沒鎖;
        # Fabric API 對 26.3 已經是穩定版(Mojang 發布後 3 天),`fabricServers` 也已鎖到
        # 26.3——選 Fabric 才能真正貼齊最新版而不是次新版。取捨過程、雙 loader 平行審查
        # 結果、mod 篩選標準全文位置,見 README 第 8 節。
        # 寫死具體版本 attribute、不用 `fabricServers.fabric` 這個自動跟最新的裸指標——
        # 下面 mods 是釘死特定 MC 版本的 jar,loader 自動跳版但 mod 沒跟上會導致啟動失敗/
        # 崩潰,寧可每次手動一起升級。
        #
        # `.override { jre_headless = ... }` 是必要的:nix-minecraft 的
        # fabric-servers/default.nix 沒有像 neoforge-servers 那樣明確傳
        # `jre_headless = vanilla-server.java`,結果 mkTextileServer 透過
        # callPackage 自動注入的是 nixpkgs 全域預設的 jre_headless(較舊版本),
        # 對 26.3 這種需要 Java 25 的新版本直接啟動失敗:
        # UnsupportedClassVersionError(class file 69.0 vs 65.0)。
        # 實測(2026-09-27,live 崩潰 log 抓到的原始例外)確認 vanilla-26_3.java
        # 就是 25.0.4.1,override 後驗證過可以正常評估出新的 derivation。
        # 每次升版都要重新確認這個 override 還有沒有必要(未來 nix-minecraft
        # 上游可能自己修好這個 default)。
        package = pkgs.fabricServers.fabric-26_3.override {
          jre_headless = pkgs.vanillaServers.vanilla-26_3.java;
        };
        # 用「MC Mod 篩選與滾動更新標準」(存在 memory,
        # feedback_mc_mod_selection_standard.md)篩出的 Fabric+26.3 完整通過清單,
        # 含遞迴解出的全部 required 依賴。清單/風險畫像細節見 README 第 8 節。
        symlinks = {
          # -- 效能/伺服器管理 --
          "mods/lithium.jar" = pkgs.fetchurl {
            url = "https://cdn.modrinth.com/data/gvQqBUqZ/versions/WXHRsMRl/lithium-fabric-0.26.1%2Bmc26.3.jar";
            sha512 = "acbb9b037a203f005e03a20bf1d9866019384abb5ad27664808a12b919639a2501ecb52f8f0d77d27e1409935b0dbdbb70e01ac466480c0ae421ee403f649c59";
          };
          "mods/ferritecore.jar" = pkgs.fetchurl {
            url = "https://cdn.modrinth.com/data/uXXizFIs/versions/d5ddUdiB/ferritecore-9.0.0-fabric.jar";
            sha512 = "d81fa97e11784c19d42f89c2f433831d007603dd7193cee45fa177e4a6a9c52b384b198586e04a0f7f63cd996fed713322578bde9a8db57e1188854ae5cbe584";
          };
          "mods/c2me.jar" = pkgs.fetchurl {
            url = "https://cdn.modrinth.com/data/VSNURh3q/versions/sSoXjAqP/c2me-fabric-mc26.3-0.4.2-alpha.0.88.jar";
            sha512 = "bb741d118c88ea6d9577fed1affacc1f1f0a7b725a619ee933437cc5e403c8f1474a708ab9bd402d154efde3ce66ef4d83ed950c0cf4f7dc656e525837239226";
          };
          "mods/chunky.jar" = pkgs.fetchurl {
            url = "https://cdn.modrinth.com/data/fALzjamp/versions/4Eotm6ov/Chunky-Fabric-1.5.3.jar";
            sha512 = "b83bfe7b218d0aa6232af977ae741dc1f82b10e50cd12bb759f65cf416b8b62beccb543e587ef0b9670abe03815660f8e091bc6823624d65cf07300571573516";
          };
          "mods/packetfixer.jar" = pkgs.fetchurl {
            url = "https://cdn.modrinth.com/data/c7m1mi73/versions/dTKbGYbb/PacketFixer-fabric-3.3.6.jar";
            sha512 = "8d3139b150ef591c62b086f553be212bc72eb4a32b0b1f8bb5cc069a9b79a85046d31b1147e5aaff23e4b69bb92c76445d41884657a7b652def25e2b73d61613";
          };

          # -- 依賴函式庫(遞迴解出的 required deps,§5 條件 4)--
          "mods/fabric-api.jar" = pkgs.fetchurl {
            url = "https://cdn.modrinth.com/data/P7dR8mSH/versions/bNnaTiuM/fabric-api-0.161.0%2B26.3.jar";
            sha512 = "ed6b2586d6fde11fde8472f5a527c51e99b67026e46f94d4bfd85e7e28ce5ee299173ee16ad576ceb51f39f98d30a811086a6deb1a86a524859cc16e12da109d";
          };
          # Visual Workbench 的必要依賴,加 Visual Workbench 時漏掉了(只查了客戶端
          # 清單,沒查伺服器端)——2026-09-28 live 崩潰 log 抓到:FormattedException
          # 要求 puzzleslib>=26.3.3,原本伺服器端完全沒裝。跟客戶端同一份 build
          "mods/puzzleslib.jar" = pkgs.fetchurl {
            url = "https://cdn.modrinth.com/data/QAGBst4M/versions/SDaDR5Dt/puzzleslib-v26.3.6-mc26.3.x%2Bfabric.jar";
            sha512 = "b4abe1c3c08f3576ae2bd35e7944eb1b52a3e82ff2e4471c62feb76a9ebcac447d437319d626e7a88bde38516bd2ab4473597d8f70a0a572880440c1d4dd7e50";
          };
          "mods/cloth-config.jar" = pkgs.fetchurl {
            url = "https://cdn.modrinth.com/data/9s6osm5g/versions/fg2uyxOW/cloth-config-fabric-26.3.159.jar";
            sha512 = "8924e19d41845096724fa10f3717bc51964a0edbbbcad0ff1e6c6187a398b08f356e49579a657c2dc44a7f92e3850771f3ca70bf8c1f654de60425163b91dbb1";
          };
          "mods/balm.jar" = pkgs.fetchurl {
            url = "https://cdn.modrinth.com/data/MBAkmtvl/versions/WiU0dv7R/balm-fabric-26.3-26.3.0.2.jar";
            sha512 = "20932c46420edbb18112410008cab41e52d05598e2dc15837753cd065807f79c69c109eceba5228f1c832bf0230698226e74f098e01f4964750a3f52dc787650";
          };
          "mods/shogi.jar" = pkgs.fetchurl {
            url = "https://cdn.modrinth.com/data/bi4iCmsw/versions/9gkJoFhj/shogi-fabric-26.3-26.3.0.3.jar";
            sha512 = "f050b6360b188a82ca7e3fbb0d00eff4c02b9b39bc991fbddcf4a3588f594887d15f6421e50d5a7452a53ec35d44ec9b325d7826f77393af9543fe3383cb142d";
          };
          "mods/fabric-language-kotlin.jar" = pkgs.fetchurl {
            url = "https://cdn.modrinth.com/data/Ha28R6CL/versions/eRRZzGMc/fabric-language-kotlin-1.14.1%2Bkotlin.2.4.20.jar";
            sha512 = "91404f87774466ce8604aafea791d8cc97b603bc310dce17c8188f94f7783cca6dc14fc726ce871ca317bfe9033c199d8d858d51284106a00754e952147703b8";
          };
          "mods/midnightlib.jar" = pkgs.fetchurl {
            url = "https://cdn.modrinth.com/data/codAaoxh/versions/wJeXgIoa/midnightlib-fabric-1.9.3%2B26.3-rc-2.jar";
            sha512 = "2b5c5ed195d44d97dd6fafdb8583d1d883f10303c0cde331da72c6004f88cf27207167aaf77f0c692113399db42f616d1174144671898a25dfa69e9525135b8b";
          };
          "mods/mezzconfig.jar" = pkgs.fetchurl {
            url = "https://cdn.modrinth.com/data/7tEfOcA7/versions/jCLRqOAa/mezz_config-26.3-fabric-0.6.5.jar";
            sha512 = "5b02eae5d29d47051867beffbb4fb72b9c182437b3b2928266cb1c574619be99431ebca4a7045f4aa6d61ce6f5665b17b0059e59cd5fb5d343d9f4f70d1ec1ce";
          };

          # -- 玩法/內容 mod --
          "mods/jei.jar" = pkgs.fetchurl {
            url = "https://cdn.modrinth.com/data/u6dRKJwZ/versions/c0AyylLw/jei-26.3-fabric-31.7.0.44.jar";
            sha512 = "8b69bcbf381a85d859120d3d2a27ccc550571e5da8c3c8010e4dab1ebfd79954917ff612f15ebb78fbbc27397cd01ce225d2a4240950b68c5f14c5e377866aef";
          };
          "mods/naturescompass.jar" = pkgs.fetchurl {
            url = "https://cdn.modrinth.com/data/fPetb5Kh/versions/pHan4UQ9/NaturesCompass-26.3-2.5.1-fabric.jar";
            sha512 = "3a6801d74a0427cb4a041b2bc15068e76858ecb0a4aaa221675b40eb2e26b3e20a25dfc00320802af33a0f9cc06e95dfd4b61805452aa33408056f94f664c475";
          };
          "mods/explorerscompass.jar" = pkgs.fetchurl {
            url = "https://cdn.modrinth.com/data/RV1qfVQ8/versions/69AbLioc/ExplorersCompass-26.3-2.5.2-fabric.jar";
            sha512 = "83e7b4217fee0eda42bf91ced65ea66135846a03e6cfc353067ccbbfab279e967d3c59887de286c90742d3ed95946398e4362d506092a34d0d99b39b502b6428";
          };
          "mods/alternatecurrent.jar" = pkgs.fetchurl {
            url = "https://cdn.modrinth.com/data/r0v8vy1s/versions/nSBWPz6x/alternate-current-mc26.3-1.9.0.jar";
            sha512 = "347fa8d0338a7e113c0cde70306d05037dbf9fc1e33c476159b4f5cf7b4fce8d3798d820ebf0e0dedd8450417802cb3a030bdcbecaf509961a83b2e43a469ad5";
          };
          "mods/waystones.jar" = pkgs.fetchurl {
            url = "https://cdn.modrinth.com/data/LOpKHB2A/versions/UKjvFJAV/waystones-fabric-26.3-26.3.0.1.jar";
            sha512 = "b9c09872b60f78dd6a37baa32a866821b84cd7386e2ea2eed641acdc31fd2635a70a22be8006c3f9ee5de495f563cb1915a2a1b6864bbaecb86c907c5b4c6ae2";
          };
          "mods/simplevoicechat.jar" = pkgs.fetchurl {
            url = "https://cdn.modrinth.com/data/9eGKb6K1/versions/OLnMVWXy/voicechat-fabric-2.6.24%2B26.3.jar";
            sha512 = "414eb51967305fe7740d34016bc8e3e4e2fa1590e1278ad06bcdfa0687f65007b825d345dc09f79a992704a51ec93baf01fe727e0bbc32fdf506828b5a65d85a";
          };
          "mods/veinminer.jar" = pkgs.fetchurl {
            url = "https://cdn.modrinth.com/data/OhduvhIc/versions/G10nvigw/veinminer-fabric-2.12.2.jar";
            sha512 = "5e31863298a36579d2eb66981709b9eed79ca0157531b44f8178977c421668010d36ef445c003215c283eacc0f6b213e7b2970c83902540144aad8dffb240fc0";
          };
          "mods/repurposedstructures.jar" = pkgs.fetchurl {
            url = "https://cdn.modrinth.com/data/muf0XoRe/versions/fl0s2Ue2/repurposed_structures-7.8.2%2B26.3-fabric.jar";
            sha512 = "b6862c71f80f39898599bf5d172a3738ea477edada06096c5e79ebccf53c82cd23811ee96966e3a2603bab2e3955a5e3ceb3066ecaeae2547758d2c840079be9";
          };
          # 2026-09-28 §7 發現流水線新增(戰鬥/裝備分類補位)。Modrinth 顯示
          # LicenseRef-Custom,但 GitHub repo 自己的 license metadata 跟 LICENSE 檔案
          # 內容都是逐字 GPL-3.0,查過兩次——這是 Modrinth 分類標籤沒選準,不是真的閉源
          "mods/advancednetherite.jar" = pkgs.fetchurl {
            url = "https://cdn.modrinth.com/data/CFX9ftUJ/versions/Qxv1ndf9/advancednetherite-fabric-2.4.3-26.3.jar";
            sha512 = "fcf5f0b58b4c879fd4c05c3a33d5e9df002e17761f6a1d09a8d39befdd17dec6d7ac74f5f3a47d0eb01c20822607fe842aa08fcfbba957a0847ab98c560521e4";
          };
          "mods/farmersdelightrefabricated.jar" = pkgs.fetchurl {
            url = "https://cdn.modrinth.com/data/7vxePowz/versions/hTNvMewX/FarmersDelight-26.3-3.6.27%2Brefabricated.jar";
            sha512 = "d7c66b883e3c900a5539b2fec91c8a81d73ad438437151019843b958584f4c45bcb29581846056ff83787efea53fe0cd244106b4856a9979d7088eebba54da44";
          };
          "mods/rightclickharvest.jar" = pkgs.fetchurl {
            url = "https://cdn.modrinth.com/data/Cnejf5xM/versions/MTui9kST/rightclickharvest-fabric-4.6.2%2B26.3.x.jar";
            sha512 = "a08edf8b52ba4197df1befcf6288dbd4292fe86b19c7f076c4f7ebfebda29a5f1b23530436b45c113ebe6db53409fa654acac0cdc403948e82fba22bfb8769c9";
          };
          "mods/jamlib.jar" = pkgs.fetchurl {
            url = "https://cdn.modrinth.com/data/IYY9Siz8/versions/EbhilCj8/jamlib-fabric-2.3.1%2B26.3.x.jar";
            sha512 = "4b739c16dd771ceae4a8a2dbf24ebba47955d69cde994f9b1b2f075c41757c5bad4f90324fd9aa417d6b6490f6f9f0e39225a9d305c7ef49fb72824479ec2e24";
          };
          # 2026-09-28 §7 補位:合併經驗球實體減輕伺服器負擔,client_side/server_side
          # 皆為 optional,兩邊都裝才有實際效果(單裝客戶端不會減輕伺服器負擔)
          "mods/clumps.jar" = pkgs.fetchurl {
            url = "https://cdn.modrinth.com/data/Wnxd13zP/versions/J4I1wxJZ/Clumps-fabric-26.3-26.3.2.jar";
            sha512 = "8c166ae97e1999d0f213d0a181d6ef87b99648016c92c9aa1414d2c2e24364b12549569cd7e247a3d675df703ae6a8a88fc175d3f527818c710578408508c8ab";
          };
          # client_side/server_side 皆 optional,兩邊都裝才有完整的遠景 LOD 效果
          "mods/distanthorizons.jar" = pkgs.fetchurl {
            url = "https://cdn.modrinth.com/data/uCdwusMi/versions/gfi11b05/DistantHorizons-3.3.2-26.3-fabric-neoforge.jar";
            sha512 = "78a378d5ec117b330923015fe6517fcfabac3db464b3321d7a25b6e5d77dd11225c83b4707e83ac720507c5ac718a1639101332295a1c580413cf2498f472959";
          };
          "mods/visual-workbench.jar" = pkgs.fetchurl {
            url = "https://cdn.modrinth.com/data/kfqD1JRw/versions/rcsB2H1O/visualworkbench-v26.3.0-mc26.3.x%2Bfabric.jar";
            sha512 = "52006eaa57053a2f6cba75a0032a81d179f1a47cc4982e391ea5a380179b9b7aaf349afcd5ac3344dcd05e1b0e224f91cf6b1a1135698a7685f1321470966ad0";
          };
          # letmedespawn 的必要依賴,Modrinth 查無公開源碼連結(條件5 技術上不過,
          # 但標準條件4只要求依賴遞迴通過1-3,見標準本文——使用者知情後決定保留
          "mods/almanac.jar" = pkgs.fetchurl {
            url = "https://cdn.modrinth.com/data/Gi02250Z/versions/IRKkj8xt/almanac-fabric-26.2-1.26.9.1.jar";
            sha512 = "40d660a1645baacbfc8639549344433f5e96eca9cdaa9e0b60db0059eedec36f45d79433667a05ed157845c8d64bad59779d97150df6cd311bc0113c3c7e1ab0";
          };
          "mods/letmedespawn.jar" = pkgs.fetchurl {
            url = "https://cdn.modrinth.com/data/vE2FN5qn/versions/VC5LRxai/letmedespawn-fabric-26.3-1.26.9.2.jar";
            sha512 = "9870c2293d6c65341bf61fce49ca4d40f0a6c7c4dae51ad68c969c4ed7d3fa9750c8da585eb04fb1d5276e9ff7e31d42c4e6b0a3dc6368a3f5fd8fdefb3c7818";
          };

          # 2026-09-28 本部署選擇不用純資料包通道,改走 fabric mod 格式(見 minecraft.md)
          "mods/geophilic.jar" = pkgs.fetchurl {
            url = "https://cdn.modrinth.com/data/hl5OLM95/versions/5kFV8CEz/Geophilic%20v3.7.mod.jar";
            sha512 = "7731d6d7f85af0dc9eb232138b1dc1096f083d13a9f3e592b84f6c89a97cca0c642c68d5943e0e63bd35e93002708b945554991f519b754a04c6eec058305c19";
          };
          # 2026-09-28 §7 六渠道發現新增,完整通過/拒絕清單與集中度風險見 flake/hosts/oci/minecraft.md
          # -- 新增:效能/伺服器管理 --
          "mods/spark.jar" = pkgs.fetchurl {
            url = "https://cdn.modrinth.com/data/l6YH9Als/versions/e3hsPc1o/spark-1.10.187-fabric.jar";
            sha512 = "c74bf5d5a16b2445ec6ea717eac756412b272a8015e91f91a7bf5a27e6f2f99c4a11878d434510f941f37b0344b3a7d1ba0dd6c34e80642762c48fb6e9a93894";
          };
          "mods/servercore.jar" = pkgs.fetchurl {
            url = "https://cdn.modrinth.com/data/4WWQxlQP/versions/LCG1Bm84/servercore-fabric-1.5.20%2B26.3.jar";
            sha512 = "abe1f806ea587971faf7de826e18b07314a4a9e690f64a4c3a54e7f61c3e6f4792633b13a917252bd8de154cec39da6619110d83799cf533450c5b4cac7a8448";
          };
          "mods/krypton.jar" = pkgs.fetchurl {
            url = "https://cdn.modrinth.com/data/fQEb0iXm/versions/UugdIYJw/krypton-0.3.2.jar";
            sha512 = "d1d57ebd41395b75b01f130cd9503eb8d208212424a399ff9f367f50be8fbc1c6472442b33c686e777c3148f6a609520e8fb732c755157c358cb207fd4d1123a";
          };
          "mods/pickupnotifier.jar" = pkgs.fetchurl {
            url = "https://cdn.modrinth.com/data/ZX66K16c/versions/veV20ScD/pickupnotifier-v26.3.0-mc26.3.x%2Bfabric.jar";
            sha512 = "fbf854580d3a9cbc3a91ca4d2f806aeb53c594d03a3a4dc677b23ab602948da75bcbb9d4665c7840f046417881df6d885bcf77105978228c387bae18e0a1e09c";
          };
          "mods/easymagic.jar" = pkgs.fetchurl {
            url = "https://cdn.modrinth.com/data/9hx3AbJM/versions/JvKuwM5d/easymagic-v26.3.0-mc26.3.x%2Bfabric.jar";
            sha512 = "58406feb2c26393a27c722fa21462ca3a90c1bbdec65cd43c83d67a28c6aadd6cfd9f4c047e918365b1267690c9f005e8dddf964bd1dba891830dbdb340776bc";
          };
          "mods/fallingtree.jar" = pkgs.fetchurl {
            url = "https://cdn.modrinth.com/data/Fb4jn8m6/versions/AAGlDV9D/FallingTree-26.3-25.jar";
            sha512 = "07134826f6d6e01232cf4c96ba1ffc529b43d93be3c18a215ba3af8572282a6b04e3175f7dc5831471f6722ad4a4f9161d43203507617c3b6c43908c50e7ef21";
          };
          "mods/leavesbegone.jar" = pkgs.fetchurl {
            url = "https://cdn.modrinth.com/data/AVq17PqV/versions/Ttuy044k/leavesbegone-v26.3.0-mc26.3.x%2Bfabric.jar";
            sha512 = "8b9ac3bd8fb28cf4c1c06ec3d1f4c33b86993461e298fc4517e017518d22b0588fb4ac8a1daa8d6f8f6a74406bc69dcdbc8f39714d7b303d03bdd17e4336ccc2";
          };
          # 待觀察:光照引擎優化,基於 Starlight,可能跟 lithium 的光照相關優化重疊,
          # 沒實測過會不會衝突。唯一 build 是 alpha(查無 release),v1.9 規則下可接受
          "mods/scalablelux.jar" = pkgs.fetchurl {
            url = "https://cdn.modrinth.com/data/Ps1zyz6x/versions/g4eqNSKd/ScalableLux-fabric-mc26.3-0.3.0-alpha.0.6-all.jar";
            sha512 = "ded5a939fb20ab81c1f33b147ca9b98050773dbb28dff16df939c7d567b626809522994ec8dbfb99e7f498dc6a4e62f25e141a87d18efb43f73fc5ad1569ccc9";
          };
          "mods/fabric-carpet.jar" = pkgs.fetchurl {
            url = "https://cdn.modrinth.com/data/TQTTVgYE/versions/yt9oDFOj/fabric-carpet-26.3%2Bv260915.jar";
            sha512 = "7a479ba69eb5049cb94365d5044bd58c9f970c50b3484861fe3675f1917f7c99c1b1f50a5e01bdd9ded940d76a995539009a3656e05be2f513f20ec14de991a7";
          };

          # -- 新增:依賴函式庫 --
          "mods/moogs-structure-lib.jar" = pkgs.fetchurl {
            url = "https://cdn.modrinth.com/data/1oUDhxuy/versions/EYVYgogR/MoogsStructureLib-fabric-26.3-3.3.0.jar";
            sha512 = "647bf42f04d160e8f775ccaacc1bb6caa5f62211c925d7a1b061f33457a69e6d8019c41b7643247ad8a7dd26977bc830b455aba14216ac65f9195c992dbfb238";
          };
          "mods/prickle.jar" = pkgs.fetchurl {
            url = "https://cdn.modrinth.com/data/aaRl8GiW/versions/aPdekuq6/PrickleMC-fabric-MC26.3-26.3.0.2.jar";
            sha512 = "8ac58d09d441e6c88c39b3e1f069ae674959c991389e35b27fa1f3e3a18ea1424d095697751e5618dd296b4eb120fe622ada7cd2214fd6bcfb2cafe398f9bffb";
          };
          "mods/forge-config-api-port.jar" = pkgs.fetchurl {
            url = "https://cdn.modrinth.com/data/ohNO6lps/versions/JpKvrr9J/ForgeConfigAPIPort-v26.3.1-mc26.3.x-Fabric.jar";
            sha512 = "b9339c21e14beec2eae0ca215317284bcaacef72e1d1dee8b3dfbe2de0eefaa758a172446df85419b6534557c479abe972d7d21f4ec194f2d436f9ed4329cb9f";
          };

          # -- 新增:玩法/QoL mod(netherportalfix/kleeslabs/hardcore-revival/crafting-tweaks/
          # trashslot/inventory-essentials/forgiving-void 皆為 BlayTheNinth,見 minecraft.md 集中度風險) --
          "mods/netherportalfix.jar" = pkgs.fetchurl {
            url = "https://cdn.modrinth.com/data/nPZr02ET/versions/RC1fmH8z/netherportalfix-fabric-26.3-26.3.0.1.jar";
            sha512 = "3e30a398702f49e6336870951bc7d64a650a370190dbab058e927aeb6a3bf398947497ae8e1750a3b52cbcdf751d5d9b6a78896313d342d16cbe204613703bb1";
          };
          "mods/kleeslabs.jar" = pkgs.fetchurl {
            url = "https://cdn.modrinth.com/data/7uh75ruZ/versions/kob8aIog/kleeslabs-fabric-26.3-26.3.0.2.jar";
            sha512 = "1274cac1b05f029f244ed8cb229a9d0884637ea55b619dadeed66449946b287994a318090e69ff89270625a2d463057b538437f2917a7d39fd40b3de7f6aba41";
          };
          "mods/hardcore-revival.jar" = pkgs.fetchurl {
            url = "https://cdn.modrinth.com/data/HqKoXaXz/versions/9d4cslv4/hardcorerevival-fabric-26.3-26.3.0.1.jar";
            sha512 = "89df9da2716ef91234568123ab62bcc62f320956eb8355ea88e1eb5cbe317447b44e47c8a943a1735556b7e3a9a8a7b9989827d72f2b394c1cb9b776c1204638";
          };
          "mods/crafting-tweaks.jar" = pkgs.fetchurl {
            url = "https://cdn.modrinth.com/data/DMu0oBKf/versions/EYGdRTcA/craftingtweaks-fabric-26.3-26.3.0.1.jar";
            sha512 = "e980162e7a5c0e82f022e0b6a39ea289cab4e6e7c4bbaf726597e942f3b6521948214759ac8f5d34302bd67967f6bcb75271fc03d6ec9981d66f164a930a678f";
          };
          "mods/trashslot.jar" = pkgs.fetchurl {
            url = "https://cdn.modrinth.com/data/vRYk0bv7/versions/aq0EjIas/trashslot-fabric-26.3-26.3.0.1.jar";
            sha512 = "ccc3edbec11eb15bf6df1b7388b331328999a419a2068713d704865b17131f6911375593e2f835a9b278d8c13ecf8c007eae8344955c2676a669f598fb9010d2";
          };
          "mods/inventory-essentials.jar" = pkgs.fetchurl {
            url = "https://cdn.modrinth.com/data/Boon8xwi/versions/tc43r9Ra/inventoryessentials-fabric-26.3-26.3.0.3.jar";
            sha512 = "a1e363e67b9c8e5aa0b0251ee36a440e88202be1999b365b72022284d67b6d61d073462d224c9007f7a4dc58ce2cd104a5dcb325a2fc97763750bee13a4102d9";
          };
          "mods/forgiving-void.jar" = pkgs.fetchurl {
            url = "https://cdn.modrinth.com/data/1vkzEZjE/versions/OOJw6DaH/forgivingvoid-fabric-26.3-26.3.0.2.jar";
            sha512 = "a02c599ff4c59fc0f65bfbe29658a3c335d8daceb5698d4e1291503455aa75c2b7eaf8ddbdb853449ec504431c83fe4a771ee7fcdadbcd21127a41aaeeee6ee6";
          };
          "mods/appleskin.jar" = pkgs.fetchurl {
            url = "https://cdn.modrinth.com/data/EsAfCjCV/versions/PHjDtQay/appleskin-fabric-mc26.3-3.0.10.jar";
            sha512 = "17d257af419b7530aa8617c2e8c0e4bbfabcf888f26655790e0188e7957e0bcd931f85f9a4c69fd27e889dee5082cf7b2b8741a14a6ed4425e9ef4bfe13a8b8c";
          };
          "mods/attributefix.jar" = pkgs.fetchurl {
            url = "https://cdn.modrinth.com/data/lOOpEntO/versions/zJLURVLx/AttributeFix-fabric-MC26.3-26.3.0.1.jar";
            sha512 = "06658aee4c9943738663cb465ab0e68737c971d8544c2fd3e84aedb6a64a5f17949498492cafdacc9ba70185bae4e68d4825a390473c06eb8a3ed06bd983b202";
          };
          "mods/carry-on.jar" = pkgs.fetchurl {
            url = "https://cdn.modrinth.com/data/joEfVgkn/versions/6kJQXHUF/carryon-fabric-26.3-2.12.0.jar";
            sha512 = "92302e1815fe8b4d41517f001f667a348d4f1e5d0a07d9495b263076cd7a9a30183a0174d4f1a4d6b447161d9d68b08a649f48633583b5955dacd7736d5decc9";
          };
          "mods/toms-storage.jar" = pkgs.fetchurl {
            url = "https://cdn.modrinth.com/data/XZNI4Cpy/versions/znUwcb7Z/toms_storage_fabric-26.3-2.12.1.jar";
            sha512 = "1a66c99d8432678f28148e03b41358a697e96127c92464afb3272b704cb89e38c7063f6cf5ae0e4bb31d1d75eda2242472ce455a08152b7dccc7e6cefc9b739f";
          };
          "mods/travelers-backpack.jar" = pkgs.fetchurl {
            url = "https://cdn.modrinth.com/data/rlloIFEV/versions/5rC23dXQ/travelersbackpack-fabric-26.3-11.4.0.jar";
            sha512 = "6c98eddabd9ebe3a14387f5870302592bd8b176b3088a5378d986d129e9861cd1cd2b55c90b518039dbbc680d194fc6c56ca8223f804c56bc1e3050016f0e4e3";
          };
          "mods/lootr.jar" = pkgs.fetchurl {
            url = "https://cdn.modrinth.com/data/EltpO5cN/versions/gVwn7m2v/lootr-fabric-26.3-1.25.42.124.jar";
            sha512 = "290786fd4af4011c4f09c425d262bacc80f6ef47e23fbf6424193c719b6045a70cae70308c95d30c5ab78bf1f5a3d089cc3b01db8cc4dacc1a74c0f2d70c245d";
          };
          # client_side=required 但 client_side 端才有實際內容(潛影盒 tooltip),伺服器單裝
          # 邊際效益低,見 minecraft.md
          "mods/shulkerboxtooltip.jar" = pkgs.fetchurl {
            url = "https://cdn.modrinth.com/data/2M01OLQq/versions/Cj9VEeGt/shulkerboxtooltip-fabric-5.4.2%2B26.3.jar";
            sha512 = "737218bda3c35fe0753595e849850bb036eefd95181a542bdbdc8ab7c47795308be10b9aec45ca7880776c1711184536d0bf468fe76e94c674daac9ed73d8826";
          };

          # -- 結構 mod(非純資料包) --
          "mods/mes-moogs-end-structures.jar" = pkgs.fetchurl {
            url = "https://cdn.modrinth.com/data/r4PuRGfV/versions/S7bUhX4n/MoogsEndStructures-universal-1.21-2.1.1.jar";
            sha512 = "5732c98bf3d1e6aa3c76cf23db77301065dd96f060fb9bf85e8af00769bc6a93e213aad7ff79a3116b3cfd5015fe98437bdadf9fdc0dd829eae1759e3c1fee96";
          };
        };
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
          difficulty = "hard";
          gamemode = "survival";
          white-list = false;
          max-players = 10;
          view-distance = 12;
          simulation-distance = 8;
          spawn-protection = 0;
          online-mode = true;
          level-seed = "0";
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
        proxy_headers_hash_max_size 4096;
        proxy_headers_hash_bucket_size 256;

        # 一组不改变渲染/请求行为的安全头，http 层的 add_header 会被所有
        # server/location 自动继承——除非某个 vhost 自己也写了 add_header（那样父
        # 层级全部不继承，按层级整体替换而非按头名字合并），目前只有
        # cache.hydroakri.cc 是这种情况，那边单独复制了一份保持一致。
        # CSP/COEP/CORP/COOP/完整版 Permissions-Policy 没有加——会挡掉未加白名单的
        # 脚本/跨源请求/WebAuthn，这几个服务没法实测，不做。
        add_header X-Content-Type-Options nosniff always;
        add_header X-Frame-Options SAMEORIGIN always;
        add_header X-Permitted-Cross-Domain-Policies none always;
        add_header X-DNS-Prefetch-Control off always;
        add_header Referrer-Policy no-referrer always;
        # 不带 includeSubDomains——一旦被浏览器缓存很难撤销，会波及 *.hydroakri.cc
        # 下所有子域，不只是这几个已知在用的，先只做本域名的强制 HTTPS。
        add_header Strict-Transport-Security "max-age=31536000" always;

        # recommendedTlsSettings 不含 OCSP stapling，这里手动补上
        ssl_stapling on;
        ssl_stapling_verify on;
        resolver 1.1.1.1 8.8.8.8 valid=300s;
        resolver_timeout 5s;

        set_real_ip_from 127.0.0.1;
        set_real_ip_from ::1;
        real_ip_header CF-Connecting-IP;

        map $http_destination $webdav_dest {
            ~^https://(.*)$ http://$1;
            default $http_destination;
        }
      '';

      # headscale.hydroakri.cc/cache.hydroakri.cc 是仅有的两个直接绑 0.0.0.0、不
      # 走 cloudflared 的 vhost（真实公网 IP 直接暴露）。没有这个兜底的话，SNI/
      # Host 对不上任何已知域名的请求会落到文件里排第一个的 vhost 上（纯粹是声明
      # 顺序决定的，不是有意为之）。复用现成的 hydroakri.cc 泛域名证书，不用另生成
      # 一份自签证书。
      virtualHosts."catchall-default" = {
        default = true;
        serverName = "_";
        useACMEHost = "hydroakri.cc";
        forceSSL = true;
        locations."/" = {
          extraConfig = "return 444;";
        };
      };

      # services.ente.web 给这四个前端自带一条 add_header（CORS），会让它们不再
      # 继承上面的全局安全头（add_header 继承按层级整体替换，不按头名字合并）；
      # extraConfig 是 types.lines，下面这份是追加，不是覆盖。
      virtualHosts."ente-accounts.hydroakri.cc".locations."/".extraConfig = ''
        add_header X-Content-Type-Options nosniff always;
        add_header X-Frame-Options SAMEORIGIN always;
        add_header X-Permitted-Cross-Domain-Policies none always;
        add_header X-DNS-Prefetch-Control off always;
        add_header Referrer-Policy no-referrer always;
        add_header Strict-Transport-Security "max-age=31536000" always;
      '';
      virtualHosts."ente-cast.hydroakri.cc".locations."/".extraConfig = ''
        add_header X-Content-Type-Options nosniff always;
        add_header X-Frame-Options SAMEORIGIN always;
        add_header X-Permitted-Cross-Domain-Policies none always;
        add_header X-DNS-Prefetch-Control off always;
        add_header Referrer-Policy no-referrer always;
        add_header Strict-Transport-Security "max-age=31536000" always;
      '';
      virtualHosts."ente-photos.hydroakri.cc".locations."/".extraConfig = ''
        add_header X-Content-Type-Options nosniff always;
        add_header X-Frame-Options SAMEORIGIN always;
        add_header X-Permitted-Cross-Domain-Policies none always;
        add_header X-DNS-Prefetch-Control off always;
        add_header Referrer-Policy no-referrer always;
        add_header Strict-Transport-Security "max-age=31536000" always;
      '';
      virtualHosts."ente-albums.hydroakri.cc".locations."/".extraConfig = ''
        add_header X-Content-Type-Options nosniff always;
        add_header X-Frame-Options SAMEORIGIN always;
        add_header X-Permitted-Cross-Domain-Policies none always;
        add_header X-DNS-Prefetch-Control off always;
        add_header Referrer-Policy no-referrer always;
        add_header Strict-Transport-Security "max-age=31536000" always;
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

      virtualHosts."vault.hydroakri.cc" = {
        # enableACME = true;
        useACMEHost = "hydroakri.cc";
        acmeRoot = null;
        forceSSL = true;
        listenAddresses = [ "127.0.0.1" ];
        locations."/" = {
          proxyPass = "http://127.0.0.1:8222";
          proxyWebsockets = true;
        };
      };

      virtualHosts."map.hydroakri.cc" = {
        useACMEHost = "hydroakri.cc";
        forceSSL = true;
        listenAddresses = [ "127.0.0.1" ];
        locations."/" = {
          proxyPass = "http://127.0.0.1:3417";
          proxyWebsockets = true;
        };
      };

      virtualHosts."ente-photos.hydroakri.cc" = {
        useACMEHost = "hydroakri.cc"; # 已覆盖 *.hydroakri.cc，不用另开证书
        listenAddresses = [ "127.0.0.1" ];
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
            client_max_body_size 0;
          '';
        };
      };

      # Stalwart 自己的 /admin（建域名/DKIM/catch-all/建信箱用）；纯 HTTP(S)，
      # 走 cloudflared tunnel 藏起来，不像 SMTP/IMAP 那样必须直连真实 IP
      virtualHosts."stalwart.hydroakri.cc" = {
        useACMEHost = "hydroakri.cc";
        forceSSL = true;
        listenAddresses = [ "127.0.0.1" ];
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
        listenAddresses = [ "127.0.0.1" ];
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
        listenAddresses = [ "127.0.0.1" ];
        root = "${pkgs.it-tools}/lib";
        locations."/" = {
          index = "index.html";
          tryFiles = "$uri $uri/ /index.html";
          # 不要在这里加 add_header——会导致这个 location 不再继承全局
          # commonHttpConfig 那一整组（按层级整体覆盖，不是按头名字合并）。
        };
      };

      virtualHosts."dav.hydroakri.cc" = {
        useACMEHost = "hydroakri.cc";
        forceSSL = true;
        listenAddresses = [ "127.0.0.1" ];
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
        acmeRoot = null;
        forceSSL = true;
        # DNS-only 直连真实 IP（不走 cloudflared tunnel），见 headscale vhost 同理：
        # 大 NAR push 会撞 Cloudflare 代理的 100MB 请求体上限，直连绕开这个限制
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

            # 不做 proxy_cache：存储是本机磁盘，缓存只会缓存过期的 narinfo/cache-config，
            # 且缓存键不含 Authorization，私有缓存会对匿名请求可读。

            # 这个 vhost 自己写了 add_header，不会继承 commonHttpConfig 里的全局那份
            # （按层级整体替换，不按头名字合并），所以复制一份保持一致；
            # noindex/interest-cohort 是这个 vhost 才有的额外两条。
            add_header X-Content-Type-Options nosniff always;
            add_header X-Frame-Options SAMEORIGIN always;
            add_header X-Permitted-Cross-Domain-Policies none always;
            add_header X-DNS-Prefetch-Control off always;
            add_header Referrer-Policy no-referrer always;
            add_header Strict-Transport-Security "max-age=31536000" always;
            add_header Permissions-Policy "interest-cohort=()" always;
            add_header X-Robots-Tag "noindex, nofollow" always;
          '';
        };
      };

      virtualHosts."ntfy.hydroakri.cc" = {
        useACMEHost = "hydroakri.cc";
        acmeRoot = null;
        forceSSL = true;
        listenAddresses = [ "127.0.0.1" ];
        locations."/" = {
          proxyPass = "http://127.0.0.1:8084";
          proxyWebsockets = true;
          extraConfig = ''
            proxy_buffering off;
            proxy_request_buffering off;
          '';
          # Upgrade/Connection 头不用手写——proxyWebsockets = true 已经设置了
          # proxy_set_header Connection $connection_upgrade，只在真正带 Upgrade
          # 头的请求上才是 "upgrade"，其余请求是 "close"；手写死会导致所有普通
          # REST 请求也被发成 Connection: upgrade。
        };
      };

      virtualHosts."bsky.hydroakri.cc" = {
        useACMEHost = "bsky.hydroakri.cc";
        serverAliases = [ "*.bsky.hydroakri.cc" ]; # 为未来的 <user>.bsky.hydroakri.cc 账号 handle 预留
        forceSSL = true;
        listenAddresses = [ "127.0.0.1" ];
        locations."/" = {
          proxyPass = "http://127.0.0.1:3000";
          proxyWebsockets = true; # AT Proto firehose 是长连接 websocket
          # X-Forwarded-For/X-Forwarded-Proto/Host 不用手写——recommendedProxySettings
          # 在同一个 location 里会用相同的值再设一遍，手写的这几行会被覆盖，是死代码
          extraConfig = ''
            client_max_body_size 0;
          '';
        };
      };

      virtualHosts."uptime.hydroakri.cc" = {
        useACMEHost = "hydroakri.cc";
        forceSSL = true;
        listenAddresses = [ "127.0.0.1" ];
        locations."/" = {
          proxyPass = "http://127.0.0.1:3001";
          proxyWebsockets = true;
        };
      };

      # server_name，走 cloudflared tunnel（客户端 API，CDN 保护源站 IP）。
      # .well-known 把联邦指到 fed.hydroakri.cc:8448，见 services.matrix-synapse 旁边的注释
      virtualHosts."matrix.hydroakri.cc" = {
        useACMEHost = "hydroakri.cc";
        forceSSL = true;
        listenAddresses = [ "127.0.0.1" ];
        # 跟 element.hydroakri.cc 同理：这两个 location 自己写了 add_header，
        # 会丢掉全局安全头（按层级整体替换），复制一份保持一致
        locations."= /.well-known/matrix/server".extraConfig = ''
          default_type application/json;
          add_header X-Content-Type-Options nosniff always;
          add_header X-Frame-Options SAMEORIGIN always;
          add_header X-Permitted-Cross-Domain-Policies none always;
          add_header X-DNS-Prefetch-Control off always;
          add_header Referrer-Policy no-referrer always;
          add_header Strict-Transport-Security "max-age=31536000" always;
          add_header Access-Control-Allow-Origin *;
          return 200 '${builtins.toJSON { "m.server" = "fed.hydroakri.cc:8448"; }}';
        '';
        locations."= /.well-known/matrix/client".extraConfig = ''
          default_type application/json;
          add_header X-Content-Type-Options nosniff always;
          add_header X-Frame-Options SAMEORIGIN always;
          add_header X-Permitted-Cross-Domain-Policies none always;
          add_header X-DNS-Prefetch-Control off always;
          add_header Referrer-Policy no-referrer always;
          add_header Strict-Transport-Security "max-age=31536000" always;
          add_header Access-Control-Allow-Origin *;
          return 200 '${
            builtins.toJSON {
              "m.homeserver"."base_url" = "https://matrix.hydroakri.cc";
            }
          }';
        '';
        locations."/_matrix/client" = {
          proxyPass = "http://127.0.0.1:8008";
          extraConfig = ''
            client_max_body_size 50M;
            # Cloudflare tunnel 边缘长连接大约 100s 空闲超时，/sync 长轮询不能超过这个值
            proxy_read_timeout 95s;
          '';
        };
        locations."/_synapse/client" = {
          proxyPass = "http://127.0.0.1:8008";
        };
        # /_synapse/admin 故意不代理——管理接口只能在 oci 本机 curl 127.0.0.1:8008，见 README
        locations."/" = {
          extraConfig = "return 404;";
        };
      };

      # 联邦端口（8448），裸 TLS，Cloudflare/tunnel 都代理不了，直连真实公网 IP（灰云 A
      # 记录，跟 mail./headscale. 同样理由），只开 8448，不占 443
      virtualHosts."fed.hydroakri.cc" = {
        useACMEHost = "hydroakri.cc";
        acmeRoot = null;
        onlySSL = true; # 自定义 listen 绕过了 forceSSL/onlySSL 才会触发的证书自动挂载，必须手动开
        listen = [
          {
            addr = "0.0.0.0";
            port = 8448;
            ssl = true;
          }
        ];
        locations."/_matrix/federation" = {
          proxyPass = "http://127.0.0.1:8008";
          extraConfig = ''
            client_max_body_size 50M;
          '';
        };
        # 其它服务器联邦握手前先拿这个端点验证你的签名密钥，漏代理这条会导致对方连得上
        # TLS 但拿不到 key，join/联邦请求卡死（实测：之前这里没加，curl 直接从 nginx 收到
        # 404，根本没转发到 Synapse）
        locations."/_matrix/key" = {
          proxyPass = "http://127.0.0.1:8008";
        };
        locations."/" = {
          extraConfig = "return 404;";
        };
      };

      # Element Web 静态文件，走 cloudflared tunnel。config.json 在构建期已经注入
      # （见上方 nixpkgs.config.element-web.conf）。下面每个 location 自己又写了
      # add_header（设 Cache-Control），会导致这些 location 不再继承全局安全头
      # （按层级整体替换，不按头名字合并）——跟 ente-accounts/cache.hydroakri.cc
      # 同一个坑，复制一份保持一致。
      virtualHosts."element.hydroakri.cc" = {
        useACMEHost = "hydroakri.cc";
        forceSSL = true;
        listenAddresses = [ "127.0.0.1" ];
        root = pkgs.element-web;
        locations."/" = {
          tryFiles = "$uri $uri/ /index.html";
          extraConfig = ''
            add_header X-Content-Type-Options nosniff always;
            add_header X-Frame-Options SAMEORIGIN always;
            add_header X-Permitted-Cross-Domain-Policies none always;
            add_header X-DNS-Prefetch-Control off always;
            add_header Referrer-Policy no-referrer always;
            add_header Strict-Transport-Security "max-age=31536000" always;
            add_header Cache-Control "no-cache";
          '';
        };
        locations."/index.html".extraConfig = ''
          add_header X-Content-Type-Options nosniff always;
          add_header X-Frame-Options SAMEORIGIN always;
          add_header X-Permitted-Cross-Domain-Policies none always;
          add_header X-DNS-Prefetch-Control off always;
          add_header Referrer-Policy no-referrer always;
          add_header Strict-Transport-Security "max-age=31536000" always;
          add_header Cache-Control "no-cache";
        '';
        locations."/version".extraConfig = ''
          add_header X-Content-Type-Options nosniff always;
          add_header X-Frame-Options SAMEORIGIN always;
          add_header X-Permitted-Cross-Domain-Policies none always;
          add_header X-DNS-Prefetch-Control off always;
          add_header Referrer-Policy no-referrer always;
          add_header Strict-Transport-Security "max-age=31536000" always;
          add_header Cache-Control "no-cache";
        '';
        locations."/config.json".extraConfig = ''
          add_header X-Content-Type-Options nosniff always;
          add_header X-Frame-Options SAMEORIGIN always;
          add_header X-Permitted-Cross-Domain-Policies none always;
          add_header X-DNS-Prefetch-Control off always;
          add_header Referrer-Policy no-referrer always;
          add_header Strict-Transport-Security "max-age=31536000" always;
          add_header Cache-Control "no-cache";
        '';
        locations."/i18n/".extraConfig = ''
          add_header X-Content-Type-Options nosniff always;
          add_header X-Frame-Options SAMEORIGIN always;
          add_header X-Permitted-Cross-Domain-Policies none always;
          add_header X-DNS-Prefetch-Control off always;
          add_header Referrer-Policy no-referrer always;
          add_header Strict-Transport-Security "max-age=31536000" always;
          add_header Cache-Control "no-cache";
        '';
      };

    };

    systemd.tmpfiles.rules = [
      "d /var/lib/dav-storage 0750 nginx nginx -"
      # cscli machine add 启动时会读取 capi credentials 文件本身（不只是检查存不
      # 存在），空文件也能解析。先占位一个空文件，后面 cscli capi register 再把
      # 真实内容写进去覆盖——"f" 类型只在文件不存在时创建，不会覆盖已写好的内容
      "f /etc/crowdsec/online_api_credentials.yaml 0600 crowdsec crowdsec -"
    ];

    system.stateVersion = "25.11";
  };

}
