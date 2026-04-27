# Unleash —— 一套用于 Harness 开发的 Skill 套件

> Design the harness once, let the AI run.（一次性把 harness 设计好，让 AI 跑起来。）

---

Unleash 是一个 Claude Code skill 套件 —— 8 个 skill 加一份可查询的知识库 —— 帮助开发者为自己的 AI 协作工作设计、构建、验证并归档定制化的 harness。它的核心洞察是：到了 2026 年，AI 编码协作在真正动到生产场景时仍然会失灵，但缺口并不在模型本身，而在**围绕**模型使用的设计纪律之中。Unleash 把这种设计纪律工业化了。它本身不运行 harness，而是帮助开发者为自己的特定项目构建合适的 harness，并保证这个 harness 在被任何真实工作运行之前已经过验证。

---

## 背景 —— 问题与缺口

### Demo-ware 与生产工程的差距

2026 年的 AI 编码助手仍然在一件事上像 demo-ware：请求进入，diff 输出，鼓掌声起。在原型阶段这没问题。但在生产工程里 —— 一次糟糕的合并要花几个小时调试、一次糟糕的迁移会损坏数据、一次对规格的误解会浪费一整个 sprint —— 这种 demo-ware 模式是用"理解"换"产出"，一旦动到真东西就立即崩塌。

失败模式是稳定的。AI 把模糊的需求宽松地解读，产出看起来合理但其实没满足真实要求的代码。AI 顺手扩大了范围（"既然在这里，那我顺便重构一下"），引入了开发者要在 review 阶段才能发现的回归。AI"实现"了一个它其实无法测试的东西，导致这段实现孤立看是正确的，但在真实系统上会失败。所有这些都不是模型的失败，而是 **harness 的失败**：模型没有任何对范围的约束、没有任何可对照的反馈信号、出问题时也没有回滚路径。

社区针对这个问题给出了两个互补的方向。

**Harness engineering**（典型代表是 Karpathy 的 `autoresearch`）把运行时环境当成头等成果物来设计。它不依赖于模型"做对的事情"，而是显式地设计约束、可量化反馈、状态持久化，从而让一个 agent 能够在最少的人工干预下可靠运行。模型行为是被它的环境塑造的 —— 它能读什么、能写什么、它在优化什么指标 —— 而不仅仅是被 prompt 塑造。这是**面向优化的**：harness 被设计成可以让 agent 长时间无人值守、对一个固定 oracle 跑很多轮迭代。

**Disciplined workflow frameworks**（典型代表是 `superpowers` skill 套件）通过强制 spec-first、test-first、verification-first 的工作流，让 AI 的输出达到与人类工程相同的质量标准。它不约束运行时环境，而是约束流程：没有 spec 就不能实现，没有 review 就不能合并，没有 plan 就不能上线。这是**面向正确性的**：纪律体现在交接环节，而不是执行循环里。

两个方向都指向同一个底层缺口：**AI 协作的可靠性，最多只能与围绕它的设计纪律相当。** 而两者都需要开发者为自己的具体任务设计一个定制的 harness。

### 这件设计工作目前是手作工坊

这件设计工作的杠杆很高。一个设计良好的 harness 改变的是 AI 能完成什么 —— 它把一个会幻觉、会扩范围、会漂移的 agent，变成一个能针对清晰契约可预测地运行的 agent。但目前**设计 harness 的过程本身是手作工坊式的**：每个开发者都从空白开始，重新发现同样的失败模式（含糊的 allowlist、未指定的反馈信号、未审视的不可逆操作），最终产出彼此不一致、无法审计也无法迁移的工件。

### F1 类比

这一缺口有一个有用的类比，源自 2026 年 4 月一段关于 harness 工程的对话（记录在 `harness.md`）。设计一个 harness，就像在赛季开始之前打造一辆 F1 赛车：你在搭建赛道（约束边界），定义计时系统（可量化反馈），搭建维修区基础设施（状态持久化），设计 Parc Fermé 规则（可逆性），设定比赛策略（自主性）。这一切都不是比赛本身 —— 它们都是准备工作，目的是让正赛开始时车手能放手推进而不至于把车队拖进危险。

这个类比在一个重要的维度上很精确。在 F1 中：

- Parc Fermé 在排位赛之前锁定赛车配置 —— 某些东西在物理上不可被修改，而不是只是"不鼓励修改"
- 反馈信号是单一标量（圈速），是在与其他指标对比后被刻意选择的
- 整个周末的结构（FP1、FP2、FP3、排位赛、正赛）是一个分阶段的过程："手动跑、观察、锁定、然后放飞"
- 一旦正赛开始，目标就是最少人工介入 —— 安全车和红旗都是失败模式，不是特性

一个用同样纪律构建出来的 harness 也是同样的形状：每个阶段有显式且被强制（不是仅仅被建议）的 allowlist、一个足够锐利以驱动决策的反馈信号、在任何无人值守运行之前进行的分阶段首次走查、以及一个能在违规时由它来处理而不需要打扰人的 runtime guardian。

而当前工具链的状态强迫你每次都重新发明这套纪律。Unleash 的存在就是为了把这件事工业化。

**Unleash 是为那些想要在 AI 编码协作上获得生产级纪律、又不愿每次都重新发明这套设计工作的开发者准备的。**

这个套件不适合所有人。如果你只是想对一个有界限的问题快速拿到答案，请直接问模型。Unleash 是为了那些**值得设计**的工作准备的：会跑数周的重构、会迭代 100 轮的指标优化循环、需要让其他人加入的编码工作流、一段被幻觉出来的实现会让你花真金白银的时间去拆掉的任务。

### 两个典型场景

设计规范定义了两个驱动整个套件 scope 的典型场景。在阅读后续抽象架构描述之前，把它们当成具体例子读一下是值得的。

**场景 A —— 编码流程 harness。** 一个开发者想以纪律重构鉴权代码。Brainstorming 浮现出：这个开发者更倾向于**在运行的应用里手动验证每一处改动**，而不是写单元测试 —— 于是 debating 把 Test 阶段替换成 Human-Check 阶段，并要求开发者在 harness 跑起来之前显式写出验证清单。Planning 产出一个 guardian prompt，要求在允许 Impl 阶段推进之前先检查清单工件存在。Validating 标记 Human-Check 阶段的退出门没有规定用户如何记录检查结果 —— 开发者和 skill 一起加上了"清单输出"的要求并重新 validate。Archiving（在重构合入之后）产出一份回顾报告，指出清单在使用过程中是非正式地长起来的，并建议下次采用更结构化的格式 —— 这是给下一个编码 harness 的一条具体经验。

**场景 B —— 指标优化 harness。** 一个开发者想要在私有评测集上优化模型的 BLEU 分。Debating 浮现出：开发者的 Decide 逻辑并不平凡 —— 即便 BLEU 略微下降，只要 latency 显著改善，他们也想保留这次 run。Debating 不接受"我会手动决定"作为答案，而是继续追问："那是一个线性组合、一个 Pareto 过滤，还是一个人工裁决？"开发者最终决定：用一个 AI-Judge 阶段，依据一份成文的 rubric。Planning 包含一个建立 baseline 的阶段以及一个 max-iters 边界 —— 后者在 validating 时被标记为遗漏。Archiving（在第 120 轮之后）产出一份回顾，指出 AI-Judge 的 rubric 在迭代过程中重点漂移了，并把这件事标记为发现 —— spec 本应钉死 rubric 或要求记录变更历史。

