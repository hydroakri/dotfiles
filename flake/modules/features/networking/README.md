# sing-box (`proxy.nix`)

设置权衡记录。域名分类以 MetaCubeX/meta-rules-dat 的 geosite 列表为准；顺序相关的设置见对应表格的"顺序"列，first-match-wins。

## 模块开关

| 设置 | Tradeoff |
|---|---|
| `modules.proxy.singbox.enable` | 启用 sing-box 作为代理后端。 |
| `modules.proxy.singbox.tun` | 启用系统级 TUN 接管（`dns_mode=hijack`），而非仅本地 SOCKS/HTTP 代理(`mixed-in`)。TUN 关闭时，未显式配置走 `127.0.0.1:1080` 的应用不受任何分流规则影响，直接裸连——这是有意的降级路径，不是缺陷。 |
| `boot.kernel.sysctl` rp_filter | TUN/dae 需要放松 `net.ipv4.conf.*.rp_filter` 到 `2`（loose）以支持非对称路由（如游戏 UDP）；用 `mkOverride 900` 显式盖过 `security.nix` 的 `mkOverride 950`（数字越小优先级越高）。 |

## HTTP 客户端 (`http_clients`)

| 设置 | Tradeoff |
|---|---|
| `spoofed-http`（utls=firefox，伪造 UA/Accept-Language） | 作为 `default_http_client` 和 `external_ui_download_url` 的下载客户端，避免面板/规则集更新请求暴露 sing-box 默认指纹。`detour=direct`——下载行为本身不需要走分流判断。 |

## DNS 服务器 (`dns.servers`)

| Tag | 类型/上游 | Tradeoff |
|---|---|---|
| `fakeip` | `198.18.0.0/15` + `64:ff9b:1::/48` | 已分类域名（境内境外皆可）优先命中，DNS 阶段零查询，真实 IP 推迟到拨号时由 outbound 的 `domain_resolver` 解析。 |
| `dns-system` | `type=local` | 仅服务 mDNS 探测域名和内网后缀（`wlan`/`intranet`/`private`/`domain`/`home`/`host`/`corp`/`geosite-private`），不是通用兜底——在这台机器上 `type=local` 不经过 unbound/dnscrypt-proxy/RPZ 管道，走网卡分配的 DNS，只把它限制在本就该走本地网络解析的窄范围内。 |
| `dns-mdns` | mDNS | 局域网设备发现优先命中。 |
| `dns-alidns` | h3，`detour=🚦 cn` | `🇨🇳 direct-cn` outbound 的 `domain_resolver`——已知国内域名走 fakeip 后，真正解析用这个而非中立的 `dns-zerotrust`。选它而非 `dns-flymc` 是因为阿里 DNS 在境外的 CDN 调度表现也更好，不只是境内优化。 |
| `dns-flymc` | h3，`detour=🚦 cn`，无 utls | 用于 `match_response` 阶段对已确认 `geoip-cn` 的响应做二次查询，拿国内优化结果。QUIC/h3 传输与 utls 不兼容，DNS 类 h3 server 均不加 utls。 |
| `dns-zerotrust` | h3，无 detour，`server_name` 走 `_secret` | 中立探测服务器：`➡️ direct`/多数 selector 的默认 `domain_resolver`，也是 `evaluate` 阶段对未分类域名探测真实 IP 的查询目标。 |
| `dns-quad9` | h3，`detour=🚦 oversea` | `dns.final` 兜底，以及 `route.default_domain_resolver`——WireGuard 出站解析域名走这个，不经过 `dns.rules` 匹配链（sing-box 硬约束：该字段只能指定单一 server，无法用 `evaluate`/`race` 竞速）。 |

## DNS 规则 (`dns.rules`，顺序敏感)

