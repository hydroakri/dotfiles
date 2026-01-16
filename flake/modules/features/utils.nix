{ config, lib, pkgs, ... }: {
  environment.systemPackages = with pkgs; [
    ## GPU / display tools
    nvtopPackages.full
    virtualglLib
    vulkan-tools
    libva-utils
    vdpauinfo
    read-edid
    clinfo
  ];

  # Glance Dashboard
  services.glance = {
    enable = true;
    settings = {
      server.port = 8080;
      pages = [{
        name = "HOME";
        head-widgets = [{
          type = "markets";
          hide-header = true;
          markets = [
            {
              symbol = "VT";
              name = "Vanguard Total World Stock ETF";
            }
            {
              symbol = "RLY";
              name = "SPDR SSgA Multi Asset Real Return";
            }
            {
              symbol = "IAU";
              name = "iShares Gold Trust";
            }
            {
              symbol = "BLOK";
              name = "Amplify Transformational Data Sharing";
            }
          ];
        }];
        columns = [
          # --- 左侧列 (Small)：侧重基础状态 ---
          {
            size = "small";
            widgets = [
              {
                type = "clock";
                hour-format = "24h";
                timezones = [
                  {
                    timezone = "Asia/Shanghai";
                    label = "上海";
                  }
                  {
                    timezone = "Pacific/Auckland";
                    label = "奥克兰";
                  }
                  {
                    timezone = "UTC";
                    label = "UTC";
                  }
                ];
              }
              { type = "to-do"; }
              {
                type = "monitor";
                title = "服务器状态";
                cache = "1m";
                sites = [{
                  title = "本地网关";
                  url = "http://192.168.1.1";
                }];
              }
              {
                type = "custom-api";
                title = "网络信息";
                url = "http://ip-api.com/json/?fields=66842623";
                template = ''
                  <div class="text-center"><p class="size-h3 color-highlight">{{ .JSON.String "query" }}</p><p class="size-h5 color-paragraph">{{ .JSON.String "country" }}, {{ .JSON.String "city" }}</p><p class="size-h6">{{ if .JSON.Bool "proxy" }}🔒 代理IP{{ else if .JSON.Bool "hosting" }}🏢 机房IP{{ else if .JSON.Bool "mobile" }}📱 移动网络{{ else }}🌐 普通IP{{ end }}</p></div>'';
                cache = "10m";
              }

            ];
          }
          # --- 中间列 (Full)：侧重高频动态 ---
          {
            size = "full";
            widgets = [
              {
                type = "videos";
                channels = [
                  "UC-BIyaiQIzNbjXErkDRCqXg"
                  "UC-n-FpWhpk5cv-2044PIU_g"
                  "UC-t6DMSwK9Kc47IWs2swwBA"
                  "UC0f7e3u5VIwmVbrdOVtM5WA"
                  "UC1JPearb-Tq29F-u-pxkLcQ"
                  "UC1sELGmy5jp5fQUugmuYlXQ"
                  "UC1zTj3xDI7gFJQ0wRPcDyQg"
                  "UC29ju8bIPH5as8OGnQzwJyA"
                  "UC2BuACLVtgKb64cU0djdbMA"
                  "UC2PA-AKmVpU6NKCGtZq_rKQ"
                  "UC2QrsAs1AKG4w2v0950SC2A"
                  "UC2_KC8lshtCyiLApy27raYw"
                  "UC2cRwTuSWxxEtrRnT4lrlQA"
                  "UC2mGo21mnwmS8J1o91aqmfw"
                  "UC2nyigZS5YNDrCu_pih809w"
                  "UC39W_uzNjIAIYrimiKkI-rA"
                  "UC3qgjH4tGNRRNlLJfAZUL0w"
                  "UC3zFGcHKdhJZNNNaRqARpKA"
                  "UC4ChspfTaiJcoHEs5b8_3IQ"
                  "UC4EY_qnSeAP1xGsh61eOoJA"
                  "UC4a-Gbdw7vOaccHmFo40b9g"
                  "UC4dtpugIYK56S_7btf5a-iQ"
                  "UC55ahPQ7m5iJdVWcOfmuE6g"
                  "UC5C0MQOXtcbnB9MdTFloLWQ"
                  "UC614x0I8Wl2FPE6D7-6yi3g"
                  "UC65anu-Q6DNNlipYi16nhcQ"
                  "UC6IyQe1xdQBZvoqwW_V7W1A"
                  "UC738SsV6BSLUVvMgKnEFFzQ"
                  "UC7HAs-KXdXoQpE5RmJVqpNw"
                  "UC7X-DYBtOSAmElgBcKqO-MA"
                  "UC7q-GcHyjCHkTpXCUTLzy7Q"
                  "UC8AqU0oVyRbJ0Rjf1f9_ykw"
                  "UC93lgNP1tEMx1Xfpz_m30zA"
                  "UC9NiZGryFKHPtHsXiXaZcyA"
                  "UC9XFvuObhfVUNAGNcH8Y_fw"
                  "UC9dET9O6PkG2yzXGttwdk0w"
                  "UCAJWS2uGiiWWl9BOpKfzn9g"
                  "UCAZqVGCUyiEBNopy7EloMTw"
                  "UCAuUUnT6oDeKwE6v1NGQxug"
                  "UCBJycsmduvYEL83R_U4JriQ"
                  "UCBYlEnfAUbrYSwF0VujcmHA"
                  "UCBo8Ygnvu36nyd2xlWD5amw"
                  "UCC9X5bLhdMeLvPxlMb-GShw"
                  "UCCbYWuRvD2q_3qSla1gNHtg"
                  "UCCrB7cG9UehkwAPnXCHI1-Q"
                  "UCD-8FUA2E1FrNYxdA2QUP7Q"
                  "UCD6ERRdXrF2IZ0R888G8PQg"
                  "UCD9z9Ivxok-ArVoXosFFoEw"
                  "UCDB2ufiNNGjTHXGaaaSzJuA"
                  "UCDSfasZ89XVcx2J-MiuQmfA"
                  "UCDs3DFSjd_iCNi68rGdOKlA"
                  "UCE1jXbVAGJQEORz9nZqb5bQ"
                  "UCEBb1b_L6zDS3xTUrIALZOw"
                  "UCEa46rlHqEP6ClWitFd2QOQ"
                  "UCF7IkcI5JK-mxFttzwh0qbQ"
                  "UCFNi4WrbQu2RwH049-rsnKg"
                  "UCFmL725KKPx2URVPvH3Gp8w"
                  "UCFr3sz2t3bDp6Cux08B93KQ"
                  "UCG68cfgp6T6PE5IwvEw41Nw"
                  "UCGSGPehp0RWfca-kENgBJ9Q"
                  "UCGWdpmDONq-8YgXjbiGxGcw"
                  "UCH-syFvxNpUB13Qve4-4liA"
                  "UCHG7IJuST_BXJkne-0u0Xtw"
                  "UCHaHD477h-FeBbVh9Sh7syA"
                  "UCI9DPD1b5_y7ApDJ00jdi5Q"
                  "UCIKOy_q2VWDv1vzeoi7KgNw"
                  "UCIq2xNjGAof0cCUaKbco6HQ"
                  "UCJFJuYpd7mMeC9mZVdTqV1g"
                  "UCJXuQ9aRkS_HaFEBhiHFpWw"
                  "UCJm2TgUqtK1_NLBrjNQ1P-w"
                  "UCJsUvAqDzczYv2UpFmu4PcA"
                  "UCKPpfQUSfHhesyjbskDKSEg"
                  "UCKcWSiffY8MpZ3NKav8LeRA"
                  "UCKeHU0eCkf17RdeCHB45JMw"
                  "UCKgpamMlm872zkGDcBJHYDg"
                  "UCKpA7cdEo6CL-Jcqhso2ZaQ"
                  "UCKxvHfqbjsn1xCIbDS9LEug"
                  "UCLA_DiR1FfKNvjuUpBHmylQ"
                  "UCLHmLrj4pHHg3-iBJn_CqxA"
                  "UCLXo7UDZvByw2ixzpQCufnA"
                  "UCM88mtSE0zRTn5ae4EbYcuw"
                  "UCMwo6hT5hI3R56rO2HYP-wQ"
                  "UCN9v4QG3AQEP3zuRvVs2dAg"
                  "UCNJTPOFN-13sb5JGrY1mNQg"
                  "UCNWhGAMcHXk8kys6u59Pdyg"
                  "UCNttUtm9vloDjo-a2jqkoNQ"
                  "UCO-fR0Fn04ByAiOxNYfi30A"
                  "UCOTO6JU7qJf5E-kFDam30VQ"
                  "UCP0_k4INXrwPS6HhIyYqsTg"
                  "UCP7WmQ_U4GB3K51Od9QvM0w"
                  "UCQwRlx8hVI-CFv_E-v5s84Q"
                  "UCR1D15p_vdP3HkrH8wgjQRw"
                  "UCR4ZpFWX29p4YCajQA5fcfQ"
                  "UCRQ5hDPIynJLF_Bo91OxNig"
                  "UCRcgy6GzDeccI7dkbbBna3Q"
                  "UCRhAjTliklPFJn49S5uHWUQ"
                  "UCRz3cGfqeMPSHMBN6CxKQ9w"
                  "UCS97tchJDq17Qms3cux8wcA"
                  "UCSJ4gkVC6NrvII8umztf0Ow"
                  "UCSRlfuA_jWes0VK9VoCT9Ng"
                  "UCSd6xd7dKy9mb0JhHGpyOIQ"
                  "UCTPDTL_YT2U814lFO6UNSKA"
                  "UCTTmQ3XmMA50n4L_s_WqhzA"
                  "UCUHW94eEFW7hkUMVaZz4eDg"
                  "UCUQo7nzH1sXVpzL92VesANw"
                  "UCWJUSpXVHTaHErtGWC5qPlQ"
                  "UCW_AWiDyWZqKv4RsgwR8CWg"
                  "UCWy4d8NwevueF7LilmpGARw"
                  "UCX6b17PVsYBQ0ip5gyeme-Q"
                  "UCX8fFzD1Kdi8uCSmbOce08w"
                  "UCXuqSBlHAE6Xw-yeJA0Tunw"
                  "UCYCO3Kifwg56zhus3XXiAVg"
                  "UCYO_jab_esuFRV4b17AJtAw"
                  "UCYSMmZnOy9LEy5jhEgMyddQ"
                  "UCYYovKIet5sKaudarGUneYw"
                  "UCYbH8CWlZkNgoE8EY0SoE3g"
                  "UCZCFT11CWBi3MHNlGf019nw"
                  "UCZK2sXDUx1V4UbIZxMq28Sw"
                  "UCZYTClx2T1of7BRZ86-8fow"
                  "UCZoMSO9-AOjXrbnhFMYfJXw"
                  "UCZxYILQoh2DHLWFV9M3uVzA"
                  "UC_PH4L_uvMdYElAtU7a7HjA"
                  "UC_gWocD8MIIxqnJUH_yFO4g"
                  "UC_slDWTPHflhuZqbGc8u4yA"
                  "UCavaX73lVLIMjzw3AkFm3Tw"
                  "UCax_Z-k3j1ZQTe0cKmHYRWg"
                  "UCb9j4NrCfwOZucU0VQunegA"
                  "UCbWcXB0PoqOsAvAdfzWMf0w"
                  "UCcaTUtGzOiS4cqrgtcsHYWg"
                  "UCcqwnYMIloZjFW4lQFSmyyg"
                  "UCcvjK35lDPZTlkIrrwxpepg"
                  "UCdSzqQPK8_Qs616MRdlIruw"
                  "UCdskEH0Wvm_HjRyqo3eE56A"
                  "UCePODBWlvAeiwwJrZJT_q6w"
                  "UCeUJO1H3TEXu2syfAAPjYKQ"
                  "UCeiYXex_fwgYDonaTcSIk6w"
                  "UCfSCv4pbterVjqVr_274Jgw"
                  "UCfuz6xYbYFGsWWBi3SpJI1w"
                  "UCfxzr4iHJ1ZFq7KT8bwfiBw"
                  "UCg0m_Ah8P_MQbnn77-vYnYw"
                  "UCg4c0o1_PDek1_OTiRcx2Xg"
                  "UCg9isnie-qBpPIWx4ZQOnJw"
                  "UCgUBjMqA_IZQVFdEElvPHDA"
                  "UCgfr45LK6VTcuuMVBHsiNnQ"
                  "UCgpnsxOqYatUDxqbs27hUdA"
                  "UCh4QrR5V6reIojGpRqkTbYw"
                  "UChXogayC52mlROq-N71_f5g"
                  "UChoqx8sV1o85klBNd7P1F-Q"
                  "UCi0goGQAa-N-qe9RWEiV_Vw"
                  "UCi6kbBNPjb7F-6LcHqUdTiA"
                  "UCiVm8XcbwS8-pcDEa5lFXIA"
                  "UCiZ-6w3wrwzYxDJd9Sy9VaQ"
                  "UCiZelWeY2cK4tKIfL70cppQ"
                  "UCilwQlk62k1z7aUEZPOB6yw"
                  "UCioZY1p0bZ4Xt-yodw8_cBQ"
                  "UCipD9Goc1blLBAW47w5wY7w"
                  "UCjKfaVS0EIQJs_prvmJTejA"
                  "UCjZQeIkmhbDXP-p6gYsLVYQ"
                  "UCjrP2TtSTifuRJ76hW2IW1A"
                  "UCjuNibFJ21MiSNpu8LZyV4w"
                  "UCjzHeG1KWoonmf9d5KBvSiw"
                  "UCk5SkNarfq9PfSwK90p1wIQ"
                  "UClyILbLldDzuh5crrgjbLHw"
                  "UCmEmX_jw_pRp5UbAdzkZq-g"
                  "UCmFEiPxlciqBmo-gfj7_BXg"
                  "UCmHdZhIk3zxkdKT8eX79eVQ"
                  "UCmkDV-GNR8oOo1ObywtxirA"
                  "UCnb3P7DG_w4dJDdZXj9n4gA"
                  "UCnzRu7YFPdvbjvF4dNwUTRw"
                  "UCoH34ICdyyRO9C88UJOEvow"
                  "UCoLf5AwBPcqhrmjDZEYQshw"
                  "UCq5PgBpw8MwBIZm2kGUML8Q"
                  "UCq8580hTB9KZEWMIYxge9vw"
                  "UCqJ5EkPzmVHTTrrHtmgWeeg"
                  "UCqYPhGiB9tkShZorfgcL2lA"
                  "UCqarYgBUlIZvANPRGLYU0rA"
                  "UCqhnX4jA0A5paNd1v-zEysw"
                  "UCqlQ5ErufqtQUhkuKj1xngg"
                  "UCrMePiHCWG4Vwqv3t7W9EFg"
                  "UCrP5zVF2JAaaFDcdkJueYAw"
                  "UCryXVOK6Ebrtfrxom16qWdA"
                  "UCsG5Ku6sdc-VcWe-hDrs1Fg"
                  "UCsRF06lSFA8zV9L8_x9jzIA"
                  "UCskWC_sPuP7fr-h0Bz7O36Q"
                  "UCtYKe7-XbaDjpUwcU5x0bLg"
                  "UCteP4dGuFeam_i5FnVQNvlA"
                  "UCu43-Z2zSQDC0zOg50U0KEQ"
                  "UCuAWs9GxuTDLNyo2-cbrwDA"
                  "UCue0AhOm8SARARIcT-0mE1w"
                  "UCvQECJukTDE2i6aCoMnS-Vg"
                  "UCvg_4SPPEZ7y4pk_iB7z6sw"
                  "UCvqg0fyR1cE_PsuFEgKJpgg"
                  "UCvqzioHYJNDMclUJBVXV-7g"
                  "UCwWxTMOJjg_IhKb7ma9jyog"
                  "UCwkhE7KiGdgqq25etJT3ekw"
                  "UCxKpoGtfQmlAFl_QuFoxYNA"
                  "UCy_hCDPedZyZI_czO3T6ROg"
                  "UCyyOZFXRsPN5YejKZvruyAw"
                  "UCyyZmjaoQtONBvxlyb-TJOw"
                  "UCz0ONCn6eRcDJGsUzupc3TA"
                  "UCzGEGjOCbgv9z9SF71QyI7g"
                ];
              }
              # 使用并排显示

              {
                type = "group";
                widgets = [
                  {
                    type = "custom-api";
                    title = "Trending News on Mastodon";
                    cache = "24h";
                    url = "https://mastodon.social/api/v1/trends/links";
                    template = ''
                      <ul class="list list-gap-10 collapsible-container" data-collapse-after="5">
                        {{ range .JSON.Array "" }}
                          <li>
                            <a class="size-title-dynamic color-primary-if-not-visited" href="{{ .String "url" }}">{{ .String "title" }}</a>
                            <ul class="list-horizontal-text">
                              <li>
                                {{ .String "provider_name" }}
                                {{ if and (.String "author_url") (.String "author_name") }}
                                  - <a class="visited-indicator" href="{{ .String "author_url" }}">{{ .String "author_name" }}</a>
                                {{ end }}
                              </li>
                              <li>
                                {{ .String "description" }}
                              </li>
                            </ul>
                          </li>
                        {{ end }}
                      </ul>
                    '';
                  }
                  {
                    type = "rss";
                    title = "RSS";
                    feeds = [
                      {
                        url = "https://sspai.com/feed";
                        title = "少数派";
                      }
                      {
                        url = "https://aeon.co/feed.rss";
                        title = "Aeon.co";
                      }
                      {
                        url = "https://linux.do/posts.rss";
                        title = "Linux.do";
                      }
                      {
                        url = "https://www.therobotreport.com/feed";
                        title = "The Robot Report";
                      }
                      {
                        url = "https://arxiv.org/rss/cs.RO";
                        title = "Robotics arxiv";
                      }
                      {
                        url = "https://www.laphamsquarterly.org/rss.xml";
                        title = "Lapham’s Daily";
                      }
                    ];
                  }

                ];
              }
              {
                type = "split-column";
                widgets = [
                  {
                    type = "custom-api";
                    title = "Trending Repositories";
                    cache = "24h";
                    url =
                      "https://api.ossinsight.io/v1/trends/repos/?period=past_week&language=All";
                    template = ''
                      <ul class="list list-gap-10 collapsible-container" data-collapse-after="3">
                        {{ range .JSON.Array "data.rows"}}
                          <li>
                            <a class="color-primary-if-not-visited" href="https://github.com/{{ .String "repo_name" }}">{{ .String "repo_name" }}</a>
                            <ul class="list-horizontal-text">
                                <li class="color-highlight"> {{.String "primary_language"}} </li>

                                <li style="display: flex; align-items: center;gap: 4px;">
                                  {{ .Int "stars" }}
                                  <svg xmlns="http://www.w3.org/2000/svg" width="10" height="10" fill="currentColor" viewBox="0 0 16 16" aria-hidden="true" focusable="false">
                                    <path d="M3.612 15.443c-.386.198-.824-.149-.746-.592l.83-4.73L.173 6.765c-.329-.314-.158-.888.283-.95l4.898-.696L7.538.792c.197-.39.73-.39.927 0l2.184 4.327 4.898.696c.441.062.612.636.282.95l-3.522 3.356.83 4.73c.078.443-.36.79-.746.592L8 13.187l-4.389 2.256z"/>
                                  </svg>
                                </li>

                                <li style="display: flex; align-items: center;gap: 4px;">
                                  {{ .Int "forks" }}
                                  <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true" focusable="false">
                                    <path stroke="none" d="M0 0h24v24H0z" fill="none"/>
                                    <circle cx="12" cy="18" r="2" />
                                    <circle cx="7" cy="6" r="2" />
                                    <circle cx="17" cy="6" r="2" />
                                    <path d="M7 8v2a2 2 0 0 0 2 2h6a2 2 0 0 0 2 -2v-2" />
                                    <path d="M12 12l0 4" />
                                  </svg>
                                </li>

                                <li style="display: flex; align-items: center;gap: 4px;">
                                  {{ .Int "pull_requests" }}
                                  <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true" focusable="false">
                                    <circle cx="6" cy="6" r="3"></circle>
                                    <circle cx="18" cy="18" r="3"></circle>
                                    <path d="M13 6h3a2 2 0 0 1 2 2v7"></path>
                                    <line x1="6" y1="9" x2="6" y2="21"></line>
                                  </svg>
                                </li>

                            </ul>
                            <ul class="list collapsible-container">
                              <li style="white-space: nowrap; overflow: hidden; text-overflow: ellipsis;" class="color-subdue">
                                Contributors: {{ .String "contributor_logins"}}
                              </li>
                              <li>
                                {{ .String "description" }}
                              </li>
                            </ul>
                          </li>
                        {{ end }}
                      </ul>
                    '';
                  }
                  {
                    type = "custom-api";
                    title = "Steam Specials";
                    cache = "12h";
                    url =
                      "https://store.steampowered.com/api/featuredcategories?cc=my";
                    template = ''
                      <ul class="list list-gap-10 collapsible-container" data-collapse-after="5">
                      {{ range .JSON.Array "specials.items" }}
                        {{ $header := .String "header_image" }}
                        {{ $urlPrefix := "https://store.steampowered.com/sub/" }}
                        {{ if findMatch "/steam/apps/" $header }}
                          {{ $urlPrefix = "https://store.steampowered.com/app/" }}
                        {{ end }}
                        <li>
                          <a class="size-h4 color-highlight block text-truncate" href="{{ $urlPrefix }}{{ .Int "id" }}/">{{ .String "name" }}</a>
                          <ul class="list-horizontal-text">
                            <li>{{ .Int "final_price" | toFloat | mul 0.01 | printf "$%.2f" }}</li>
                            {{ $discount := .Int "discount_percent" }}
                            <li{{ if ge $discount 40 }} class="color-positive"{{ end }}>{{ $discount }}% off</li>
                          </ul>
                        </li>
                      {{ end }}
                      </ul>
                    '';
                  }
                  {
                    type = "custom-api";
                    title = "Steam Top Sellers";
                    cache = "12h";
                    url =
                      "https://store.steampowered.com/api/featuredcategories?cc=my";
                    template = ''
                      <ul class="list list-gap-10 collapsible-contain" data-collapse-after="15">
                          {{ range .JSON.Array "top_sellers.items" }}
                          {{ if ne (.String "name") "Steam Deck" }}
                          <li style="display: flex; align-items: center; gap: 1rem;">
                              <img src="{{ .String "small_capsule_image" }}" alt="{{ .String "name" }}"
                                  style="width: 120px; height: auto; border-radius: 4px; flex-shrink: 0;">
                              <div style="min-width: 0;">
                                  <a class="size-h4 color-highlight text-truncate" style="display: block;"
                                      href="https://store.steampowered.com/app/{{ .Int "id" }}/">
                                      {{ .String "name" }}
                                  </a>
                                  <ul class="list-horizontal-text">
                                      <li>{{ div (.Int "final_price" | toFloat) 100 | printf "$%.2f" }}</li>
                                      {{ $discount := .Int "discount_percent" }}
                                      {{ if gt $discount 0 }}
                                      <li{{ if ge $discount 40 }} class="color-positive" {{ end }}>
                                          {{ $discount }}% off
                                    </li>
                                    {{ end }}
                                </ul>
                              </div>
                          </li>
                          {{ end }}
                          {{ end }}
                          </ul>
                    '';
                  }
                ];
              }
            ];

          }
          # --- 右侧列 (Small)：侧重个人日程 & 订阅 ---
          {
            size = "small";
            widgets = [
              {
                type = "weather";
                location = "Hangzhou, China";
                units = "metric";
              }
              {
                type = "custom-api";
                title = "Last.fm";
                cache = "60s";
                url = "http://ws.audioscrobbler.com/2.0/";
                parameters = {
                  method = "user.getRecentTracks";
                  user = "\${LASTFM_USERNAME}";
                  api_key = "\${LASTFM_API_KEY}";
                  format = "json";
                  limit = "10";
                };
                template = ''
                  <ul class="list list-gap-10 collapsible-container" data-collapse-after="5">
                    {{ range .JSON.Array "recenttracks.track" }}
                      <li class="flex items-center gap-10">
                        <div style="border-radius: 5px; min-width: 5rem; max-width: 5rem; overflow: hidden;" class="card">
                          <object data={{ .String "image.2.#text" }} type="image/png">
                            <img src="https://lastfm.freetls.fastly.net/i/u/174s/2a96cbd8b46e442fc41c2b86b821562f.png" alt="Fallback">
                          </object>
                        </div>
                        <div class="flex-1">
                          <p class="color-positive size-h5">{{ .String "artist.#text" }}</p>
                          <p class="size-h5">{{ .String "name" }}</p>
                          <p class="size-h6">
                            {{ if .String "@attr.nowplaying" }}
                              <span class="color-positive">Now playing</span>
                            {{ else }}
                              <span class="color-subdue" {{ .String "date.#text" | parseRelativeTime "02 Jan 2006, 15:04" }}></span>
                            {{ end }}
                          </p>
                        </div>
                      </li>
                    {{ end }}
                  </ul>
                '';
              }

            ];
          }
        ];
      }];
    };
  };

  # Configure systemd service to inject secrets into glance config
  systemd.services.glance = {
    serviceConfig = {
      EnvironmentFile = lib.mkForce config.sops.templates."lastfm-env".path;
    };
  };
}