两个场景都展示了同一条弧线：设计纪律让用户没有显式说出口的假设浮上水面，而 harness 的工件让这些假设在事后可被验证。

---

## 命名 —— 为什么叫 "Unleash"

### 命名弧线：从 harness 到 Formula 再到 Unleash

"harness" 这个词在英文里字面就是缰具：一组缰绳、皮带和马嚼子，它**约束**动物的动作、**疏导**它的力量。Karpathy 选择 "harness" 作为 `autoresearch` 运行时结构的名字非常贴切 —— harness 限制 agent 能做什么、把它的输出引导进反馈循环、让它的行为可预测。这个比喻很坦白：harness 是一个**控制系统**。

最终产出 "Unleash" 这个名字的对话也是从这个词源观察开始的。2026 年 4 月，原作者 (ghk) 与一个 AI 协作者 (claw) 一起探讨了 F1 类比，从赛马 ——"harness" 既作为词、也作为实践存在的地方 —— 一路追溯到 F1，那是一项已经完全工程化的运动。F1 赛道的设计哲学很干净地映射到 harness 工程上：`规则 (constraints)`、`反馈 (feedback)`、`可逆性 (reversibility)`、`自主性 (autonomy)`、`积分赛 (the real run)`。

从那场对话出发，AI 提议了一族走 "Formula" 路线的名字 —— Formula A、Formula X 以及一些相关变体 —— 它们都在唤起"设计好规则，让 agent 去比赛"这种哲学。早期方案的 tagline 写的是：*"Design the Formula, Unleash the Agent."*

在那场对话里，**Formula** 最终被选作这种**哲学**的名字：一个 harness 就是一个 formula（一份精确的、被规则约束的规格），agent 在其中竞争。对话也就停在 "Formula" 这里 —— 大家理解：这个名字属于纪律本身，属于让 agent 行为变得可预测的那套规则与约束。

但**用来帮开发者构建那些 harness 的工具套件**最后取了另一个名字。命名讨论中浮现出过一句话，比 "Formula" 更准确地抓住了这条弧线：*"Design the Formula, Unleash the Agent."* 用户真正想要的，是这条弧线**末端**的那个动作。**Unleash** 就成了套件的名字。**Unleash** 抓住的是这件工作的**结果**，不是机制。机制是 harness 设计 —— 约束、严谨、纪律。结果是：当那一切完成后，你**赢得了**让 AI 自信运行的资格。

### 机制命名 vs. 结果命名

这个名字里有一个刻意的哲学反转。整个套件的内容**都是在构建约束**：更锐利的 allowlist、更具体的反馈信号、更紧的 guardian prompt。每天用它的体验是限制。但限制不是目的，而是手段。目的是**信心**：当所有这些限制都被设计、被验证之后，你才真的可以信任 agent 去运行。

- `harness` 这种命名暗示"我们约束你"。它描述系统**是什么**。
- `unleash` 这种命名暗示"我们解放你"。它描述系统在前置工作就绪之后**让你能做什么**。

一个叫 `harness-builder` 的套件会吸引那些想构建约束的开发者。一个叫 `unleash` 的套件吸引的是那些想让自己的 AI 干真活的开发者。两者其实是同一个开发者 —— 取名只是改变了哪一半的工作在感觉上居于首位。

`superpowers` skill 套件（Unleash 借鉴了它的若干设计 pattern）使用的是同样的"结果命名"逻辑：名字描述用户获得的能力，而不是底层的工程纪律。

在 Unleash 这里，这种反转尤其鲜明。这个套件存在的全部目的就是构建**更好的缰** —— 更显式的 allowlist、更锐利的反馈信号、更可验证的 guardian prompt。它做的每一件事都在**增加约束**。但它这么做是为了 —— 当约束被做对之后 —— 你能够足够信任那个 agent，**真正放它去跑**。这个名字选了终点，不是旅程。

### 命名对比

| 名字 | 隐含 | 描述 | 焦点落在哪里 |
|------|------|------|---------------|
| `harness` | "我们约束你" | 机制 | 缰具 |
| `harness-builder` | "我们替你造约束" | 工具 | 造缰具的过程 |
| `Formula` | "我们给你规则" | 哲学 | 规则集 |
| `unleash` | "我们解放你" | 结果 | 走完纪律之后你赢得的东西 |

这个名字也是一个**主张**：如果你做完了设计工作，那份自主性是你**赚来的**。脱离前置工作而单说 "unleash"，是鲁莽的。带着前置工作说，它就是准确的。

### Tagline

> *Design the harness once, let the AI run.*

这条 tagline 同时抓住了两半：前期的设计纪律（"design the harness once"）以及它使能的自主运行（"let the AI run"）。少了任何一半，另一半都不成立。

---

## 技术框架 —— 架构

Unleash 的架构由 5 条承重的设计原则塑造。skill 设计中的每一个决定都能追溯到其中的一条或多条。理解这些原则是理解整个套件为什么这样工作的最快路径。

### 3.1 Skill 优先，而非模板优先

Unleash 不包含任何写死的 harness 模板，没有预填好的阶段配置，也没有让你 copy 之后改一改的起手脚手架。看起来像一个"五阶段编码 pipeline"的东西，并不是套件**输出**的模板 —— 它是 brainstorming skill 给出的对话建议，因为它注意到你的项目里有测试套件、且功能 scope 是有界的。你可以原样接受、可以修改任意阶段，也可以拒绝它，从原语词汇出发自己设计。

理由是：模板会训练用户去**填空**，而不是**设计**。如果套件把结构写死，那么偏离它就需要去 hack 模板；AI 也就没有理由出现在设计对话里。如果套件交付的是**知识** —— 词汇、模式、反模式、适用性探针 —— 并要求 AI 把这些知识应用到**当前这个项目**上，那么浮现出来的每一个 harness 都是真正贴着它要治理的工作做出来的。

知识引导 AI；AI 完成设计。没有填空。

### 3.2 B 层 + C 层双输出

每个 Unleash 帮助产出的 harness 都有两个截然不同的输出层。

**B 层**是软引导：`spec.md`、`plan.md`、各阶段的 markdown 文档、guardian prompt 文件。它们是写**给** AI 看的，是给那个将要使用这个 harness 的 AI 的：给它结构、词汇、上下文，以及每条约束背后的推理。一个 B 层工件并不能阻止 AI 做错事 —— 它在**说服与定位**。

**C 层**是硬强制：Claude Code hooks、`settings.local.json` 条目、pre-commit 脚本。这些工件**绑定** AI 实际能做什么 —— 它们针对的是 AI 的**工具调用**，不是 AI 的意图。一个拦截 `git push --force` 的 C 层 hook 不会请求 AI 三思 —— 它直接让那次操作完成不了。

关键在于，**两个层都是由实现阶段的 subagent 根据 spec 写出来的真代码**。一份随 Unleash 工具包一起预先写好的 `.claude/hooks/` 脚本会变成模板 —— 也就违反了 skill 优先原则。一个 hook 是由实现者读了用户的 spec、理解了在这个特定项目里哪些操作是不可逆的、然后专门为这些操作写出具体的拦截逻辑 —— 这不是模板，这是 harness 工件。

