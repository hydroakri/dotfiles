# oci 主機:未被 nix 管理的狀態

`oci.nix` 只管得到系統設定本身。這份文件記錄**重新部署(全新安裝/災難復原)時需要手動處理**的東西——secrets 的實際值、Cloudflare/OCI 主控台裡的設定、Stalwart 存在資料庫裡的物件。日常 `nh os switch` 不需要看這份文件,只有重建/搬家才用得到。

## 1. Secrets(`flake/modules/features/secrets/secrets.yaml`)

`sops secrets.yaml` 補值。大部分隨便生一組強密碼/random string 就行(`openssl rand -base64 24`),下面只列**需要額外步驟才拿得到值**的:

| Secret                                                                    | 從哪拿                                                                                                                                                          |
| ------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `cf_oracle`                                                               | Cloudflare API Token,DNS 編輯權限,`hydroakri.cc` 這個 zone                                                                                                      |
| `r2_access_key_id` / `r2_secret_access_key` / `r2_endpoint` / `r2_bucket` | Cloudflare R2 → Manage API Tokens,**all-buckets** scope(webdav 備份 + vaultwarden restic 都靠這組)                                                              |
| `r2_bucket_attic`                                                         | R2 裡另一個獨立 bucket 的名稱(atticd 專用,見下方遷移步驟)                                                                                                       |
| `r2_bucket_ente`                                                          | R2 裡另一個獨立 bucket 的名稱(ente 的照片/影片/縮圖 blob 專用)                                                                                                  |
| `ente_key_encryption` / `ente_key_hash`                                   | 本機生成,32/64 bytes random,standard base64(`openssl rand -base64 32`,hash 用 64):**建第一個帳號後就不能換**                                                    |
| `ente_jwt_secret`                                                         | 本機生成,32 bytes random,但要 **URL-safe base64**(不是 standard!見下方第 7 節):`openssl rand -base64 32 \| tr '+/' '-_'`:**建第一個帳號後就不能換**             |
| `cloudflared_tunnel_credentials`                                          | `cloudflared tunnel create` 在本機產生的 `credentials.json` 原文(classic tunnel,tunnel ID:`901e5935-3f36-4609-9bb3-9a204bf7f79a`)                               |
| `oci_email_delivery_username` / `oci_email_delivery_password`             | OCI Console → Identity & Security → Users → 你的使用者 → Resources → SMTP credentials → Generate(同一組憑證 stalwart outbound relay 和 ente 登入驗證碼信都在用) |
| `pds_plc_rotation_key`                                                    | Bluesky PDS 官方文件的 keygen 流程                                                                                                                              |
| `warp_mdm`                                                                | Cloudflare Zero Trust WARP 的 MDM policy XML                                                                                                                    |
| `webdav_htpasswd`                                                         | `htpasswd -nb user pass` 產生(`apacheHttpd` 已在 `environment.systemPackages` 裡)                                                                               |

## 2. Cloudflare DNS

**走 cloudflared tunnel(CNAME → `901e5935-3f36-4609-9bb3-9a204bf7f79a.cfargotunnel.com`,橘雲代理)**:
`dav` `cache` `vault` `tools` `ente-photos` `ente-accounts` `ente-cast` `ente-albums` `ente-api` `stalwart` `mta-sts` `ntfy`,以及 `bsky`(+ `*.bsky` 手動保留,見 `oci.nix` 註解)

**直連真實 IP(A 記錄,灰雲/DNS-only,沒法走 tunnel)**:

- `mail.hydroakri.cc` → oci 公網 IP(`curl ifconfig.me` 現查)——SMTP/IMAP 不是 HTTP(S),tunnel 天生不支援
- `headscale.hydroakri.cc` → 同一個 oci 公網 IP——Cloudflare 會剝掉 POST 請求的 `Upgrade` 頭,TS2021 握手就是靠這個,搬去 tunnel 會導致節點全部掉線(headscale#3287,官方確認無解)。別手滑搬回 tunnel

**其他**:

- `hydroakri.cc` MX → `mail.hydroakri.cc`,優先度任意正整數
- `hydroakri.cc` TXT (SPF):`v=spf1 include:ap.rp.oracleemaildelivery.com -all`(硬失敗;唯一授權的寄信路徑就是這個 relay,沒有其他來源要顧慮)
- `stalwart._domainkey.hydroakri.cc` CNAME → OCI Email Domain 的 DKIM 設定產生的值(見下方 Stalwart 章節)
- `_mta-sts.hydroakri.cc` TXT:`v=STSv1; id=<改 oci.nix 里那份 policy 内容时要换新值,否则缓存旧 policy 的发信方不会重新抓取>`(目前 `oci.nix` 里的 policy `mode` 是 `enforce`)
- `_smtp._tls.hydroakri.cc` TXT:`v=TLSRPTv1; rua=mailto:tls-reports@hydroakri.cc`
- `_dmarc.hydroakri.cc` TXT:`p=quarantine`(舊 Cloudflare Email Routing 年代留下的,現在繼續沿用,不用動)
- **DNSSEC**:Cloudflare Dashboard → 這個 zone → DNS → 開關,domain 是在 CF 買的所以不用跨註冊商處理 DS 記錄,開了才能發布下面的 TLSA
- `_25._tcp.mail.hydroakri.cc` **TLSA**(DANE,usage 3 / selector 1 / matching-type 1):值是目前這張憑證公鑰的 SHA-256 hash,算法見下方指令。因為 `security.acme.certs."hydroakri.cc"` 設了 `extraLegoRenewFlags = [ "--reuse-key" ]`,續期只換憑證不換金鑰,**這條記錄理論上發布後永久有效,不用跟著憑證續期更新**——除非哪天手動改了這個 nix 選項或整組金鑰重新生成,才需要重算:
  ```bash
  openssl x509 -in /var/lib/acme/hydroakri.cc/cert.pem -noout -pubkey \
    | openssl pkey -pubin -outform DER \
    | openssl dgst -sha256 -binary \
    | xxd -p -c 32
  ```

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
6. **2FA/TOTP**:主信箱帳號(`me@hydroakri.cc`)跟 `admin`(fallback-admin)都各自在自己的帳號設定裡開,兩個要分開開,不共用

## 5. Ente 帳號(`https://ente-photos.hydroakri.cc`)

5 個子域名統一用 `ente-*` 前綴(`ente-photos`/`ente-accounts`/`ente-cast`/`ente-albums`/`ente-api`),不是裸的 `photos`/`accounts`/...。

沒有 PhotoPrism 那種部署時就設好的 admin 密碼——第一個真實帳號是上網頁走 email OTP 註冊出來的(驗證碼信走上面的 OCI Email Delivery SMTP)。想把某個帳號設成 instance admin,拿到該帳號的 user ID 後手動加 `services.ente.api.settings.internal.admin` 再重新部署。

**單人自架的收尾三步**(`internal.disable-registration = true` 已經寫進 `oci.nix` 了,⚠️ **部署前要先確認自己已經註冊完帳號**,不然會把自己也鎖在門外,要解封只能先改回 `false` 重新部署):

1. 查自己的數字 user id(不是 email,欄位叫 `user_id` 不是 `id`):`doas -u postgres psql ente -c "SELECT user_id, email FROM users;"`
2. 把這個數字加進 `oci.nix` 的 `services.ente.api.settings.internal.admin`,重新部署
3. 拉滿儲存空間走 `ente-cli`,不是 nix 配置:
   ```yaml
   # ~/.ente/config.yaml
   endpoint:
     api: https://ente-api.hydroakri.cc
   ```
   ```bash
   ente account add     # 登入剛註冊的帳號
   ente admin update-subscription -a <你的email> -u <你的email> --no-limit
   ```
   `--no-limit` 給到 100TB + 有效期 +100 年;這步依賴第 2 步的 admin 白名單先生效

**存儲走 Cloudflare R2**,不是本機磁碟——museum 只認 S3 協議,原本試過用 `rclone serve s3` 在本機起一個 S3-compatible endpoint 存本機磁碟,但 Ente 的上傳是客戶端(瀏覽器/手機)直接對著這個 endpoint 發 presigned URL 傳檔案、不經過 museum,綁 `127.0.0.1` 的話手機/瀏覽器根本連不到,等於得再開一個公開子域名 + nginx + tunnel 才能用,權衡下來不如直接用本來就全球可連的 R2(見上方 `r2_bucket_ente`)。

**`ente` 這個 postgres 資料庫有 restic 備份(`restic-backups-ente-db.timer`,05:30)**,存的是 E2EE 主密鑰/單檔案密鑰這類加密後的金鑰材料——不是密碼/recovery key 算得出來的,資料庫丟了 R2 裡的照片就永久解不開,跟 atticd 那種可重建 cache 完全不是一回事,還原步驟見下方第 6 節。

## 6. R2 資料復原(災難復原情境用,平時不用管)

- **atticd**:全新 bucket 用 Cloudflare R2 的 **Data Migration** 功能從舊資料搬,或直接讓它冷啟動重建(binary cache 本來就是可重建的衍生資料,不算真正的資料遺失)
- **webdav 本地資料**(`/var/lib/dav-storage`):`rclone copy r2:$R2_BUCKET_NAME/webdav-backup /var/lib/dav-storage -P`
- **vaultwarden**:`sudo restic-vaultwarden restore latest --target /var/lib/vaultwarden-restore`,restic 密碼是 `restic_vaultwarden_password`,丟了就真的救不回來
- **Stalwart 邮件**:`sudo restic-stalwart-mail restore latest --target /var/lib/stalwart-mail-restore`,restic 密碼是 `restic_stalwart_password`
- **Bluesky PDS**:`sudo restic-bluesky-pds restore latest --target /var/lib/pds-restore`,restic 密碼是 `restic_pds_password`,連同帳號金鑰(PLC rotation key)一起在裡面,丟了等於丟了 handle 的控制權
- **ente 資料庫**(全新機器/災難復原情境,順序很重要):
  1. `nh os switch` 部署完後**先 `doas systemctl stop ente`**——`enableLocalDB` 會在全新部署時自動建一個空 `ente` db,museum 一啟動就會在裡面跑 migration 建表,之後灌真實資料會撞 "relation already exists"
  2. `doas -u postgres dropdb ente && doas -u postgres createdb ente`(確保是真正空的)
  3. `doas restic-ente-db restore latest --target /var/lib/ente-db-restore`,restic 密碼是 `restic_ente_password`
  4. `doas -u postgres psql ente < /var/lib/ente-db-restore/var/lib/ente-db-backup/ente.sql` 灌回去
  5. 確認灌回去沒報錯,才 `doas systemctl start ente`
  - ⚠️ **`ente_key_encryption`/`ente_key_hash`/`ente_jwt_secret` 絕對不能重新生成**——用 sops 裡原本那份原封不動的值重新部署,這三個「建號後就不能換」,換了資料庫裡靠這幾把 key 保護的資料全部對不上
  - 這份資料庫存的是 E2EE 加密金鑰材料,丟了 R2 裡的照片全部解不開,比 R2 blob 本身更關鍵,見上方第 5 節
  - R2 blob(`r2_bucket_ente`)本身不用搬,新機器用 sops 裡同一組 R2 憑證/bucket 名稱接上去就是同一批檔案;cloudflared tunnel 同理,`cloudflared_tunnel_credentials` 從 sops 帶過去,DNS(CNAME 指向 tunnel ID,不是機器 IP)完全不用動

## 7. 已知的坑,重新部署時會再踩一次

- `services.stalwart` 之類模組的預設使用者名/資料目錄名字跟 `stateVersion` 掛鉤(見 `oci.nix` 裡對應註解),第一次部署遇到 assertion 失敗多半是這個
- ente 的 `_secret` 是 museum preStart 自己讀檔案(非 root),不是走 systemd LoadCredential——所有餵給 `services.ente.api.settings.*._secret` 的 sops secret 都要設 `owner = "ente"`,不然 `/run/secrets/<name>` 預設 root:root 0400 讀不到,`ente.service` 起不來
- `services.ente.api.nginx.enable` 那個模組自帶的 nginx 集成把 upstream 寫死在 `localhost:8080`,跟 `services.stalwart` 的 JMAP/webadmin(`127.0.0.1:8080`)撞——已經關掉這個集成,museum 自己改監聽 `settings.http.port = 8082`,nginx vhost 手動寫
- `jwt.secret` 這個 key museum 要求 **URL-safe base64**(`base64.URLEncoding`,`-`/`_` 不是 `+`/`/`),`key.encryption`/`key.hash` 才是一般 standard base64——`openssl rand -base64` 產出的是 standard,直接餵給 `jwt.secret` 有機率(產出的隨機值剛好含 `+`或`/`)炸出 `Could not decode jwt-secret: illegal base64 data`。生成 `jwt.secret` 要用:
  ```bash
  openssl rand -base64 32 | tr '+/' '-_'
  ```
- `services.ente.api.settings.smtp.encryption = "tls"`(或 `"ssl"`)在 museum 裡是**隱式 TLS**(`tls.Dial` 直接握手),只適合 465 這種端口;OCI Email Delivery 的 587 是 **STARTTLS**(先明文再升級),`encryption` 要留空(museum 沒設就走 `net/smtp.SendMail`,自動談 STARTTLS)——設成 `"tls"` 配 587 會炸 `tls: first record does not look like a TLS handshake`
- sops-nix 的 secrets 渲染路徑是 `/run/secrets/<name>`,template 是 `/run/secrets/rendered/<name>`,兩個不一樣,不要搞混
- `s3.b2-eu-cen` 這個 key 名字是 museum 寫死要找的(跟實際接的是不是 Backblaze B2 無關,改別的名字它認不到),我們接的其實是 R2,別被名字誤導去改
- Ente 的上傳是客戶端(瀏覽器/手機)直接對著 `s3.b2-eu-cen.endpoint` 發 presigned URL 傳檔案,museum 只負責發 URL、不經手內容——這個地址**必須是客戶端連得到的**,不能是只有伺服器自己連得到的內部地址(這也是這裡直接用 R2、不用本機 S3 endpoint 的原因,見上方)
