# sing-box (`proxy.nix`)

设置权衡记录。域名分类以 MetaCubeX/meta-rules-dat 的 geosite 列表为准；顺序相关的设置见对应表格的"顺序"列，first-match-wins。

## 模块开关

| 设置 | Tradeoff |
|---|---|
| `modules.proxy.singbox.enable` | 启用 sing-box 作为代理后端。 |
| `modules.proxy.singbox.tun` | 启用系统级 TUN 接管（`dns_mode=hijack`），而非仅本地 SOCKS/HTTP 代理(`mixed-in`)。TUN 关闭时，未显式配置走 `127.0.0.1:1080` 的应用不受任何分流规则影响，直接裸连——这是有意的降级路径，不是缺陷。 |
| `modules.proxy.singbox.killSwitch.enable` | 独立 nft 表 `sing-box-killswitch`（`sing-box-killswitch.service`），对普通用户（uid 1000-59999）发往公网、且最终不经 `lo`/`tun0`/`tailscale0` 的包在 postrouting 钩子 drop。drop 规则正向匹配 uid（`meta skuid 1000-59999 drop`）：RST、TIME_WAIT 的 ACK/FIN 等无归属 socket 的包取不到 uid，规则不匹配，走默认放行（live 日志 150 条命中全是这类包，用反向 `skuid != ... accept` 写法它们会被丢掉）。必须是 postrouting：output 钩子里 `oifname` 是 sing-box 打标记重路由**之前**的网卡，TUN 流量和重定向到 127.0.0.1 的 TCP 都显示为物理网卡，会被误杀（实测：用 output 钩子部署后 TUN 正常运行时用户会话断网）。放行：私网/链路本地/多播（对应 `geoip-private` 绕过 TUN）、uid 范围外的进程（root/sing-box/unbound/dnscrypt-proxy/tor 本来就直连）。需要 `tun=true`（断言）。sing-box 停止期间用户会话无公网，TCP 表现为超时（postrouting 不能 reject），UDP 立即 EPERM；手动停 sing-box 要连 `sing-box-killswitch.service` 一起停。范围外的 uid（systemd DynamicUser、subuid 容器进程）和绑定物理网卡的程序不受保护。验证：真实 sing-box（auto_redirect + strict_route、双栈 TUN）在网络命名空间里、用 uid 1000 客户端测 IPv4/IPv6 的 TCP/UDP——运行时通过、停止时拦截、重启后恢复、私网豁免；未在 omen15 上实测。 |
| `boot.kernel.sysctl` rp_filter | TUN 需要放松 `net.ipv4.conf.*.rp_filter` 到 `2`（loose）以支持非对称路由（如游戏 UDP）；用 `mkOverride 900` 显式盖过 `security.nix` 的 `mkOverride 950`（数字越小优先级越高）。 |

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
| `dns-ts` | `type=tailscale`，`endpoint=tailscale-in`，`accept_default_resolvers=false`，`accept_search_domain=true` | 解析 MagicDNS 名字（`*.ts.hydroakri.cc`，含裸名）。`accept_default_resolvers=false`：非 tailnet 名字返回 NXDOMAIN，不回落到 headscale 的全局解析器，公网解析仍走 `dns-quad9`/fakeip。 |
| `dns-alidns` | h3，`detour=🚦 cn` | `🇨🇳 direct-cn` outbound 的 `domain_resolver`——已知国内域名走 fakeip 后，真正解析用这个而非中立的 `dns-zerotrust`。选它而非 `dns-flymc` 是因为阿里 DNS 在境外的 CDN 调度表现也更好，不只是境内优化。 |
| `dns-flymc` | h3，`detour=🚦 cn`，无 utls | 用于 `match_response` 阶段对已确认 `geoip-cn` 的响应做二次查询，拿国内优化结果。QUIC/h3 传输与 utls 不兼容，DNS 类 h3 server 均不加 utls。 |
| `dns-zerotrust` | h3，无 detour，`server_name` 走 `_secret` | 中立探测服务器：`➡️ direct`/多数 selector 的默认 `domain_resolver`，也是 `evaluate` 阶段对未分类域名探测真实 IP 的查询目标。 |
| `dns-quad9` | h3，`detour=🚦 oversea` | `dns.final` 兜底，以及 `route.default_domain_resolver`——WireGuard 出站解析域名走这个，不经过 `dns.rules` 匹配链（sing-box 硬约束：该字段只能指定单一 server，无法用 `evaluate`/`race` 竞速）。 |

## DNS 规则 (`dns.rules`，顺序敏感)

