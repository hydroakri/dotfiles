# Sources, derivations and assumptions for the numbers below: home-assistant/README.md
{ config, lib, ... }:
let
  cfg = config.modules.homeAssistant;
  inherit (lib) mkOption types;
  inherit (cfg) lamp;
  tm = cfg.timing;
  num = types.numbers.positive;

  # Brightness limits from geometry: eye illuminance per lumen = direct (intensity / distance^2, looking at the lamp) + room bounce.
  intensityPerLumen = lamp.downwardFraction * 1.0 / lamp.beamSolidAngleSr;
  bounce = lamp.utilisation * 1.0 / lamp.roomAreaM2;
  luxPerLumen =
    eye:
    let
      dz = lamp.ceilingHeightM - eye;
    in
    intensityPerLumen / (dz * dz + lamp.horizontalOffsetM * lamp.horizontalOffsetM) + bounce;
  maxFraction = limit: eye: limit * 1.0 / (luxPerLumen eye * lamp.melanopicRatio * lamp.ratedLumens);
  clamp =
    lo: hi: x:
    lib.max lo (lib.min hi x);
  evening =
    if cfg.eveningPct != null then
      cfg.eveningPct
    else
      clamp 1 100 (builtins.floor (100 * maxFraction cfg.limits.eveningMelLux lamp.eyeHeightM.sitting));
  night =
    if cfg.nightBrightness != null then
      cfg.nightBrightness
    else
      clamp 1 255 (builtins.floor (255 * maxFraction cfg.limits.sleepMelLux lamp.eyeHeightM.lying));
  preAlarm = if cfg.preAlarmBrightness != null then cfg.preAlarmBrightness else night;
  nightPct = toString (night * 100.0 / 255.0);
  preAlarmPct = toString (preAlarm * 100.0 / 255.0);

  points =
    field: lib.concatMapStringsSep ", " (p: "(${toString p.elevation}, ${toString p.${field}})");
  ascending =
    xs:
    lib.length xs >= 2
    && lib.all (i: (lib.elemAt xs i).elevation < (lib.elemAt xs (i + 1)).elevation) (
      lib.range 0 (lib.length xs - 2)
    );

  asleep = "is_state('input_boolean.lifx_asleep', 'on')";
  preAlarmOn = "is_state('binary_sensor.lifx_pre_alarm_dawn', 'on')";

  kelvinTemplate = ''
    {% set pts = [${points "kelvin" cfg.kelvinCurve}] %}
    {% set e = state_attr('sun.sun', 'elevation') | float(-90) %}
    {% set ns = namespace(v=(pts[0][1] if e < pts[0][0] else pts[-1][1])) %}
    {% for a, b in zip(pts[:-1], pts[1:]) %}
      {% if a[0] <= e < b[0] %}
        {% set ns.v = a[1] + (b[1] - a[1]) * (e - a[0]) / (b[0] - a[0]) %}
      {% endif %}
    {% endfor %}
    {% set ns.v = [[ns.v, ${toString cfg.floorKelvin}] | max, ${toString cfg.ceilingKelvin}] | min %}
    {% if ${asleep} and not ${preAlarmOn} %}{% set ns.v = ${toString cfg.nightKelvin} %}{% endif %}
    {{ ns.v | round(0) | int }}
  '';

  # Awake: brightness follows the log illuminance of the sun at its elevation. From the earlier of sunset and eveningWindowHours before
  # sleepAt it eases (cosine) to the evening level over duskMinutes. While the sun is below the horizon and descending, next_setting is
  # tomorrow's, so today's sunset is a day earlier; only today_at depends on the configured time zone.
  # Asleep: the night level, or while the pre-alarm dawn sensor is on the sun's value capped at the pre-alarm level.
  brightnessTemplate = ''
    {% set pl = [${points "lux" cfg.luxCurve}] %}
    {% set lo = log(${toString cfg.lowLux}, 10) %}
    {% set hi = log(${toString cfg.highLux}, 10) %}
    {% set e = state_attr('sun.sun', 'elevation') | float(-90) %}
    {% set res = namespace(cur=0, sunset=0) %}
    {% for ev in [e, 0] %}
      {% set q = namespace(g=(log(pl[0][1], 10) if ev < pl[0][0] else log(pl[-1][1], 10))) %}
      {% for a, b in zip(pl[:-1], pl[1:]) %}
        {% if a[0] <= ev < b[0] %}
          {% set q.g = log(a[1], 10) + (log(b[1], 10) - log(a[1], 10)) * (ev - a[0]) / (b[0] - a[0]) %}
        {% endif %}
      {% endfor %}
      {% set p = ${toString cfg.lowPct} + (${toString cfg.highPct} - ${toString cfg.lowPct}) * ([[(q.g - lo) / (hi - lo), 0] | max, 1] | min) %}
      {% if loop.first %}{% set res.cur = p %}{% else %}{% set res.sunset = p %}{% endif %}
    {% endfor %}
    {% set ns = namespace(v=res.cur) %}
    {% set above = is_state('sun.sun', 'above_horizon') %}
    {% set nxt = as_datetime(state_attr('sun.sun', 'next_setting')) %}
    {% set sunset = nxt if above else nxt - timedelta(days=1) %}
    {% set start = [sunset, today_at('${cfg.sleepAt}') - timedelta(hours=${toString cfg.limits.eveningWindowHours})] | min %}
    {% if (not above and not state_attr('sun.sun', 'rising')) or (above and now() >= start) %}
      {% set u = [[1 - (now() - start).total_seconds() / ${toString (tm.duskMinutes * 60)}, 0] | max, 1] | min %}
      {% set top = ${toString cfg.highPct} if start < sunset else res.sunset %}
      {% set ns.v = ${toString evening} + (top - ${toString evening}) * (1 + cos(pi * (1 - u))) / 2 %}
    {% endif %}
    {% if ${asleep} %}{% set ns.v = ([res.cur, ${preAlarmPct}] | min) if ${preAlarmOn} else ${nightPct} %}{% endif %}
    {{ ns.v | round(1) }}
  '';

  # Asleep, the sun has passed dawnStartElevation and the next alarm is within alarmWindowHours: the light may start dawning.
  preAlarmTemplate =
    if cfg.nextAlarm == null then
      "{{ false }}"
    else
      ''
        {% set e = state_attr('sun.sun', 'elevation') | float(-90) %}
        {% set t = states('${cfg.nextAlarm}') %}
        {{ ${asleep} and state_attr('sun.sun', 'rising') and e >= ${toString tm.dawnStartElevation} and t not in ['unknown', 'unavailable'] and 0 < (as_datetime(t) - now()).total_seconds() < ${
          toString (tm.alarmWindowHours * 3600)
        } }}
      '';

  # An event entity fires on every event type; let the time triggers through and filter the event trigger by type.
  onlyEventType = type: {
    condition = "or";
    conditions = [
      {
        condition = "not";
        conditions = [
          {
            condition = "trigger";
            id = "event";
          }
        ];
      }
      {
        condition = "template";
        value_template = "{{ trigger.to_state.attributes.event_type == '${type}' }}";
      }
    ];
  };

  sleepSteps = lib.max 1 (tm.sleepFadeMinutes / tm.sleepStepMinutes);
  sleepStepSeconds = tm.sleepFadeMinutes * 60 / sleepSteps;
  at = t: "${t}:00";
  hhmm = types.strMatching "[0-2][0-9]:[0-5][0-9]";
  # light.turn_on takes brightness 0-255; the sensor is a percentage
  sensorBrightness = "{{ [(states('sensor.circadian_brightness') | float(1) * 255 / 100) | round(0) | int, 1] | max }}";
  sensorKelvin = "{{ states('sensor.circadian_kelvin') | int }}";
  wakeEnabled = cfg.wakeAt != null || cfg.nextAlarm != null || cfg.wakeEvent != null;