这个区分很重要，因为只有 B 层的 harness（工作流即 harness）和带 C 层的 harness（运行时机器被装上去了）有不同的**生命周期终点**。详见 §3.5 以及 skill 走查。

### 3.3 AI 优先的运行时强制

硬强制（C 层）**不是默认**。默认的是 **Runtime Guardian**：一个独立的 AI subagent，对每一批 harness 活动做事后审查，并在违规时触发 `git reset --hard` 回滚。

Hook 被保留给一个非常具体、非常窄的场景：**真正不可逆的操作** —— 破坏性 bash 命令、对外的 API 调用、邮件发送、包发布。对这些操作来说，事后审查太晚了。一个在 `git push --force` 已经传播到远端之后才注意到的 guardian，根本不是有用的安全网。对真正不可逆的操作，套件回退到工具调用层的事前拦截。

这是**一个刻意的哲学，而不是遗漏**。如果每一个 AI 决策都需要在 OS 层面来一道技术拦截才能保证安全，那这就不是 harness，而是**笼子**了。harness 的设计前提是：它的约束足够可信，guardian 可以在违规之后再处理（因为它们是可逆的），把事前拦截留给真正不可逆的边角。

哲学代价是被承认的：会有一些违规在 guardian 来得及审查之前就已发生。这个代价之所以被接受，是因为大多数违规是可逆的（一次糟糕的文件编辑就是 `git reset` 的一次回滚）；因为 guardian 能处理 hook 处理不了的细微情形（hook 读不到上下文，guardian 可以）；也因为"在物理上阻止一切可能的不当行为"和 harness 应该是什么是不一致的。

这条原则的副作用是：**guardian prompt 本身是一类一等公民的设计工件，不是事后补的东西**。Debating skill 有一类专门的挑战：**"在阶段 N 期间，有哪些操作 guardian 看不到，那是否可接受？"** Planning 把 guardian prompt 当作一等工件来 review，有专属的质量检查。Validating 检查 guardian 的审查范围是否覆盖了阶段的整个动作面。Walking-through 在一次真实违规上验证 guardian 真的会触发。**对同一个工件设了 4 道独立检查点** —— 因为一个**有盲点**的 guardian 比没有 guardian 更糟，它会带来一种虚假的覆盖感。

### 3.4 5 元素框架作为提问骨架

harness 设计的五个底层条件是：**约束边界 (constraint boundary)**（agent 在每个阶段能读、能写、能执行什么）、**可量化反馈 (quantifiable feedback)**（harness 如何知道自己在前进）、**状态持久化 (state persistence)**（历史如何在中断和重启中存活）、**可逆性 (reversibility)**（每个阶段的动作如何被撤销，触发条件是什么）、**自主性 (autonomy)**（harness 在多大程度上无人值守运行，由什么治理）。

这五个元素在 brainstorming 和 debating 中被作为**提问骨架** —— 是用来发现 harness 需要什么才会可靠的探针 —— 而**不是**一份必填字段清单。关键的纪律是：如果一个特定 harness 对某个元素没有任何有意义的表达，那这个元素必须被显式地标记为 **N/A 并附带理由**，并在所有下游工件里跳过。一个在每个阶段过渡处都有人介入的编码 harness，可以合法地把 Autonomy 标为 N/A。一个不带循环的单次变换可以合法地把 State Persistence 标为 N/A。但这个 N/A 必须是**刻意且明示**的，不能是隐含的。

元素从不被强迫填充。一个 harness 实际只需要三个元素，却在 spec 里塞满了五个填好的元素小节，那是在制造样板 —— 设计纪律塌回了模板填空。

知识库（`references/unleash-knowledge.md`）里包含了对每个元素的详细适用性探针和示例对话 —— 那些扎根于真实项目观察的具体问题，并配有两种答案形态，演示根据用户回答对话会如何分叉。这正是 brainstorming 和 debating skill 所依据的知识。它**不是**一份要填的问卷，而是用来为当前这个具体项目设计**对的那个问题**的参考。

### 3.5 显式接口契约

skill 链上每一个 skill 都在自己的头部声明一份四部分契约：**Consumes**（依赖什么上游工件）、**Produces**（交付什么下游工件）、**Precondition**（启动前必须为真的条件）、**Postcondition**（结束时必须为真的条件）。

这是为了应对套件作者在 `superpowers` 中观察到的一种脆弱性：那个套件里的跨 skill 契约是**隐式**的，可能在版本演进里悄悄漂移，直到某个下游 skill 收到意料之外的输入才被注意到。Unleash 这条链是**为每一道交接都可被验证**而工程化设计的。如果 `unleash:implementing` 声明它产出 `.unleash/manifest.json`，那 `unleash:validating` 就可以在它的 precondition 里**显式地**检查这个文件是否存在。没有任何东西被假设；每一道交接都可被检视。

契约语言在 8 个 skill 里是统一的。读完一个 skill 的头部就足够知道：它需要上游什么、它给下游什么、它启动和终止的条件分别是什么。这让整条链可被调试：一旦出问题，你能确定是哪个 skill 的 postcondition 没满足、哪个工件缺失。

---

### 3.6 两种 harness 形态

Unleash 这条链显式地支持两种不同形态的 harness，它们有不同的生命周期终点。

**Runtime harness（运行时 harness）。** harness 在 `.unleash/` 目录下产出运行时工件 —— 阶段配置文件、guardian prompt 文件、可选的 hook、settings 补丁。这种 harness 是被构建来**反复使用**的：每晚运行的指标优化循环、治理一场进行中的重构的编码纪律。manifest（`.unleash/manifest.json`）跟踪每一个 Unleash 创建或修改过的文件。runtime harness 的生命周期终点是 `unleash:archiving`，它会把所有生命周期工件打包，并派发一个全新的独立 reviewer 进行 end-of-life 审计。

**Single-task harness（仅 B 层的 harness）。** harness **就是对话本身**：brainstorm → debate → plan → implement 驱动一个 bug 修复或一个 feature。没有任何运行时机器被装上去。`.unleash/manifest.json` 要么不存在，要么不包含运行时工件。生命周期终点是 `unleash:reporting`，它派发一个新鲜的 reviewer 对 git diff 进行**冷读**审计 —— 只对照 spec。

两种形态都是一等公民。套件用**互斥的**生命周期终点 skill 显式地支持两者：每一个 skill 都会检测 harness 形态错配并把用户重定向到另一个。一个用 Unleash 对话链完成了一次 bug 修复的用户，如果调用了 `unleash:archiving`，会被重定向到 `unleash:reporting`，因为没有 manifest。

两种形态在"end of life 是什么意思"上也不同。runtime harness 有一个**生命周期**：被构建、被反复运行、最终被退役。end-of-life 的问题是："这个 harness 在它的生命周期里完成了什么？一个**没看过构建过程**的 reviewer 会怎么看它的设计？" single-task harness 没有生命周期：它驱动了一次实现、产出了一份 diff，就结束了。end-of-life 的问题是："这份 diff 是否符合 spec 的承诺？一个 reviewer 在冷读时会发现什么？" 不同的问题需要不同的 reviewer 配以不同的输入。

---

### 3.7 纪律机制

跨多个 skill 出现了若干具体机制，它们用来**在 AI 最容易合理化偏离的边缘**去强制纪律。