| 顺序 | 规则 | Tradeoff |
|---|---|---|
| 0 | `preferred_by = dns-ts` → `dns-ts` | MagicDNS 主机名命中 tailnet 解析，排在最前，不会被 fakeip 接走（实测：经 Clash API 查 `oci.ts.hydroakri.cc` 得 tailnet 地址，`example.com` 得 fakeip）。 |
| 1 | mDNS 域名 → `dns-mdns` | `preferred_by` 触发本地发现协议特化处理。 |
| 2 | 内网关键词/后缀/`geosite-private` → `dns-system` | 局域网/内网域名走网卡分配 DNS，不进 fakeip/探测管道。**排在顺序 3 前面是必须的**——`fakeip-filter.srs`（见下）里的 `+.msftconnecttest.com`/`+.msftncsi.com`/`+.linksys.com`/`+.linksyssmartwifi.com` 跟这条的 `domain_keyword` 逐字重复，顺序反了会导致这几个连通性检测/路由器域名从 `dns-system` 改判给 `dns-quad9`——msftconnecttest/msftncsi 这类强制门户检测域名本该看本地网络的真实返回（可能被门户劫持成跳转页），用加密解析器给出诚实答案反而让检测失灵。 |
| 3 | `fakeip-filter`（`query_type` A/AAAA） → `dns-quad9` | 跳过 fakeip 直接返回真实 IP——STUN/主机游戏 NAT 探测/语音服务依赖连接到的真实地址或对往返时间戳敏感，命中 fakeip 会直接连不上。列表来自 `DustinWin/ruleset_geodata@sing-box-ruleset`（上游 `ShellCrash/public/fake_ip_filter.list`），覆盖 PlayStation/Xbox/Nintendo/Battle.net NAT 探测、NTP、英雄联盟语音、VoWiFi 等。**代价**：STUN 部分用 `+.stun.*.*` 通配，任意含 `stun.` 的域名都会放真实 IP；列表另含与此机制无关的国内 App 域名（网易云音乐、微信登录、招商银行等），无副作用。`discord.media` 不在列表内，未单独处理。IoT 云 API 类无通用清单，见下方已知未覆盖表。 |
| 4 | `tld-cn`/`geolocation-cn`/`cn`/`gfw`/`geolocation-!cn` + `🚦 i18n-service`/`🚦 finance`/`🚦 webrtc-bt-proxy`/`🚦 tailscale-out`/`game-platforms-download`（硬编码 direct）用到的全部域名类 `rule_set`（ai-chat-!cn/media/entertainment/emby/social-media-!cn/apple@cn/finance/cryptocurrency/ecommerce/category-pt/category-public-tracker/category-game-platforms-download/tailscale） → `fakeip` | 已分类域名跳过下面的探测，省一次往返。覆盖范围不止境内境外判断——`route.rules` 里这些规则的路由结果全靠 `rule_set` 域名匹配决定、且排在 `geoip-cn` 之前，真实 IP 对路由判断毫无意义，不管出站是走 selector 还是硬编码，都能省掉探测那次往返。未被这些列表覆盖的域名才进入下一步。`🚦 tailscale-out` 规则里 oracle 域名/IP 走的是 `_secret` 模板而非 `rule_set`，没有一并纳入——单独一个 secret 域名要塞进这条规则得改成 `rule_set`+`domain` 的逻辑或结构，为一个低频域名换来的收益太小，没做。`adblock-dns` 也不在这条里——广告域名不再享受 DNS 阶段零查询优化，正常走完整条链路（多数落到下面顺序 6 的兜底 fakeip），block/direct-cn/oversea 的判断完全交给 route 层的 `🛡️ adblock` selector（见路由规则表顺序 3、下方分组 selector 表）。 |
| 5 | `evaluate` action，`dns-zerotrust`，`disable_optimistic_cache=true` | `evaluate` 本身不路由——它只查询并挂起一个响应，不直接返回给客户端；后面带 `match_response=true` 的规则才检查这个挂起响应的内容并决定去向。这里用它探测未分类域名的真实 IP，供下一步 GeoIP 判断。`disable_optimistic_cache=true`：这次查询的目的就是拿到当前的真实 IP 来判断地区，乐观缓存会先返回过期答案，GeoIP 判断随之不准；代价是缓存过期后重复访问要再等一次查询。`timeout=5s` 不要调低：冷查询（31 个未被规则集收录的域名）实测中位数约 0.4 到 0.6 秒，p90 约 1 到 2 秒，最大 2.9 秒（上游递归解析的时间）；超时会回落到最后的 fakeip 规则，国内站点会被当成海外。未覆盖：国内托管的未收录域名没有测。 |
| 6 | `geoip-cn` + `match_response=true` → `dns-flymc` | 挂起的响应经 GeoIP 判断是国内 IP 时，改用 `dns-flymc` 重新查询换取国内优化响应。 |
| 7 | `match_response` + `NXDOMAIN`/`SERVFAIL` → respond | 挂起响应本身是失败结果时直接透传，不再往下走。 |
| 8（`final` 前的最后一条） | 兜底 → `fakeip` | 挂起响应是境外真实 IP（未命中顺序 6/7 任一分支）时也走到这里：不直接把探测到的真实 IP 返回给客户端，仍然统一返回 fakeip。fakeip 是几乎所有查询的最终归宿，不只是顺序 4 已分类域名的特例——真实 IP 只在拨号那一刻由 outbound 的 `domain_resolver` 按需解析，sing-box 自己回答的 DNS 响应永远不直接暴露真实境外 IP（系统解析器 unbound → dnscrypt-proxy 的应用不经过这里，拿到的是真实 IP，由嗅探到的域名路由）。 |

`dns.final = dns-quad9`；`strategy = prefer_ipv4`；`cache_capacity = 4096`；`optimistic = true`；`store_fakeip`/`store_dns` 持久化在 `cache_file`。`selector` 的当前选中状态也会自动持久化——`store_selected` 从 sing-box 1.8.0 起废弃，行为改成只要 `cache_file.enabled=true`（本配置一直是）就默认持久化，不需要也不能再单独配置这个字段；手动经 Clash API 选过一次之后，重启不会丢。

`.onion` 在 `dns-system` 规则之后有两条专用 DNS 规则：A/AAAA 返回 fakeip（让 `route.rules` 的 `.onion → 🧅 tor` 规则能命中），其余类型返回 NXDOMAIN；否则 `.onion` 查询会被 `evaluate` 发给上游解析器（实测返回真实递归解析器的 NXDOMAIN）。

## 入站 (`inbounds`)

