#!/usr/bin/env python3
"""Derivations behind modules.homeAssistant (see README.md in this directory). Standard library only.

  derive_curve.py spectra CSSP_spectra.csv   illuminance and chromaticity per 3 degree solar-elevation bin
  derive_curve.py sun                        direct-sun colour temperature versus elevation
  derive_curve.py brightness                 brightnessPct at the curve elevations from the spectra bins
  derive_curve.py ceiling                    melanopic lux per lumen and the brightness limits (defaults = module defaults)

CSSP_spectra.csv: https://github.com/spitschan/IlluminationSpectraDataset/blob/master/data/CSSP_spectra.csv
"""
import csv
import math
import statistics
import sys

WLS = list(range(280, 841))  # the CSV rows are 280-840 nm at 1 nm


def _lobe(x, mu, s1, s2):
    t = (x - mu) / (s1 if x < mu else s2)
    return math.exp(-0.5 * t * t)


def cmf(wl):
    """CIE 1931 2-degree observer, Wyman/Sloan/Shirley multi-lobe fit."""
    return (
        1.056 * _lobe(wl, 599.8, 37.9, 31.0) + 0.362 * _lobe(wl, 442.0, 16.0, 26.7) - 0.065 * _lobe(wl, 501.1, 20.4, 26.2),
        0.821 * _lobe(wl, 568.8, 46.9, 40.5) + 0.286 * _lobe(wl, 530.9, 16.3, 31.1),
        1.217 * _lobe(wl, 437.0, 11.8, 36.0) + 0.681 * _lobe(wl, 459.0, 26.0, 13.8),
    )


CMF = [cmf(w) for w in WLS]


def xy_and_Y(spd):
    X = sum(s * c[0] for s, c in zip(spd, CMF))
    Y = sum(s * c[1] for s, c in zip(spd, CMF))
    Z = sum(s * c[2] for s, c in zip(spd, CMF))
    t = X + Y + Z
    return X / t, Y / t, Y


def planck(wl_nm, T):
    l = wl_nm * 1e-9
    return 1.0 / (l ** 5 * (math.exp(1.4388e-2 / (l * T)) - 1.0))


def uv1960(x, y):
    d = -2 * x + 12 * y + 3
    return 4 * x / d, 6 * y / d


LOCUS = [(T, uv1960(*xy_and_Y([planck(w, T) for w in WLS])[:2])) for T in range(1000, 12001, 10)]


def cct(x, y):
    """Nearest point on the Planckian locus in CIE 1960 uv; None when the chromaticity is far from the locus."""
    u, v = uv1960(x, y)
    T, (lu, lv) = min(LOCUS, key=lambda g: (g[1][0] - u) ** 2 + (g[1][1] - v) ** 2)
    return T if math.hypot(u - lu, v - lv) < 0.02 else None


def airmass(h):  # Kasten & Young 1989, h in degrees
    return 1.0 / (math.sin(math.radians(h)) + 0.50572 * (h + 6.07995) ** -1.6364)


def sun_xy(h, beta=0.05, alpha=1.3, T=5778.0):
    m = airmass(h)
    spd = [planck(w, T) * math.exp(-(0.008735 * (w / 1000) ** -4.08 + beta * (w / 1000) ** -alpha) * m) for w in WLS]
    return xy_and_Y(spd)[:2]


def bins_from_csv(path):
    with open(path) as f:
        rows = list(csv.reader(f))
    ncol = min(len(r) for r in rows[1:])
    elev = [float(v) for v in rows[2][:ncol]]
    spectra = rows[5:]
    assert len(spectra) == len(WLS)
    out = {}
    for j in range(ncol):
        spd = [float(r[j]) for r in spectra]
        if any(math.isnan(v) for v in spd):
            continue
        x, y, Y = xy_and_Y(spd)
        lux = 683.0 * Y  # spectra are W m-2 nm-1, 1 nm steps
        if lux > 0:
            out.setdefault(math.floor(elev[j] / 3.0) * 3, []).append((lux, x, y))
    return out


def cmd_spectra(path):
    print("elev_bin      n   median_lux   median_x  median_y  CCT_K (nearest Planckian locus point, blank when off locus)")
    for b, v in sorted(bins_from_csv(path).items()):
        x, y = statistics.median(a[1] for a in v), statistics.median(a[2] for a in v)
        print("%4d..%-4d %4d  %10.4g   %.4f   %.4f   %s" % (b, b + 3, len(v), statistics.median(a[0] for a in v), x, y, cct(x, y) or ""))


