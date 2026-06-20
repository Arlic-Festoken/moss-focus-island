# Moss · 专注岛

一款本地优先、极低打扰的原生 Mac 学习记录工具。

## 已实现

- 菜单栏一键开始上一次任务；
- 顶部刘海 / 无刘海降级专注岛；
- 25 分钟专注、五分钟点火、暂停与休息；
- 结束后三击记录；
- 分心开始、回流与原因记录；
- 今日任务、学习波形、透明规则反馈；
- 七日洞察与学科花园；
- 53 × 7 年度专注热力网格，时间越多颜色越深；
- 累计专注、活跃天数、当前与最长连续天数；
- 鼠尾草、海湾蓝、暮光紫、暖杏橙、山茶粉、石墨灰六套完整主题；
- 自动记住上次打开的页面和主题；
- 本地 JSON / CSV 导出；
- App 重启后恢复未结束专注；
- 合盖或休眠后按真实时间恢复。

快捷键：

- `⌘ ⇧ F`：开始上一次任务；
- `⌘ ⇧ P`：暂停 / 继续；
- `⌘ ⇧ E`：结束并进入三击记录。

## 年度专注图

洞察页按天汇总最近 365 天的有效专注时长：

| 色阶 | 当天专注 |
| --- | --- |
| 1 | 少于 25 分钟 |
| 2 | 25–60 分钟 |
| 3 | 1–2 小时 |
| 4 | 2–3 小时 |
| 5 | 3 小时以上 |

悬停任意格子可查看日期和当天总专注时长。

## 主题

在「设置 → 外观主题」中切换。主题不仅替换按钮颜色，还会同步改变：

- 主强调色；
- 完成状态色；
- 休息提示色；
- 明暗模式下的纸张背景与卡片背景；
- 年度专注图色阶。

所有数据只保存在：

```text
~/Library/Application Support/Moss/moss-data.json
```

## 构建与运行

当前机器只有 Apple Command Line Tools，因此仓库提供不依赖完整 Xcode 的构建脚本：

```bash
./scripts/typecheck.sh
./scripts/build-app.sh
open dist/Moss.app
```

如果以后安装了完整 Xcode，也可以直接在 Xcode 中打开 `Package.swift`。

系统若提示尚未接受 Apple SDK 许可，请在终端执行：

```bash
sudo xcodebuild -license accept
```

这一步需要输入 Mac 管理员密码。

## 卸载

删除应用：

```bash
rm -rf /Applications/Moss.app
```

连同本地记录一起清理：

```bash
rm -rf "$HOME/Library/Application Support/Moss"
defaults delete com.zhikanghuang.moss 2>/dev/null || true
```
