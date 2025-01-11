# hysteria2-reality-install-script (Based on sing-box)



## 如何使用



### 1. 将仓库克隆到本地

```shell
git clone https://github.com/levinion/hysteria2-reality-install-script
```



### 2. 安装just

```shell
curl --proto '=https' --tlsv1.2 -sSf https://just.systems/install.sh | bash -s -- --to /usr/bin
```



### 3. 安装sing-box

```shell
cd hysteria2-reality-install-script
just install_singbox
```



### 4. 随机生成配置

```shell
just generate
```

配置文件（.env）文件会生成在当前目录下，可按需修改（非强制）



### 5. 安装证书、生成配置文件、配置端口跳跃、优化系统参数

```shell
just install
```



### 6. 可选：配置防火墙

```shell
apt install ufw
just ufw
systemctl enable ufw --now
```



### 7. 运行

```shell
just run
```



### 8. 可选：生成客户端Outbounds示例

```shell
just outbounds
```

执行前最好在`.env`文件中填写服务器IP地址



### 9. 停止运行

```shell
pkill sing-box
```

或

```shell
just stop
```



### 10. 更新配置以及重新运行

```shell	
just update
```