| 设置 | Tradeoff |
|---|---|
| `mixed-in`，`127.0.0.1:1080` | 始终开启，供显式配置走本地代理的应用使用，不受 `tun` 开关影响。 |
| `tun-in`（`modules.proxy.singbox.tun=true` 时） | `dns_mode=hijack`+`auto_route`+`auto_redirect`+`strict_route` 系统级接管；`route_exclude_address` 静态列表（MetaCubeX `geoip-private` 的 28 条快照，去掉 fakeip 池 `198.18.0.0/15` 和 `64:ff9b:1::/48`，与路由规则 6/6a 共用同一份 `privateCidrs`；该列表含这两段，用 `route_exclude_address_set` 引用会让 fakeip 连接不进 sing-box，实测：池内地址的包不被接管）。fakeip 池不得出现在此列表。列表是快照，不随上游更新；条目来自 IANA 特殊用途地址登记，很少变化；`exclude_uid_range` 放行 root/unbound/dnscrypt-proxy/tor 自身进程的对外连接，避免这些进程的流量被 tun 递归接管形成回路。`mtu=1280`——低于常见的 1500，代价是包头开销占比更高、大流量吞吐略降；换来的是这条 tun 是双栈（同时配置了 IPv4/IPv6 地址），1280 是 IPv6 规定的最小链路 MTU（RFC 8200），用它能保证隧道内部不需要对 IPv6 包做二次分片，不用去猜某个出站封装（WireGuard/Reality 等）还会再叠多少层开销。 |

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
| `🚦 i18n-service` | 身份/地区轴 · 换区需求 | `➡️ direct` → `🎯 isp` → `🎯 manual` → `🚫 block` | 覆盖 ai-chat/media/entertainment/emby/social-media + `apple@cn`。旗舰域名（twitter/youtube/facebook/instagram/netflix/google 等）多数在 `gfw.list` 内，境内默认无法直连；境外则是直连可用、换区内容库时才需要代理。`apple@cn` 域名（App Store 区域内容相关的共用 CDN 边缘域名）在境内/境外两份 geosite 列表里都覆盖率极低，靠域名本身分不出中外，一并纳入此组显式管理。selector 选中状态随 `cache_file` 自动持久化（见 DNS 规则表下方说明），手动选过之后重启不会丢；候选顺序只决定从未手动选过（首次启动/清了 `cache.db`）时的默认值。 |
| `🚦 finance` | 身份/地区轴 · 风控需求 | `➡️ direct` → `🎯 isp` → `🎯 proxy` → `🎯 manual` → `🚫 block` | 覆盖国际银行/券商/加密货币/电商。默认直连——异地 IP 触发风控（异地登录/资金冻结）是真实成本，不是可简化的认知负荷问题；候选顺序保留 `➡️ direct` 优先。仅作为应对极端场景（境内 IP 被制裁式封锁）的手动开关存在。真正被 `gfw.list` 确认封锁的部分（该分类里占比个位数到十几个百分点）已经在 `route.rules` 里被排在这个分组判断之前的专门规则接住，不会落到这里默认直连失败。 |
| `🚦 webrtc-bt-proxy` | 节点能力轴 | `➡️ direct` → `🎯 isp` → `🎯 proxy` → `🎯 manual` → `🚫 block` | BT/PT/STUN 流量需要出口节点明确支持/不限速 P2P，与地区、风控无关，独立管理避免被通用海外节点的 ToS 限制。 |
| `🎯 isp` / `🎯 proxy` / `🎯 manual` | 叶子池 | 各自候选见 Nix 源码 | 供上面几个 `🚦` 分组间接引用的实际出口候选池；`isp` 不含 `🧅 tor`，`proxy` 含 `🧅 tor`，`manual` 额外含 `➡️ direct`（供纯手动指定场景使用）。 |
| `🚦 tailscale-out` | 自有基础设施，不适用上述三轴 | `➡️ direct` → `🎯 isp` → `🎯 proxy` → `🎯 manual` | 到达 Tailscale 协调域名/`oracle` 主机公网身份的路径选择；`tailscale-in`（`100.64.0.0/10`/`fd7a:...`）本身没有 selector，因为那段地址只能经 Tailscale-aware 出站到达，没有替代路径。 |
| `🛡️ adblock` | 运行时开关，不落在上述三轴 | `🚫 block` → `🚦 cn` → `🚦 oversea` | 广告拦截从硬编码 DNS/route 层 `reject` 改成的可切换分组——默认拦截；候选是 `🚦 cn`/`🚦 oversea` 而不是单一 `➡️ direct`，因为命中 `adblock-dns` 的域名境内境外都有且规则引擎无法按域名再分流（见路由规则表顺序 3），选哪条链路得看你在排查哪个具体域名，手动挑更合适的那个。 |

## 路由规则 (`route.rules`，顺序敏感，first-match-wins)

