# MLS 交接文档 V8.4(长期档)

> **更新时间**:Day 19 末(2026-05-06 晚)
> **承接**:V8.3 长期档(Day 17 末状态 + 17.x Day 18-19 进行中)
> **本档新增**:Day 19 · 6 commit 全收官 · 反作弊基石场景 5 闭环 · 2 新坑(33/34)· 5 条登债新增
> **下次开工锚点**:Day 20 · 真机验证 8 条清单 + V2 收官决策 + push 远端

---

## V8.4 vs V8.3 主要变化

V8.3 承诺的"模拟难缠用户测试场景 5"在 Day 19 完成。**反作弊基石全链路闭环**:rejected 双向修改 / manual reject 双重拦截 / cancelled 视角隔离前后端对称 / cancelled 重发路径双入口。

Day 19 累计 **6 commit**(纯 fix,无新功能),修了 4 个真 bug + 抽 1 个共享 helper + 加 1 条新待办类型 + 修复 1 个回滚导致的旧 bug。

V2 完成度从 99% → **99.5%+**。剩真机回归 + push 远端。

---

## 一、人 / 项目基本信息(承袭 V8.3)

- **磊**:创始人 + 唯一开发者,张家口,Windows 11 笔记本,非技术背景
- **项目路径**:`C:\projects\mls\`
- **栈**:Flutter 3.41.7 + FastAPI + MongoDB 8.2 + fakeredis + APScheduler 3.11.2 + JWT
- **当前 IP**:重启后查 `ipconfig` 确认,可能变化
- **测试账号**:张三 13912345678 (LA) / 李红 13200132000 (BA)
- **验证码**:开发期固定 `123456`(Day 18 chore 改),生产前必须改回随机
- **Swagger UI**:`http://<ip>:8000/docs`
- **Claude Code 模型**:deepseek-v4-pro[1m] via deepseek anthropic-compatible 端点

---

## 二、累计战绩(Day 10-19)

### Day 10-17(承袭 V8.3,简列)

- Day 10:客户管理后端 4 commit
- Day 11:5 Tab 骨架 + 工作台重写 3 commit
- Day 12:客户 Tab 全套 1 commit
- Day 13:协作 Tab + 进度条 1 commit
- Day 14:5 Tab 全部真实化 1 commit
- Day 15:1:N 带看专项重构 + 退出登录 4 commit
- Day 16:bug 清理 + 客户选择器 + 直接带看入口 7 commit
- Day 17:内部系统性测试 V1,25 commit,修 8 真 bug

### Day 18(承袭 V8.3 §17,简列)

- 工作树清理 + 验证码固定 123456 + 户型默认值移除 + 路由 typo + 模拟难缠用户测试场景 1-4 + Map cast 安全化部分 + dashscope key revoke + Qwen3-max 试用回退
- 21 commits,真 bug 4 个全修

### Day 19 🆕 反作弊基石场景 5 闭环(6 commit)

```
944a29e  fix(Day19): cancelled 状态支持重新发起成交确认(协作路由 + 申请详情页双入口)
8ae2d46  fix(Day19): 前端视角隔离 mask 白名单与后端对称,补全 maskLa 同型脱敏
6ab9af5  fix(Day19): 工作台待办 LA 操作后刷新 + BA 被驳回待办
b45a120  fix(Day19): rejected 状态 LA 可修改自己填报,共用比对 helper
3b6343f  fix(Day19): 坑#34 同 sr 多条 showing 只看最新一条,rejected 后可重提
c9165fd  fix(Day19): 带看现场照片回到仅相机,防作弊与模块四 §5.2.2 对齐
```

**反作弊基石场景 5 闭环成果**:

| 路径 | 修复 | commit |
|---|---|---|
| rejected 双向修改对称 | 抽 `_compare_and_finalize` helper,BA/LA 任一方改完直接比对(BA 不再回 pending_la_confirm 等 LA 重看,LA 已填值不被清) | b45a120 |
| manual reject 双重拦截 | 后端 PATCH 拦 `reject_kind=='manual'` 返 400 + 前端 BA 红警告区改"撤回成交确认"按钮 + LA 不渲染修改入口 | b45a120 |
| cancelled 视角隔离前后端对称 | 后端 `_format` 的 `not_confirmed` 判断本就覆盖 cancelled,但前端 `maskBa` 只覆盖 `pending_la_confirm`(裸奔 2 个状态),改为 `!= 'confirmed'` 与后端对称,顺手加同型 maskLa | 8ae2d46 |
| cancelled 重发路径打通 | 协作 Tab cancelled 卡片改跳 /showing-request 申请详情(原 /transaction 是 SizedBox.shrink 死胡同),申请详情 BA 视角加"重新发起成交确认"按钮 + LA 视角"BA 已撤回"提示 | 944a29e |
| 工作台待办双向闭环 | LA 操作完返工作台角标自动 -1(_handleTodoTap async + await + _refresh)+ BA 端新增"成交确认被驳回"待办类型(/dashboard/todos 第 5 类) | 6ab9af5 |
| 相机自伤回滚 | Day 17 误把"仅相机"放开为相册,Day 19 改回 ImageSource.camera 与模块四 §5.2.2 对齐 | c9165fd |
| 坑#34 修复 | submit_showing 同 sr 拦截改"只看最新一条",rejected 后可重提,confirmed 后走"再次带看"入口(对齐 1:N 带看设计) | 3b6343f |

**关键技术决策**:

1. `_compare_and_finalize` helper 强制 caller 显式传 `expected_status` 做乐观锁,helper 不从 doc 快照取(避免 race window)
2. PATCH `/transactions/{id}/my-submission` 双分支路由(BA/LA),后端按 caller 身份分调对应函数
3. 视角隔离铁律新规则:**前后端 mask 白名单必须对称**,任一方修改必须前后端同步,否则一边裸奔(坑 33)

---

## 三、当前 5 Tab 状态(Day 19 末)

无变化(承袭 V8.3 第三节)。新增能力都在现有页面里:

- 协作 Tab cancelled 卡片现在跳申请详情(避开 transaction 死胡同)
- 申请详情页 BA 视角 cancelled 加"重新发起"按钮
- transaction 详情页 rejected 三分支显式列(BA/LA/null),manual reject BA 红警告 + 撤回按钮
- 工作台 BA 端新增"成交确认被驳回"待办

---

## 四、当前已知 bug 清单

**无确认的功能性 bug**。

Day 19 反作弊基石场景 5 闭环。剩 8 条真机回归清单:

| # | 路径 | 预期 |
|---|---|---|
| 1 | 张三看 rejected transaction → "修改我的填报" Dialog 预填 = LA 上次填的(非 BA 数值) | 不泄露 BA 数值 |
| 2 | 张三填错价 → reject_reason "价格仍不一致,请双方核实"(无数值) | 中性文案 |
| 3 | 张三填对价 → confirmed + listing sold + settlement 自动 | helper 一致路径 |
| 4 | 李红改 rejected → 直接 confirmed(不再回 pending_la_confirm) | BA 对称改造 |
| 5 | 李红改错价 → 继续 rejected,LA 已填值不被清 | 不丢数据 |
| 6 | manual rejected,李红进详情 → 红警告 + "撤回成交确认"(无"修改并重新提交") | manual 拦截 |
| 7 | 张三确认/驳回 pop 回工作台 → 角标 -1 | B1 待办刷新 |
| 8 | 李红工作台 → 出现"成交确认被驳回,待修改重提" + edit 图标 | B2 BA 待办 |

8 条全过 → push 远端 + V2 收官。

---

## 五、Day 20 待办

### 5.1 真机回归 8 条(估 30-45 分钟)

后端冷启 + 前端 q + flutter run,按上面 8 条清单逐条验。任一卡住先回写本档而非贸然修。

### 5.2 push 远端(8 条全过后)

```cmd
cd C:\projects\mls
git push origin main
```

push 前确认 6 个 Day19 commit 都在,工作树干净,无残留改动。