**HARD-GATE 标记。** 每个 skill 都包含 `HARD-GATE` 块 —— 命令式的"do NOT"指令，关闭了 skill 作者预判到的特定合理化路径。`unleash:brainstorming` 的 HARD-GATE：**"在 Phase A 静默上下文探索完成之前，不得问问题"**。`unleash:implementing` 的 HARD-GATE：**"终止消息必须严格如字面所写；不得追加部署步骤或除调用 `unleash:validating` 之外的任何手动 e2e 指令"**。这些 gate 之所以存在，是因为 AI 驱动的工作流中最常见的失败**不是随机的** —— 它们是当下感觉很有帮助的可预测外推。

**反模式 Thought/Rebuttal 对。** 每个 skill 列出特定的失败模式，写成一对 thought 和 rebuttal。"This project is simple enough to skip debating" → "Complexity is not the criterion for skipping design. Skipping debating means the spec is not committed; implementing a harness from uncommitted brainstorm notes is a plan failure." 这些对子先发制人地堵住那些已被观察到出现在 AI 驱动工作流会话中的具体合理化语句。

**新鲜上下文交叉验证。** Validation 作为一个**独立 agent** 运行，它从 implementing 会话继承到的上下文是**零** —— 它只收到 harness 工件和原始 spec。Archiving 派发的 reviewer 从未见过构建、validation 报告或 plan。Reporting 派发的 reviewer 只看到 spec 和一份过滤过的 git diff。**新鲜上下文隔离在链上 3 个独立点出现**，正是因为：一个继承了实现者**框定**的 agent，会倾向于**确认**实现者的假设，而不是**挑战**它。

**Phase 原语词汇。** harness 的阶段由 6 个具名原语组合而成：`Read-Only`、`Restricted-Write`、`Script`、`Human-Check`、`AI-Judge`、`Loop`。每个原语有定义好的行为、典型 allowlist 形状、典型 gate 条件。这套词汇**不是**对 harness 能做什么的限制 —— 它是用来**设计与沟通** harness 的共享语言。一份说"phase 3 是 `Restricted-Write` 阶段，只写入 `src/auth/`"的 spec 是无歧义的；一份说"phase 3 做实现工作"的 spec 不是。

**manifest 作为权威清单。** `.unleash/manifest.json` 是 Unleash 已安装内容的**唯一真相源**。它记录每一个被创建或修改的文件（被修改的文件还会记录原始内容的 SHA）、安装时间戳、以及 skill 版本。`unleash:validating` 用它检查孤儿工件。`unleash:walking-through` 用它确认所有工件都被跟踪了。`unleash:archiving` 用它框定实现快照的范围。卸载脚本（`scripts/unleash-uninstall.sh`）用它来反向撤销所有改动，对手工改过的文件会**拒绝回滚**，除非用户显式确认。

---

## 8 个 Skill 如何构成一套 Harness 开发系统

### 4.1 整条链的全貌

两种形态，一个共享内核：

```
                     intent ("I want to harness X")
                                │
                                ▼
                       unleash:brainstorming
                  (silent context exploration → grounded
                   dialogue → committed brainstorm notes)
                                │
                                ▼
                        unleash:debating
                  (gap-driven challenge → committed spec.md)
                                │
                                ▼
                        unleash:planning
                  (Artifact Dependency Map + harness-construct
                   task groups → committed plan.md)
                                │
                                ▼
                       unleash:implementing
                  (fresh subagent per task → real harness code
                   + .unleash/manifest.json)
                                │
                                ▼
            ┌─────── decision: runtime artifacts installed? ───────┐
            │                                                       │
      YES (.unleash/manifest                               NO (manifest
      exists with runtime                                  absent or
      artifacts)                                          B-layer only)
            │                                                       │
            ▼                                                       ▼
    unleash:validating                                   unleash:reporting
    (harness-aware audit,                            (cold-review report from
     6 invariant checks)                              fresh reviewer)
            │                                        [end of single-task chain]
            ▼
    unleash:walking-through
    (first real run + intentional
     violation smoke test)
            │
            ▼
    [user runs harness for real work — indefinite duration]
            │
            ▼
    unleash:archiving
    (lifecycle bundle + fresh
     independent reviewer audit)
            │
            ▼
    [optional: scripts/unleash-uninstall.sh]
```

左分支是 runtime harness 路径，右分支是 single-task（仅 B 层）路径。两条分支上的 skill 都强制互斥：如果你试图在仅 B 层的 harness 上跑 `unleash:archiving`，它会停下并把你重定向到 `unleash:reporting`。

链上每两个 skill 之间都有**用户审批门**。**没有任何 skill 自动调起下一个**。每一个 skill 的 postcondition（工件已 git commit、用户已 review 并批准）正是下一个 skill 的 precondition。

---

### 4.2 单个 skill 的走查

#### 1. `unleash:brainstorming`

入口。它定义性的纪律是**顺序**：在向用户提任何问题之前，skill 严格按顺序跑完三个阶段。

**Phase A（静默上下文探索）：** 读 `README.md`、`CLAUDE.md`、包清单、`git log --oneline -20`、顶层目录结构、有代表性的源文件、任何已存在的 `.unleash/` 目录。这一阶段**不**产生任何用户可见的输出 —— 只产出一个对项目的内部模型。在这一阶段完成前提问，是显式的 HARD-GATE 违规。

**Phase B（假设形成）：** 基于 Phase A 的观察形成假设：这是个什么项目、用户大概想 harness 什么、5 个元素中哪些可能适用。仍然是内部的。

**Phase C（接地对话）：** 只有到这里 skill 才开始问。每个问题都必须**可验证地引用 Phase A 的某项观察**。"What is your constraint boundary?"（差 —— 离开了上下文）。"我看到 `src/auth/` 有 40 个文件，最近的 commit 看起来是一次活跃的重构 —— 约束边界是整个 auth 模块，还是某个具体子树？"（好 —— 接地）。每轮一个问题，倾向单选，最后一个选项永远是"其它/请自行描述"。

**Produces:** `docs/unleash/brainstorm/<YYYY-MM-DD>-<name>.md` —— brainstorm 笔记，包括 Phase A 观察摘要（这样静默探索之后可被审计）、harness 意图、case-type 假设（coding / metric / hybrid / freeform）、5 元素适用性草图、以及结转给 debating 的开放问题。

**不做：** 产出 spec、提议阶段、做出设计承诺。Brainstorming 是**生成式（发散）**的。设计承诺是 debating 的工作。

brainstorming 与 debating 之间的分割不是随意的。生成式模式（开放探索、形成假设、问问题）和批判式模式（基于 gap 的挑战、向承诺收敛）受益于截然不同的 prompt 和不同的心理状态。把它们混进同一个 skill 会产出感觉很有效率但其实产出含糊 spec 的会话 —— 生成的能量不停打开问题，而批判的能量本应关闭问题。把它们分开，意味着 brainstorming 可以以"这是我们已经知道的，这是仍然开放的"作结，而 debating 可以以"这是我在写 spec 之前需要关闭的 gap 地图"作起。

---

#### 2. `unleash:debating`

收敛 skill。它定义性的纪律是 **gap-driven（gap 驱动），而不是 template-driven（模板驱动）**。它**不**遍历一份标准的 harness 问题清单。它仔细读 brainstorm 笔记，构建一份"什么是具体的 vs. 什么是含糊的"的认知 gap 地图，并发起**引用具体段落**的挑战。