| 顺序 | 规则 | Tradeoff |
|---|---|---|
| 1 | `adblock-dns` → reject | 广告域名在 DNS 阶段直接拒绝，不进入任何 outbound 判断。 |
| 2 | mDNS 域名 → `dns-mdns` | `preferred_by` 触发本地发现协议特化处理。 |
| 3 | 内网关键词/后缀/`geosite-private` → `dns-system` | 局域网/内网域名走网卡分配 DNS，不进 fakeip/探测管道。**排在顺序 4 前面是必须的**——`fakeip-filter.srs`（见下）里的 `+.msftconnecttest.com`/`+.msftncsi.com`/`+.linksys.com`/`+.linksyssmartwifi.com` 跟这条的 `domain_keyword` 逐字重复，顺序反了会导致这几个连通性检测/路由器域名从 `dns-system` 改判给 `dns-quad9`——msftconnecttest/msftncsi 这类强制门户检测域名本该看本地网络的真实返回（可能被门户劫持成跳转页），用加密解析器给出诚实答案反而让检测失灵。 |
| 4 | `fakeip-filter` + `geosite-discord` → `dns-quad9` | 跳过 fakeip 直接吐真实 IP——STUN/主机游戏 NAT 探测/语音服务这几类协议要么拿"连接到的地址"本身做 NAT 类型探测/打洞，要么对往返时间戳敏感，命中 fakeip 不是分流不准，是直接连不上。`fakeip-filter`（`DustinWin/ruleset_geodata@sing-box-ruleset`）是这个用途社区里最权威、被抄得最多的列表——上游其实是 `ShellCrash/public/fake_ip_filter.list`，交叉核对过十几份"独立维护"的同类列表，内容逐条一致，说明都是抄自这份或更早的共同祖先，不是各自调研的结果。它覆盖 PlayStation/Xbox/Nintendo/Battle.net NAT 探测、NTP、英雄联盟语音、WiFi 通话（VoWiFi）等，比自己手工点名全面得多。**代价**：它的 STUN 覆盖用 `+.stun.*.*` 这类通配写法——任意网页只要把 WebRTC 探测指向一个带 `stun.` 字样的域名就会被放真实 IP，达不到"只放行可信服务"的精确效果；但查过整个社区（包括最大的分流规则项目 blackmatrix7/ios_rule_script，它反而没有 fakeip-filter 这个文件），没有任何一份列表在这一点上做得更精确——这是主流工具链一致接受的功能优先取舍，不是这里漏做了什么。列表里还混了一些跟这个机制无关但无害的国内 App 域名（网易云音乐、微信登录、招商银行等，这份配置的使用场景用不上，但都是固定域名不会被第三方利用，留着不影响安全）。`geosite-discord` 单独保留——`fakeip-filter` 没收录 Discord 专属媒体中继域名 `discord.media`；核对过 Zoom/Webex/Slack/WhatsApp/Signal 的 geosite 分类，都没有类似的独立媒体域名，大概率是中继地址由各自 API 响应直接下发字面量 IP、不经过客户端本地 DNS 解析，fakeip 机制对它们根本不适用，不是遗漏。IoT 云 API 类仍然没有可信通用清单，见下方已知空白表。 |
| 5 | `tld-cn`/`geolocation-cn`/`cn`/`gfw`/`geolocation-!cn` + `🚦 i18n-service`/`🚦 finance`/`🚦 webrtc-bt-proxy`/`🚦 tailscale-out`/`game-platforms-download`（硬编码 direct）用到的全部域名类 `rule_set`（ai-chat-!cn/media/entertainment/emby/social-media-!cn/apple@cn/finance/cryptocurrency/ecommerce/category-pt/category-public-tracker/category-game-platforms-download/tailscale） → `fakeip` | 已分类域名跳过下面的探测，省一次往返。覆盖范围不止境内境外判断——`route.rules` 里这些规则的路由结果全靠 `rule_set` 域名匹配决定、且排在 `geoip-cn` 之前，真实 IP 对路由判断毫无意义，不管出站是走 selector 还是硬编码，都能省掉探测那次往返。未被这些列表覆盖的域名才进入下一步。`🚦 tailscale-out` 规则里 oracle 域名/IP 走的是 `_secret` 模板而非 `rule_set`，没有一并纳入——单独一个 secret 域名要塞进这条规则得改成 `rule_set`+`domain` 的逻辑或结构，为一个低频域名换来的收益太小，没做。 |
| 6 | `evaluate` action，`dns-zerotrust`，`disable_optimistic_cache=true` | `evaluate` 本身不路由——它只查询并挂起一个响应，不直接返回给客户端；后面带 `match_response=true` 的规则才检查这个挂起响应的内容并决定去向。这里用它探测未分类域名的真实 IP，供下一步 GeoIP 判断。 |
| 7 | `geoip-cn` + `match_response=true` → `dns-flymc` | 挂起的响应经 GeoIP 判断是国内 IP 时，改用 `dns-flymc` 重新查询换取国内优化响应。 |
| 8 | `match_response` + `NXDOMAIN`/`SERVFAIL` → respond | 挂起响应本身是失败结果时直接透传，不再往下走。 |
| 9（`final` 前的最后一条） | 兜底 → `fakeip` | 挂起响应是境外真实 IP（未命中顺序 7/8 任一分支）时也走到这里：不直接把探测到的真实 IP 返回给客户端，仍然统一返回 fakeip。fakeip 是几乎所有查询的最终归宿，不只是顺序 5 已分类域名的特例——真实 IP 只在拨号那一刻由 outbound 的 `domain_resolver` 按需解析，DNS 响应本身永远不直接暴露真实境外 IP。 |

