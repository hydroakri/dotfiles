{ lib, ... }:

{
  options.mainUser = lib.mkOption {
    type = lib.types.str;
    default = "user";
    description = "The main system username";
  };
}
