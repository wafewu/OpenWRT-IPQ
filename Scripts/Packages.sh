#!/bin/bash

#安装和更新软件包
UPDATE_PACKAGE() {
	local PKG_NAME=$1
	local PKG_REPO=$2
	local PKG_BRANCH=$3
	local PKG_SPECIAL=$4
	local PKG_LIST=("$PKG_NAME" $5)  # 第5个参数为自定义名称列表
	local REPO_NAME=${PKG_REPO#*/}

	echo " "

	# 删除本地可能存在的不同名称的软件包
	for NAME in "${PKG_LIST[@]}"; do
		# 查找匹配的目录
		echo "Search directory: $NAME"
		local FOUND_DIRS=$(find ../feeds/luci/ ../feeds/packages/ -maxdepth 3 -type d -iname "*$NAME*" 2>/dev/null)

		# 删除找到的目录
		if [ -n "$FOUND_DIRS" ]; then
			while read -r DIR; do
				rm -rf "$DIR"
				echo "Delete directory: $DIR"
			done <<< "$FOUND_DIRS"
		else
			echo "Not fonud directory: $NAME"
		fi
	done

	# 克隆 GitHub 仓库
	git clone --depth=1 --single-branch --branch $PKG_BRANCH "https://github.com/$PKG_REPO.git"

	# 处理克隆的仓库
	if [[ "$PKG_SPECIAL" == "pkg" ]]; then
		find ./$REPO_NAME/*/ -maxdepth 3 -type d -iname "*$PKG_NAME*" -prune -exec cp -rf {} ./ \;
		rm -rf ./$REPO_NAME/
	elif [[ "$PKG_SPECIAL" == "name" ]]; then
		mv -f $REPO_NAME $PKG_NAME
	fi
}

# 调用示例
# UPDATE_PACKAGE "OpenAppFilter" "destan19/OpenAppFilter" "master" "" "custom_name1 custom_name2"
# UPDATE_PACKAGE "open-app-filter" "destan19/OpenAppFilter" "master" "" "luci-app-appfilter oaf" 这样会把原有的open-app-filter，luci-app-appfilter，oaf相关组件删除，不会出现coremark错误。

# UPDATE_PACKAGE "包名" "项目地址" "项目分支" "pkg/name，可选，pkg为从大杂烩中单独提取包名插件；name为重命名为包名"
#UPDATE_PACKAGE "argon" "sbwml/luci-theme-argon" "openwrt-24.10"
#UPDATE_PACKAGE "kucat" "sirpdboy/luci-theme-kucat" "js"

UPDATE_PACKAGE "homeproxy" "VIKINGYFY/homeproxy" "main"
UPDATE_PACKAGE "nikki" "nikkinikki-org/OpenWrt-nikki" "main"
UPDATE_PACKAGE "openclash" "vernesong/OpenClash" "dev" "pkg"
#UPDATE_PACKAGE "passwall" "xiaorouji/openwrt-passwall" "main" "pkg"
#UPDATE_PACKAGE "passwall2" "xiaorouji/openwrt-passwall2" "main" "pkg"

UPDATE_PACKAGE "luci-app-tailscale" "asvow/luci-app-tailscale" "main"
UPDATE_PACKAGE "ddns-go" "sirpdboy/luci-app-ddns-go" "main"
#UPDATE_PACKAGE "easytier" "EasyTier/luci-app-easytier" "main"
UPDATE_PACKAGE "gecoosac" "lwb1978/openwrt-gecoosac" "main"
UPDATE_PACKAGE "mosdns" "sbwml/luci-app-mosdns" "v5" "" "v2dat"
UPDATE_PACKAGE "netspeedtest" "sirpdboy/luci-app-netspeedtest" "js" "" "homebox speedtest"
UPDATE_PACKAGE "partexp" "sirpdboy/luci-app-partexp" "main"
#UPDATE_PACKAGE "qbittorrent" "sbwml/luci-app-qbittorrent" "master" "" "qt6base qt6tools rblibtorrent"
UPDATE_PACKAGE "qmodem" "FUjr/QModem" "main"
UPDATE_PACKAGE "viking" "VIKINGYFY/packages" "main" "" "luci-app-timewol luci-app-wolplus"
UPDATE_PACKAGE "vnt" "lmq8267/luci-app-vnt" "main"

UPDATE_PACKAGE "luci-app-adguardhome" "kenzok8/small-package" "main" "pkg"
#UPDATE_PACKAGE "luci-app-adguardhome" "sirpdboy/luci-app-adguardhome" "js"
UPDATE_PACKAGE "adguardhome" "kenzok8/small-package" "main" "pkg"

git_sparse_clone main https://github.com/sbwml/openwrt_pkgs package luci-app-socat luci-app-diskman luci-app-eqos luci-app-vlmcsd vlmcsd 

#更新软件包版本
UPDATE_VERSION() {
	local PKG_NAME=$1
	local PKG_MARK=${2:-false}
	local PKG_FILES=$(find ./ ../feeds/packages/ -maxdepth 3 -type f -wholename "*/$PKG_NAME/Makefile")

	if [ -z "$PKG_FILES" ]; then
		echo "$PKG_NAME not found!"
		return
	fi

	echo -e "\n$PKG_NAME version update has started!"

	for PKG_FILE in $PKG_FILES; do
		local PKG_REPO=$(grep -Po "PKG_SOURCE_URL:=https://.*github.com/\K[^/]+/[^/]+(?=.*)" $PKG_FILE)
		local PKG_TAG=$(curl -sL "https://api.github.com/repos/$PKG_REPO/releases" | jq -r "map(select(.prerelease == $PKG_MARK)) | first | .tag_name")

		local OLD_VER=$(grep -Po "PKG_VERSION:=\K.*" "$PKG_FILE")
		local OLD_URL=$(grep -Po "PKG_SOURCE_URL:=\K.*" "$PKG_FILE")
		local OLD_FILE=$(grep -Po "PKG_SOURCE:=\K.*" "$PKG_FILE")
		local OLD_HASH=$(grep -Po "PKG_HASH:=\K.*" "$PKG_FILE")

		local PKG_URL=$([[ "$OLD_URL" == *"releases"* ]] && echo "${OLD_URL%/}/$OLD_FILE" || echo "${OLD_URL%/}")

		local NEW_VER=$(echo $PKG_TAG | sed -E 's/[^0-9]+/\./g; s/^\.|\.$//g')
		local NEW_URL=$(echo $PKG_URL | sed "s/\$(PKG_VERSION)/$NEW_VER/g; s/\$(PKG_NAME)/$PKG_NAME/g")
		local NEW_HASH=$(curl -sL "$NEW_URL" | sha256sum | cut -d ' ' -f 1)

		echo "old version: $OLD_VER $OLD_HASH"
		echo "new version: $NEW_VER $NEW_HASH"

		if [[ "$NEW_VER" =~ ^[0-9].* ]] && dpkg --compare-versions "$OLD_VER" lt "$NEW_VER"; then
			sed -i "s/PKG_VERSION:=.*/PKG_VERSION:=$NEW_VER/g" "$PKG_FILE"
			sed -i "s/PKG_HASH:=.*/PKG_HASH:=$NEW_HASH/g" "$PKG_FILE"
			echo "$PKG_FILE version has been updated!"
		else
			echo "$PKG_FILE version is already the latest!"
		fi
	done
}

#UPDATE_VERSION "软件包名" "测试版，true，可选，默认为否"
UPDATE_VERSION "sing-box"
UPDATE_VERSION "tailscale"

# Git稀疏克隆，只克隆指定目录到指定目录
git_sparse_clone() {
    local branch="$1"    # 分支名
    local repourl="$2"   # 仓库地址
    local mvpath="$3"    # 转移地址（相对脚本目录）
    shift 3              # 剩余参数为稀疏检出路径

	local repodir cachepath src_dir foldername del_dirs dir
	# 克隆指定分支的仓库，使用稀疏检出
    repodir=$(basename "$repourl" .git)
	echo -e "\n[info] sparse clone: $repodir"

    # 获取当前操作目录
    local pwd_path
	pwd_path="$PWD"
	echo "[info] pwd_path: $pwd_path"
    cachepath="$pwd_path/cache_repo/$repodir"

    # 冲突处理：已存在则加时间戳
    if [[ -d "$cachepath" ]]; then
        local timestamp
        timestamp=$(date +%Y%m%d-%H%M%S)
        cachepath="${cachepath}_${timestamp}"
    fi

	echo -e "[clone] $repourl => $cachepath (branch: $branch)"

    # 执行稀疏克隆
	git clone --depth=1 -b "$branch" --single-branch --filter=blob:none --sparse "$repourl" "$cachepath"

	# 检出指定的文件夹
	git -C "$cachepath" sparse-checkout set "$@"

    local full_mvpath="$pwd_path/${mvpath%/}"  # 去掉末尾/
    mkdir -p "$full_mvpath"

	# 循环移动所有需要检出的文件夹
	for folder in "$@"; do
		foldername=$(basename "$folder")
		echo -e "sparse-checkout: $foldername"
		# 删除 feeds 中存在的同名目录
		del_dirs=$(find "$pwd_path/feeds/luci" "$pwd_path/feeds/packages" -maxdepth 3 -type d -iname "*$foldername*" 2>/dev/null)
        if [[ -n "$del_dirs" ]]; then
            while read -r dir; do
                rm -rf "$dir"
                echo "[delete] $dir"
            done <<< "$del_dirs"
        else
            echo "[miss] not found in feeds: $foldername"
        fi

        # 计算 maxdepth = 传入路径中 '/' 个数 + 1
        maxdepth_count=$(( $(echo "$folder" | awk -F"/" '{print NF}') ))

		# 查找克隆目录中匹配的文件夹
		# src_dir=$(find "$cachepath" -maxdepth 3 -type d -iname "*$foldername*" -prune | head -n 1)
		src_dir=$(find "$cachepath" -maxdepth "$maxdepth_count" -type d -exec bash -c '[[ "$(basename "{}")" == "'"$foldername"'" ]] && echo "{}"' \; | head -n 1)
        if [[ -n "$src_dir" ]]; then
            cp -rf "$src_dir" "$full_mvpath/"
            echo "[copy] $src_dir => $full_mvpath/"
        else
            echo "[fail] source not found: $foldername"
            continue
        fi

        # 修复 Makefile 引用路径（仅针对 package 目录）
        if [[ "$mvpath" == "package" ]]; then
			echo "need update Makefile"
            find "$full_mvpath/$foldername" -name "Makefile" -exec sed -i \
                -e 's|include ../../luci.mk|include $(TOPDIR)/feeds/luci/luci.mk|g' \
                -e 's|include ../../lang/golang/golang-package.mk|include $(TOPDIR)/feeds/packages/lang/golang/golang-package.mk|g' {} +
        fi
		
		echo "[done] sparse update: $foldername success!"


		# if [[ $mvpath == "package/" ]]; then
		# 	find ./package/$foldername/ -name "Makefile" -exec sed -i 's|include ../../luci.mk|include $(TOPDIR)/feeds/luci/luci.mk|g' {} +
		# 	find ./package/$foldername/ -name "Makefile" -exec sed -i 's|include ../../lang/golang/golang-package.mk|include $(TOPDIR)/feeds/packages/lang/golang/golang-package.mk|g' {} +
		# fi
	done

	rm -rf "$pwd_path/cache_repo"
}

REPO_PATCH="$GITHUB_WORKSPACE/wrt/"

cd $REPO_PATCH

# git_sparse_clone "分支名" "仓库地址" "转移地址(编译根目录下)" "单/多个需要文件夹的目录"
#git_sparse_clone main https://github.com/VIKINGYFY/packages package luci-app-wolplus luci-app-timewol
git_sparse_clone main https://github.com/sbwml/openwrt_pkgs package luci-app-diskman luci-app-vlmcsd vlmcsd 