| 顺序 | 规则 | 去向 | Tradeoff |
|---|---|---|---|
| 1 | `sniff` | — | 对 `tun-in`(如启用)/`mixed-in` 做协议嗅探，300ms 超时；即使连接方自行做了 DNS 解析（如浏览器走 DoH 绕过下面的 `hijack-dns`），只要是 TLS 连接仍可从 ClientHello 的 SNI 恢复域名，用于后续按域名分类；HTTP/TLS 之外、且未经过 sing-box DNS 解析的连接无法恢复域名，只能落到 IP-based 规则（`geoip-cn`/`bypass`）。 |
| 2 | port 53 / protocol dns | hijack-dns | 拦截传统 DNS 协议纳入 sing-box 的 `dns.rules` 管道；**拦不住 DoH**（DNS over HTTPS 用 443 端口，看起来是普通 HTTPS 流量），走 DoH 自行解析的应用不经过 fakeip/`dns-flymc`/`dns-alidns` 这套优化，域名分类仍可能靠 sniff 命中，但拨号用的是应用自己解析出的 IP。 |
| 2a | 入站 `tailscale-in` | `➡️ direct` | 别的 tailnet 节点连进本机的连接，否则会落到 `final`（`🚦 oversea`）。 |
| 3 | `adblock-dns` | `🛡️ adblock` selector | 默认候选 `🚫 block`（硬丢弃，跟改动前行为一致）；可经 Clash API 手动切到 `🚦 cn`/`🚦 oversea` 放行——三选一而非直接 `➡️ direct`，是因为广告域名本身境内境外都有，路由规则不能读取 selector 的运行时状态、无法在命中这条规则后"退回"给下面顺序 4 及之后的 cn/oversea/兜底规则重新判断，选哪条链路只能由用户手动指定。 |
| 4 | `100.64.0.0/10`/`fd7a:115c:a1e0::/48` | `tailscale-in` | Tailscale/内部 CGNAT 地址段直接指定出站，无 selector。 |
| 4a | `preferred_by = tailscale-in` | `tailscale-in` | MagicDNS 主机名以域名形式进入路由，顺序 4 的 `ip_cidr` 匹配不到它们；没有这条会落到 `➡️ direct`，由其 `domain_resolver`（公网解析器）查不到。 |
| 5 | `geosite-tailscale` / oracle 域名 / oracle IP（后两者 `_secret`） | `🚦 tailscale-out` | 到达 Tailscale 协调域名或 `oracle` 主机的路径选择。 |
| 6 | 私有地址（`geoip-private` 的静态快照，见下）或 `geosite-private` | bypass + `➡️ direct` | 内网流量不进入代理判断（`bypass` 仅 Linux）。必须带 `outbound`：不带时 `bypass` 对 `mixed-in` 被跳过，私有目的地落到 `final`（实测：mixed-in 连私网被 block），带上后在所有入站上等同 route 到该出站。TUN 里私网段已被 `route_exclude_address` 排除，几乎不会走到这条。 |

`geoip-private` 是 `proxy.nix` 里的静态快照 `privateCidrs`（26 条，去掉两段 fakeip 池），TUN 的 `route_exclude_address` 与路由规则 6/6a 共用；远程规则集里只剩 `geosite-private`（域名类，保持远程）。快照不随上游更新；条目来自 IANA 特殊用途登记，很少变化。
| 7 | protocol bittorrent/stun 或 `category-pt`/`category-public-tracker` | `🚦 webrtc-bt-proxy` | 节点能力轴，见上表。 |
| 8 | `.onion` 域名后缀 | `🧅 tor` | 直接指定 `🧅 tor` 出站，不经过任何 selector——匿名性需求与"选哪个出口"无关。 |
| 9 | `category-game-platforms-download` | `➡️ direct`（硬编码） | Steam/Blizzard 等下载 CDN，纯粹就近拉取，无换区/风控诉求，不占用任何可切换分组。 |
| 10 | ai-chat/media/entertainment/emby/social-media + `apple@cn` | `🚦 i18n-service` | 见 selector 表；排在下面 gfw-only 规则之前，域名判定优先于风控专用规则。 |
| 11 | `geosite-gfw` | `🚦 oversea` | 仅用确认被封锁的名单（不含 `geolocation-!cn`），排在 `🚦 finance` 之前——避免该分类里真正被墙的内容被 `🚦 finance` 的默认直连接住导致连不上。`geolocation-!cn` 只表示"运营主体不在大陆"，不等于被封锁（如 HSBC HK/BOCHK 仅在 `geolocation-!cn` 名单内，境内直连可用），与 `gfw` 取并集处理会把这类内容错误划给 `🚦 oversea`，导致以后手动切换该分组时被一并带入代理隧道。`category-cryptocurrency` 按条目数只有 15.5% 在 `gfw.list` 里，但这部分恰好覆盖了主流交易所主站（`binance.com`/`coinbase.com`/`okx.com`/`huobi.com`/`kraken.com`/`bybit.com`/`gate.io` 均在内）——实际使用中加密货币流量大多在这条命中走 `🚦 oversea`，`🚦 finance` 接住的是该分类剩下的部分（子域名/行情/钱包等风控敏感但未被墙的内容）。 |
| 12 | `category-finance`/`category-cryptocurrency`/`category-ecommerce` | `🚦 finance` | 见 selector 表。 |
| 13 | `geosite-gfw` + `geosite-geolocation-!cn`（完整并集） | `🚦 oversea` | 上面两个分组范围之外的一般海外内容兜底。并非与后面的域名兜底规则（顺序 15）完全冗余——`geolocation-!cn` 名单里约 0.55% 的域名同时也在境内名单里，删掉这条会让这批域名在顺序 15 被误判成境内站点。 |
| 14 | `geoip-cn` | `🚦 cn` | 基于真实解析 IP 的境内判断，仅对经过 sing-box 完整解析（未被 fakeip 提前命中）的连接生效。 |
| 15 | 非 `tld-cn`/`geolocation-cn`/`cn` 的任意域名 | `🚦 oversea` | 域名兜底：未命中以上任何规则、且不在境内名单内的流量。 |
| 16 | `tld-cn`/`geolocation-cn`/`cn` | `🚦 cn` | 域名兜底：境内名单命中。 |