gap 地图有 4 类：*含糊（vagueness）*（用户的话哪里发毛了、哪里精确）、*未明示假设（unstated assumptions）*（可能不成立的设计前提）、*重建漏洞（reconstruction holes）*（笔记里推不出来的任何东西）、*5 元素盲区（5-element blind spots）*（标了适用但还没具体化的元素）。进度的衡量是**关闭了多少 gap**，不是**问了多少问题**。

每个挑战都引用 brainstorm 笔记里的一个具体段落，旨在产出三种结果之一：具体的新内容、对一个 trade-off 的显式承认、或带理由的显式 N/A。skill **从不**接受"我以后再想"作为对一个 gap 的回答。

**Produces:** `docs/unleash/specs/<YYYY-MM-DD>-<name>-spec.md` —— 正式的 harness 设计 spec，必填小节包括：`case_type`、`five_element_analysis`、`phase_machine`（按序的阶段，每个阶段有 name、type、allowlist、entry gate、exit gate、消费/产出工件）、`guardian_design`、`optional_hooks` 以及 `out_of_scope`。任何小节都不得包含占位符。

Debating 也是捕获 `testing_mode` 的 skill。当它针对编码案例的 harness 探查 Quantifiable Feedback 元素时，它抛出一个四选一问题：(A) 标准红绿 TDD、(B) 由人工核验的逻辑/手动清单、(C) 完全跳过测试、(D) 其它。这个 mode 被记录到 spec 中，并向下传到 planning 的 Test 阶段形态以及 implementing 的 subagent 指令里。如果没有这个探针，planning 会对每一个编码 harness 默认走 TDD —— 这对那一类很重要的、其工作根本不适合自动测试模型的用户来说是错误的。

**不做：** 产出 plan、提议实现路径、或锁定任何工件文件名。spec 是一份**设计文档** —— 它规定 harness 应该做什么以及为什么，**不**规定如何实现。

spec 的质量门是**结构性**的：每一个必填小节都必须存在且非占位。一个写着 "guardian design: TBD" 的小节会过不了门。这不是官僚式形式主义 —— 它是**保证 debating 的严谨能贯穿到 implementing** 的机制。如果 spec 里有 gap，plan 会替它糊上去，而 implementing 的 subagent 会用一个"看起来合理但其实错"的猜测把 gap 填掉。**在 debating 中关闭 gap 比在 validation 失败时再发现要便宜得多**。

---

#### 3. `unleash:planning`

实现规划 skill，建立在 `superpowers:writing-plans` 的纪律之上，并作了 harness 特定扩展。它继承了父 skill 的两条不可让步的铁律：零占位规则（"TBD"、"TODO"、"implement later" 以及 "similar to Task N" 都属于 plan 失败），以及 2-5 分钟任务粒度要求（无法在 2-5 分钟内完成的任务太粗，琐碎的子步骤太细）。

harness 特定的扩展是：

**Artifact Dependency Map（工件依赖图）。** 一张表，对 harness 将产出的每一个工件，显式地说明哪个 task 创建它，哪些下游 task 消费它。这能在写出一行代码之前，发现孤儿工件（被产出但从未被消费）和消费断口（被消费但从未被产出）。

**按 harness construct 组织的 task 组。** plan 不是平铺的 task list，而是把任务组织成：Group A（Phase Machine —— 配置文件、状态文件、阶段进入/退出逻辑）、Group B（Runtime Guardian —— prompt 文件、调用粘合层、回滚机制）、Group C（Optional Hooks —— 仅在 spec 声明了不可逆操作时才出现）、Group D（Walkthrough Scripts —— 给 `unleash:walking-through` 执行）。这种结构让 plan 与 harness 架构之间的关系**显式**。

**`testing_mode` 分支**（v0.3.2 加入）。plan 从 spec 的 Quantifiable Feedback 小节中提取 `testing_mode`，并据此塑造 Test 阶段：mode A（TDD）产生一个 `Restricted-Write` 的"写测试"任务；mode B（手动清单）产生一个 `Human-Check` 任务，附有一个明确路径下的 markdown 清单和一个显式的 halt 步骤；mode C（跳过）完全省略 Test 阶段；mode D（其它）跟随 spec 的规定，若 spec 含糊则停止。

**Produces:** `docs/unleash/plans/<YYYY-MM-DD>-<name>-plan.md`。

**不做：** 实现任何东西、做 spec 中没有的决定、或在一份 plan 里混入多个独立子系统。如果 spec 治理一个有界的 harness，那 plan 治理的就是**这个 harness** 的实现，仅此而已。

plan 的自审（Phase D）显式声明它检查什么：Spec Coverage（每条 spec 要求都映射到了 plan 任务吗？）、Placeholder Scan（零 "TBD" 或 "TODO"）、Type Consistency（每个工件的类型正确吗）、Artifact Dependency Closure（不存在没有被消费的产出任务，也不存在没有产出来源的消费任务）、Guardian Prompt Quality（guardian prompt 作为一等工件被 review，**不是**"只是个字符串"）、Testing-Mode Honored Check（plan 的 Test 阶段与 spec 的 `testing_mode` 一致）。这道自审正是把"会干净实现的 plan"和"两步之后会触发 validation 失败的 plan"区分开来的东西。

---

#### 4. `unleash:implementing`

控制器 skill。它**对 plan 中的每一个 task 派发一个全新的 subagent** —— 不是一个 subagent 跑完整个 plan，也不是把相关任务批量打包。每个 subagent 都收到**任务全文逐字粘贴**到自己 prompt 里。subagent **从不读 plan 文件**；由控制器读 plan 并把文本投递过来。这能阻止 subagent"提前阅读"并基于尚未分配给它的任务做决定。

每个 subagent 还会收到场景设置：harness 的 case type、guardian 角色摘要（一句话），以及它应当知道的任何上游工件。subagent 报告 DONE、BLOCKED 或 NEEDS-CONTEXT。**这一阶段不做深度 review** —— 那是 validating 的工作。

每完成一个 task 组并提交，skill 就向 `.unleash/manifest.json` 追加条目。manifest 是**增量长大**的；每一次 commit 都是一个可被验证的检查点。如果 implementing 在中途被打断，manifest 精确反映已经被安装的内容，让 validating 可以审计这种部分状态。

**Produces:** 用户项目里的真实 harness 代码 —— 阶段配置文件、guardian prompt 文件、可选 hook 脚本、settings 补丁、walkthrough 脚本 —— 加上 `.unleash/manifest.json`。

**不做：** 深度 review、部署、CI/CD 配置，或任何越过"用户项目里已 commit 的代码"边界的事情。终止消息上的 HARD-GATE 是显式的：**不要给出"除调用 `unleash:validating` 之外的下一步"**。

"每任务一个 subagent"的派发模式有两条值得理解的关键性质。**第一**，每个 subagent 从前面的任务那里继承的上下文是零 —— 除了通过共享的仓库状态外，它对前一个 subagent 的决定或代码毫无记忆。这意味着每个 subagent 必须收到**完整、自包含**的指令；它无法依赖"你知道前一个任务做了什么"。控制器（implementing）负责确保每条任务 prompt 是完整的。**第二**，subagent **从不读 plan 文件** —— 它收到的是被直接粘贴过来的任务文本。这能堵住一种失败模式：subagent 读到相邻的任务，然后"很贴心地"把它们合起来或者跳着做。task N 的 subagent 实现 task N；task N+1 到 N+M 不归它管。