`dns.final = dns-quad9`；`strategy = prefer_ipv4`；`cache_capacity = 4096`；`optimistic = true`；`store_fakeip`/`store_dns` 持久化在 `cache_file`。`selector` 的当前选中状态也会自动持久化——`store_selected` 从 sing-box 1.8.0 起废弃，行为改成只要 `cache_file.enabled=true`（本配置一直是）就默认持久化，不需要也不能再单独配置这个字段；手动经 Clash API 选过一次之后，重启不会丢。

## 入站 (`inbounds`)

| 设置 | Tradeoff |
|---|---|
| `mixed-in`，`127.0.0.1:1080` | 始终开启，供显式配置走本地代理的应用使用，不受 `tun` 开关影响。 |
| `tun-in`（`modules.proxy.singbox.tun=true` 时） | `dns_mode=hijack`+`auto_route`+`auto_redirect`+`strict_route` 系统级接管；`route_exclude_address_set=[geoip-private]` 排除内网网段；`exclude_uid_range` 放行 root/unbound/dnscrypt-proxy/tor 自身进程的对外连接，避免这些进程的流量被 tun 递归接管形成回路。`mtu=1280`——低于常见的 1500，代价是包头开销占比更高、大流量吞吐略降；换来的是这条 tun 是双栈（同时配置了 IPv4/IPv6 地址），1280 是 IPv6 规定的最小链路 MTU（RFC 8200），用它能保证隧道内部不需要对 IPv6 包做二次分片，不用去猜某个出站封装（WireGuard/Reality 等）还会再叠多少层开销。 |

## 出站与分组 (`outbounds`)

### 叶子出站

| Tag | Tradeoff |
|---|---|
| `🚫 block` | 硬拒绝。 |
| `➡️ direct` | 通用直连，`domain_resolver=dns-zerotrust`（中立解析）。 |
| `🇨🇳 direct-cn` | 国内优化直连，`domain_resolver=dns-alidns`；`🚦 cn` 分组的默认候选。 |
| `🔒 zerotrust` | 本地 SOCKS5(`127.0.0.1:40000`)，`network=tcp`——本地 SOCKS5 不支持 UDP ASSOCIATE，显式禁掉避免静默丢包。 |
| `🧅 tor` | 本地 SOCKS5(`127.0.0.1:9050`)，`network=tcp`——Tor 协议本身不支持 UDP。 |

### 分组 selector

判断一个分类要不要单独占一个 selector（而非直接并入 `🚦 oversea`），看它是否落在下面三条轴之一；不落在任何一条轴上的内容不建 selector，直接走通用兜底或写死。

| 轴 | 含义 |
|---|---|
| 身份/地区轴 | 该内容是否在意出口 IP 的地区/身份属性；`换区`(想主动切换)和`风控`(必须固定不切)是这条轴的两端。 |
| 节点能力轴 | 该流量是否需要出口节点支持特定协议/策略。 |
| 性能/延迟轴 | 该流量是否需要低延迟/稳定 UDP。目前**没有对应 selector**——已识别但未处理，接受默认行为的风险。 |

