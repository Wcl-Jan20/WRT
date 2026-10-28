#!/bin/bash
# SPDX-License-Identifier: MIT
# Copyright (C) 2026 VIKINGYFY

#移除luci-app-attendedsysupgrade
sed -i "/attendedsysupgrade/d" $(find ./feeds/luci/collections/ -type f -name "Makefile")
#修改默认主题
sed -i "s/luci-theme-bootstrap/luci-theme-$WRT_THEME/g" $(find ./feeds/luci/collections/ -type f -name "Makefile")
#修改immortalwrt.lan关联IP
sed -i "s/192\.168\.[0-9]*\.[0-9]*/$WRT_IP/g" $(find ./feeds/luci/modules/luci-mod-system/ -type f -name "flash.js")
#添加编译日期标识
#sed -i "s/(\(luciversion || ''\))/(\1) + (' \/ $WRT_MARK-$WRT_DATE')/g" $(find ./feeds/luci/modules/luci-mod-status/ -type f -name "10_system.js")

WIFI_SH=$(find ./target/linux/{mediatek/filogic,qualcommax}/base-files/etc/uci-defaults/ -type f -name "*set-wireless.sh" 2>/dev/null)
WIFI_UC="./package/network/config/wifi-scripts/files/lib/wifi/mac80211.uc"
if [ -f "$WIFI_SH" ]; then
	#修改WIFI名称
	sed -i "s/BASE_SSID='.*'/BASE_SSID='$WRT_SSID'/g" $WIFI_SH
	#修改WIFI密码
	sed -i "s/BASE_WORD='.*'/BASE_WORD='$WRT_WORD'/g" $WIFI_SH