这种模式的代价是开销：N 个任务意味着 N 次 subagent 调用，每次都重新加载上下文。收益是**可预测性与可调试性**：每个任务的实现都是可隔离的，每个 subagent 的 commit 是可追溯的，task N 的失败不会污染 task N+1 到 N+M。对 harness 实现而言 —— 目标是正确性，而不是吞吐量 —— 这是正确的取舍。

---

#### 5. `unleash:validating`

构建期审计 skill。它作为**独立 agent** 在新鲜上下文中运行 —— 它收到的是 harness 工件和原始 spec，**没有任何**来自 implementing 会话的东西。这种隔离正是它的意义所在：一个继承了实现者**框定**的 agent，会倾向于**确认**实现者的假设。

skill 跑 8 项检查，其中 6 项是 harness 特定的不变量：

1. **跨阶段 allowlist 一致性** —— 阶段 N 的输出路径包含在阶段 N+1 的可读路径中。不存在静默的交接断口。
2. **Guardian-阶段对齐** —— guardian 的审查范围是阶段动作面的**超集**。不存在盲区。
3. **不可逆性把关** —— spec 声明为不可逆的每一个操作都是被 hook 拦的，不是被 guardian 拦的。事后审查对不可逆动作来说不够。
4. **工件契约闭合** —— 每个工件都有产出者和消费者。不存在孤儿。
5. **循环可终止** —— 所有 Loop 类型阶段都有有界的退出条件（最大迭代数、提前停止判据、外部信号）。无界循环属于 spec 失败。
6. **Decide 的确定性** —— 所有 Decide 阶段都说明了决定是脚本/AI-judge/human-check 中的哪一种，以及谁执行由此产生的 git 操作。

外加 2 项通用检查：spec coverage（每条要求都映射到一个工件）以及 code quality（工件具有清晰的单一职责）。

skill 报告发现，**不修改任何东西**。它在任意时间**可重跑**：用户可以在初始实现之后改一个阶段配置，重新调用 `unleash:validating`，拿到一份回归审计，而**不需要**走完整条链。这种可重跑性是刻意的：harness 在它的运行生命周期里是一个**活的工件**，用户应当能够在不回到完整构建链的前提下改它（加阶段、调 allowlist、精修 guardian prompt）并验证这次修改。

**Produces:** `docs/unleash/validation/<YYYY-MM-DD>-<name>-validation.md` —— 各项检查的通过/失败、具体问题位置、建议修复。

**不做：** 修问题、改 harness 文件、或自动推进到 walking-through。它的 scope 仅限审计。

在真实测试中，`unleash:validating` 在一次只刻意种了 3 个不变量违规的会话中**抓出了第 4 个未计划的违规** —— 一个意外的彩蛋，证明了"让一个新鲜上下文的审计员在没有预设框架的情况下读 harness"是值得的。validator 找到了 implementer 漏掉的东西，因为 implementer 知道自己**想做什么**；validator 只知道**写下来是什么**。

---

#### 6. `unleash:walking-through`

首次运行 skill。静态校验是必要的，但不充分；一个通过了所有不变量检查的 harness 仍可能在实际运行中失败 —— 如果 guardian prompt 被误解、如果 allowlist 在边角不对、或者 hook 触发条件不对。Walking-through 这一步**踏在安全网上**确认它扛得住重量。

skill 在一个**真实任务**（不是玩具夹具）上驱动一次真实的 phase 0 → phase 1 过渡。然后它**故意**尝试一次已知的 allowlist 违规 —— 编辑一个不在配置 allowlist 范围内的文件 —— 并验证 guardian 触发、`git reset --hard` 回滚成功。如果装了不可逆 hook，它会脚本化地尝试触发那个 hook 并验证它真的拦住了。这些**不是可选的**：一个 guardian 从未被证明会触发的 harness，不是被验证过的 harness。

首次运行记录会捕获：用了什么任务、尝试了什么违规、guardian 是否正确触发、回滚是否成功、hook（如果存在）是否如期拦截。如果任何一项失败，skill 会回到 validating 进行修复，然后才能继续。

**Produces:** `docs/unleash/walkthroughs/<YYYY-MM-DD>-<name>-first-run.md`。

**不做：** 跑多轮迭代、在真实工作上评估 harness、或在所有冒烟测试通过之前把控制权交给用户。

walking-through 在链上占据一个不寻常的位置：它是**唯一**与"运行中的 harness"打交道的 skill，而不是"在建中的 harness"。所有前置 skill 都把 spec、plan 和实现工件当作**静态文档**来处理。Walking-through 把 harness 当作**活系统**：它调用 phase machine、触发 guardian、观察行为。这就是为什么它是一个独立 skill 而不是被合并进 validating 的原因。**静态代码分析（validating）和动态行为验证（walking-through）是不同的断言**。一个通过了全部 6 项不变量检查的 harness，仍然可能有一个 guardian 在运行时会误读的 prompt。Walking-through 抓得住那个；validating 抓不住。

---

#### 7. `unleash:archiving`

runtime harness 的生命周期终点 skill。当 runtime harness 完成它的使命时，由用户触发。它把**全部生命周期工件** —— brainstorm 笔记、spec、plan、validation 报告、walkthrough 记录，以及一份**截止归档时刻**的每个 harness 文件的实现快照 —— 打包到 `.unleash/archives/<YYYY-MM-DD>-<name>/`。

它定义性的纪律是 **fresh reviewer（新鲜 reviewer）**。review agent 作为一个全新的 subagent 被派发，**对所有先前 Unleash 阶段的上下文都为零**。它只收到：被归档的 spec 和实现快照。它**不**收到 plan、不收到实现者的推理、不收到 validator 之前的报告、不收到 validation 的发现、不收到 walkthrough 记录。这是套件提供的**最严格**的隔离，且是刻意的：目标是一种"无法被构建期框架污染"的 end-of-life 视角。

reviewer 把 `review.md` 写成**叙事性 markdown**（不是清单），覆盖 6 个维度：**忠实度**（实现是否兑现 spec？凡有偏离之处，偏离是改进还是回归？）、**质量**（代码整洁度、guardian prompt 清晰度）、**guardian 健壮性**（有没有 validator 没抓到的盲区？）、**hook 适当性**（是否在 guardian 已经够用的地方滥用了 hook？）、**可观测性**（一个未来的维护者能不能仅凭工件理解这个 harness？）以及**经验**（reviewer 会建议下一次复用或避免的具体模式是什么？）。

**Produces:** `.unleash/archives/<YYYY-MM-DD>-<name>/` 归档包 + `review.md`。

**不做：** 卸载 harness 文件（那是 `scripts/unleash-uninstall.sh` 的工作）、修改活的 harness、或执行 validating 那一类构建期检查。**Archive 是保存性的；uninstall 是破坏性的。** 它们可组合：archive 然后 uninstall = "保留记录，移除机器"。

---

#### 8. `unleash:reporting`

single-task 的生命周期终点 skill —— archiving 的、仅 B 层的对偶。当 Unleash 驱动了对话（brainstorm → debate → plan → implement）但没有装运行时 harness 时使用。互斥性是被强制的：如果 manifest 存在，这个 skill 会停下并把用户重定向到 `unleash:archiving`。