| Tag | 归类 | 候选顺序 | Tradeoff |
|---|---|---|---|
| `🚦 cn` | 基线（境内） | `🇨🇳 direct-cn` → `🎯 isp` → `🎯 proxy` → `🎯 manual` → `🚫 block` | 域名分类为境内的兜底出口。 |
| `🚦 oversea` | 基线（境外，无独立诉求） | `➡️ direct` → `🎯 isp` → `🎯 proxy` → `🎯 manual` → `🚫 block` | 通用海外内容兜底，不含下面两个分组各自的独立诉求。 |
| `🚦 i18n-service` | 身份/地区轴 · 换区需求 | `🎯 isp` → `➡️ direct` → `🎯 manual` → `🚫 block` | 覆盖 ai-chat/media/entertainment/emby/social-media + `apple@cn`。旗舰域名（twitter/youtube/facebook/instagram/netflix/google 等）多数在 `gfw.list` 内，境内默认无法直连；境外则是直连可用、换区内容库时才需要代理。`apple@cn` 域名（App Store 区域内容相关的共用 CDN 边缘域名）在境内/境外两份 geosite 列表里都覆盖率极低，靠域名本身分不出中外，一并纳入此组显式管理。候选顺序把 `🎯 isp` 排第一——selector 选中状态本身会随 `cache_file` 自动持久化（见 DNS 规则表下方说明），手动选过之后重启不会丢，这个顺序只影响两种场景：从未手动选过（首次启动/清了 `cache.db`）时的默认值，以及该组内容多数需要代理才能连通，此时让 `➡️ direct` 排第一会导致默认值直接失效。 |
| `🚦 finance` | 身份/地区轴 · 风控需求 | `➡️ direct` → `🎯 isp` → `🎯 proxy` → `🎯 manual` → `🚫 block` | 覆盖国际银行/券商/加密货币/电商。默认直连——异地 IP 触发风控（异地登录/资金冻结）是真实成本，不是可简化的认知负荷问题；候选顺序保留 `➡️ direct` 优先。仅作为应对极端场景（境内 IP 被制裁式封锁）的手动开关存在。真正被 `gfw.list` 确认封锁的部分（该分类里占比个位数到十几个百分点）已经在 `route.rules` 里被排在这个分组判断之前的专门规则接住，不会落到这里默认直连失败。 |
| `🚦 webrtc-bt-proxy` | 节点能力轴 | `➡️ direct` → `🎯 isp` → `🎯 proxy` → `🎯 manual` → `🚫 block` | BT/PT/STUN 流量需要出口节点明确支持/不限速 P2P，与地区、风控无关，独立管理避免被通用海外节点的 ToS 限制。 |
| `🎯 isp` / `🎯 proxy` / `🎯 manual` | 叶子池 | 各自候选见 Nix 源码 | 供上面几个 `🚦` 分组间接引用的实际出口候选池；`isp` 不含 `🧅 tor`，`proxy` 含 `🧅 tor`，`manual` 额外含 `➡️ direct`（供纯手动指定场景使用）。 |
| `🚦 tailscale-out` | 自有基础设施，不适用上述三轴 | `➡️ direct` → `🎯 isp` → `🎯 proxy` → `🎯 manual` | 到达 Tailscale 协调域名/`oracle` 主机公网身份的路径选择；`tailscale-in`（`100.64.0.0/10`/`fd7a:...`）本身没有 selector，因为那段地址只能经 Tailscale-aware 出站到达，没有替代路径。 |

## 路由规则 (`route.rules`，顺序敏感，first-match-wins)

