# Moss 专注闭环调研与优化设计

## 目标

在不改变 Moss 现有视觉语言的前提下，补齐“写下意图—安排时间—开始专注—回看事实”的关键交互。

本轮不追求功能堆叠。现有的纸页感、编辑字体、低饱和主题、克制动效和本地优先边界保持不变。

## GitHub 项目纵览

### 番茄钟与专注

- [Super Productivity](https://github.com/super-productivity/super-productivity)
  把任务、时间盒、时间跟踪、休息提醒、番茄钟和复盘指标放在同一条工作流中。优势是闭环完整；代价是主界面信息密度较高。
- [Pomotroid](https://github.com/Splode/pomotroid)
  以单一大计时器为核心，提供短休息、长休息、周期进度、全局快捷键、托盘进度、紧凑模式和多尺度统计。优势是状态非常清晰。
- [Pomatez](https://github.com/zidoro/pomatez)
  提供任务列表、全屏休息、特殊休息、自动开始、严格模式和紧凑模式。强制式行为适合部分用户，但不符合 Moss 低压力、保留自主权的产品气质。
- [TomatoBar](https://github.com/ivoronin/TomatoBar)
  证明了 macOS 菜单栏里的最小控制面仍然可以保留全局快捷键、通知、事件日志和 URL Scheme 集成。
- [Goodtime](https://github.com/adrcotfas/goodtime)
  同时支持经典番茄钟和正向 Flow Timer，并允许跳过或延长阶段。值得借鉴的是对不同进入状态方式的尊重。
- [Pomodoro Logger](https://github.com/zxch3n/PomodoroLogger)
  把计划卡片的预计用时与实际专注记录关联，形成“计划与事实”对照。自动采集桌面活动会扩大隐私面，不纳入 Moss。

### 计划与排程

- [WeekToDo](https://github.com/manuelernestog/weektodo)
  通过安静的周视图、拖放、子任务、任务颜色、时间、重复和提醒降低排程摩擦。其横向周布局与 Moss 排程页方向一致。
- [Logseq Agenda](https://github.com/haydenull/logseq-plugin-agenda)
  用日历、周视图和看板表达同一批任务，说明计划条目需要在时间视图和状态视图之间顺畅切换。
- [Snaptick](https://github.com/vishal2376/snaptick)
  将每日计划、Pomodoro、多个提醒、日历同步、ICS 导入、重复任务和空闲时间分析放在移动端闭环中。

### 手记与回看

- [jrnl](https://github.com/jrnl-org/jrnl)
  强项是快速输入、自然日期、全文搜索和可读纯文本。说明手记的第一优先级应是写得快、找得到。
- [Linked](https://github.com/lostdesign/linked)
  采用按天写作、跨日搜索和完整键盘导航，界面保持低打扰。
- [Memos](https://github.com/usememos/memos)
  用 timeline-first 的快速捕捉减少写作仪式感。
- [RedNotebook](https://github.com/jendrikseipp/rednotebook)
  提供标签、搜索、模板、图片与多格式导出，代表传统桌面日记的完整能力面。
- [Lotti](https://github.com/matthiasn/lotti)
  明确区分“原本想做什么”和“实际上发生了什么”，并把计划块、时间记录和手记保留为独立事实。这与 Moss 的真实记录原则最一致。
- [GitJournal](https://github.com/GitJournal/GitJournal)
  强调 Markdown、可迁移数据和用户自选同步位置，支持 Moss 继续坚持本地优先与显式导入边界。

## 本轮实现

### 1. 统一搜索

- 在“今天”“未来”“手记”书架提供同一枚安静的搜索控件。
- 计划匹配标题、说明和关联任务；手记匹配标题和正文摘要。
- 搜索无结果时显示明确空状态，不改变原有默认选中逻辑。
- `⌘K` 聚焦搜索，`Esc` 清空并退出搜索。

### 2. 过期计划重排

- 对仍未完成且日期早于今天的计划显示暖杏色“已过期”提示。
- 在计划详情与右键菜单提供“移到今天”和“移到明天”。
- 重排保留原来的时分和预计用时，只改变日期；所有写入继续经过 `DataStore`。

### 3. 今日收束手记

- 从今天完成的专注、计划完成数、等待数和实际专注时长生成本地草稿。
- 草稿只提供事实骨架和两个留白问题，不调用模型、不自动保存。
- 用户确认编辑后才写入 `JournalRecord`。
- 入口位于“今天的一页”和手记总览，继续使用现有编辑器和纸页视觉。

## 明确不做

- 不复制其他项目的主题、品牌资产或高密度任务墙。
- 不增加强制全屏休息、严格模式或桌面活动监控。
- 不让 AI 静默修改计划或手记。
- 不把搜索结果、草稿或重排操作上传到新的服务。
- 不改变现有导航、主题色、编辑字体、卡片圆角和动效强度。

## 验证

- 行为检查覆盖搜索匹配、跨日重排和今日收束草稿的事实内容。
- UI 回归检查锁定搜索控件、过期提示和收束入口。
- 运行 `./scripts/verify-all.sh`。
- 构建并实际检查计划页在浅色、深色和最小窗口尺寸下的层级、截断与焦点状态。
