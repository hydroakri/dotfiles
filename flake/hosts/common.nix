# Owner identity shared by every host: user, binary caches, base SSH key (hardware keys stay per-host).
{
  mainUser = "hydroakri";

  modules.core = {
    extraSubstituters = [
      "https://cache.hydroakri.cc/cachix"
      "https://attic.xuyh0120.win/lantian"
    ];
    extraTrustedPublicKeys = [
      "cachix:RTT3Lx/HwP7OQwsaF6HpidQZvmpbu6xxa/Bc9CCp8zI="
      "lantian:EeAUQ+W+6r7EtwnmYjeVwx5kOGEBpjlBfPlzGlTNvHc="
    ];
  };

  modules.security.authorizedKeys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPYQdA9KBa2n2xrSk4cr5dYhbLgsUl3vPtc+qjdcIotE"
  ];
}
