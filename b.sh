#!/system/bin/sh

# 读取地图数据（逗号分隔）
map_data=$(cat map.txt | tr -d '\n')
IFS=',' read -r -a map_lines <<< "$map_data"
IFS=$' \t\n'  

if [ ${#map_lines[@]} -ne 200 ]; then
    echo "地图数据错误，预期200行，实际 ${#map_lines[@]}"
    exit 1
fi

cleanup() {
    printf '\033[?1049l\033[?25h'
    exit
}
trap cleanup INT TERM EXIT

printf '\033[?1049h\033[2J\033[?25l'

last_cx=""
last_cy=""
last_width=0
last_height=0

while true; do
    # ---- 自适应尺寸：获取当前终端行列数 ----
    if ! read rows cols < <(stty size 2>/dev/null); then
        rows=24; cols=80  # 降级默认值
    fi
    # 确保最小尺寸
    [ $rows -lt 3 ] && rows=3
    [ $cols -lt 10 ] && cols=10

    # ---- 读取玩家坐标（从当前目录的 player_pos） ----
    if [ -f ./player_pos ]; then
        read px py dx dy < ./player_pos 2>/dev/null
        if [ -z "$px" ] || [ -z "$py" ]; then
            px=40; py=40; dx=0; dy=0
        fi
    else
        px=40; py=40; dx=0; dy=0
    fi

    cx=${px%.*}; cy=${py%.*}

    # 仅当玩家位置或尺寸改变时才刷新，减少无谓绘制
    if [ "$cx" = "$last_cx" ] && [ "$cy" = "$last_cy" ] && [ "$cols" = "$last_width" ] && [ "$rows" = "$last_height" ]; then
        sleep 0.05
        continue
    fi
    last_cx=$cx; last_cy=$cy; last_width=$cols; last_height=$rows

    # 计算地图显示范围（玩家居中，状态行占最后一行）
    HALF_W=$((cols / 2))
    MAP_ROWS=$((rows - 1))          # 留一行给状态栏
    HALF_MAP_H=$((MAP_ROWS / 2))

    start_x=$((cx - HALF_W))
    end_x=$((cx + HALF_W))
    start_y=$((cy - HALF_MAP_H))
    end_y=$((cy + HALF_MAP_H))

    printf '\033[H'

    y=$start_y
    while [ $y -le $end_y ]; do
        x=$start_x
        line=""
        while [ $x -le $end_x ]; do
            if [ $x -eq $cx ] && [ $y -eq $cy ]; then
                ch='p'
            elif [ $x -lt 0 ] || [ $x -ge 200 ] || [ $y -lt 0 ] || [ $y -ge 200 ]; then
                ch='#'
            else
                row_str="${map_lines[$y]}"
                cell="${row_str:$x:1}"
                if [ "$cell" = "0" ]; then
                    ch=' '
                else
                    ch='#'
                fi
            fi
            line="$line$ch"
            x=$((x + 1))
        done
        # 固定宽度，清除行尾残留
        printf '%-*s\n' "$cols" "$line"
        y=$((y + 1))
    done

    # 状态行（占满宽度）
    status=$(printf "玩家坐标: (%.1f, %.1f)  方向: (%.2f, %.2f)  尺寸: %dx%d" "$px" "$py" "$dx" "$dy" "$cols" "$rows")
    printf '%-*s\n' "$cols" "$status"

    sleep 0.05
done
