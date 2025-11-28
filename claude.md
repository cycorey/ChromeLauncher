Profile 管理
需要自动扫描并列出所有现有的 Profile
需要显示每个 Profile 的名称、图标、最后使用时间等信息
支持创建新的 Profile

启动选项
需要支持其他启动参数（如无痕模式、指定窗口大小、禁用扩展等）
需要保存每个 Profile 的常用启动配置

界面设计
采用什么样的界面风格: 列表视图;支持把部分常用的启动模式添加到下拉菜单中。
需要驻留在菜单栏（Menu Bar App）,但是也有一个可以激活的大界面，用来看完整的视图列表。

额外功能
需要支持快捷键快速切换 Profile
需要检测 Chrome 是否已运行
需要支持导入/导出 Profile 配置

技术相关：
数据存储
Profile 列表是手动配置还是自动扫描 ~/Library/Application Support/Google/Chrome/ 目录？
需要为每个 Profile 添加自定义别名/标签,默认应该读取每个profile目前在谷歌浏览器中显示的那个名称。

兼容性
支持 Google Chrome，也要支持 Chrome Canary、Chromium、Edge、brave 等chrome内核的浏览器.

用方案 A：工作目录绑定浏览器（推荐）
每个工作目录关联一个「默认浏览器」
用户可以选择用其他浏览器打开，但会有警告提示

界面上如何组织多浏览器？
一行图标，区分浏览器类型，默认就是这5个。
点击菜单栏图标时：
显示收藏的快捷启动项 + "打开完整界面" 选项？ 其中，收藏的快捷启动项不要放在子菜单里。
全局快捷键唤起主界面（⌘⇧G）
需要支持为特定 Profile 分配独立的全局快捷键，但是默认并没有。

每个 Profile 可以保存的启动参数，以下都支持：
--incognito 无痕模式
--window-size=1920,1080 窗口大小
--disable-extensions 禁用扩展
--new-window 新窗口
--start-fullscreen 全屏启动
自定义参数输入框

用户的自定义配置（别名、收藏、启动参数）存在哪里？
A：~/Library/Application Support/ChromeLauncher/config.json

项目放在当前目录 /Users/c/claudedo/ccc 下，项目名叫什么？
ChromeLauncher

还要能删除不需要的profile，这个需要删除的时候需要弹出确认框。
创建新 Profile: 是「在 ChromeLauncher 里创建」
Profile 图标: Chrome 的 Profile 有自定义头像，需要显示
检测 Chrome 运行状态: 需要显示某个 Profile 当前是否已打开,可以做，通过检查进程参数,这个一定要支持

ultrathink