这里的 fresh reviewer 只收到 spec 和一份 **pathspec 过滤过的 git diff** —— 用 `git diff -- ':!docs/unleash/'` 过滤，把 Unleash 自己的文档 commit 排除在 diff 之外，只保留 plan 产生的代码变更。**过滤用的是 git pathspec 语法，不是 grep commit message** —— 这个区分在 skill 的反模式里被特别记下来，因为一个 commit message 在叙述里提到了 `docs/unleash/specs/...`、但实际只动了 `src/logger.py` 的 commit，应当被**包含**而不是被排除。

reviewer 覆盖 4 个维度：**忠实度**（diff 与 spec 的承诺一致）、**质量**（代码干净、没有范围蔓延）、**完整度**（spec 要求的没有任何东西在 diff 里缺失）以及**开放问题**（如果做后续 code review，reviewer 会探查什么）。输出 300-600 字 —— 实质但轻量，对应"一次单独编码任务"的体量，而不是数周的 harness 生命周期。

**Produces:** `docs/unleash/reports/<YYYY-MM-DD>-<name>-report.md`。

**不做：** 生命周期打包、实现快照、或 archiving 覆盖的那 6 个 guardian/hook 审计维度。**Reporting 是 diff 审计；archiving 是生命周期审计。**

---

#### Skill 之间的交互：契约表长什么样

下表以契约形式给出整条链：

| Skill | Consumes | Produces |
|-------|----------|----------|
| `unleash:brainstorming` | 用户意图 + 项目目录 | `docs/unleash/brainstorm/<date>-<name>.md` |
| `unleash:debating` | `brainstorm.md`（已 commit） | `docs/unleash/specs/<date>-<name>-spec.md` |
| `unleash:planning` | `spec.md`（已 commit、已 validate） | `docs/unleash/plans/<date>-<name>-plan.md` |
| `unleash:implementing` | `plan.md`（已 commit） | harness 代码 + `.unleash/manifest.json` |
| `unleash:validating` | manifest + harness + `spec.md` | `docs/unleash/validation/<date>-<name>-validation.md` |
| `unleash:walking-through` | 已验证的 harness + walkthrough 脚本 | `docs/unleash/walkthroughs/<date>-<name>-first-run.md` |
| `unleash:archiving` | 用户信号 + manifest + 全部前序工件 | `.unleash/archives/<date>-<name>/` + `review.md` |
| `unleash:reporting` | 用户信号 + `spec.md` + 过滤过的 git diff | `docs/unleash/reports/<date>-<name>-report.md` |

Consumes 列里每一个"已 commit"限定词都是一道**门**：skill 在继续之前显式检查上游工件已 commit 到 git。一个**只在磁盘上存在但还没 commit** 的工件**不算**满足条件 —— 是 commit 这个动作让工件成为**可验证的检查点**。

---

### 4.3 这种组合为什么成立

整条链是**线性的、且每两个 skill 之间都有强制的用户审批门**。没有任何 skill 自动推进。用户必须在 debating 启动前批准 brainstorm 笔记，在 planning 启动前批准 spec，在 implementing 启动前批准 plan，等等。这**不仅仅**是工作流卫生 —— 它是**让用户始终是权威设计者**的机制。AI 执行；用户批准。每一个穿过门的工件都被 git commit，所以**上下文压缩不会偷偷弄丢一个设计决定**。

每个 skill 的 HARD-GATE 让 scope 边界变得无歧义。执行这些 skill 的 AI 不依赖好判断力来知道**应该停在哪里** —— 它有显式的、命令式的指令，关闭最诱人的外推路径。这些 gate 是**经验性**地识别出来的：每一道都关闭了一种**至少在一次真实测试会话里出现过**的合理化语句。

**新鲜上下文的交叉验证在链上 3 个独立点出现：** validating（构建期，无 implementing 上下文）、archiving 的 reviewer（runtime harness 的 end-of-life，无构建上下文）、reporting 的 reviewer（single-task 的 end-of-life，只看 spec 与 diff）。**3 次独立读取，发生在不同生命周期阶段，每一次都不带前一次的框架** —— 这是套件最核心的可靠性保证。隔离是严格的：archiving 的 reviewer **显式不收到** validation 报告 —— 不是因为报告是秘密，而是因为一个"已经读过构建期审计员结论"的 end-of-life reviewer 会倾向于**裁决那些结论**而不是**形成自己的独立结论**。

manifest 是 runtime harness 路径上的**脊柱**。Implementing 产出它（每完成一个 task 就长大）。Validating 读它来检查工件闭合。Walking-through 读它来确认所有装上去的文件都被跟踪。Archiving 读它来框定实现快照。Uninstall 读它来反向撤销每一处改动。**每一个动到 runtime harness 的 skill 都动 manifest；没有任何 skill 自己另立清单。**

两形态设计（runtime harness vs. single-task）是**有意为之**而非偶然。Unleash 设计之初，"harness" 的主流心智模型是 autoresearch 那种 runtime 机器。但实际上，开发者真正想用 AI 做的工作有相当一部分是**有界的**：把这个 bug 仔细修了、把这个 feature 用纪律实现完，不要漂移。对那种工作来说，没有什么机器要装 —— 只有**对话**。把仅 B 层的路径作为一等公民对待（而不是事后补丁），意味着把 `unleash:reporting` 设计为一个**真正**的 end-of-life skill，配备它自己的 fresh reviewer，而不是简单地跳过 archiving。v0.3.1 让这条路径变成显式的。v0.3.1 的 release note 记录了动机：一次真实用户测试发现了缺口 —— 用户在一个 B 层任务上调用 `unleash:archiving`，被正确地重定向了，但**无处可去**。`unleash:reporting` 填上了那个缺口。

---

### 来源与谱系

Unleash 内化了来自两个外部源的模式：

**Superpowers（Obra Labs）** —— 工作流纪律模式：skill 结构、HARD-GATE 标记、反模式 Thought/Rebuttal 对、spec → plan → execute 链、subagent 驱动开发。Unleash **不**把 superpowers 作为依赖引入 —— 而是把这些模式**内化**进自己的 skill 实现。设计目标是用户面层**对外部 skill 包零运行时依赖**。

**Karpathy 的 autoresearch** —— 极简 harness 设计哲学：frozen oracle、最小动作面、单一标量指标、git 原子级保留/丢弃、TSV 长期记忆。这五项设计选择是"优雅完成的指标优化 harness"的典范例子。它们在 `references/unleash-knowledge.md §2` 中作为 metric-case 起手模式的参考实现。

**creative-agents-harness（haokun，2026）** —— 用于 PPT 优化的生产级 autoresearch 实现。提供了 phase 级工具 allowlist、按迭代组织的工件结构、优雅停机等方面的实战经验。这个 harness 直接驱动了 `unleash:validating` 中若干 allowlist 一致性检查和 loop 终止检查的设计。

知识库（`references/unleash-knowledge.md`）把这些来源综合成 8 个章节的参考材料：5 元素框架（§1）、常见起手模式（§2）、阶段原语词汇（§3）、runtime guardian 设计模式（§4）、hook vs. guardian 决策指南（§5）、常见陷阱（§6）、词汇表（§7）、项目目录布局（§8）。这份知识文档被链上各 skill 读取；它是让"skill 优先设计"成为可能的概念基质。