`route.rule_set` 里的 MetaCubeX 条目由 tag 名派生 URL（`geoip-`/`geosite-` 前缀决定 `geo/{geoip|geosite}/` 路径段），避免手写重复；`adblock-dns` 单独指向自建 blocklist。`category-ai-!cn`/`category-ai-chat-!cn@!cn`/`category-social-media-!cn@cn`/`category-entertainment@!cn` 未收录——`ai-!cn` 与 `ai-chat-!cn` 字节级相同，其余三个是各自父列表（`ai-chat-!cn`/`social-media-!cn`/`entertainment`）的 100% 子集，父列表已在同一条规则里覆盖。`route.final = 🚦 oversea`；`default_http_client = spoofed-http`；`default_domain_resolver = dns-quad9`（`route.default_domain_resolver` 硬约束：只能指定单一 server，不经过 `dns.rules`，无法用 `evaluate`/`race` 竞速）。

## Tailscale 端点 (`tailscale-in`)

对象：sing-box 内置的 `tailscale` 端点，登录自建 headscale（`hosts/oci/oci.nix`，`base_domain = ts.hydroakri.cc`）。`tailnetDomain` 与 `control_url` 重复了 `oci.nix` 的值，改一边要同步另一边。

### 配置

| 设置 | Tradeoff |
|---|---|
| `auth_key`（sops `headscale-authkey`，预授权密钥可复用） | 状态存在后 `auth_key` 被忽略，所以 `state_directory = /var/lib/sing-box/tailscale` 必须跨重启保留；丢失后要重新注册。 |
| `listen_port = 41641` + 防火墙放行 UDP | tailscaled 的默认 WireGuard 端口，放行后对端能主动连入。不放行时靠双向打洞也能直连（oci 到 Pi 实测用的是 NAT 映射端口）。保留放行的代价：笔记本在公共网络上多开一个 UDP 口。 |
| `system_interface = true`（`tailscale0`） | 内核可见的网卡，本机进程不经代理就能访问 tailnet。代价见加固表（权限）；网关上与 TUN 共存未验证。 |
| `domain_resolver = dns-zerotrust` | 否则控制面域名的查询会走 fakeip DNS 路由。 |
| `taildrop_directory` | 收件箱 `/var/lib/sing-box/Taildrop`。 |
| `ssh_server` 不开 | 开启后端点接管 tailnet 地址上的 22 端口（横幅 `SSH-2.0-sing-box`），宿主 sshd 在 tailnet 上不可达；无 root 时只能登录成 `sing-box` 用户；还需要 headscale 配 SSH 策略。 |
| `accept_routes` 不开 | 主机在被宣告的网段内时会与本地网段冲突（omen15 在 `192.168.10.0/24`）；LAN 外的节点才需要。 |
| 出口节点、`advertise_tags`、自有 DERP 不做 | 出口节点会绕开 sing-box 自己的分流；其余当前没有需求。 |

### MagicDNS

| 机制 | Tradeoff |
|---|---|
| `dns-ts` + DNS 规则 0 + 路由规则 4a | 经 sing-box 自己的解析和路由处理 tailnet 名字。 |
| unbound `stub-zone` → `100.100.100.100` + `domain-insecure` | 让系统解析器也认 MagicDNS（`getent`、`ssh oci`）。`core.nix` 把根 `forward-zone` 设为 `mkDefault`，再写一份会整体覆盖，所以用 `stub-zone`。tailnet 内部名不做 DNSSEC 校验。 |
| `networking.search = ts.hydroakri.cc` | 裸名可用；单标签查询先试这个后缀。 |
| 名字的 AAAA | 官方客户端与内置端点都不返回 AAAA（headscale 未下发）；IPv6 地址字面量可用。 |

### 与官方客户端的差异

| 能力 | 官方 | 内置端点 |
|---|---|---|
| 登录、直连、IPv4/IPv6、`tailscale0` | 有 | 一致 |
| 状态查看 | `status`、`ping`、`netcheck`、`whois` | `sing-box api tailscale status/peer/ping`，没有 `netcheck`、`whois` |
| Taildrop | 收发需要 operator 或 root | 无需 root（`api tailscale taildrop`、dashboard） |
| 系统 DNS | 自动改系统解析器 | 靠 unbound `stub-zone` 和搜索域 |
| `tailscale0` 入站 | tailscaled 放行 | 受主机防火墙约束，未做对比测试 |
| 版本 | 独立更新 | 跟随 sing-box 版本 |

### 验证范围

| 项 | 状态 |
|---|---|
| 登录、沿用旧节点、直连、三机 6 个方向 TCP 互通、IPv6 TCP | 已验证（omen15，WARP 关闭） |
| 子网路由：oci 经 Pi 访问 HA、LIFX、LAN 主机 | 已验证（TCP；手机未测；ICMP 被 `security.nix` 禁用，只能用 TCP 和 `tailscale ping`） |
| Taildrop 6 个方向 | 已验证；发往 omen15 的核对了内容，其余以对端 `tailscaled` 日志的 `peerapi: got put` 为准 |
| 路由规则回归 | 已验证：相对基线只多 3 条路由规则和 1 条 DNS 规则 |
| 重启后行为（`/var/lib/sing-box` 权限、服务顺序） | 未验证 |
| 网关 TUN 共存、headscale 长中断 | 未验证 |

### 运维

| 项 | 说明 |
|---|---|
| `/var/lib/sing-box` 文件属主错位 | 现象 `open cache.db: permission denied` 循环重启；`chown -R sing-box:sing-box /var/lib/sing-box`。保留 `tailscale/` 目录可沿用旧节点身份。`sing-box` 的 uid 和 gid 固定为 960（`proxy.nix`，和 `unbound`、`dnscrypt-proxy` 的做法一致），动态分配的 id 在重启后出现过变化（989 变成 992）；首次部署固定值后要执行一次上面的 `chown`，网关的 `/var/lib/sing-box` 同理。 |
| selector 指向 `🔒 zerotrust`（`127.0.0.1:40000`） | 该端口是 WARP 代理模式的本地代理；全局隧道模式或 WARP 关闭时无人监听，经 Clash API 切到 `➡️ direct`（选择存在 `cache.db`）。 |
| 部署顺序 | oci 的 `--accept-routes` 要求 headscale 已批准 Pi 的路由，否则不起作用。 |

