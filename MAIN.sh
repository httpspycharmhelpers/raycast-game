#!/system/bin/sh
# MAIN.sh - 检查依赖、生成地图、使用 tmux 分屏运行 I.sh 和 b.sh

# 检查依赖命令
missing=0
for cmd in awk bc tmux; do
    if ! command -v $cmd >/dev/null 2>&1; then
        echo "缺少 $cmd 命令"
        missing=1
    fi
done

if [ $missing -eq 1 ]; then
    echo "尝试安装依赖..."
    # 检测是否为 Termux（Android）
    if [ -n "$PREFIX" ] && [ -d "$PREFIX" ]; then
        pkg update && pkg install -y gawk bc tmux
    else
        # 假设为 Debian/Ubuntu
        sudo apt-get update && sudo apt-get install -y gawk bc tmux || {
            echo "安装失败，请手动安装 awk、bc、tmux"
            exit 1
        }
    fi
    # 重新检查
    for cmd in awk bc tmux; do
        if ! command -v $cmd >/dev/null 2>&1; then
            echo "安装 $cmd 失败，请手动安装"
            exit 1
        fi
    done
fi

# 生成地图（如果不存在）
if [ ! -f map.txt ]; then
    echo "地图文件 map.txt 不存在，正在生成（200x200，随机墙）..."
    awk 'BEGIN{
        size=200; srand();
        for(i=0;i<size;i++){
            for(j=0;j<size;j++){
                if(i==0||i==size-1||j==0||j==size-1) printf "1";
                else {
                    r=rand();
                    if(r<0.35) printf "%d", int(rand()*5)+1;
                    else printf "0";
                }
            }
            if(i<size-1) printf ",";
            else printf "\n";
        }
    }' > map.txt
fi

# 确保 I.sh 和 b.sh 可执行
chmod +x I.sh b.sh 2>/dev/null

# 使用 tmux 分屏：上 I.sh，下 b.sh
tmux new-session -d -s maze3d 'bash I.sh' \; split-window -v 'bash b.sh' \; attach -t maze3d