---

**关于这条链不是什么的一点说明。** 这条链**不是**项目管理工具。它不跟踪任务、不分配 ticket、不管理 sprint。它治理一个 harness 从意图到首次验证运行的**设计与构建**。在 walking-through 之后，harness 归用户所有，并在用户的控制下运行。Unleash 对这个 harness 做什么、跑多少次、用户拿结果干什么，**没有意见**。它的 scope 在"harness 已被构建并被验证"时就结束了。再往后发生的事情属于用户。

类似地，这条链**不是**对 code review、测试套件或 CI/CD 的替代。它是一层**坐落在那些之上**的纪律层 —— 它确保 harness 在被任何下游流程跑过之前就已经被有意图地设计。一个强制 TDD 纪律的设计良好的 harness，仍然依赖开发者的测试套件去抓功能 bug。Unleash 设计约束；约束治理 AI；AI 产出代码；代码仍然要通过项目已有的质量门。

---

---

## 旅程，与剩下的事

Unleash 的设计被写在一份单独的 spec 里 —— `2026-04-24-unleash-toolkit-design.md` —— 然后在接下来的 24 小时里跨 3 份实现 plan 完成构建：Plan 1 在 v0.1.0 产出了前两个 skill（brainstorming 与 debating）；Plan 2 在 v0.2.0 产出了 planning 与 implementing；Plan 3 在 v0.3.0 产出了 validating、walking-through 与 archiving。再往后一天又跟了 3 个补丁，其中两个直接来自真实用户测试反馈。

**v0.2.1** 在一次测试暴露了"AI 很贴心地追加了 spec 没授权的部署步骤"之后，收紧了 implementing 的终止消息。implementing skill 的 scope 是"用户项目里已 commit 的代码"。部署、push、CI/CD 与发布打 tag 都被显式排除在 scope 之外 —— spec 治理 plan 的范围，plan 在 git 边界处终止。终止消息上的 HARD-GATE 是为了让这一点变得无歧义而被加上去的。

**v0.3.1** 在一位用户用完整对话链完成了一个 bug 修复、试图归档却发现缺口之后，加了 reporting skill：`unleash:archiving` 因为没有 manifest 而正确地停了下来，但**无处可去**。对话本身是有价值的 —— brainstorm → debate → plan → implement 这条链确实给整个实现上了纪律 —— 但那份价值没有任何 end-of-life 工件来体现。`unleash:reporting` 用一份轻量的冷读 review 报告填上了这个缺口。

**v0.3.2** 关闭了 planning → implementing 交接处的一个具体错位。v0.2.1 已经向 debating 加上了 `testing_mode` 探针，让 spec 能捕获用户究竟想要 TDD、人工清单、不测，还是别的方式。但 planning 仍然把所有 Test 阶段都当作 TDD 来处理 —— 不管 spec 怎么说，它都写 pytest 任务。对那些做 UI 流程、浏览器集成测试或判断性核验的用户 —— 也就是**正因为他们的测试不适合自动模具，最需要 harness 纪律的那一类用户** —— 这意味着 spec 捕获到的意图被 plan 静默忽略了。v0.3.2 闭合了这个回路：spec → plan → implement 现在端到端地尊重 `testing_mode`，并在一个真实的 `testing_mode: B` 夹具（Flask 登录 UI bug）上验证通过，5/5 项 rubric 检查全过。

**这套设计在使用中扛住了。** 三个补丁都没有要求重审核心哲学。所有补丁都是**在边角处的 scope 微调** —— spec 的核心原则其实已经隐含了这些边界，只是初版实现没有把它们表达得**足够显式以让 AI 可靠地执行**。这是这一类工具包的预期模式：哲学是稳定的，边角随使用而变锐。

**当前状态：** 8 个 skill、6 个 git tag（v0.1.0 到 v0.3.2）、一份 8 章节知识库、一个由 manifest 驱动机械卸载的 `scripts/unleash-uninstall.sh`，以及覆盖了 validating 的主要不变量违规路径、walking-through 的"guardian 在违规时触发"路径、以及 archiving 的"fresh reviewer 盲读"路径的压力测试场景。位于 `tests/scenarios/integration/full-chain.md` 的全链路集成场景作为手动端到端验证夹具 —— 一份完整的 runbook，给希望在构建第一个真实 harness 之前先验证套件如规所述运作的首次用户。原始 spec 中只剩一个未解的开放问题：§10.4（市场分发 —— `unleash:` 命名空间如何被分发给其他用户）。§10 开放问题清单中其它所有项都已在 3 份构建 plan 中解决。

**未来：** 当真实用户撞上新的边角情况时，会有更多补丁。模式已经建立：发现一个缺口，为它写一份测试场景，给相关 skill 打补丁，验证补丁关闭了缺口。除非哲学被证明是错的，否则不重新设计。最终是市场发布 —— 这样其他遇到同样问题（"我想 harness X，但要从空白开始"）的开发者，可以在不必是原作者的情况下拿起这个套件。spec §10.4 的市场分发开放问题是最后一个待决的设计决定；除此之外的一切都已发布。

---

### 进一步阅读

如果上面的架构描述引起了你对具体机制的疑问 —— 一个设计良好的 guardian prompt 究竟长什么样，对一个调用 shell 脚本的阶段 allowlist 应当怎么写，Human-Check 与 AI-Judge 阶段的差别是什么 —— 那么知识库（`references/unleash-knowledge.md`）就是你应该去的地方。它被组织成参考文档而非教程，所以**不需要**线性读完；跳到你需要的那一节即可。

在首次调用 `unleash:brainstorming` 之前最有用的章节：

- **§1（5 元素框架）** —— 在 brainstorming 之前理解这 5 个元素及其 N/A 标准；skill 会用它们作探针，先读过词汇会让对话更快。
- **§2（常见起手模式）** —— 编码 pipeline 与指标循环模式，这样当 brainstorming 把它们当作建议抛出时你能识别出来。
- **§3（阶段原语词汇）** —— 6 个阶段类型；知道这些会让 debating 的 phase_machine 小节具体得多。

在调用 `unleash:debating` 之前最有用的章节：

- **§6（常见陷阱）** —— 7 种 harness 反模式；知道它们长什么样能帮你识别出 debating 是在挑战你避免哪一种。

在 `unleash:implementing` 完成后最有用的章节：

- **§5（hook vs. guardian 决策指南）** —— 如果你不确定 harness 中是否有任何操作本应被 hook 把关，在 validating 之前回看这一节。
- **§8（项目目录布局）** —— 规范的 `.unleash/` 与 `docs/unleash/` 目录约定；在调用 validating 之前确认你的实现遵循它们。

---

工具包的文档与维护位于 `https://github.com/haokun/unleash`（尚未公开）。设计 spec 位于 `present-tools` 仓库的 `docs/superpowers/specs/2026-04-24-unleash-toolkit-design.md`。CHANGELOG 记录了每个发布决定，包括每个补丁的动因与验证状态。如果你想理解某条具体 HARD-GATE 或反模式**为什么**存在，对应版本的 CHANGELOG 通常带有触发它的真实测试。

---

如果你看到了这里并想试一下 Unleash，请见 `README.md` 了解安装步骤以及你的第一次 `unleash:brainstorming` 调用。