### 5.3 V2 收官决策

- 8 条全过 + 撤回重发跑通 → V2 收官,转 V2.1 边迭代边拉用户
- 任一卡住 → V2 延期,先把卡点修干净

### 5.4 工作区清理(承袭 V8.3 §5.3)

- `api_config.dart` modified(WiFi IP 残留)→ `git restore` 或加 .gitignore
- 检查 `_api_resp*.json` 等临时文件是否已被 d3b51f4 的 gitignore 规则覆盖

---

## 六、技术债清单(V8.4 全量更新)

### 🔴 高优先级(种子上线前必修)

1. **🆕 BA 工作台待办覆盖不全**(Day 19 末发现,同型 3 条)
   - 当前 `/dashboard/todos` 5 类:LA 视角 4 类(审批申请 / 确认带看 / 确认成交 / 操作奖金)+ BA 视角 1 类(成交被驳回,Day 19 加)
   - 缺位的 BA 视角待办:
     a. **LA 通过带看确认后**,BA 端无"带看已通过,可发起成交"提醒
     b. **LA 标定金已付后**,BA 端无"房源进入交易阶段,请发起成交"提醒
     c. **LA 通过带客申请后**,BA 端无"申请已通过,请联系 LA 安排带看"(需验证当前是否已有)
   - 修法:扩 `api_dashboard_todos`,补 BA 视角 3 类待办。a 类要去重(只显示"最近 confirmed 但 BA 还没发起 transaction 的"),否则历史所有 confirmed 带看会刷一堆消不掉的卡
   - 注意 a 类语义校验:listing 不在 deposit_paid/transaction_ongoing 时,BA 即使有 confirmed 带看也发起不了成交。是否推待办需 spec 决策(强推可能导致用户困惑,弱推可能漏)
   - 预期工作量:1-2 小时(含双视角验收)

2. **B 对象存储迁移**(承袭 V8.3,3-4 小时)
   - 照片 base64 存 MongoDB 是 50 户内的临时方案
   - 必做先决条件:申请腾讯/阿里/七牛 COS 账号

3. **Pydantic 校验补强**(承袭 V8.3,Day 17 经验 9)
   - 后端关键字段无校验:price_wan 允许负数 / 姓名 50 字 / 备注 1000 字均通过
   - 修法:所有用户可编辑字段加 Pydantic validator

4. **实时推送(WebSocket / 极光)**(承袭 V8.3)
   - Day 17 ad451b0 是部分修(详情页 pop 后刷新),Day 19 6ab9af5 也只解决"从待办点入"
   - 真正解法:WebSocket 长连接 / 极光推送

### 🟡 中优先级(3-5 天内)

1. **🆕 被拒带客申请的"再次申请"入口**(Day 19 末发现)
   - BA 看 status='rejected' 的 sr 详情页是死胡同,无操作按钮
   - 变通路径:走"申请带看"主入口创建新 sr,流程能跑通但绕
   - **spec 决策待定**(改前必须先拍板):
     - 选项 a:允许立即重提(纯体验补,有刷屏风险)
     - 选项 b:加冷却期(比如 24 小时)
     - 选项 c:同一拒绝理由不让重提(更严)
   - 修法草案:
     - 后端校验:确认 rejected sr 不算"占位"(可能已经如此,需查)
     - 前端:申请详情页 BA 视角 status='rejected' 加"再次申请"按钮,跳 `/showing-request/new` 预填 listing + customer
   - 预期工作量:30-40 分钟(spec 决策定后)