## 已知未覆盖的失效模式

| 场景 | 现状 |
|---|---|
| sing-box 进程崩溃/被停止/系统重启时的 TUN 模式 | `killSwitch.enable=true` 的主机：用户会话直连被拒（见模块开关表），重启窗口、崩溃后的 10 秒 `Restart` 间隔、开机时 `network-online` 之前都覆盖。未启用的主机（`tun=true` 的网关等）：TUN 接口连带路由随进程消失，内核退回物理网卡默认路由，分流判断全部失效，流量静默直连。`mixed-in` 不受影响——连接直接失败而非裸连。开机时 `NetworkManager-wait-online` 超时（实测 60 秒）会把 sing-box 启动推迟到约 85 秒，kill switch 期间用户会话无网络。 |
| 应用自行 DNS-over-HTTPS 解析 | 见路由规则表顺序 2。 |
| 性能/延迟轴需求（游戏、实时语音视频） | 见 selector 表；已识别，未建 selector，接受默认行为的风险。 |
| 网关（`tun=true`）上 `system_interface` 与 sing-box TUN 共存 | 未验证，没有机器运行过这份配置。首次部署建议用 `nh os test`（不写开机项，异常时重启回滚）。 |
| headscale 长时间中断、节点改名/删除后内置端点是否跟随 | 未验证（上游 issue #4371 报告不会自动重连）；约 1 秒的重启实测不受影响。 |
| IoT 云 API 把解析到的 IP 字面量嵌进负载 | STUN/TURN、主机游戏 NAT 探测、NTP 已在 DNS 规则表顺序 3 覆盖。IoT 云 API（智能家居设备向云端上报公网 IP 用于远程访问之类）无通用清单。遇到具体故障域名时，参照顺序 3 的写法加一条 `domain`/`domain_suffix` 匹配、`server = "dns-quad9"` 的 DNS 规则。 |

## `experimental`

| 设置 | Tradeoff |
|---|---|
| `cache_file.store_fakeip`/`store_dns` | 持久化 fakeip 映射和 DNS 缓存；不含 selector 选中状态（见 i18n-service 那行）。`cache.db` 记录访问过的域名；`UMask=0077` 让它只对 sing-box 用户可读。 |
| `clash_api.secret`（sops `singbox-api-secret`）、`access_control_allow_origin = http://127.0.0.1:9090` | 留空时 CORS 为 `*`，任意网页都能调用控制器。`external_ui_download_url` 已移除：面板不再从 GitHub 分支自动下载（`ui/` 里已有的文件保留）。 |
| `services` 里的 `api`（`127.0.0.1:9091`，`secret` = sops `singbox-api-secret`） | `sing-box api tailscale status/peer/ping/taildrop` 与 dashboard（Taildrop、端点登录）的后端。它注册的是 `StartedService`（42 个 RPC，含停止/重载服务、选出站、`SetTailscaleExitNode`、订阅日志和全部连接），`secret` 为空时本机任何进程可调用。`access_control_allow_origin` 限为 dashboard 自己的来源，其他网页的跨域请求被浏览器拒绝；本机进程仍不受限。要消除需要新增 sops 密钥作 `secret`，命令行此后要用 root 读取它。 | CORS 只约束 `fetch`；gRPC-over-WebSocket 不检查 Origin（源码 `InsecureSkipVerify`，实测伪造 Origin 握手 101），所以真正的保护是 `secret`。dashboard 默认每天从 SagerNet 的 gh-pages 分支自动更新，未固定版本。CLI 需要 `BOX_API_SECRET` 或 `--secret`。

## systemd 服务加固 (`systemd.services.sing-box`)

| 设置 | Tradeoff |
|---|---|
| `after`/`wants` 含 `unbound`/`dnscrypt-proxy`（+ 条件性 `tor`（`tor.enable`）、`adguardhome`） | 启动顺序依赖，不代表运行时依赖这些服务的 DNS 解析结果（见 `dns-system` 那行，本机 `type=local` 不经过 unbound 管道）。 |
| sops secret（`proxy.nix`/`proxy-nodes.nix`） | `restartUnits = sing-box.service`（`singbox.enable` 时）：secret 变化会重启 sing-box。 |
| 断言 | 每个 selector 的候选必须是已有 outbound/endpoint 的 tag；`proxy.nix` 里 `rs` 的每个 rule-set 必须列入 `ruleSetTags`。 |
| `AmbientCapabilities`/`CapabilityBoundingSet` = `CAP_NET_ADMIN` + `CAP_NET_RAW`，`DeviceAllow = /dev/net/tun rw` | 无条件授予：Tailscale 端点的 `system_interface` 在 `tun=false` 时也要创建 TUN 网卡。列表首项为空串用来重置：上游 unit 自带 `CAP_DAC_READ_SEARCH`（能读 `/run/secrets`）、`CAP_SYS_PTRACE`、`CAP_NET_BIND_SERVICE`，systemd 对重复赋值是合并，不写空串就会保留（`systemctl show` 实测）。`CAP_NET_RAW` 为 ICMP 保留。代价：所有开 sing-box 的主机不再有按 `tun` 区分的最小权限。 |
| `DevicePolicy = closed`，`PrivateDevices = false` | `DeviceAllow` 只有在 `DevicePolicy=closed` 下才限制设备（默认 `auto` 放行所有设备节点）；TUN 需要 `/dev/net/tun`，与 `PrivateDevices` 互斥。 |
| `RestrictAddressFamilies` 含 `AF_NETLINK` | 无条件授予：网络管理和 Tailscale 端点读路由/网卡信息都要。 |
| `PrivateTmp = true` | `external_ui_download_url` 面板下载先落到 `/tmp` 再解压；`ProtectSystem=strict` 下 `/tmp` 默认只读，需要私有可写的 `/tmp`。 |
| 其余（`NoNewPrivileges`/`ProtectSystem=strict`/`ProtectHome`/`ProtectClock`/`ProtectHostname`/`ProtectKernelLogs`/`ProtectKernelModules`/`ProtectControlGroups`/`LockPersonality`/`RestrictRealtime`/`RestrictSUIDSGID`/`MemoryDenyWriteExecute`/`SystemCallFilter=[@system-service,~@privileged]`） | 上游 nixpkgs 的 sing-box 模块未加任何 systemd 沙箱，这里补齐标准加固项。 |

