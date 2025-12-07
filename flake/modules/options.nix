{ config, lib, pkgs, ... }:

with lib;

{

  options = {
    # 定义全局用户名选项
    mainUser = mkOption {
      type = types.str;
      default = "hydroakri";
      description = "The main system username";
    };

    # 定义全局邮箱选项 (用于 Git 签名、SSH 标识等)
    userEmail = mkOption {
      type = types.str;
      default = "24475059+hydroakri@users.noreply.github.com.com";
      description = "The email for the main user";
    };
  };

}
