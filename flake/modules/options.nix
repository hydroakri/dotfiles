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
  };

}
