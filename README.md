## raycast-game
3D shell game in termux

# 如何使用？

1左转 2前进 3右转 4左移 5摄像头往上 6右移 7抬头 8后退 9低头 0摄像头往下 +增加视野 -减少视野 q退出

# 依赖

pkg install gawk
pkg install bc tmux
实际上MAIN.sh会自动安装
# 生成自己的迷宫地图.txt

awk 'BEGIN{size=179;srand();for(i=0;i<size;i++){for(j=0;j<size;j++){if(i==0||i==size-1||j==0||j==size-1)printf"1";else{r=rand();if(r<0.35)printf"%d",int(rand()*5)+1;else printf"0"}}if(i<size-1)printf",";else printf"\n"}}' > map.txt

可以自己修改大小前提是你得在I.sh里面自己修改，地图加载时长你自己的手机性能说了算

# 自适应屏幕

· 游戏画面会自动适应终端窗口大小
· 无论窗口缩放、键盘弹出/收起，画面都会自动铺满
· 我认为还是缩小终端看得更舒服

# 实时小地图

· 游戏下方会显示玩家周围环境的小地图
· 使用 tmux 上下分屏：上方3D视图，下方小地图
· 小地图中 p 标记玩家当前位置
· 小地图同样自适应屏幕尺寸
· 刷新率低的可怜
# 启动游戏

```bash
# 首次使用需赋予执行权限
chmod +x MAIN.sh I.sh b.sh

# 启动游戏
./MAIN.sh
```

# 退出游戏

按 q 键退出主程序，或直接关闭 Termux 会话。

