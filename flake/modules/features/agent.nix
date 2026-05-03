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

  sops = {
    secrets = {
      hermes_env = { };
      searx_secret_key = { };
      telegram_bot_token = { };
    };
  };

  services.hermes-agent = {
    enable = true;
    container.enable = true;
    addToSystemPackages = true;
    container.hostUsers = [ "${config.mainUser}" ];

    settings = {
      provider = "openrouter";
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

}
