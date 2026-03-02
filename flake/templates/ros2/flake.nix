{
  inputs = {
    nix-ros-overlay.url = "github:lopsided98/nix-ros-overlay/master";
    nixpkgs.follows = "nix-ros-overlay/nixpkgs";
  };

  outputs = { self, nix-ros-overlay, nixpkgs }:
    nix-ros-overlay.inputs.flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [ nix-ros-overlay.overlays.default ];
        };

        # 1. 定义你需要的 ROS 包列表，方便统一管理
        rosPkgs = with pkgs.rosPackages.humble; [
          desktop
          ros-core
          turtlesim

          ament-cmake # 必须！提供 ament_cmake 的基础宏
          ament-cmake-core
          ament-index-cpp # 如果涉及 C++ 索引

          # 3. 你的项目依赖
          rclcpp # C++ 支持
          std-msgs # 标准消息支持
          v4l2-camera
        ];

        # 2. 创建一个集成的 ROS 环境
        # 使用 buildEnv 的好处是它会将所有包的路径并入一个虚拟根目录，减少环境变量长度
        rosEnv = pkgs.rosPackages.humble.buildEnv { paths = rosPkgs; };
      in {
        devShells.default = pkgs.mkShell {
          name = "Robust ROS2 Project";

          packages = [
            pkgs.colcon
            pkgs.cmake
            pkgs.gcc
            pkgs.pkg-config
            rosEnv
            # 辅助工具
            pkgs.tmux
            pkgs.glxinfo # 用于调试 OpenGL
          ];

          # 3. 核心加固：shellHook
          shellHook = ''
            # --- 基础环境 Source ---
            # 直接 source buildEnv 产生的 setup.bash，这能确保所有的 ROS 包都在路径中
            source ${rosEnv}/setup.bash

            # --- 解决 OpenGL / GUI 崩溃问题 ---
            # 映射系统驱动路径，这对 RViz2 和 Gazebo 至关重要
            export LD_LIBRARY_PATH=/run/opengl-driver/lib:$LD_LIBRARY_PATH

            # 解决 Qt 插件路径问题（防止 RViz 找不到 xcb 插件）
            export QT_PLUGIN_PATH=${pkgs.qt5.qtbase}/${pkgs.qt5.qtbase.qtPluginPrefix}
            # 如果是 Qt6 项目，取消注释下一行
            # export QT_PLUGIN_PATH=${pkgs.qt6.qtbase}/${pkgs.qt6.qtbase.qtPluginPrefix}

            # --- 解决 Python 路径污染 ---
            # 确保本地 build 出来的包优先于系统路径
            export PYTHONPATH=$PYTHONPATH:$(pwd)/install/lib/python3.10/site-packages

            # --- 解决终端显示问题 ---
            export ROS_DOMAIN_ID=0  # 建议显式指定，避免多人在同一局域网冲突
            export PYTHONOPTIMIZE=1 # 抑制某些 Python 警告

            echo "🛡️  Robust ROS2 Environment Loaded!"
            echo "Current ROS Distro: $ROS_DISTRO"
            echo "Checking GPU: $(glxinfo | grep 'Device:' || echo 'No GPU detected')"
          '';
        };
      });

  nixConfig = {
    extra-substituters = [ "https://ros.cachix.org" ];
    extra-trusted-public-keys =
      [ "ros.cachix.org-1:dSyZxI8geDCJrwgvCOHDoAfOm5sV1wCPjBkKL+38Rvo=" ];
  };
}
