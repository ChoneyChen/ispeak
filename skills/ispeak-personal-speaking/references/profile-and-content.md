# Personal facts → speaking curriculum

## Intake and grounding

一次自然的输入就够，例如：“我在一家小公司做设计，住在离办公室不远的地方，平时喜欢跑步。去年组织过一次内部分享，也有一次项目延期的经历。”有这些信息后继续做；不要逼用户逐题填满 28 话题。

把输入逐项抽取为事实，而不是把推断当成事实。职业不等于具体公司或项目职责；喜欢旅行不等于去过某个国家；参加团队不等于担任负责人。姓名、学校、城市可用概括称呼。用户明确提供的学校/城市可以写进其私人产物，不能进入本 skill 的公共 assets。

Profile 的最小结构：
```json
{
  "schemaVersion": 1,
  "learning": {"nativeLanguage": "zh-CN", "targetLanguage": "en-GB", "exam": "IELTS Speaking", "targetBand": "7.5–8.0"},
  "facts": [{"id": "F01", "topicIds": [1, 11, 25], "kind": "identity", "status": "confirmed", "text": "用户在一家小公司做设计。"}],
  "avoid": ["不写真实公司名"]
}
```

`kind` 可取 identity/experience/preference/goal。`status` 为 confirmed 或 uncertain。`topicIds` 是可使用该事实的目录章节，允许空数组；计划脚本的 suggestedFactIds 只是建议，AI 可根据语义重新引用。例子中的 learning 可按用户目标调整，目标分数只用于语言难度取舍，不构成保分承诺。

每个句子带溯源：
- `confirmed`：根据用户已确认的事实表达，factIds 至少一个；不要借一个真实事实延伸出新的未经确认细节。
- `general`：一般观点、非个人事实或合理的讨论内容，factIds 为空；使用恰当的限定词，避免没有证据的普遍断言。
- `scenario`：练习用的场景或面向对话者的问题。可以引用相关事实作为语境，但不把该问题里的设定当成用户经历。
- `hypothetical`：明确的假设、愿望或反事实练习。引用事实时仍需语义成立。应用将 scenario/hypothetical 标为“情境练习”。

输入不充分时，用通用观点、假设和明确标注的情境补足结构覆盖，不编造朋友、家庭、旅行、收入、获奖、研究成果或工作职责。涉及敏感话题时可以用中性对象，用户无需披露隐私。

## Course contract

默认目录在 `assets/grammar-catalog.json`：Part 1 为 1–12 章、Part 2 为 13–20 章、Part 3 为 21–28 章；每章 5 个语法点，G001–G140。标题和知识点不应随意改变；第一话题可根据学生/职场人士改成自己的身份背景，保留基础语法。

每个 chapter 文件是一个对象，不包 `chapters`：
```json
{
  "id": 1, "part": 1, "title": "My work & identity", "subtitle": "工作、身份与学习", "shortTitle": "身份·学习",
  "questions": ["What do you do?", "What do you enjoy about it?", "What would you like to learn next?"],
  "practice": "用 20 秒说明自己的身份、日常工作和喜欢的一点。",
  "startPage": 0,
  "grammar": [{
    "id": "G001", "title": "be 动词：身份、状态与否定", "level": "A1",
    "pattern": "从共享目录原样读取", "note": "从共享目录原样读取", "page": 0,
    "examples": [{"id": "G001-1", "en": "I'm a designer at a small company.", "zh": "我在一家小公司做设计。", "kind": "肯", "provenance": {"type": "confirmed", "factIds": ["F01"]}}]
  }]
}
```
此片段只解释字段；默认完整课程每点必须 5 个完整例句（custom 导入模式保留原分组数量），pattern/note 使用目录真实值，不能把上面的说明文字当作内容。正式 root 为 `{"chapters": [...], "supplements": [...]}`。例句 ID 是 `<grammar-id>-<1...5>`；排序与 ID 稳定，后续修改不随意重编号，否则无法保持已有学习记录。新增内容追加 ID；删除/合并已学内容需要明确的数据迁移设计。

自定义导入可以保留每点原有的非零句数；使用 `--mode custom`，应用按实际数量显示进度与整节解锁。默认完整模式仍严格检查 28/140/700。

`kind` 为“肯”“否”“问”，用于帮助识别练习形式，不当成严格语言学分类。supplement 字段：`id,title,subtitle,page,body`。素材生成阶段的页码全部设 0；书籍渲染器根据实际布局重算。不要沿用别人教材的页码。

## Five examples that teach, rather than paraphrase

同一点的 5 句应覆盖不同语义和使用目的，如身份/习惯、否定或限制、提问、具体经历、反思或比较。通常包含一个自然提问和一个否定，但不要为了配齐标签制造不适合该结构的问句。不能仅换 5 个主语或名词。

- Part 1：直接、自然的日常表达，基础结构准确；用原因和细节扩展。
- Part 2：事实支持的叙事顺序、时间与转折，突出行动、结果、感受；假设片段明确标注。
- Part 3：观点、条件/例外、机制、例子，使用限定与适度复杂句，避免把绝对化断言当作“高级”。

默认英式拼写，缩写形式自然，常用搭配优先。句子通常 8–25 个英文词，复杂结构可更长；不要把词数当硬指标。句子能口头说顺、结构服务真实意思，比堆砌复杂形式更重要。中文须能支持回忆该英语：保留时态/完成意义、否定范围、条件与说话者立场，不逐词硬译。

每章给 3 个训练用问题与一个可执行的开口任务。它们是教学问题，不宣称是真实考题或未来题库。共享 12 时态/45 纠错/30 天路线由 `assemble` 加入。个性化故事可按“背景 → 变化 → 行动 → 结果 → 反思”写；讨论示范按“倾向 → 条件/例外 → 机制 → 例子”写，并同样保留事实边界。

## Semantic QA

在组装前逐章检查：语法点是否真正出现在每句，主谓一致/冠词/时态是否正确，中英含义是否一致，5 句是否有语义区分，事实链接是否支持整句而非只支持一个名词。特别回查第三条件句、混合条件句、过去推断、倒装与分词悬垂。

查看 profile 的 avoid 项和 uncertain 项，检查是否被错误写进 confirmed 例句。陌生人无需看见原始 profile 才能辨认情境练习，标签应在数据里而非藏在报告中。

CLI 的验证不代替这一步。可以交付结构校验报告和逐章语义检查摘要；不要捏造自动“事实准确率”或在没检查时声称“逐句验证”。