| 顺序 | 规则 | 去向 | Tradeoff |
|---|---|---|---|
| 1 | `sniff` | — | 对 `tun-in`(如启用)/`mixed-in` 做协议嗅探，300ms 超时；即使连接方自行做了 DNS 解析（如浏览器走 DoH 绕过下面的 `hijack-dns`），只要是 TLS 连接仍可从 ClientHello 的 SNI 恢复域名，用于后续按域名分类；HTTP/TLS 之外、且未经过 sing-box DNS 解析的连接无法恢复域名，只能落到 IP-based 规则（`geoip-cn`/`bypass`）。 |
| 2 | port 53 / protocol dns | hijack-dns | 拦截传统 DNS 协议纳入 sing-box 的 `dns.rules` 管道；**拦不住 DoH**（DNS over HTTPS 用 443 端口，看起来是普通 HTTPS 流量），走 DoH 自行解析的应用不经过 fakeip/`dns-flymc`/`dns-alidns` 这套优化，域名分类仍可能靠 sniff 命中，但拨号用的是应用自己解析出的 IP。 |
| 3 | `adblock-dns` | reject（drop） | 广告域名硬丢弃。 |
| 4 | `100.64.0.0/10`/`fd7a:115c:a1e0::/48` | `tailscale-in` | Tailscale/内部 CGNAT 地址段直接指定出站，无 selector。 |
| 5 | `geosite-tailscale` / oracle 域名 / oracle IP（后两者 `_secret`） | `🚦 tailscale-out` | 到达 Tailscale 协调域名或 `oracle` 主机的路径选择。 |
| 6 | `geoip-private`/`geosite-private` | bypass | 内网流量完全不进入代理判断（仅 Linux 可用此 action）。 |
| 7 | protocol bittorrent/stun 或 `category-pt`/`category-public-tracker` | `🚦 webrtc-bt-proxy` | 节点能力轴，见上表。 |
| 8 | `.onion` 域名后缀 | `🧅 tor` | 直接指定 `🧅 tor` 出站，不经过任何 selector——匿名性需求与"选哪个出口"无关。 |
| 9 | ai-chat/media/entertainment/emby/social-media + `apple@cn` | `🚦 i18n-service` | 见 selector 表；排在下面 gfw-only 规则之前，域名判定优先于风控专用规则。 |
| 10 | `geosite-gfw` | `🚦 oversea` | 仅用确认被封锁的名单（不含 `geolocation-!cn`），排在 `🚦 finance` 之前——避免该分类里真正被墙的内容被 `🚦 finance` 的默认直连接住导致连不上。`geolocation-!cn` 只表示"运营主体不在大陆"，不等于被封锁（如 HSBC HK/BOCHK 仅在 `geolocation-!cn` 名单内，境内直连可用），与 `gfw` 取并集处理会把这类内容错误划给 `🚦 oversea`，导致以后手动切换该分组时被一并带入代理隧道。`category-cryptocurrency` 按条目数只有 15.5% 在 `gfw.list` 里，但这部分恰好覆盖了主流交易所主站（`binance.com`/`coinbase.com`/`okx.com`/`huobi.com`/`kraken.com`/`bybit.com`/`gate.io` 均在内）——实际使用中加密货币流量大多在这条命中走 `🚦 oversea`，`🚦 finance` 接住的是该分类剩下的部分（子域名/行情/钱包等风控敏感但未被墙的内容）。 |
| 11 | `category-game-platforms-download` | `➡️ direct`（硬编码） | Steam/Blizzard 等下载 CDN，纯粹就近拉取，无换区/风控诉求，不占用任何可切换分组。 |
| 12 | `category-finance`/`category-cryptocurrency`/`category-ecommerce` | `🚦 finance` | 见 selector 表。 |
| 13 | `geosite-gfw` + `geosite-geolocation-!cn`（完整并集） | `🚦 oversea` | 上面两个分组范围之外的一般海外内容兜底。并非与后面的域名兜底规则（顺序 15）完全冗余——`geolocation-!cn` 名单里约 0.55% 的域名同时也在境内名单里，删掉这条会让这批域名在顺序 15 被误判成境内站点。 |
| 14 | `geoip-cn` | `🚦 cn` | 基于真实解析 IP 的境内判断，仅对经过 sing-box 完整解析（未被 fakeip 提前命中）的连接生效。 |
| 15 | 非 `tld-cn`/`geolocation-cn`/`cn` 的任意域名 | `🚦 oversea` | 域名兜底：未命中以上任何规则、且不在境内名单内的流量。 |
| 16 | `tld-cn`/`geolocation-cn`/`cn` | `🚦 cn` | 域名兜底：境内名单命中。 |

`route.rule_set` 里的 MetaCubeX 条目由 tag 名派生 URL（`geoip-`/`geosite-` 前缀决定 `geo/{geoip|geosite}/` 路径段），避免手写重复；`adblock-dns` 单独指向自建 blocklist。`category-ai-!cn`/`category-ai-chat-!cn@!cn`/`category-social-media-!cn@cn`/`category-entertainment@!cn` 未收录——`ai-!cn` 与 `ai-chat-!cn` 字节级相同，其余三个是各自父列表（`ai-chat-!cn`/`social-media-!cn`/`entertainment`）的 100% 子集，父列表已在同一条规则里覆盖。`route.final = 🚦 oversea`；`default_http_client = spoofed-http`；`default_domain_resolver = dns-quad9`（`route.default_domain_resolver` 硬约束：只能指定单一 server，不经过 `dns.rules`，无法用 `evaluate`/`race` 竞速）。