elif [ -f "$WIFI_UC" ]; then
	#约定: WRT_WORD 为 "无"/空 表示不要密码(开放网络),不能把 "无" 当成一个字面密码
	case "$WRT_WORD" in
		''|无|无密码|none|None) WIFI_KEY="" ;;
		*) WIFI_KEY="$WRT_WORD" ;;
	esac
	#修改WIFI名称
	sed -i "s/ssid='.*'/ssid='$WRT_SSID'/g" $WIFI_UC
	#修改WIFI密码(空=不加密)
	sed -i "s/key='.*'/key='$WIFI_KEY'/g" $WIFI_UC
	#关键:该模板默认 encryption='none',只改 key 不会生效(刷完是开放网络),有密码时必须同时改加密方式
	if [ -n "$WIFI_KEY" ]; then
		sed -i "s#encryption = 'none';#encryption = 'psk2';#" $WIFI_UC
	else
		echo "提示: WRT_WORD 为 无/空,默认无线将不加密(开放网络)"
	fi
	if [ -n "$WRT_SSID" ] && ! grep -q "ssid='$WRT_SSID'" $WIFI_UC; then
		echo "警告: 默认无线 SSID 替换失败,请检查 mac80211.uc 是否改版"
	elif [ -n "$WIFI_KEY" ] && ! grep -q "key='$WIFI_KEY'" $WIFI_UC; then
		echo "警告: 默认无线密码替换失败,请检查 mac80211.uc 是否改版"
	fi
	if [ -n "$WIFI_KEY" ] && [ ${#WIFI_KEY} -lt 8 ]; then
		echo "警告: WiFi 密码少于 8 位,psk2 会导致 hostapd 启动失败(至少 8 位)"
	fi
fi

CFG_FILE="./package/base-files/files/bin/config_generate"
#修改默认IP地址
sed -i "s/192\.168\.[0-9]*\.[0-9]*/$WRT_IP/g" $CFG_FILE
#修改默认主机名
sed -i "s/hostname='.*'/hostname='$WRT_NAME'/g" $CFG_FILE

#配置文件修改
echo "CONFIG_PACKAGE_luci=y" >> ./.config
echo "CONFIG_LUCI_LANG_zh_Hans=y" >> ./.config
echo "CONFIG_PACKAGE_luci-theme-$WRT_THEME=y" >> ./.config
echo "CONFIG_PACKAGE_luci-app-$WRT_THEME-config=y" >> ./.config

#引入私有扩展配置
if [ -f "$GITHUB_WORKSPACE/Config/PRIVATE.txt" ]; then
	echo "Applying private configurations from PRIVATE.txt..."
	cat $GITHUB_WORKSPACE/Config/PRIVATE.txt >> ./.config
fi

#手动调整的插件
if [ -n "$WRT_PACKAGE" ] && [ -f .config ]; then
    echo "$WRT_PACKAGE" | tr ' ' '\n' | sed '/^$/d' | while read -r line; do
        if [[ "$line" == *"="* ]]; then
            pkg_name="${line%=*}"
            state="${line#*=}"
        else
            pkg_name="$line"
            state="y"
        fi
        full_key="CONFIG_PACKAGE_${pkg_name}"
        sed -i "/^${full_key}=/d" ./.config
        sed -i "/^# ${full_key} is not set/d" ./.config
        if [ "$state" = "y" ]; then
            echo "${full_key}=y" >> ./.config
        elif [ "$state" = "n" ]; then
            echo "# ${full_key} is not set" >> ./.config
        fi
    done
fi

#无WIFI配置标志
if [[ "${WRT_CONFIG,,}" == *"wifi"* && "${WRT_CONFIG,,}" == *"no"* ]]; then
	echo "WRT_WIFI=wifi-no" >> $GITHUB_ENV
fi

#高通平台调整
DTS_PATH="./target/linux/qualcommax/dts/"
if [[ "${WRT_TARGET^^}" == *"QUALCOMMAX"* ]]; then
	#无WIFI配置调整Q6大小
	if [[ "${WRT_CONFIG,,}" == *"wifi"* && "${WRT_CONFIG,,}" == *"no"* ]]; then
		find $DTS_PATH -type f ! -iname '*nowifi*' -exec sed -i 's/ipq\(6018\|8074\).dtsi/ipq\1-nowifi.dtsi/g' {} +
		echo "qualcommax set up nowifi successfully!"
	fi
fi

#修改luci首页显示
#CPU 标签(兼容 _('CPU usage') 与 _('CPU usage (%)'))
sed -i "s#_('CPU usage[^']*')#_('CPU使用率')#g" feeds/luci/modules/luci-mod-status/htdocs/luci-static/resources/view/status/include/10_system.js
#去掉"主机名"整行
sed -i "/_('Hostname')/d" feeds/luci/modules/luci-mod-status/htdocs/luci-static/resources/view/status/include/10_system.js
#温度行索引前移(删掉主机名/目标平台后数组少了4个元素)
sed -i "s#fields\.splice(6,[[:space:]]*0,[[:space:]]*_('Temperature'))#fields.splice(4, 0, _('Temperature'))#" feeds/luci/modules/luci-mod-status/htdocs/luci-static/resources/view/status/include/10_system.js
sed -i "s#fields\.splice(7,[[:space:]]*0,[[:space:]]*tempinfo\.tempinfo)#fields.splice(5, 0, tempinfo.tempinfo)#" feeds/luci/modules/luci-mod-status/htdocs/luci-static/resources/view/status/include/10_system.js
#运行时长
sed -i "s#_('Uptime')#_('运行时长')#g" feeds/luci/modules/luci-mod-status/htdocs/luci-static/resources/view/status/include/10_system.js
#本地时间去掉时区:timeStyle long/full 会带 GMT+8,medium 只留 时:分:秒
sed -i "s#timeStyle:[^,]*,#timeStyle: 'medium',#" feeds/luci/modules/luci-mod-status/htdocs/luci-static/resources/view/status/include/10_system.js
#去掉"目标平台"整行
sed -i "/_('Target Platform')/d" feeds/luci/modules/luci-mod-status/htdocs/luci-static/resources/view/status/include/10_system.js
#内存精简 + 去掉存储
sed -i '38,47d' feeds/luci/modules/luci-mod-status/htdocs/luci-static/resources/view/status/include/20_memory.js
rm -rf feeds/luci/modules/luci-mod-status/htdocs/luci-static/resources/view/status/include/25_storage.js

#usr+sys+nss
CPUUSAGE_QC="./target/linux/qualcommax/base-files/sbin/cpuusage"
if [ -f "$CPUUSAGE_QC" ]; then
	cat << 'EOF' > "$CPUUSAGE_QC"
#!/bin/sh
#CPU占用按usr/sys分开显示,并附带NSS硬件加速占用
read -r usr sys <<EOT
$(top -bn1 2>/dev/null | awk '/^CPU:/ {print $2, $4; exit}')
EOT
#取 Core0 的 Avg 列:首个含百分号的行,第2列(Min/Avg/Max 中的 Avg)
#不用固定行号,避免上游多一行空行或注释就取错
nss_load="$(awk '/%/ { print $2; exit }' /sys/kernel/debug/qca-nss-drv/stats/cpu_load_ubi 2>/dev/null)"
case "$nss_load" in
	''|*%) ;;
	*) nss_load="${nss_load}%" ;;