in
{
  options.modules.homeAssistant = {
    enable = lib.mkEnableOption "Home Assistant with a LIFX light that follows the sun and winds down for sleep";

    light = mkOption {
      type = types.str;
      default = "light.lifx_supercolour";
      description = "Entity ID of the bulb; shown in Settings > Devices after adding the LIFX integration.";
    };

    lamp = {
      ratedLumens = mkOption {
        type = num;
        default = 1600;
        description = "Luminous flux at 100 pct; assumed linear in the brightness setting.";
      };
      downwardFraction = mkOption {
        type = num;
        default = 0.9;
        description = "Share of the flux that reaches the room (ceiling mount: the lower hemisphere plus the ceiling bounce).";
      };
      beamSolidAngleSr = mkOption {
        type = num;
        default = 6.283185;
        description = "Solid angle the flux is spread over: 2 pi for a lower hemisphere, 4 pi for a bare bulb in free space.";
      };
      ceilingHeightM = mkOption {
        type = num;
        default = 2.4;
        description = "Height of the lamp above the floor.";
      };
      horizontalOffsetM = mkOption {
        type = types.numbers.nonnegative;
        default = 1.9;
        description = "Horizontal distance from the point below the lamp to the head.";
      };
      eyeHeightM = {
        sitting = mkOption {
          type = num;
          default = 1.1;
          description = "Eye height in the evening posture; sets the evening level.";
        };
        lying = mkOption {
          type = num;
          default = 0.7;
          description = "Eye height lying down; sets the night and pre-alarm levels.";
        };
      };
      roomAreaM2 = mkOption {
        type = num;
        default = 15;
        description = "Floor area, for the light bounced back from the room surfaces.";
      };
      utilisation = mkOption {
        type = types.numbers.nonnegative;
        default = 0.4;
        description = "Share of the flux that ends up on the room surfaces and so adds to the average illuminance.";
      };
      melanopicRatio = mkOption {
        type = num;
        default = 0.3333;
        description = "Melanopic over photopic illuminance of the light at the colour temperature in use (Brown 2022: 30 lux warm white = 10 melanopic lux).";
      };
    };

    limits = {
      eveningMelLux = mkOption {
        type = num;
        default = 10;
        description = "Melanopic lux at the eye allowed in the evening window and for night-time activity.";
      };
      sleepMelLux = mkOption {
        type = num;
        default = 1;
        description = "Melanopic lux at the eye allowed while asleep; sets the night and pre-alarm levels.";
      };
      eveningWindowHours = mkOption {
        type = num;
        default = 3;
        description = "Hours before sleepAt from which the evening limit applies.";
      };
    };

    # These three default to the level that meets the limit for the geometry above; set one to override it.
    eveningPct = mkOption {
      type = types.nullOr (types.ints.between 1 100);
      default = null;
      description = "Brightness (pct) held after the dusk ease.";
    };
    nightBrightness = mkOption {
      type = types.nullOr (types.ints.between 1 255);
      default = null;
      description = "light.turn_on brightness (0-255) at the end of the wind-down and whenever the light is on during the night.";
    };
    preAlarmBrightness = mkOption {
      type = types.nullOr (types.ints.between 1 255);
      default = null;
      description = "light.turn_on brightness (0-255) that the dawn light before an alarm never exceeds while asleep.";
    };

    sleepAt = mkOption {
      type = hhmm;
      default = "23:00";
      description = "Wind-down starts at this time when no sleepEvent has started it; also the bedtime that the evening window counts back from.";
    };
    sleepEvent = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "Event entity (Sleep as Android 'time to bed') that starts the wind-down before sleepAt.";
    };
    sleepEventType = mkOption {
      type = types.str;
      default = "time_to_bed_alarm_alert";
      description = "event_type of sleepEvent that counts; the Sleep as Android user notification entity carries several types.";
    };
    nextAlarm = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "Timestamp sensor with the next alarm (Sleep as Android 'Next alarm'); the light starts following the sun wakeLeadMinutes before it.";
    };
    wakeEvent = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "Event entity (Sleep as Android alarm) that starts the same when it fires, for alarms that nextAlarm does not cover.";
    };
    wakeEventType = mkOption {
      type = types.str;
      default = "alert_start";
      description = "event_type of wakeEvent that counts; the Sleep as Android alarm clock entity also reports snoozes and reschedules.";
    };
    wakeAt = mkOption {
      type = types.nullOr hhmm;
      default = null;
      description = "Fixed fallback wake time; null means the light only switches on for an alarm.";
    };

    timing = {
      duskMinutes = mkOption {
        type = types.ints.positive;
        default = 30;
        description = "Length of the ease down to the evening level.";
      };
      sleepFadeMinutes = mkOption {
        type = types.ints.positive;
        default = 60;
        description = "Wind-down length; brightness decays exponentially, colour temperature linearly.";
      };
      sleepStepMinutes = mkOption {
        type = types.ints.positive;
        default = 5;
        description = "Length of one wind-down step; the bulb fades linearly within a step.";
      };
      wakeLeadMinutes = mkOption {
        type = types.ints.positive;
        default = 30;
        description = "Minutes before the alarm that the pre-alarm cap is lifted and the light starts to follow the sun.";
      };
      dawnStartElevation = mkOption {
        type = types.numbers.between (-90) 90;
        default = -10;
        description = "Solar elevation (degrees) from which the light may start dawning while an alarm is pending.";
      };
      dayResetElevation = mkOption {
        type = types.numbers.between (-90) 90;
        default = 5;
        description = "Solar elevation (degrees) above which sleep mode is left even without an alarm.";
      };
      alarmWindowHours = mkOption {
        type = types.ints.positive;
        default = 12;
        description = "A next alarm further away than this does not start the dawn light.";
      };
      updateMinutes = mkOption {
        type = types.ints.positive;
        default = 2;
        description = "How often the light is set to the sun-following values.";
      };
      transitionSeconds = mkOption {
        type = types.ints.unsigned;
        default = 60;
        description = "Transition of each sun-following update.";
      };
    };

    floorKelvin = mkOption {
      type = types.ints.between 1500 9000;
      default = 2200;
      description = "Lowest colour temperature while awake.";
    };
    ceilingKelvin = mkOption {
      type = types.ints.between 1500 9000;
      default = 5000;
      description = "Highest colour temperature.";
    };
    nightKelvin = mkOption {
      type = types.ints.between 1500 9000;
      default = 1800;
      description = "Colour temperature at the end of the wind-down and during the night.";
    };

    lowLux = mkOption {
      type = num;
      default = 0.3;
      description = "Outdoor illuminance (lux) that maps to lowPct.";
    };
    highLux = mkOption {
      type = num;
      default = 3000;
      description = "Outdoor illuminance (lux) that maps to highPct.";
    };
    lowPct = mkOption {
      type = types.ints.between 1 100;
      default = 1;
      description = "Brightness at lowLux.";
    };
    highPct = mkOption {
      type = types.ints.between 1 100;
      default = 100;
      description = "Brightness at highLux and above.";
    };

    kelvinCurve = mkOption {
      description = "Direct-sun colour temperature by solar elevation (degrees), linearly interpolated, held flat outside the ends, then clipped to floorKelvin..ceilingKelvin.";
      # 5778 K blackbody through Rayleigh + aerosol (beta 0.05) attenuation at the Kasten-Young air mass; the Spitschan 2016 sky spectra
      # are bluest at low sun, so they are not used for colour.
      default = [
        {
          elevation = 2;
          kelvin = 1840;
        }
        {
          elevation = 3;
          kelvin = 2130;
        }
        {
          elevation = 5;
          kelvin = 2620;
        }
        {
          elevation = 10;
          kelvin = 3400;
        }
        {
          elevation = 15;
          kelvin = 3870;
        }
        {
          elevation = 20;
          kelvin = 4170;
        }
        {
          elevation = 30;
          kelvin = 4550;
        }
        {
          elevation = 40;
          kelvin = 4760;
        }
        {
          elevation = 50;
          kelvin = 4890;
        }
        {
          elevation = 60;
          kelvin = 4980;
        }
        {
          elevation = 90;
          kelvin = 5070;
        }
      ];
      type = types.listOf (
        types.submodule {
          options = {
            elevation = mkOption { type = types.numbers.between (-90) 90; };
            kelvin = mkOption { type = types.ints.between 1000 12000; };
          };
        }
      );
    };

    luxCurve = mkOption {
      description = "Outdoor illuminance (lux) by solar elevation (degrees); interpolated in log10 and mapped to brightness between lowLux and highLux.";
      # Median of the Spitschan 2016 rural spectra per 3 degree bin, bin centres.
      default = [
        {
          elevation = -10.5;
          lux = 0.093;
        }
        {
          elevation = -7.5;
          lux = 2.874;
        }
        {
          elevation = -4.5;
          lux = 76.9;
        }
        {
          elevation = -1.5;
          lux = 613.6;
        }
        {
          elevation = 1.5;
          lux = 1860.0;
        }
        {
          elevation = 4.5;
          lux = 3184.0;
        }
        {
          elevation = 7.5;
          lux = 4257.0;
        }
      ];
      type = types.listOf (
        types.submodule {
          options = {
            elevation = mkOption { type = types.numbers.between (-90) 90; };
            lux = mkOption { type = num; };
          };
        }
      );
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = ascending cfg.kelvinCurve && ascending cfg.luxCurve;
        message = "modules.homeAssistant.kelvinCurve and luxCurve need at least two points with strictly ascending elevation.";
      }
      {
        assertion =
          lamp.ceilingHeightM > lamp.eyeHeightM.sitting && lamp.ceilingHeightM > lamp.eyeHeightM.lying;
        message = "modules.homeAssistant.lamp.ceilingHeightM must be above both eye heights.";
      }
      {
        assertion =
          cfg.floorKelvin <= cfg.ceilingKelvin && cfg.lowLux < cfg.highLux && cfg.lowPct <= cfg.highPct;
        message = "modules.homeAssistant: floorKelvin <= ceilingKelvin, lowLux < highLux and lowPct <= highPct are required.";
      }
      {
        assertion = tm.sleepFadeMinutes >= tm.sleepStepMinutes;
        message = "modules.homeAssistant.timing.sleepFadeMinutes must be at least sleepStepMinutes.";
      }
    ];

    services.home-assistant = {
      enable = true;
      extraComponents = [
        "lifx"
        "sleep_as_android"
        "mobile_app"
      ];
      config = {
        # Any key under homeassistant: makes HA lock location, time zone and URLs in the UI; null drops the module's time_zone default.
        homeassistant.time_zone = null;
        http = { };
        frontend = { };
        sun = { };
        # the Android companion app refuses servers without it
        mobile_app = { };
        history = { };
        logbook = { };
        # sqlite on an SD card: batch commits and keep little history
        recorder = {
          commit_interval = 60;
          purge_keep_days = 3;
        };

        # Reset to off on every HA start so a restart mid-fade cannot freeze the colour updates.
        input_boolean.lifx_fading = {
          name = "LIFX fading";
          initial = false;
        };

        # Turn on to stop the automations from overriding a manual brightness or colour.
        input_boolean.lifx_manual = {
          name = "LIFX manual lock";
          initial = false;
        };

        # On from the start of the wind-down until wake; no initial so it survives a restart.
        input_boolean.lifx_asleep.name = "LIFX asleep";

        template = [
          {
            binary_sensor = [
              {
                name = "LIFX pre-alarm dawn";
                unique_id = "lifx_pre_alarm_dawn";
                state = preAlarmTemplate;
              }
            ];
          }
          {
            sensor = [
              {
                name = "Circadian Kelvin";
                unique_id = "circadian_kelvin";
                unit_of_measurement = "K";
                state = kelvinTemplate;
              }
              {
                name = "Circadian Brightness";
                unique_id = "circadian_brightness";
                unit_of_measurement = "%";
                state = brightnessTemplate;
              }
            ];
          }
        ];

        automation = [
          {
            id = "lifx_circadian";
            alias = "LIFX follow the sun";
            # Skipped during a fade, which a new colour command would cancel.
            triggers = [
              {
                trigger = "time_pattern";
                minutes = "/${toString tm.updateMinutes}";
              }
              {
                trigger = "state";
                entity_id = cfg.light;
                to = "on";
              }
            ];
            conditions = [
              {
                condition = "state";
                entity_id = cfg.light;
                state = "on";
              }
              {
                condition = "state";
                entity_id = [
                  "input_boolean.lifx_fading"
                  "input_boolean.lifx_manual"
                ];
                state = "off";
              }
            ];
            actions = [
              {
                action = "light.turn_on";
                target.entity_id = cfg.light;
                data = {
                  brightness = sensorBrightness;
                  color_temp_kelvin = sensorKelvin;
                  transition = tm.transitionSeconds;
                };
              }
            ];
          }
          {
            id = "lifx_sleep_fade";
            alias = "LIFX wind down for sleep";
            mode = "single";
            triggers = [
              {
                trigger = "time";
                at = at cfg.sleepAt;
              }
            ]
            ++ lib.optional (cfg.sleepEvent != null) {
              trigger = "state";
              id = "event";
              entity_id = cfg.sleepEvent;
            };
            conditions = [
              {
                condition = "state";
                entity_id = "input_boolean.lifx_asleep";
                state = "off";
              }
            ]
            ++ lib.optional (cfg.sleepEvent != null) (onlyEventType cfg.sleepEventType);
            actions = [
              {
                action = "input_boolean.turn_on";
                target.entity_id = [
                  "input_boolean.lifx_fading"
                  "input_boolean.lifx_asleep"
                ];
              }
              {
                "if" = [
                  {
                    condition = "state";
                    entity_id = cfg.light;
                    state = "on";
                  }
                ];
                "then" = [
                  {
                    variables = {
                      b0 = "{{ [state_attr('${cfg.light}', 'brightness') | int(${toString night}), ${toString night}] | max }}";
                      k0 = "{{ state_attr('${cfg.light}', 'color_temp_kelvin') | int(${toString cfg.floorKelvin}) }}";
                    };
                  }
                  {
                    repeat = {
                      count = sleepSteps;
                      sequence = [
                        {
                          action = "light.turn_on";
                          target.entity_id = cfg.light;
                          data = {
                            brightness = "{{ (b0 * ((${toString night} / b0) ** (repeat.index / ${toString sleepSteps}))) | round(0) | int }}";
                            color_temp_kelvin = "{{ (k0 + (${toString cfg.nightKelvin} - k0) * repeat.index / ${toString sleepSteps}) | round(0) | int }}";
                            transition = sleepStepSeconds;
                          };
                        }
                        { delay.seconds = sleepStepSeconds; }
                      ];
                    };
                  }
                  {
                    action = "light.turn_off";
                    target.entity_id = cfg.light;
                  }
                ];
              }
              {
                action = "input_boolean.turn_off";
                target.entity_id = "input_boolean.lifx_fading";
              }
            ];
          }
          {
            id = "lifx_dawn_before_alarm";
            alias = "LIFX dawn light before the alarm";
            # The binary sensor turns on once the sun passes dawnStartElevation while an alarm is pending; the circadian automation keeps it going.
            triggers = [
              {
                trigger = "state";
                entity_id = "binary_sensor.lifx_pre_alarm_dawn";
                to = "on";
              }
            ];
            conditions = [
              {
                condition = "state";
                entity_id = "input_boolean.lifx_manual";
                state = "off";
              }
            ];
            actions = [
              {
                action = "light.turn_on";
                target.entity_id = cfg.light;
                data = {
                  brightness = sensorBrightness;
                  color_temp_kelvin = sensorKelvin;
                  transition = tm.transitionSeconds;
                };
              }
            ];
          }
          {
            id = "lifx_day_reset";
            alias = "LIFX leave sleep mode in daylight";
            # Safety net for days without an alarm, so the asleep state cannot hold the light at its night level.
            triggers = [
              {
                trigger = "numeric_state";
                entity_id = "sun.sun";
                attribute = "elevation";
                above = tm.dayResetElevation;
              }
            ];
            actions = [
              {
                action = "input_boolean.turn_off";
                target.entity_id = "input_boolean.lifx_asleep";
              }
            ];
          }
        ]
        ++ lib.optional wakeEnabled {
          id = "lifx_wake_fade";
          alias = "LIFX start following the sun at wake";
          mode = "single";
          triggers =
            lib.optional (cfg.wakeAt != null) {
              trigger = "time";
              at = at cfg.wakeAt;
            }
            ++ lib.optional (cfg.nextAlarm != null) {
              trigger = "time";
              # offset is only valid inside the at: mapping that names the entity
              at = {
                entity_id = cfg.nextAlarm;
                offset = "-${lib.fixedWidthString 2 "0" (toString (tm.wakeLeadMinutes / 60))}:${
                  lib.fixedWidthString 2 "0" (toString (lib.mod tm.wakeLeadMinutes 60))
                }:00";
              };
            }
            ++ lib.optional (cfg.wakeEvent != null) {
              trigger = "state";
              id = "event";
              entity_id = cfg.wakeEvent;
            };
          conditions = lib.optional (cfg.wakeEvent != null) (onlyEventType cfg.wakeEventType);
          actions = [
            {
              action = "input_boolean.turn_off";
              target.entity_id = "input_boolean.lifx_asleep";
            }
            # let the sensors re-render with daytime values
            { delay.seconds = 2; }
            # Start from 1/255 when off so the first step does not begin at the bulb's last brightness; a dawn light already on keeps its level.
            {
              "if" = [
                {
                  condition = "state";
                  entity_id = cfg.light;
                  state = "off";
                }
              ];
              "then" = [
                {
                  action = "light.turn_on";
                  target.entity_id = cfg.light;
                  data = {
                    brightness = 1;
                    color_temp_kelvin = sensorKelvin;
                    transition = 0;
                  };
                }
              ];
            }
            # From here the circadian automation follows the sun.
            {
              action = "light.turn_on";
              target.entity_id = cfg.light;
              data = {
                brightness = sensorBrightness;
                color_temp_kelvin = sensorKelvin;
                transition = tm.transitionSeconds;
              };
            }
          ];
        };
      };
    };

    # 8123 is reachable from the LAN only: router.nix trusts the LAN interfaces and not the WAN one.
  };
}