2. **🆕 LA 标定金/成交进行中改造为协作内操作 + 锁定促成 BA**(Day 19 讨论,架构级)
   - 当前问题:LA 在房源页改状态,与 BA 协作脱钩。LA 审核不严 + 非真实 BA 发起成交,反作弊基石靠"双方填价不一致"兜底,而非前置锁定
   - 改造方案:
     - listing 加 `deposit_associated_showing_id` 字段
     - 标定金/成交进行中入口移到协作 Tab,强制关联一条 confirmed showing
     - 房源页只留撤牌入口
     - 成交发起前置校验只允许 deposit_associated_showing_id 对应的 BA
     - 自促成交(LA=BA)路径校验
     - 老数据迁移脚本(deposit_paid 历史 listing 回填或允许 None)
   - **spec 改 3 篇**:模块二 V11 §5.1 / 模块四 §2.5 §2.6 / 模块五 §3.1
   - 注意 trade-off:模块四 §2.5 "deposit_paid 仍接受新申请作为 backup" 是否还成立,需重新审视
   - 预期工作量:1-2 天(spec 改 + 双端 + 迁移 + 全链路回归)
   - **建议时机**:V2 发版后种子用户跑一周,看是否真出现"LA 误判促成 BA"或"BA 忘记发起",再决定时机

3. **🆕 cancelled 状态文案语义优化**(Day 19 末发现)
   - 现象:cancelled transaction 详情页 BA 卡片仍显示"防伪机制:请您独立填写记忆中的成交价,系统将自动比对"(pending_la_confirm 期间引导文案),但 cancelled 已无任何动作可做
   - 修法:status='cancelled' 时不渲染防伪引导文案,改为静态"已撤回"提示
   - 预期工作量:5 分钟

4. **直接带看(1:N)的 listing 状态守卫过严**(承袭 V8.3)
   - 后端 `create_direct_showing` 当前只允许 listing 在 on_sale/deposit_paid 时再次带看,业务上 transaction_ongoing 也有合理"陪家人复看"场景
   - 修法:`backend/customers.py` 把 transaction_ongoing 加进白名单

5. **房源表单缺奖金输入字段 + 字段维度过少**(承袭 V8.3)
   - 缺:朝向 / 面积 / 楼层 / 装修 / 户型特点标签 / 户型结构
   - 共享库 BA 找房无法多维筛选
   - 预期工作量:1-2 天

6. **成交日期 vs 带看时间严格比较 bug**(承袭 V8.3,Day 8 暴露)

7. **initiate_transaction 未给 bonus_yuan 拍快照**(承袭 V8.3,Day 8 暴露)

8. **带客申请 7 天过期定时任务**(承袭 V8.3)

9. **BottomNav 切回 Tab 时 refetch**(承袭 V8.3,B1 边界外刷新路径)

10. **工作台待办 IA 重构**(承袭 V8.3 §17.5)
    - dashboard_widget 文案"今日要做"→"待办事项"
    - /dashboard/todos 接口过滤 status=='pending'
    - 新增"已办"分页

11. **后端硬编码前端路由路径**(承袭 V8.3 §17.5)

12. **客户详情页 timeline showing event 显示"(未知房源)"**(承袭 V8.3)

13. **奖金结算详情页角色标签中英文混用**(承袭 V8.3)

14. **Map cast 安全化收尾**(Day 19 上半场登债 5 处)
    - response.data['data'] 第二层嵌套 4 处:listing_detail_screen.dart:30 / showing_request_service.dart:63/70/86
    - listing_edit_screen.dart line 61 List<Map> 元素强转

15. **test/widget_test.dart MyApp 类不存在**(Day 19 全工程 flutter analyze 发现)

### 🟢 低优先级(50 户内不做)

- 状态码命名风格不统一(pending_confirm vs pending_la_confirm)(承袭)
- dashboard_summary 单次会话重复请求(承袭)
- 日期/时间选择器中文化(承袭)
- LA 催促 / 14 天回退(等推送)
- 驳回 2 次冻结(等推送)
- 30 天修正窗口
- 自促成交分支(LA=BA)
- 无定金直接签约
- 后台代确认 / 争议仲裁
- 奖金结算 BA 确认收款 + 凭证(等 B)
- listing_cycle 字段全集合落地 + re-list 流程实现(归 V9 spec 未实现项,Day 19 上半场登债)
- 其他 5 个房源状态:coming_soon / paused / pending_check / archived / locked
- DOM 计算 + 自动转状态定时任务
- 归属变更流程
- 开放看房日 / 收藏房源 / 共享库卡片点击进详情
- 状态徽章重构(Day 17 506581c 是最小补丁,根治应改用 widgets/status_labels.dart 字典)
- Flutter deprecated API 批量清理
- 房源表单朝向字段默认"南北通透"是否可接受(产品决策)
- **🆕 带看现场照片改 BottomSheet 二选一**(拍照 / 从相册选,Day 19 讨论)
  - V9 §5.2.5 UI 设计画的是相机+相册并存
  - 当前(c9165fd 之后)是"仅相机"
  - 长期看应支持二选一,与 V9 spec 对齐
  - 预期工作量:30 分钟