## captive portal (`captive-portal`，`desktop.nix`)

| 设置 | Tradeoff |
|---|---|
| `networking.networkmanager.settings.connectivity` | 写进 `NetworkManager.conf`（NM 服务的 `restartTriggers`），`switch` 后自动重载；放 `conf.d` 不会触发重载，运行中的 NM 会对探测返回假结果（日志 `start fake request`）。`response` 必须非空——空串匹配任何回应，portal 的 307 也判成 FULL。204 无正文的端点（GrapheneOS、Cloudflare）不适用，故用 Arch 的 `nm-check.txt`，代价是 Arch 能看到出口 IP。 |
| dispatcher `PORTAL` 分支停 `sing-box` | portal 态出口不通，tun 会给 portal 域名发 fakeip。代价是认证前的流量直连、无 tun 保护。`FULL`/`NONE` 时拉起，因此手动停掉的 sing-box 会在下次 `FULL` 被重新拉起。 `PORTAL` 先停 `sing-box-killswitch.service`（存在时），否则用户会话打不开登录页；`FULL`/`NONE` 先拉起 kill switch 再拉起 sing-box。 |
| `PORTAL` 时 unbound 转发改为 DHCP 下发的 DNS | dnscrypt 上游被封时对查询静默挂死，`forward-first` 的回退来不及（getent 约 45 秒后失败）。代价是 portal 态 DNS 为明文。还原值读自 `services.unbound.settings.forward-zone`，不另写一份。 |
| 状态切换时 `flush_zone .` | `cache-min-ttl 300` 会留住 portal 态的 fakeip、劫持和失败答案。 |
| 登录页经 `curl -4` 取探测网址的 307 `Location` 再开 | 浏览器会把 http 升级成 https，portal 拦不到；解析结果首选 IPv6 时该网络无路由。经 `systemd-run --user --machine=<user>@.host` 在用户会话里用默认浏览器打开，`xdg-open` 须用绝对路径（单元 PATH 里没有）。 |
| `PORTAL` 停 sing-box 时 `tailscale0` 随之消失 | unbound 的 `stub-zone`（`ts.hydroakri.cc` → `100.100.100.100`）不可达，`networking.search` 使单标签名先试这个后缀，首次查询会多等。unbound 是否随后把不可达地址标记为 down 以缩短等待，未验证。 |
| `LIMITED` 不处理 | 探测失败不等于 portal，误判会把 DNS 降级为明文，代价高于收益。 |
| `dns.rules` 的 `dns-system` 规则含 `ping.archlinux.org` | NM 探测域名走系统解析。未验证去掉后探测是否仍判成 `portal`。 |
| 验证范围 | 仅在 `desktop.nix` 的主机生效（探测与 dispatcher 都在其中，服务器不探测）。仅在一家 Meraki 点击即过的 portal 上端到端验证；需要账号、拦截 HTTPS、丢弃外部 53 的 portal 未测。portal 按客户端 MAC 记录授权，`cloned-mac-address=random` 下每次连接都是新客户端，会被分流到店家的注册流程。 |

# sqm (`sqm.nix`)

| 项 | 事实 |
|---|---|
| 开关 | `modules.networking.sqm.enable`，`core.nix` 导入，默认关闭。 |
| 触发 | NetworkManager dispatcher 脚本 `gaming-sqm`，接口 `up` 时运行；只对 NetworkManager 管理的接口生效。 |
| WAN（上传） | `wanInterface` 上 CAKE：`diffserv4 triple-isolate wash ack-filter nat`。 |
| LAN（下载） | `lanInterface` 上 CAKE：`besteffort triple-isolate wash nat`；`lanInterface == wanInterface` 时（如单网卡 Wi-Fi）只应用 WAN 一侧。 |
| 网卡卸载 | 目标接口关闭 GRO/GSO/TSO/LRO；`wl*` 接口仅关闭 GRO。 |
| 带宽/开销 | `uploadBandwidth`/`downloadBandwidth` 为 `null` 时不传 `bandwidth`（按线速）；`overhead = 0` 时不传 `overhead`。 |
| 默认接口名 | `enp1s0`/`enp1s1` 是占位值，启用的主机须显式设置。 |

# router (`router.nix`)

