#!/usr/bin/env bash
# Run directly on the target machine (sudo recommended). Scans network
# interfaces and suggests networking.sysfsTuning / networking.sqm settings.
# Usage: ssh host 'bash -s' < discover.sh   or copy it over and run locally.
set -euo pipefail

have() { command -v "$1" >/dev/null 2>&1; }

if ! have ethtool || ! have ip; then
  echo "Needs ethtool and iproute2: nix-shell -p ethtool iproute2 --run bash" >&2
  exit 1
fi

NPROC=$(nproc)
FULL_MASK=$(printf '%x' $(((1 << NPROC) - 1)))
NO_CPU0_MASK=$(printf '%x' $((((1 << NPROC) - 1) & ~1)))

echo "# CPUs: ${NPROC} | full mask=${FULL_MASK} | cpu0-excluded mask=${NO_CPU0_MASK}"
echo "# (xps_cpus writes on single-queue NICs are rejected by the kernel with ENOENT; those are skipped automatically)"
echo

default_iface=$(ip -4 route show default 2>/dev/null | awk '/^default/ {print $5; exit}')

sqm_snippet=""
tuning_lines=""

for ifpath in /sys/class/net/*; do
  iface=$(basename "$ifpath")

  case "$iface" in
  lo | docker* | veth* | virbr* | br-* | tailscale* | wg* | tun* | tap* | ppp* | vnet* | zt*)
    continue
    ;;
  esac

  operstate=$(cat "$ifpath/operstate" 2>/dev/null || echo unknown)
  driver="?"
  [ -e "$ifpath/device/driver" ] && driver=$(basename "$(readlink -f "$ifpath/device/driver")")
  is_usb="no"
  [ -e "$ifpath/device" ] && case "$(readlink -f "$ifpath/device")" in */usb*) is_usb="yes" ;; esac
  is_wireless="no"
  [ -d "$ifpath/wireless" ] && is_wireless="yes"

  rx_q=$(find "$ifpath/queues" -maxdepth 1 -name 'rx-*' 2>/dev/null | wc -l)
  tx_q=$(find "$ifpath/queues" -maxdepth 1 -name 'tx-*' 2>/dev/null | wc -l)

  speed="n/a"
  if [ "$operstate" = "up" ] && [ "$is_wireless" = "no" ]; then
    speed=$(ethtool "$iface" 2>/dev/null | awk -F': ' '/Speed:/ {print $2}')
    [ -z "$speed" ] && speed="n/a"
  fi

  is_virtual="no"
  [ -e "$ifpath/device" ] || is_virtual="yes"
  lower_iface=""
  for l in "$ifpath"/lower_*; do
    [ -e "$l" ] && lower_iface=$(basename "$l" | sed 's/^lower_//')
  done

  role="-"
  [ "$iface" = "$default_iface" ] && role="WAN candidate (default route)"

  echo "## $iface"
  echo "  state=$operstate driver=$driver usb=$is_usb wireless=$is_wireless speed=$speed role=$role"
  echo "  queues: rx=$rx_q tx=$tx_q"

  skip_reason=""
  if [ "$is_virtual" = "yes" ]; then
    skip_reason="software interface (VLAN/bridge/etc), no queue/interrupt of its own to steer -- RPS on it is a no-op, steering already happened on the physical device"
    [ -n "$lower_iface" ] && skip_reason="$skip_reason ($lower_iface)"
  fi

  if [ -n "$skip_reason" ]; then
    echo "  skip rps_cpus/xps_cpus: $skip_reason"
  else
    if [ "$operstate" != "up" ]; then
      echo "  note: interface is currently down -- could just be an unplugged cable (still worth configuring,"
      echo "        e.g. a dock/switch port that comes up later) or a genuinely unused/disabled device (skip it)."
      echo "        sysfs can't tell these apart; use your judgment before including it below."
    fi
    # rps_cpus: works regardless of queue count, suggest full mask or cpu0-excluded
    echo "  suggest rps_cpus = \"$FULL_MASK\"; # all CPUs; use \"$NO_CPU0_MASK\" to leave cpu0 for interrupts"

    # xps_cpus: kernel returns ENOENT unconditionally for single-tx-queue devices, don't set it
    if [ "$tx_q" -le 1 ]; then
      echo "  skip xps_cpus: single tx queue (tx_q=$tx_q); kernel's xps_cpus_store() returns ENOENT for non-multiqueue devices, setting it would show up as a failed unit on switch"
    else
      echo "  suggest xps_cpus = \"$FULL_MASK\"; # ${tx_q} tx queues, multiqueue device supports it"
    fi
  fi

  if [ "$is_virtual" = "yes" ] && [ -n "$lower_iface" ]; then
    echo "  note: $iface is stacked on physical device $lower_iface; if sqm needs to shape this link,"
    echo "        cake usually belongs on $lower_iface, not on $iface (even though the default route uses $iface)"
  fi
  echo

  if [ -z "$skip_reason" ]; then
    tuning_lines="${tuning_lines}          ${iface} = {\n            rps_cpus = \"${FULL_MASK}\";\n"
    if [ "$tx_q" -gt 1 ]; then
      tuning_lines="${tuning_lines}            xps_cpus = \"${FULL_MASK}\";\n"
    fi
    tuning_lines="${tuning_lines}          };\n"
  fi

  if [ "$iface" = "$default_iface" ]; then
    if [ "$is_virtual" = "yes" ] && [ -n "$lower_iface" ]; then
      sqm_snippet="${sqm_snippet}      wanInterface = \"${lower_iface}\"; # default route uses ${iface} (VLAN), but shaping should target the physical device ${lower_iface}\n"
    else
      sqm_snippet="${sqm_snippet}      wanInterface = \"${iface}\"; # current default route egress, line rate=${speed}\n"
    fi
  elif [ "$operstate" = "up" ] && [ "$role" = "-" ]; then
    sqm_snippet="${sqm_snippet}      # lanInterface candidate: ${iface} (line rate=${speed})\n"
  fi
done

echo "==================== suggested nix snippet ===================="
echo
echo "    networking.sysfsTuning = {"
echo "      enable = true;"
echo "      interfaces = {"
printf "%b" "$tuning_lines"
echo "      };"
echo "    };"
echo
echo "    networking.sqm = {"
echo "      enable = true;"
printf "%b" "$sqm_snippet"
echo "      lanInterface = \"<pick one of the candidates above>\";"
echo "      # downloadBandwidth/uploadBandwidth: 90-95% of line rate, e.g. speed=1000Mb/s -> \"900mbit\""
echo "    };"
echo
echo "Note: these are only suggestions based on current interface state/queue count. WAN/LAN roles and bandwidth values still need to be checked against the actual topology."
