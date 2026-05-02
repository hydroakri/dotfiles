{
  config,
  pkgs,
  inputs,
  ...
}:

{
  imports = [
    inputs.hermes-agent.nixosModules.default
  ];

  nix.settings = {
    allowed-users = [ "root" "hermes" ];
    trusted-users = [ "root" "hermes" ];
  };

  sops = {
    secrets = {
      hermes_env = { };
      searx_secret_key = { };
      telegram_bot_token = { };
    };
  };

  security.sudo-rs.extraRules = [
    {
      users = [ "${config.mainUser}" ];
      commands = [
        {
          command = "/run/current-system/sw/bin/podman";
          options = [ "NOPASSWD" ];
        }
      ];
    }
  ];

  services.hermes-agent = {
    enable = true;
    addToSystemPackages = true;

    # 关闭容器模式，改用原生模式
    container.enable = false;

    settings = {
      # 修正后的 Gemini 3 模型设置
      provider = "gemini";
      model = "gemini-3-flash-preview";
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
    # Mount the decrypted sops secret as an environment file
    environmentFiles = [
      config.sops.secrets.hermes_env.path
    ];
  };

}