# bin-centre medians of the rural spectra (output of `spectra`), used for the brightness mapping
LUX = [(-10.5, 0.093), (-7.5, 2.874), (-4.5, 76.9), (-1.5, 613.6), (1.5, 1860.0), (4.5, 3184.0), (7.5, 4257.0)]
LOW_LUX, HIGH_LUX = 0.3, 3000.0  # 1 pct and 100 pct


def bright_pct(e):
    if e <= LUX[0][0]:
        lg = math.log10(LUX[0][1])
    elif e >= LUX[-1][0]:
        lg = math.log10(HIGH_LUX)
    else:
        (a, la), (b, lb) = next(((a, la), (b, lb)) for (a, la), (b, lb) in zip(LUX, LUX[1:]) if a <= e < b)
        lg = math.log10(la) + (math.log10(lb) - math.log10(la)) * (e - a) / (b - a)
    return 1 + 99 * min(1.0, max(0.0, (lg - math.log10(LOW_LUX)) / (math.log10(HIGH_LUX) - math.log10(LOW_LUX))))


def cmd_sun():
    print("elev  airmass  clear(beta=.05)  moderate(.10)  hazy(.15)   [K]")
    for h in [2, 3, 4, 5, 6, 8, 10, 12, 15, 20, 25, 30, 40, 50, 60, 75, 90]:
        print("%4d  %6.2f   %8s         %8s       %8s" % (h, airmass(h), cct(*sun_xy(h)), cct(*sun_xy(h, 0.10)), cct(*sun_xy(h, 0.15))))
    print("check D65 %s (6500), D55 %s (5500), illuminant A %s (2856)" % (cct(0.3127, 0.3290), cct(0.3324, 0.3474), cct(0.4476, 0.4074)))


def cmd_brightness():
    for e in [-10, -9, -7.5, -6, -4.5, -3, -1.5, 0, 1.5, 3, 5]:
        print("%5.1f deg -> %5.1f %%" % (e, bright_pct(e)))


def cmd_ceiling(H=2.4, offset=1.9, eyes=(("sitting", 1.1), ("lying", 0.7)), area=15.0, uf=0.4, frac=0.9, sr=2 * math.pi, mder=0.3333, rated_lm=1600.0):
    """Eye illuminance per lumen for a ceiling lamp, and the brightness that meets Brown 2022's melanopic limits.

    Same formulas and defaults as modules.homeAssistant.lamp.*: direct light looking at the lamp (frac/sr per lumen over distance squared)
    plus uf/area of room bounce, times mder.
    """
    per_lm = lambda eye: frac / sr / ((H - eye) ** 2 + offset ** 2) + uf / area
    print("ceiling %.1f m, horizontal offset %.1f m, room %.0f m2, utilisation %.1f, melanopic/photopic %.4f, rated %.0f lm" % (H, offset, area, uf, mder, rated_lm))
    print("posture   eye_m   lux/lm   max lm (10 mel lux)  pct     max lm (1 mel lux)  pct   /255")
    for name, eye in eyes:
        k = per_lm(eye)
        lm10, lm1 = 10 / (k * mder), 1 / (k * mder)
        print("%-9s %.1f    %.4f   %6.0f              %5.1f   %6.0f             %5.1f  %5.1f" % (name, eye, k, lm10, 100 * lm10 / rated_lm, lm1, 100 * lm1 / rated_lm, 255 * lm1 / rated_lm))
    print("pct   lm    mel lux: " + " / ".join(n for n, _ in eyes))
    for pct in (100, 34, 25, 15, 10, 3.5, 0.39):
        phi = rated_lm * pct / 100
        print("%5.2f %5.0f  %s" % (pct, phi, " / ".join("%5.1f" % (per_lm(e) * phi * mder) for _, e in eyes)))


if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else ""
    if cmd == "spectra" and len(sys.argv) == 3:
        cmd_spectra(sys.argv[2])
    elif cmd == "sun":
        cmd_sun()
    elif cmd == "brightness":
        cmd_brightness()
    elif cmd == "ceiling":
        cmd_ceiling()
    else:
        sys.exit(__doc__)