| 项 | 事实 |
|---|---|
| 开关 | `modules.router.enable`（不在 `modules.networking` 下）；不由 `core.nix` 导入，主机需自行 import。 |
| WAN | `wan.interface`；`vlanId` 非空时 VLAN 接口名为 `vlan<id>`，物理口 `useDHCP=false`；可选 `mtu`、`useDHCP`。 |
| LAN | `lan.interfaces` 全部加入 `firewall.trustedInterfaces`；仅第一个接口配置 `ipv4Address`/`ipv4PrefixLength`（默认 `192.168.10.1/24`）。 |
| DHCP | `dhcp.enable`：dnsmasq 仅做 DHCP/RA（`port=0`，不提供 DNS），绑定第一个 LAN 接口，默认范围 `<LAN 前缀>.10,.100,24h`；`port=0` 时 dnsmasq 不会把自己通告为 DNS，故显式下发 `option:dns-server,<lan.ipv4Address>`（指向本机解析器）；关闭 `resolved`。 |
| NAT | `nat.enable`：`networking.nat`，外部接口为 WAN（VLAN 时为 VLAN 接口）。 |
| MSS | `mssClamping.enable`：mangle `POSTROUTING` 加 `TCPMSS`；`mss = null` 时 `--clamp-mss-to-pmtu`。 |
| 断言 | DHCP 或 NAT 启用时 `lan.interfaces` 不能为空。 |
| sysctl/tuned | `ip_forward` 及 IPv6 forwarding 置 1（`mkOverride 950`）；tuned profile `network-latency`（`mkOverride 900`，仍可被 `modules.server.tunedProfile` 覆盖）；`checkReversePath` 为 `mkDefault false`。 |

# tailscale（官方客户端：`rpi4-switch`、`oci`）

| 项 | 事实 |
|---|---|
| `rpi4-switch` 子网路由器 | `services.tailscale`：`extraUpFlags` 只在登录时运行，所以只放 `--login-server`；`--advertise-routes=192.168.10.0/24` 和 `--accept-dns=false` 放 `extraSetFlags`（每次启动重放）；`useRoutingFeatures = "server"` 显式声明转发。路由要在 headscale 里 `approve-routes`。 |
| `rpi4-switch` 防火墙 | 对 WAN 放行 TCP 22、UDP 41641（`openFirewall`）；LAN 接口信任。tailnet 入站**不被** NixOS 防火墙过滤（实测：TCP 53 不在放行列表中，tailnet 内两台机器仍能连上）；暴露面靠各服务自己的认证：sshd 只认公钥、unbound 的 `access-control` 拒绝 `100.64.0.0/10`、HA 自带登录。DHCPv6 回包由 NixOS 防火墙内置规则处理，未单独声明端口。 |
| `oci` 的 `--accept-routes` | `extraSetFlags`，使 oci 能经 Pi 访问 `192.168.10.0/24`。不用 `useRoutingFeatures = "client"`：它把反向路径过滤放松为 `loose`，实测不需要。 |
| 使用方 | 在 LAN 外的节点才开 accept-routes；LAN 内节点开启会与本地网段冲突。 |
| 验证范围 | oci 到 HA（8123）、LIFX（`192.168.10.85`）、LAN 内另一台主机（22）TCP 通；手机未测。 |

# sysfs tuning (`tuning.nix`)

| 项 | 事实 |
|---|---|
| 开关 | `modules.networking.sysfsTuning.enable`，`core.nix` 导入，默认关闭。 |
| 行为 | 经 `boot.kernel.sysfs` 写 `rx-0/rps_cpus` 与 `tx-0/xps_cpus`，值为十六进制 CPU 掩码；字段为 `null` 时不写；多队列设备的其余队列不受影响。 |
| 辅助 | `discover.sh` 在目标机上扫描接口，输出 `modules.networking.sysfsTuning`/`modules.networking.sqm` 建议片段。 |

# warp (`warp.nix`)

| 项 | 事实 |
|---|---|
| 开关 | `modules.warp.enable`：启用 `services.cloudflare-warp`，MDM policy 来自 sops secret `warp_mdm`（`secrets.yaml`）。 |
| 落盘方式 | warp-svc 以 `O_NOFOLLOW` 打开 `mdm.xml`，sops 的符号链接会 `ELOOP`；`preStart` 把 secret 复制为 `/var/lib/cloudflare-warp/mdm.xml` 真实文件。 |
| 重启 | `warp_mdm` 变化时重启 `cloudflare-warp.service`。 |
| 全局隧道 | `modules.warp.fullTunnel`（默认关）：`preStart` 把 `service_mode` 强制写成 `warp`，并把 unbound 收窄到回环（WARP DNS 代理要绑 `127.0.2.2/3:53`，通配 `:53` 会冲突）。oci 共用同一 secret，不开。 |
| 与 sing-box 的关系 | 独立于 `proxy-nodes.nix` 里 sing-box 内置的 `wg-cloudflare-warp` WireGuard endpoint。 |
| 与 Tailscale 的关系 | 代理模式（`fullTunnel` 关，`warp-cli settings` 显示 `WarpProxy on port 40000`）不创建 `CloudflareWARP` 网卡、策略路由和防火墙规则，omen15 上实测 Tailscale 直连、MagicDNS、HA 都正常，sing-box 的 `🔒 zerotrust`（`127.0.0.1:40000`）经它出去 `warp=on`。全局隧道下不能共存：`inet cloudflare-warp` 的 `input`/`output` 链默认丢弃，只放行排除列表里的目的地；Tailscale 引擎的套接字绑定在物理网卡上，到对端公网地址和 DERP 的包被丢弃，只有控制面经隧道登录成功，数据面不通。同时 WARP 把 `/etc/resolv.conf` 改成 `127.0.2.2/3`，绕过 unbound，MagicDNS 失效。想共存需要把所有对端公网地址加进排除列表，不可行。 |