esac
#NSS 当前频率(自动调频,会在 low/mid/max 三档之间变),取不到就不显示
nss_freq="$(cat /sys/kernel/debug/clk/ubi0_core_clk/clk_rate 2>/dev/null)"
[ -z "$nss_freq" ] && nss_freq="$(awk '/ubi0_core_clk/ {print $5; exit}' /sys/kernel/debug/clk/clk_summary 2>/dev/null)"
case "$nss_freq" in
	''|*[!0-9]*) nss_freq="" ;;
	*) nss_freq=" ($((nss_freq / 1000000)).$(( (nss_freq % 1000000) / 100000 ))MHz)" ;;
esac
echo -n "USR: ${usr:-0%} SYS: ${sys:-0%} NSS: ${nss_load:-N/A}${nss_freq}"
EOF
	chmod 0755 "$CPUUSAGE_QC"
	#校验:最后一行必须是 echo 输出行且能被 sh 解析,否则说明 heredoc 结束符位置不对
	if tail -n 1 "$CPUUSAGE_QC" | grep -q '^echo -n "USR:' && sh -n "$CPUUSAGE_QC" 2>/dev/null; then
		echo "cpu状态已修改:usr+sys+nss"
	else
		echo "警告: cpuusage 生成不完整(检查 EOF 结束符是否紧跟在 echo 行之后)"
	fi
fi

#filogic PPE显示:MT7981实际只有1个PPE,隐藏PPE1并把PPE0显示为PPE
FILOGIC_CPUUSAGE="./target/linux/mediatek/filogic/base-files/sbin/cpuusage"
if [ -f "$FILOGIC_CPUUSAGE" ]; then
	cat << 'EOF' > "$FILOGIC_CPUUSAGE"
#!/bin/sh
# Copyright (C) 2024 ZqinKing <zqinking23@gmail.com>
read -r usr sys <<EOT
$(top -bn1 2>/dev/null | awk '/^CPU:/ {print $2, $4; exit}')
EOT
output="USR: ${usr:-0%} SYS: ${sys:-0%}"
#MT7981只有1个PPE:隐藏PPE1,并把PPE0显示为PPE
is_mt7981=0
for dt in /proc/device-tree/compatible /sys/firmware/devicetree/base/compatible; do
	[ -f "$dt" ] || continue
	if tr '\0' '\n' < "$dt" | grep -q 'mediatek,mt7981'; then
		is_mt7981=1
	fi
	break
done
for ppe in /sys/kernel/debug/ppe*/entries; do
	[ -f "$ppe" ] || continue
	name="$(basename "$(dirname "$ppe")" | tr 'a-z' 'A-Z')"
	[ "$is_mt7981" = "1" ] && [ "$name" = "PPE1" ] && continue
	[ "$is_mt7981" = "1" ] && name="PPE"
	read -r total ipv4 ipv6 <<EOT
$(awk '/IPv4/{a++}/IPv6/{b++} END {print NR, a+0, b+0}' "$ppe")
EOT
	[ -n "$total" ] && output="${output} ${name}: ${total} (IPv4: ${ipv4} IPv6: ${ipv6})"
done
echo -n "$output"
EOF
	echo "MT7981 PPE显示已调整:PPE0显示为PPE"
fi

# 25.12 feeds fix
for mk in $(grep -rl --include=Makefile '^[[:space:]]*USERID' ./feeds 2>/dev/null); do
	perl -i -pe '
		BEGIN {
			%hw = (audio => 29, "audio-capture" => 32, midi => 55,
			       video => 40, "video-capture" => 36, render => 43,
			       input => 41, dvb => 49, kvm => 34, lp => 7,
			       scanner => 47, hidraw => 48);
		}
		if (/^(\s*USERID:=)(.+)$/) {
			my ($pre, $spec) = ($1, $2);
			my @f = split(/:/, $spec, 3);
			for my $i (1 .. 2) {
				next unless defined $f[$i];
				my @g = split(/,/, $f[$i]);
				for my $j (0 .. $#g) {
					my ($n) = split(/=/, $g[$j], 2);
					$g[$j] = "$n=$hw{$n}" if exists $hw{$n};
				}
				$f[$i] = join(",", @g);
			}
			$_ = $pre . join(":", @f) . "\n";
		}
	' "$mk"
done