## 已知未覆盖的失效模式

| 场景 | 现状 |
|---|---|
| sing-box 进程崩溃/被停止/系统重启时的 TUN 模式 | 无 kill switch——`networking.firewall` 只开放监听端口，没有"非 tun 出站一律丢弃"的强制规则。TUN 接口连带路由随进程消失，内核退回物理网卡默认路由，此前所有分流判断（fakeip/gfw/cn 分类）全部失效，流量静默直连。`mixed-in`（显式配置走 SOCKS 的应用）不受影响——连接直接失败而非裸连，是安全的失效模式。一度用 `networking.firewall.extraCommands`/`extraStopCommands` 写过一版 iptables/ip6tables kill switch，后来撤掉了——那段是这份配置里最不"nix"的部分：裸 shell 脚本挂在 `OUTPUT` 链上，牵动整台机器的防火墙而不只是 sing-box 相关流量，声明式程度和改动的系统级影响不成正比，权衡下接受这个已知风险，不再维护那条路径。 |
| 应用自行 DNS-over-HTTPS 解析 | 见路由规则表顺序 2。 |
| 性能/延迟轴需求（游戏、实时语音视频） | 见 selector 表；已识别，未建 selector，接受默认行为的风险。 |
| IoT 云 API 把解析到的 IP 字面量嵌进负载 | STUN/TURN、主机游戏 NAT 探测、NTP 已经在 DNS 规则表顺序 2 覆盖（见上）。IoT 云 API（智能家居设备向云端上报自己的公网 IP 用于远程访问之类）没有可信的通用清单——调研时找到的相关条目全是品牌专属（小米米家、路由器厂商远程管理）或个人自建服务，无法泛化。遇到具体故障域名时，参照顺序 2 那条规则的写法加一条 `domain`/`domain_suffix` 匹配、`server = "dns-quad9"` 的 DNS 规则即可。 |

## `experimental`

| 设置 | Tradeoff |
|---|---|
| `cache_file.store_fakeip`/`store_dns` | 持久化 fakeip 映射和 DNS 缓存；不含 selector 选中状态（见 i18n-service 那行）。 |
| `clash_api.secret = ""` | 面板控制器无鉴权——仅监听 `127.0.0.1:9090`，不对外暴露。 |

## systemd 服务加固 (`systemd.services.sing-box`)

| 设置 | Tradeoff |
|---|---|
| `after`/`wants` 含 `unbound`/`dnscrypt-proxy`/`tor`（+ 条件性 `adguardhome`） | 启动顺序依赖，不代表运行时依赖这些服务的 DNS 解析结果（见 `dns-system` 那行，本机 `type=local` 不经过 unbound 管道）。 |
| `AmbientCapabilities`/`CapabilityBoundingSet`/`DeviceAllow` 条件性含 `CAP_NET_ADMIN`/`/dev/net/tun` | 仅 `tun=true` 时授予——TUN 模式需要创建/配置虚拟网卡。 |
| `PrivateDevices = !tun` | TUN 模式需要访问 `/dev/net/tun`，与 `PrivateDevices` 互斥。 |
| `RestrictAddressFamilies` 条件性含 `AF_NETLINK` | 仅 `tun=true` 时授予，用于路由表操作。 |
| `PrivateTmp = true` | `external_ui_download_url` 面板下载先落到 `/tmp` 再解压；`ProtectSystem=strict` 下 `/tmp` 默认只读，需要私有可写的 `/tmp`。 |
| 其余（`NoNewPrivileges`/`ProtectSystem=strict`/`ProtectHome`/`ProtectClock`/`ProtectHostname`/`ProtectKernelLogs`/`ProtectKernelModules`/`ProtectControlGroups`/`LockPersonality`/`RestrictRealtime`/`RestrictSUIDSGID`/`MemoryDenyWriteExecute`/`SystemCallFilter=[@system-service,~@privileged]`） | 上游 nixpkgs 的 sing-box 模块未加任何 systemd 沙箱，这里补齐标准加固项。 |
