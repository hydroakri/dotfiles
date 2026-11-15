# rpi4 主機:未被 nix 管理的狀態

## miniflux-push-blocked(`rpi4-switch`)

oci 的 Miniflux 抓不到的訂閱(站點對數據中心 IP 做機器人檢測),改由 `rpi4-switch` 用家裡 WAN 出口抓,再用 Miniflux 的 `Import Entry` API(`POST /feeds/{id}/entries/import`)逐條推進 Miniflux 裡已有的同一個訂閱。腳本:`flake/hosts/rpi4/miniflux-push-blocked.py`,定時任務在 `rpi4-switch.nix`(每 30 分鐘)。

**首次設定,順序不能亂:**

1. Miniflux「設定 → API 金鑰」建一個金鑰
2. `sops flake/modules/features/secrets/rpi4.yaml`,加入 `miniflux_api_key: <金鑰>`(`.sops.yaml` 已有這個檔案的規則,收件人:`rpi4`、`hydroakri-new`、`nitrokey`)
3. `git add flake/modules/features/secrets/rpi4.yaml`。flake 只看得到 git 追蹤的檔案,缺這個檔案時 `rpi4-switch` 求值會失敗,CI 也會失敗,所以它要跟 nix 改動一起提交
4. `nh os switch -H rpi4-switch ./flake`
5. `systemctl start miniflux-push-blocked`,看 `journalctl -u miniflux-push-blocked`

**行為:**

- 腳本先試 `/v1/feeds/{id}/entries/import`,404 時退回不帶 `/v1` 的路徑(官方文檔寫的是不帶前綴),成功的前綴記在狀態檔裡
- 第一次運行時,發佈超過 7 天的文章以已讀匯入,其餘以未讀匯入;之後新文章都是未讀
- 狀態檔:`/var/lib/private/miniflux-push-blocked/state.json`(`DynamicUser` 的實際路徑),刪掉會重新匯入,Miniflux 對已存在的條目回 200,不會重複
- API 金鑰是整個 Miniflux 帳號的權限,不能縮小範圍;洩漏時在 Miniflux 設定裡撤銷

**加訂閱 / 維護:**

- `rpi4-switch.nix` 的 `ExecStart` 裡每個 `FEED_ID=URL` 對應一個 Miniflux 訂閱,`FEED_ID` 是 Miniflux 資料庫裡的 id(現在:14 = The Quietus,20 = iFixit News)。重建訂閱後要同步改
- 被推進來的訂閱本身在 Miniflux 裡仍會嘗試自己抓取並報錯;報錯不影響推送進來的條目是否可見這一點尚未驗證