#去掉(OpenWrt U-Boot layout)后缀
if [ -d "./target/linux/mediatek/dts" ]; then
	find ./target/linux/mediatek/dts -type f -name '*.dts' -exec sed -i 's/ (OpenWrt U-Boot layout)//g' {} +
	echo "已去掉型号中的(OpenWrt U-Boot layout)后缀"
fi

#首页固件版本显示为 "品牌 r年份-提交哈希"（例:ImmortalWRT r2026-b23cc87）
WRT_DIST="ImmortalWRT"
if [ -f include/version.mk ] && [ -f package/base-files/files/etc/openwrt_release ]; then
	#发行版名称
	sed -i "s/,LibWrt)/,${WRT_DIST})/g" include/version.mk
	#版本码=r年份-源码提交短哈希(getver.sh 会优先读取根目录 version 文件)
	echo "r$(date +%Y)-$(git rev-parse --short=7 HEAD 2>/dev/null || echo unknown)" > version
	#/etc/openwrt_release 里的描述(仅影响 cat /etc/openwrt_release)
	sed -i "s#^DISTRIB_DESCRIPTION=.*#DISTRIB_DESCRIPTION='%D %C'#" package/base-files/files/etc/openwrt_release
	#关键:LuCI 首页与 ubus call system board 读的是 /etc/os-release 的 OPENWRT_RELEASE
	#(procd 解析 os-release,OPENWRT_RELEASE -> release.description),必须一起改
	OS_RELEASE_FILE="package/base-files/files/usr/lib/os-release"
	if [ -f "$OS_RELEASE_FILE" ]; then
		sed -i 's#^OPENWRT_RELEASE=.*#OPENWRT_RELEASE="%D %C"#' "$OS_RELEASE_FILE"
		#PRETTY_NAME 一并统一(cat /etc/os-release 看到的那一行)
		sed -i 's#^PRETTY_NAME=.*#PRETTY_NAME="%D %C"#' "$OS_RELEASE_FILE"
	fi
	#SSH 登录横幅同样去掉大版本号
	if [ -f package/base-files/files/etc/banner ]; then
		sed -i 's#%D %V, %C#%D %C,#' package/base-files/files/etc/banner
	fi
	echo "固件版本标识: $(cat version)"
fi

#去掉首页固件版本后面的" / LuCI xxx"后缀(描述本身已是 ImmortalWRT r年份-哈希)
sed -i "s#_('Firmware Version'), (L.isObject(boardinfo.release) ? boardinfo.release.description + ' / ' : '') + (luciversion || ''),#_('Firmware Version'), (L.isObject(boardinfo.release) ? (boardinfo.release.description || '') : ''),#g" feeds/luci/modules/luci-mod-status/htdocs/luci-static/resources/view/status/include/10_system.js

#为fakeip关闭重绑定保护
sed -i 's/option rebind_protection 1/option rebind_protection 0/g' package/network/services/dnsmasq/files/dhcp.conf

#sqm修复ipk支持及启动延迟
sed -i 's/DEPENDS:=+tc +ip +kmod-sched-cake +kmod-ifb +iptables +iptables-mod-ipopt/DEPENDS:=+tc +ip +kmod-sched-cake +kmod-ifb/g' feeds/packages/net/sqm-scripts/Makefile
if ! grep -q "Build/Prepare" feeds/packages/net/sqm-scripts/Makefile; then
    sed -i '/$(eval $(call BuildPackage,sqm-scripts))/i\
define Build/Prepare\n\
	$(call Build/Prepare/Default)\n\
	sed -i "s/START=50/START=95/g" $(PKG_BUILD_DIR)/platform/openwrt/sqm-init\n\
	sed -i "/export SQM_VERBOSITY_MIN=5/i \	sleep 9" $(PKG_BUILD_DIR)/platform/openwrt/sqm-init\n\
endef\n' feeds/packages/net/sqm-scripts/Makefile
fi
#NSS SQM(nss-zk.qos)依赖 qca-nss-qdisc,但该 kmod 没生成 /etc/modules.d 自动加载条目,补一个
if [ -d package/base-files/files/etc ]; then
	mkdir -p package/base-files/files/etc/modules.d
	echo "qca-nss-qdisc" > package/base-files/files/etc/modules.d/60-qca-nss-qdisc
	echo "已补 qca-nss-qdisc 开机自动加载"
fi

