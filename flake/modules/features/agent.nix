{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:

let
  localModelGguf = pkgs.fetchurl {
    url = "https://huggingface.co/unsloth/Qwen3.5-9B-GGUF/resolve/main/Qwen3.5-9B-IQ4_XS.gguf";
    hash = "sha256-fpGK7KBsUry1KOprBLTslX517owKcxOIVMDfzzcepCk=";
  };
in

{
  imports = [
    inputs.hermes-agent.nixosModules.default
    inputs.sops-nix.nixosModules.sops
  ];

  options.modules.agent = {
    hermes.enable = lib.mkEnableOption "Hermes Agent gateway service";

    "llama-cpp".enable =
      lib.mkEnableOption "local llama.cpp server serving Qwen3.5-9B, standalone (not wired into Hermes Agent)";
  };

  config = {
    sops = {
      secrets = {
        hermes_env = { };
        searx_secret_key = { };
        telegram_bot_token = { };
      };
    };

    services.llama-cpp = lib.mkIf config.modules.agent."llama-cpp".enable {
      enable = true;
      package = pkgs.llama-cpp.override { vulkanSupport = true; };
      settings = {
        host = "127.0.0.1";
        port = 8081;
        model = localModelGguf;
        "n-gpu-layers" = 999;
        "ctx-size" = 32768;
        "flash-attn" = "on";
        "cache-type-k" = "q8_0";
        "cache-type-v" = "q8_0";
        "parallel" = 1;
        "temp" = 1.0;
        "top-k" = 20;
        "top-p" = 0.95;
        "min-p" = 0.0;
        "presence-penalty" = 1.5;
        "n-predict" = 4096;
        "api-key" = "184266d6bf1b835243203ccb9afccc7b3d276898a3de560f3e1315ca51564685";
      };
    };

    # $HOME is unset under DynamicUser, so Vulkan's shader cache tries to
    # write to literal "//.cache", fails (read-only under ProtectSystem),
    # $HOME is unset under DynamicUser, so Vulkan's shader cache tries to
    # write to literal "//.cache", fails (read-only under ProtectSystem),
    systemd.services.llama-cpp.environment = lib.mkIf config.modules.agent."llama-cpp".enable {
      HOME = "/tmp";
    };

    services.hermes-agent = {
      enable = config.modules.agent.hermes.enable;
      container.enable = true;
      addToSystemPackages = true;
      container.hostUsers = [ "${config.mainUser}" ];

      settings = {
        provider = "Deepseek";
        model = "deepseek-v4-flash";
        context_length = 65000;
        toolsets = [ "all" ];
        api_server = {
          enabled = true;
          port = 8642;
        };

        platforms.telegram = {
          enabled = true;
          token_file = config.sops.secrets.telegram_bot_token.path;
          allowed_users = [ 340947530 ];
        };
      };
      # Mount the decrypted sops secret as an environment file
      environmentFiles = [
        config.sops.secrets.hermes_env.path
      ];
      documents = {
        "SOUL.md" = ''
          You are Hermes Agent, an intelligent AI assistant created by Nous Research. You are helpful, knowledgeable, and direct. You assist users with a wide range of tasks including answering questions, writing and editing code, analyzing information, creative work, and executing actions via your tools. You communicate clearly, admit uncertainty when appropriate, and prioritize being genuinely useful over being verbose unless otherwise directed below. Be targeted and efficient in your exploration and investigations.

          # Hermes Agent Soul: Extreme Functionalism & Cognitive Ergonomics

          ## 1. Extreme Functionalism
          * **Pursuit of the Optimal**: Provide the "Best Practice" directly. Bypass mediocre or redundant choices.
          * **Maximum Information Density**: Strive for peak information entropy. Responses must be concise.
          * **Rejection of Marketing Fluff**: Aggressively filter out decorative language and filler.

          ## 2. Cognitive Load Minimization
          * **Structural Transparency**: Outputs must maintain a high-contrast, hierarchical structure.
          * **Single-Purpose Excellence**: Responses must converge on the most precise instrumental logic.

          ## 3. Operational Directives
          * In NixOS environments, default to Declarative methodologies.
          * Maintain a Physical Determinist mindset: transparency, reproducibility, and statelessness.
          * Maintain bilingual proficiency: respond in user's language, but preserve technical precision in English.
        '';
      };
    };
  };
}
