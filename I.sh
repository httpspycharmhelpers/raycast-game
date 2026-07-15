#!/system/bin/sh
# 动态边框版 - 自适应屏幕尺寸，地图从 map.txt 读取
# 按键: 2前 8后 4左 6右 1左转 3右转 5升高 0降低 7抬头 9低头 +FOV扩 -FOV缩 Q退出

if ! command -v awk >/dev/null 2>&1; then
    echo "缺少 awk 命令"
    exit 1
fi

if [ ! -f map.txt ]; then
    echo "地图文件 map.txt 不存在，请先运行生成命令"
    exit 1
fi
MAP=$(cat map.txt)

posX=40.0; posY=40.0; dirX=-1.0; dirY=0.0; planeX=0.0; planeY=0.66
pitch=0.0; camHeight=0.0; fovScale=1.0
MW=200; MH=200

cleanup() { printf '\033[?1049l\033[?25h'; stty sane 2>/dev/null; exit; }
trap cleanup INT TERM EXIT
stty -icanon -echo min 0 time 0 2>/dev/null
printf '\033[?1049h\033[2J\033[H\033[?25l'
echo "按任意键开始..."; IFS= read -rs -n 1; printf '\033[2J\033[H'

while true; do
    # ---- 自适应尺寸：获取当前终端行列数 ----
    if ! read rows cols < <(stty size 2>/dev/null); then
        rows=40; cols=70   # 降级默认值
    fi
    # 确保最小尺寸
    [ $rows -lt 3 ] && rows=3
    [ $cols -lt 10 ] && cols=10

    # 写入玩家位置供小地图读取（当前目录，避免 /tmp 权限问题）
    echo "$posX $posY $dirX $dirY" > ./player_pos

    printf '\033[H'
    awk -v px="$posX" -v py="$posY" -v dx="$dirX" -v dy="$dirY" \
        -v plx="$planeX" -v ply="$planeY" \
        -v pitch="$pitch" -v camHeight="$camHeight" -v fov="$fovScale" \
        -v mapstr="$MAP" -v WIDTH="$cols" -v HEIGHT="$rows" -v MW="$MW" -v MH="$MH" \
    'BEGIN {
        split(mapstr, lines, ",")
        for(i=0; i<MH; i++) { line = lines[i+1]; for(j=0; j<MW; j++) map[i*MW + j] = substr(line, j+1, 1) + 0 }
        H2 = HEIGHT
        pitchOffset = int(H2 * pitch * 0.4)
        heightShift = int(camHeight * 6)
        horizon = int(H2 / 2 + pitchOffset + heightShift)

        for(x=0; x<WIDTH; x++) {
            cameraX = (2*x/WIDTH - 1) * fov
            rayDirX = dx + plx * cameraX; rayDirY = dy + ply * cameraX
            mapX = int(px); mapY = int(py)
            if(rayDirX==0) deltaDistX = 1e30; else { deltaDistX = (rayDirX<0 ? -1 : 1) / rayDirX; if(deltaDistX<0) deltaDistX = -deltaDistX }
            if(rayDirY==0) deltaDistY = 1e30; else { deltaDistY = (rayDirY<0 ? -1 : 1) / rayDirY; if(deltaDistY<0) deltaDistY = -deltaDistY }
            if(rayDirX<0) { stepX=-1; sideDistX=(px-mapX)*deltaDistX } else { stepX=1; sideDistX=(mapX+1.0-px)*deltaDistX }
            if(rayDirY<0) { stepY=-1; sideDistY=(py-mapY)*deltaDistY } else { stepY=1; sideDistY=(mapY+1.0-py)*deltaDistY }
            hit=0
            while(hit==0) {
                if(sideDistX < sideDistY) { sideDistX += deltaDistX; mapX += stepX; side=0 }
                else { sideDistY += deltaDistY; mapY += stepY; side=1 }
                if(mapX<0 || mapX>=MW || mapY<0 || mapY>=MH) { hit=1; mapX = (mapX<0) ? 0 : ((mapX>=MW) ? MW-1 : mapX); mapY = (mapY<0) ? 0 : ((mapY>=MH) ? MH-1 : mapY) }
                else if(map[mapY*MW + mapX] > 0) hit=1
            }
            if(side==0) perpWallDist = sideDistX - deltaDistX; else perpWallDist = sideDistY - deltaDistY
            if(perpWallDist <= 0) perpWallDist = 0.001
            if(side==0) { wallX = py + perpWallDist * rayDirY; wallY = px - perpWallDist * rayDirX }
            else { wallX = px + perpWallDist * rayDirX; wallY = py - perpWallDist * rayDirY }
            wallX -= int(wallX); wallY -= int(wallY)
            lineHeight = int(H2 / perpWallDist)
            drawStart = -lineHeight/2 + H2/2 + pitchOffset + heightShift
            if(drawStart < 0) drawStart = 0
            drawEnd = lineHeight/2 + H2/2 + pitchOffset + heightShift
            if(drawEnd >= H2) drawEnd = H2 - 1
            colStart[x] = drawStart; colEnd[x] = drawEnd; colWallX[x] = wallX
        }
        for(y=0; y<HEIGHT; y++) {
            line = ""
            for(x=0; x<WIDTH; x++) {
                ds = colStart[x]; de = colEnd[x]
                if(y >= ds && y <= de) {
                    wx = colWallX[x]
                    edgeDist = (wx < 0.5) ? wx : (1 - wx)
                    isVertical = (edgeDist < 0.08)
                    isHorizontal = (y == ds || y == de)
                    if(isVertical && isHorizontal) ch = "·"
                    else if(isVertical) ch = "|"
                    else if(isHorizontal) {
                        if(pitch > 0.05) ch = "/"
                        else if(pitch < -0.05) ch = "\\"
                        else ch = "_"
                    } else ch = " "
                    line = line ch
                } else if(y >= horizon) {
                    line = line "."
                } else {
                    line = line " "
                }
            }
            print line
        }
    }'

    key=""; IFS= read -rs -t 0.08 -n 1 key 2>/dev/null || true
    [ "$key" = "q" ] || [ "$key" = "Q" ] && break
    [ "$key" = "+" ] && { fovScale=$(echo "$fovScale + 0.1" | bc 2>/dev/null || echo "1.0"); [ "$(echo "$fovScale > 2.0" | bc)" -eq 1 ] && fovScale=2.0; continue; }
    [ "$key" = "-" ] && { fovScale=$(echo "$fovScale - 0.1" | bc 2>/dev/null || echo "1.0"); [ "$(echo "$fovScale < 0.3" | bc)" -eq 1 ] && fovScale=0.3; continue; }

    if [ -n "$key" ]; then
        IFS=' ' read -r posX posY dirX dirY planeX planeY pitch camHeight <<< $(awk -v px="$posX" -v py="$posY" -v dx="$dirX" -v dy="$dirY" -v plx="$planeX" -v ply="$planeY" -v pitch="$pitch" -v camHeight="$camHeight" -v key="$key" -v mapstr="$MAP" -v MW="$MW" -v MH="$MH" \
        'BEGIN {
            split(mapstr, lines, ",")
            for(i=0; i<MH; i++) { line = lines[i+1]; for(j=0; j<MW; j++) map[i*MW + j] = substr(line, j+1, 1) + 0 }
            moveSpeed=0.5; rotSpeed=0.15; heightStep=0.15; pitchSpeed=0.05
            if(key=="2") { newPx=px+dx*moveSpeed; newPy=py+dy*moveSpeed; if(map[int(py)*MW+int(newPx)]==0) px=newPx; if(map[int(newPy)*MW+int(px)]==0) py=newPy }
            if(key=="8") { newPx=px-dx*moveSpeed; newPy=py-dy*moveSpeed; if(map[int(py)*MW+int(newPx)]==0) px=newPx; if(map[int(newPy)*MW+int(px)]==0) py=newPy }
            if(key=="4") { newPx=px-plx*moveSpeed; newPy=py-ply*moveSpeed; if(map[int(py)*MW+int(newPx)]==0) px=newPx; if(map[int(newPy)*MW+int(px)]==0) py=newPy }
            if(key=="6") { newPx=px+plx*moveSpeed; newPy=py+ply*moveSpeed; if(map[int(py)*MW+int(newPx)]==0) px=newPx; if(map[int(newPy)*MW+int(px)]==0) py=newPy }
            if(key=="1") { oldDx=dx; dx=dx*cos(rotSpeed)-dy*sin(rotSpeed); dy=oldDx*sin(rotSpeed)+dy*cos(rotSpeed); oldPlx=plx; plx=plx*cos(rotSpeed)-ply*sin(rotSpeed); ply=oldPlx*sin(rotSpeed)+ply*cos(rotSpeed) }
            if(key=="3") { oldDx=dx; dx=dx*cos(-rotSpeed)-dy*sin(-rotSpeed); dy=oldDx*sin(-rotSpeed)+dy*cos(-rotSpeed); oldPlx=plx; plx=plx*cos(-rotSpeed)-ply*sin(-rotSpeed); ply=oldPlx*sin(-rotSpeed)+ply*cos(-rotSpeed) }
            if(key=="5") { camHeight += heightStep; if(camHeight > 2.0) camHeight = 2.0 }
            if(key=="0") { camHeight -= heightStep; if(camHeight < -2.0) camHeight = -2.0 }
            if(key=="7") { pitch += pitchSpeed; if(pitch > 0.8) pitch = 0.8 }
            if(key=="9") { pitch -= pitchSpeed; if(pitch < -0.8) pitch = -0.8 }
            printf "%.6f %.6f %.6f %.6f %.6f %.6f %.6f %.6f", px, py, dx, dy, plx, ply, pitch, camHeight
        }')
    fi
done