#CPU 默认模式改为平衡(schedutil),同时打开 NSS 自动调频(auto_scale)
#注意:开机最后生效的是 /etc/config/pbuf(START=95),cpufreq(START=15)会被它覆盖
#auto_scale 不只是"调频开关":驱动把它的值当作 stats_enable 发给 NSS 固件,
#关掉(=0)后固件就不再上报 core stats,首页 NSS 百分比会永远冻住,调频也不会启动
PBUF_UCI="package/kernel/mac80211/files/pbuf.uci"
if [ -f "$PBUF_UCI" ]; then
	if grep -q "^[[:space:]]*option scaling_governor" "$PBUF_UCI"; then
		sed -i "s#^[[:space:]]*option scaling_governor.*#  option scaling_governor 'schedutil'#" "$PBUF_UCI"
	else
		printf "\n  option scaling_governor 'schedutil'\n" >> "$PBUF_UCI"
	fi
	if grep -q "^[[:space:]]*option auto_scale" "$PBUF_UCI"; then
		sed -i "s#^[[:space:]]*option auto_scale.*#  option auto_scale 'on'#" "$PBUF_UCI"
	else
		printf "\n  option auto_scale 'on'\n" >> "$PBUF_UCI"
	fi
	if grep -q "option scaling_governor 'schedutil'" "$PBUF_UCI" && grep -q "option auto_scale 'on'" "$PBUF_UCI"; then
		echo "CPU 模式: schedutil(动态调频) / NSS: auto_scale=on(统计+调频已开启)"
	else
		echo "警告: pbuf.uci 设置不完整,当前为: $(grep -E 'scaling_governor|auto_scale' "$PBUF_UCI" | sed 's/^[[:space:]]*//' | tr '\n' ' ')"
	fi
else
	echo "提示: 未找到 pbuf.uci,跳过 CPU/NSS 模式设置"
fi

#原驱动把 auto_scale 的值当作 stats_enable 发给 NSS 固件,auto_scale=0 时固件停止上报统计,
#cpu_load_ubi(首页那个百分比)就永久冻结;补丁让 stats_enable 恒为 1,只用 auto_scale 控制是否调频
#来源: VIKINGYFY/immortalwrt 的 012-fix-keep-core-stats-with-autoscale-disabled.patch
NSS_STATS_PATCH="${GITHUB_WORKSPACE:-.}/Scripts/patches/0029-nss-drv-keep-core-stats-with-autoscale-disabled.patch"
if [ -f "$NSS_STATS_PATCH" ]; then
	for NSS_PATCH_DIR in feeds/nss_packages/qca-nss-drv/patches feeds/nss_packages/qca-nss-drv/patches-11.4; do
		if [ -d "$NSS_PATCH_DIR" ]; then
			cp -f "$NSS_STATS_PATCH" "$NSS_PATCH_DIR/$(basename "$NSS_STATS_PATCH")"
			echo "NSS core stats 补丁已加入: $NSS_PATCH_DIR"
		fi
	done
else
	echo "提示: 未找到 NSS core stats 补丁,跳过"
fi

#禁用zram开机自启
#if ! grep -q "S15zram" include/rootfs.mk; then
#    sed -i "/clean_ipkg,\$(1)/a $(printf '\t')rm -f \$(1)/etc/rc.d/S15zram" include/rootfs.mk
#	echo "禁用zram开机启动"
#fi
#zram默认大小改为内存的1/3,并默认使用lz4压缩
ZRAM_INIT="./package/system/zram-swap/files/zram.init"
if [ -f "$ZRAM_INIT" ]; then
	#ram_size单位是kB: ram_size/1024/3 => MB,即 1/3 内存
	sed -i 's|echo \$(( ram_size / 2048 ))|echo $(( ram_size / 3072 ))|' "$ZRAM_INIT"
	#同步更新注释
	sed -i 's|# e.g. 6mb for 16mb-routers or 61mb for 128mb-routers|# use 1/3 of RAM, e.g. 5mb for 16mb-routers or 40mb for 128mb-routers|' "$ZRAM_INIT"
	#默认压缩算法 lzo -> lz4
	sed -i 's|zram_comp_algo="lzo"|zram_comp_algo="lz4"|' "$ZRAM_INIT"
	sed -i 's|# default to lzo, which is always available|# default to lz4|' "$ZRAM_INIT"
	if grep -q 'ram_size / 3072' "$ZRAM_INIT"; then
		echo "zram已调整: 1/3内存 + lz4"
	else
		echo "警告: zram.init 默认大小替换失败,请检查上游是否改动了该文件" >&2
	fi
fi
