# luci-app-singbox-server

OpenWrt 25.12 sing-box 多实例服务端 LuCI 插件。

## 功能

- 用户管理表格：启用、状态、备注、类型、端口、日志、上移、下移、编辑、删除
- 添加/编辑节点
- 协议：VMess、VLESS、Trojan、Hysteria2、TUIC
- 传输：TCP、WebSocket、gRPC、Reality（VLESS）
- 自动生成 UUID/密码与 sing-box JSON 配置
- procd 多实例管理、配置变更 reload 自动重启实例
- 中文语言包

## 编译

把目录放到 OpenWrt 源码的 `package/` 或自定义 feed 中：

```sh
./scripts/feeds update -a
./scripts/feeds install -a
make menuconfig
# LuCI -> Applications -> luci-app-singbox-server
make package/luci-app-singbox-server/compile V=s
```

## 配置文件

- UCI：`/etc/config/singbox_server`
- 临时 JSON：`/tmp/etc/singbox_server/<section>.json`
- 主日志：`/tmp/log/singbox_server.log`
- 实例日志：`/tmp/log/singbox_server_<section>.log`