### 🟣 迁移相关

- 上 git 远程版本管理(GitHub / Gitee)— **Day 20 push 后部分完成**
- 前端 baseUrl 做 dotenv 配置
- 生产 MongoDB 迁云
- `.claude/settings.json` 的 `ANTHROPIC_AUTH_TOKEN` 改造为环境变量引用(push GitHub 前必做,Day 18 SEC 事件后登债)

---

## 七、🔑 路由命名速查表(承袭 V8.3,无变化)

详见 V8.3 第七节。Day 19 没新增路由。

**踩坑频次累计**:
- Day 7 / 13 / 15 / 16:transaction 单复数往返
- Day 17:`/showings/can-direct` 路由顺序坑 3 同型复发
- Day 18:listings/showing-request/settlement 单日 3 次坑 9 同型复发
- Day 19:无新路由 typo

---

## 八、🔑 坑位档(累计到 Day 19)

V8.1 已记坑 1-27,V8.2 加 28-31,V8.3 加 32,**V8.4 加 33-34**。

### 🆕 坑 33(Day 19):前后端 mask 白名单不对称导致 cancelled 状态视角隔离裸奔

**症状**:中泰城 5-2-301 cancelled transaction,LA 端详情页能看到 BA 填的 500000(应脱敏)。curl 直打后端确认 `ba_deal_price_yuan: null` 已脱敏,问题在前端。

**根因**:
- 后端 `_format` 用 `not_confirmed = doc.get("status") != "confirmed"` 判断,覆盖 pending_la_confirm + rejected + cancelled 三态
- 前端 `transaction_detail_screen.dart` 用 `maskBa = isLA && status == 'pending_la_confirm'`,**只覆盖一态**
- cancelled / rejected 状态下前端 maskBa=false,直接读 doc 字段渲染

**修复 8ae2d46**:前端 maskBa 改为 `!= 'confirmed'` 与后端对称,顺手补 maskLa 同型脱敏。

**经验**:**视角隔离铁律新规则** — 前后端 mask 白名单**必须对称**,任一方修改必须前后端同步,否则一边裸奔。代码注释里明确标注 `参见 transactions.py:586`,future modifications 必须前后端联动改。

### 🆕 坑 34(Day 13 中继 + Day 19 修复):同 sr 多条 showing 只看最新一条

**症状**:同一 showing_request 下挂多条 showings(rejected 后重提的场景),前端协作 Tab 卡片状态机和详情页"带看记录"区域只取最新一条 → rejected 把更早的 confirmed 盖掉,导致进度条停在"带看",成交确认入口永远不出现。

**修复 3b6343f**:`backend/showings.py:submit_showing` 拦截逻辑改"只看最新一条",rejected 后可重提,confirmed 后走"再次带看"入口。

**经验**:1:N 带看场景下任何"同 sr 多条 showing"的判断都要明确"看哪一条"。"全表 status 范围检查"过严会拦合法操作,"只看最新一条"更贴近用户心智。

### 坑 32(承袭 V8.3):Windows cmd 不要用 Linux 命令

详见 V8.3 第八节。

### 坑 28-31(承袭 V8.2)

详见 V8.2 第九节。

---

## 九、协作约定(承袭 V8.3,无变化)

详见 V8.3 第十四节(代码交付 / 服务名一致性 / FastAPI 路由顺序 / Pydantic 三处必改 / viewer-aware 格式化器规范)。

