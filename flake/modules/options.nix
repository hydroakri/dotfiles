{ lib, ... }:

{
  options.mainUser = lib.mkOption {
    type = lib.types.str;
    default = "hydroakri";
    description = "The main system username";
  };
}
