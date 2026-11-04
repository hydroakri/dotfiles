# home-assistant (`modules.homeAssistant`)

HA + LIFX 灯泡:亮度和色温跟随太阳高度,日落后降到晚间亮度,睡前对数衰减,夜里和闹钟前的亮度受论文上限约束。亮度上限由灯的几何位置算出,所有设计常数都是选项。数值的来源和假设都在这里;`derive_curve.py` 可重新生成。

## 来源

| 来源 | 内容 | 用在 | 核对状态 |
|---|---|---|---|
| Spitschan, Aguirre, Brainard, Sweeney, Sci Rep 6:26756 (doi:10.1038/srep26756, PMC4895134);数据和 MATLAB 代码 [spitschan/IlluminationSpectraDataset](https://github.com/spitschan/IlluminationSpectraDataset)(MIT) | 乡村/城市站点的绝对光谱和太阳高度;薄暮天空光偏蓝,乡村最蓝约 -12°,城市约 -6° | `curve.brightnessPct`(照度)。不用于色温 | 乡村站点 `CSSP_spectra.csv` 已下载并计算。勘误 doi:10.1038/srep46930 未核对 |
| Brown et al., PLOS Biol 20(3):e3001571 (doi:10.1371/journal.pbio.3001571, PMC8929548) | 眼睛处(垂直面,约 1.2 m)黑视素等效照度:白天 ≥250 lx;睡前至少 3 h 起 ≤10 lx;睡眠环境 ≤1 lx;夜间活动 ≤10 lx。暖白 LED(2700–3000K)约 30 lx 即满足 10 lx | `limits.*`、`lamp.melanopicRatio`、晚间窗口 | 建议部分已读(正文前约一半)。0.33 由"30 lx 对应 10 lx"推出,2200K 和 1800K 未单独计算 |
| Zeitzer et al., J Physiol 2000(夜间光对人体生物钟的敏感性) | 褪黑素抑制和相位延迟随光强呈 logistic 剂量-反应,约 100 lx 为一半效应 | 睡前衰减按对数等比下降 | 仅读摘要和二手引用 |
| Kasten & Young 1989(大气质量);Kasten 1980(瑞利光学厚度 0.008735·λ^-4.08 μm);Ångström 气溶胶 | 直射太阳光色随太阳高度 | `curve.kelvin` | 公式系数按记忆写入,未对照原文。气溶胶 β=0.05、α=1.3 是假设 |
| Wyman, Sloan, Shirley 2013(CIE 1931 色匹配函数解析拟合) | 光谱到 xy | `derive_curve.py` | 按记忆写入。自检:D65→6500K、D55→5490K、光源 A→2830K(标称 2856K) |
| [Sleep as Android 集成文档](https://www.home-assistant.io/integrations/sleep_as_android/) | 传输为 webhook(Local Push),应用不重试;提供"下一次闹钟"传感器和闹钟、该睡觉了、睡眠追踪等事件实体;不能反向控制应用 | `sleepEvent`、`nextAlarm`、`wakeEvent` | 文档已读。实体 ID 要在 UI 里添加集成后才知道 |
| BRANZ 指南(2017)引文;BRANZ Build 166 | 新房最低层高 2.4 m、旧房 2.1 m;NZS 3604:2011 不规定墙筋高度 | 几何计算取 2.4 m | 各来源对出处说法不一致,2.4 m 是假设 |
| Hernández-Andrés, Lee, Romero, Appl Opt 38:5703(1999);Ratnasingam et al., EURASIP JIVP 2013:14 | 天光 CCT 公式;CCT 与太阳高度、时段相关 | 未采用 | 前者早期用于交叉验证,后者只取到摘要,无公式 |
| [ESPectre](https://github.com/francescopace/espectre) | Wi-Fi CSI 只报告运动,不证明房间无人 | 存在检测暂缓 | 仅读项目页 |

## 参数与依据

下面都是 `modules.homeAssistant` 的选项,表里是默认值。设计常数和几何输入都可以改,亮度上限由几何和限值算出。

| 选项 | 默认值 | 依据 |
|---|---|---|
| `luxCurve` | -10.5°:0.093、-7.5°:2.874、-4.5°:76.9、-1.5°:613.6、1.5°:1860、4.5°:3184、7.5°:4257 lx | 乡村站点各 3° 箱的照度中位数(`derive_curve.py spectra`) |
| `lowLux`、`highLux`、`lowPct`、`highPct` | 0.3 lx、3000 lx、1%、100% | 设计选择:照度取 log10 后线性映射到亮度(`derive_curve.py brightness`) |
| `kelvinCurve` | 2°:1840、3°:2130、5°:2620、10°:3400、20°:4170、30°:4550、40°:4760、60°:4980、90°:5070 | 5778K 黑体经瑞利+气溶胶衰减,晴天 β=0.05(`derive_curve.py sun`) |
| `floorKelvin`、`ceilingKelvin`、`nightKelvin` | 2200、5000、1800 | 设计选择 |
| `limits.eveningMelLux`、`limits.sleepMelLux`、`limits.eveningWindowHours` | 10、1、3 | Brown 2022:睡前至少 3 h 起 ≤10 lx,睡眠 ≤1 lx,夜间活动 ≤10 lx |
| `eveningPct` | 空 = 由几何算出(34) | 坐姿眼睛处黑视素等效照度 ≤`eveningMelLux` |
| `nightBrightness`、`preAlarmBrightness` | 空 = 由几何算出(9/255,约 3.5%) | 躺姿眼睛处黑视素等效照度 ≤`sleepMelLux` |
| `sleepAt` | 23:00 | 用户作息;也是晚间窗口倒推的起点 |
| `timing.duskMinutes`、`sleepFadeMinutes`、`sleepStepMinutes`、`wakeLeadMinutes` | 30、60、5、30 | 设计选择。对数等比衰减参考 Zeitzer 的对数剂量-反应 |
| `timing.dawnStartElevation`、`dayResetElevation`、`alarmWindowHours`、`updateMinutes`、`transitionSeconds` | -10°、5°、12 h、2 min、60 s | 设计选择。-10° 是 `luxCurve` 亮度降到下限的位置 |

## 亮度上限的公式

眼睛处每流明的光照度 = 直射 + 房间反射:

    E/Φ = downwardFraction / beamSolidAngleSr / (dz² + horizontalOffsetM²) + utilisation / roomAreaM2
    dz = ceilingHeightM − eyeHeightM

直射按"眼睛看着灯"取最坏情况。允许的亮度比例 = 限值 ÷ (E/Φ × melanopicRatio × ratedLumens)。亮度与光输出线性。`evening` 用坐姿眼高,`night` 和 `preAlarm` 用躺姿眼高;结果向下取整。

| 输入 | 默认值 | 来源 |
|---|---|---|
| `ceilingHeightM` | 2.4 m | 用户。新西兰新房最低层高 2.4 m(见来源表) |
| `horizontalOffsetM` | 1.9 m | 用户:灯在床尾,到睡觉时头部的水平距离 |
| `eyeHeightM.sitting`、`.lying` | 1.1 m、0.7 m | 假设。晚间姿势取与睡觉时同一水平位置 |
| `roomAreaM2`、`utilisation` | 15 m²、0.4 | 假设 |
| `downwardFraction`、`beamSolidAngleSr` | 0.9、2π sr | 假设:天花板灯座,光向下半球输出,含天花板反射 |
| `melanopicRatio` | 0.3333 | Brown 2022:暖白约 30 lx 对应 10 lx 黑视素 |
| `ratedLumens` | 1600 | 型号名 `Color 1600` 推测 |

| 姿势 | 眼高 | E/Φ | 10 lx 对应最大亮度 | 1 lx 对应最大亮度 |
|---|---|---|---|---|
| 坐 | 1.1 m | 0.0537 lx/lm | 559 lm(34.9%) | 56 lm(3.5%,8.9/255) |
| 躺 | 0.7 m | 0.0487 | 616 lm(38.5%) | 62 lm(3.9%,9.8/255) |

| 亮度 | 光通量 | 坐 黑视素 lx | 躺 黑视素 lx |
|---|---|---|---|
| 100% | 1600 lm | 28.6 | 26.0 |
| 34% | 544 lm | 9.7 | 8.8 |
| 25% | 400 lm | 7.2 | 6.5 |
| 15% | 240 lm | 4.3 | 3.9 |
| 3.5% | 56 lm | 1.0 | 0.9 |
| 0.4%(1/255) | 6 lm | 0.1 | 0.1 |

## Spitschan 数据的范围

| 项 | 事实 |
|---|---|
| 站点和时间 | 乡村站点 CSSP(Cherry Springs State Park,美国宾州,N41.7),2014 年 6–7 月;有效光谱 3192 条,脚本用 2580 条(去掉含 NaN 的) |
| 覆盖 | 主要是黄昏和夜间。太阳高度 9° 到 24° 之间没有数据,24° 以上只有 1 条 |
| 低太阳高度 | 全天空光 CCT 在 0° 到 9° 约 8300–9300K,比正午冷;-12° 到 -6° 已离开普朗克轨迹,CCT 无意义 |
| 夜间 | 低于 -18° 的 CCT 约 3800–5400K,照度约 0.001 lx,属仪器和天空辉光底噪 |
| 单位 | 按 W m⁻² nm⁻¹ 计算照度。-6° 和 -12° 附近的结果与常用的曙暮光参考照度同量级(参考值未核对来源) |

## 未验证

| 项 | 说明 |
|---|---|
| LIFX 亮度到光输出的线性 | 未知,需用照度计在眼睛位置实测 100%、34%、3.5% 并校准 |
| 黑视素/光照度 0.3333 | 取自暖白 2700–3000K;2200K 和 1800K 应更低,未计算 |
| 房间几何 | 层高和水平距离由用户给出;眼高、房间面积、利用系数、配光是假设 |
| 额定 1600 lm | 由型号名 `Color 1600` 推测,2200K 下实际更低 |
| 闭眼时的眼睑衰减 | 未采用 |

## 复现

```bash
curl -LO https://raw.githubusercontent.com/spitschan/IlluminationSpectraDataset/master/data/CSSP_spectra.csv
python3 -I derive_curve.py spectra CSSP_spectra.csv
python3 -I derive_curve.py sun
python3 -I derive_curve.py brightness
python3 -I derive_curve.py ceiling
```

## 校验配置

`nix eval` 只说明 Nix 能渲染出结构,不检查 HA 的 schema。`check_config.sh` 在 x86 上用 HA 自己的 `check_config` 校验主机的完整配置,不构建 arm64:

```bash
flake/modules/features/home-assistant/check_config.sh [host]
```

它能抓到 schema 错误,例如时间触发的 `offset` 不能和 `at` 平级(报 `extra keys not allowed @ data['offset']`)。它不检查模板运行时的行为;`frontend`、`openai`、`Pillow` 的依赖警告来自最小化的 Python 环境,与配置无关。