**Day 19 新增约定**:

- **PATCH `/transactions/{id}/my-submission`** 双分支路由,后端按 caller 身份(BA / LA)分调对应函数,共用 `_compare_and_finalize` helper
- **`_compare_and_finalize` helper** 强制 caller 显式传 `expected_status` 做乐观锁条件,helper 内不从 doc 快照取(防 race window)
- **reject_reason 中性化铁律**:任何状态比对失败的 reject_reason 严禁包含对方填报数值,统一文案 `"价格仍不一致,请双方核实"`

---

## 十、常用命令速查(承袭 V8.3,无变化)

```cmd
REM 后端启动
cd C:\projects\mls\backend && venv\Scripts\activate && uvicorn main:app --reload --host 0.0.0.0 --port 8000

REM 前端启动
cd C:\projects\mls\app\mls_app && flutter run

REM 查 IP
ipconfig

REM 杀残余 Java(Gradle 锁)
taskkill /F /IM java.exe

REM 看 listings 全表
cd C:\projects\mls\backend && venv\Scripts\activate && python -c "from database import db; [print(d.get('community'), d.get('building'), d.get('room_no'), '| status=', d.get('status')) for d in db['listings'].find({},{'community':1,'building':1,'room_no':1,'status':1})]"

REM 看 transactions 全表
python -c "from database import db; [print(t['_id'], '|', t.get('listing_snapshot',{}).get('community'), '|', t.get('status')) for t in db['transactions'].find({})]"
```

---

## 十一、Day 19 经验小结(给未来的磊)

1. **PLAN 制度的价值在反复修订**:Day 19 的反作弊基石 PLAN 修订了 3 版才放行。第一版漏了视角隔离铁律 + 三分支 UI + listing_cycle 决策;第二版漏了乐观锁 expected_status + 死代码;第三版才完整。**不要嫌烦,贸然执行的代价更大**

2. **`_compare_and_finalize` helper 是反作弊基石的灵魂**:三处比对逻辑(la_confirm / la_update / ba_update)用同一个 helper,future spec 改一处所有路径同步生效。**不抽 helper 的代码迟早因不一致出生产事故**

3. **前后端 mask 对称是不能省的功夫**:坑 33 暴露的是工程级偷懒 — 后端做了完整脱敏,前端 mask 白名单偷懒只写一态。**安全字段的 mask 任何一边宽松都是裸奔**

4. **Day 17 的 63a00e8 自伤教训不要忘**:今天为产品体验放开的限制,可能两天后另一个场景就需要它回来。任何"放宽限制"的 commit message 必须写清**当时的判断和未来的预期**,future Claude 才能 catch 回滚的时机

5. **Claude Code 用第三方 API 时的 OAuth metadata 玄学**:Day 19 末撞了 deepseek user_id 400,折腾 30 分钟才发现是 settings.json 同时设了 `ANTHROPIC_AUTH_TOKEN` + `ANTHROPIC_API_KEY` 冲突。**两者只能选一个**,deepseek 文档示例只列 AUTH_TOKEN

6. **登债的颗粒度要够细**:V8.4 中优先级里"被拒带客申请的再次申请"和"LA 标定金锁 BA 架构改造"都不是简单加按钮,先拍板 spec 决策再写代码,否则白做

7. **场景 5 反作弊基石闭环不是"防止 100% 串通"**:LA + BA 真要串通伪造成交,前置锁 BA 也防不住(他们就是合作的)。系统能做的是:① 双方填价独立 + 一致才通过 ② 留痕完整可审计 ③ 后台巡检 + 事后惩罚。**反作弊基石是"提高门槛 + 留证据",不是"杜绝可能"**

---

**文档版本**:V8.4(Day 19 末完整快照)
**生成时间**:2026-05-06 晚
**承接**:V8.3(Day 17 末 + 17.x Day 18-19 进行中)
**作者**:磊 + Web 端 Claude(Opus 4.7)+ deepseek-v4-pro(Claude Code 内)
**适用**:Day 20 开工首条信息,新对话锚点
