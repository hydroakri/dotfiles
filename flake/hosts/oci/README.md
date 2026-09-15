# oci 主機:未被 nix 管理的狀態

`oci.nix` 只管得到系統設定本身。這份文件記錄**重新部署(全新安裝/災難復原)時需要手動處理**的東西——secrets 的實際值、Cloudflare/OCI 主控台裡的設定、Stalwart 存在資料庫裡的物件。日常 `nh os switch` 不需要看這份文件,只有重建/搬家才用得到。

## 1. Secrets(`flake/modules/features/secrets/secrets.yaml`)

`sops secrets.yaml` 補值。大部分隨便生一組強密碼/random string 就行(`openssl rand -base64 24`),下面只列**需要額外步驟才拿得到值**的:

| Secret | 從哪拿 |
|---|---|
| `cf_oracle` | Cloudflare API Token,DNS 編輯權限,`hydroakri.cc` 這個 zone |
| `r2_access_key_id` / `r2_secret_access_key` / `r2_endpoint` / `r2_bucket` | Cloudflare R2 → Manage API Tokens,**all-buckets** scope(webdav 備份 + vaultwarden restic 都靠這組) |
| `r2_bucket_attic` | R2 裡另一個獨立 bucket 的名稱(atticd 專用,見下方遷移步驟) |
| `cloudflared_tunnel_credentials` | `cloudflared tunnel create` 在本機產生的 `credentials.json` 原文(classic tunnel,tunnel ID:`901e5935-3f36-4609-9bb3-9a204bf7f79a`) |
| `oci_email_delivery_username` / `oci_email_delivery_password` | OCI Console → Identity & Security → Users → 你的使用者 → Resources → SMTP credentials → Generate |
| `pds_plc_rotation_key` | Bluesky PDS 官方文件的 keygen 流程 |
| `warp_mdm` | Cloudflare Zero Trust WARP 的 MDM policy XML |
| `webdav_htpasswd` | `htpasswd -nb user pass` 產生(`apacheHttpd` 已在 `environment.systemPackages` 裡) |

## 2. Cloudflare DNS

**走 cloudflared tunnel(CNAME → `901e5935-3f36-4609-9bb3-9a204bf7f79a.cfargotunnel.com`,橘雲代理)**:
`dav` `cache` `vault` `tools` `searx` `headscale` `pad`(+`pad-sandbox`)`photos` `stalwart` `mta-sts`,以及 `bsky`(+ `*.bsky` 手動保留,見 `oci.nix` 註解)

**直連真實 IP(A 記錄,灰雲/DNS-only,SMTP/IMAP 沒法走 tunnel)**:
`mail.hydroakri.cc` → oci 公網 IP(`curl ifconfig.me` 現查)

**其他**:
- `hydroakri.cc` MX → `mail.hydroakri.cc`,優先度任意正整數
- `hydroakri.cc` TXT (SPF):`v=spf1 include:ap.rp.oracleemaildelivery.com ~all`
- `stalwart._domainkey.hydroakri.cc` CNAME → OCI Email Domain 的 DKIM 設定產生的值(見下方 Stalwart 章節)
- `_mta-sts.hydroakri.cc` TXT:`v=STSv1; id=<改 policy 內容時要换新值>`
- `_smtp._tls.hydroakri.cc` TXT:`v=TLSRPTv1; rua=mailto:tls-reports@hydroakri.cc`
- `_dmarc.hydroakri.cc` TXT:`p=quarantine`(舊 Cloudflare Email Routing 年代留下的,現在繼續沿用,不用動)

## 3. OCI Email Delivery 主控台

Developer Services → Email Delivery:
1. **Email Domains** → 建 `hydroakri.cc` → DKIM 分頁 → Add DKIM(selector `stalwart`)→ 拿到 CNAME 值填進 DNS → 用 SPF/DKIM verification 確認狀態變 **Active**
2. **Approved Senders** → 建 `me@hydroakri.cc`(或實際用的寄件地址)
3. Identity & Security → Users → SMTP credentials → 生成憑證(見上方 secrets 表格)
4. Configuration 分頁確認實際 region SMTP endpoint(目前是 `smtp.email.ap-singapore-2.oci.oraclecloud.com:587`,不同 region 不一樣,別照抄)

## 4. Stalwart `/admin`(`https://stalwart.hydroakri.cc`,fallback-admin 登入)

**這些是資料庫物件,不受 nix 管,寫在 TOML 裡也不會生效**(實測過:`mta.route` 寫在 nix 裡會被資料庫同名 key 覆蓋,報 `Gateway not found`):

1. **Domain**:建 `hydroakri.cc`
2. **Account**:建主信箱(例如 `me@hydroakri.cc`)+ 密碼
3. **Catch-all**:domain 設定裡指向主信箱(讓舊的 `隨機字符@hydroakri.cc` 轉發地址繼續有效)
4. **Outbound → Routes**:建一條 relay route,名稱 `oci-email-delivery`,address/port/帳密用上方 OCI Email Delivery 那組
5. **Outbound → Strategy → Routing**:預設值(else,沒有條件框的那個)從 `'mx'` 改成 `'oci-email-delivery'`,讓非本機網域一律走 relay,不然會直接撞 OCI 封鎖的 outbound port 25

## 5. R2 資料復原(災難復原情境用,平時不用管)

- **atticd**:全新 bucket 用 Cloudflare R2 的 **Data Migration** 功能從舊資料搬,或直接讓它冷啟動重建(binary cache 本來就是可重建的衍生資料,不算真正的資料遺失)
- **webdav 本地資料**(`/var/lib/dav-storage`):`rclone copy r2:$R2_BUCKET_NAME/webdav-backup /var/lib/dav-storage -P`
- **vaultwarden**:`sudo restic-vaultwarden restore latest --target /var/lib/vaultwarden-restore`,restic 密碼是 `restic_vaultwarden_password`,丟了就真的救不回來

## 6. 已知的坑,重新部署時會再踩一次

- `services.stalwart`/`services.photoprism` 之類模組的預設使用者名/資料目錄名字跟 `stateVersion` 掛鉤(見 `oci.nix` 裡對應註解),第一次部署遇到 assertion 失敗多半是這個
- sops-nix 的 secrets 渲染路徑是 `/run/secrets/<name>`,template 是 `/run/secrets/rendered/<name>`,兩個不一樣,不要搞混
