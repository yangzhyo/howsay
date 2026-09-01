# whats-en

"这句英语怎么说？"——一个即用即走的英文表达验证工具。

脑子里冒出一句中文，自己默默翻成英文，掏出 iPhone 按一下操作按钮，输入那句中文，两秒内看到地道的英文说法，对照完就结束。不评价、不解释、不记录。

术语见 [CONTEXT.md](./CONTEXT.md)。

## 组成

整个工具只有两样东西：

| 文件 | 作用 |
|---|---|
| `prompt.txt` | 提示词的源头。改提示词只改这个文件，改完粘进快捷指令。 |
| `check.sh` | 在 Mac 终端里用和快捷指令**完全相同**的请求调 Gemini，先把提示词调到满意再搭快捷指令。 |

没有服务端，没有数据库。iPhone 快捷指令直接调 Gemini 的 Interactions 接口。

## 第一步：在终端里跑通

```sh
export GEMINI_API_KEY=你的key
./check.sh 他走了
./check.sh 麻烦你帮我看一下这个问题
./check.sh --raw 他走了        # 看完整返回 JSON
./check.sh --dry-run 他走了    # 只看将要发送的请求体
```

预期输出是一到三行英文，末尾的 `(gemini-3.5-flash-lite, 0.8s)` 是耗时，打在 stderr 上。

对输出不满意就改 `prompt.txt` 再跑。改完记得同步到快捷指令。

## 第二步：搭快捷指令

建议在 **Mac 的"快捷指令"App** 里搭，粘长文本方便，搭完会通过 iCloud 自动同步到 iPhone。

新建快捷指令，命名比如 "英文怎么说"，依次添加下面的动作（括号里是英文界面名）：

**1. 要求输入（Ask for Input）**
- 输入类型：文本
- 提示：`中文？`
- 键盘自带听写按钮，路上不方便打字可以直接说。

**2. 如果（If）**
- 条件：`提供的输入` 没有任何值
- 里面放一个 **停止此快捷指令（Stop This Shortcut）**
- 空输入直接结束，不发请求。

**3. 获取 URL 内容（Get Contents of URL）**
- URL：`https://generativelanguage.googleapis.com/v1beta/interactions`
- 方法：`POST`
- 头部（Headers），加三条：
  - `x-goog-api-key` → 你的 Gemini API key
  - `Content-Type` → `application/json`
  - `Api-Revision` → `2026-05-20`
- 请求正文：`JSON`，加下面五个字段（注意类型）：

  | 键 | 类型 | 值 |
  |---|---|---|
  | `model` | 文本 | `gemini-3.5-flash-lite` |
  | `system_instruction` | 文本 | 把 `prompt.txt` 全文粘进来 |
  | `input` | 文本 | 选变量 `提供的输入`（第 1 步的结果） |
  | `store` | 布尔值 | 关（false） |
  | `generation_config` | 词典 | 里面加一项：`thinking_level`（文本）→ `minimal` |

  `store` 一定要选**布尔值**类型而不是文本 `"false"`，否则接口会报类型错误。

**4. 获取词典值（Get Dictionary Value）**
- 从 `URL 内容` 获取键 `steps` 的值

**5. 从列表中获取项目（Get Item from List）**
- 从上一步结果中获取 **最后一个项目**
- （返回的 `steps` 里可能先有一个 `thought` 步，最后一步才是模型输出）

**6. 获取词典值（Get Dictionary Value）**
- 从上一步结果获取键 `content` 的值

**7. 从列表中获取项目（Get Item from List）**
- 获取 **第一个项目**

**8. 获取词典值（Get Dictionary Value）**
- 获取键 `text` 的值

**9. 如果（If）**
- 条件：第 8 步结果 有任何值
  - **显示结果（Show Result）**：第 8 步结果
- 否则
  - **显示结果（Show Result）**：`URL 内容`（把接口的原始返回显示出来，方便看报错）

第一次运行会弹出"允许连接 generativelanguage.googleapis.com"的提示，选"始终允许"。

## 第三步：绑到物理按键

- iPhone 15 Pro 及以后：设置 → 操作按钮 → 快捷指令 → 选这条。
- 其他机型：设置 → 辅助功能 → 触控 → 轻点背面 → 轻点两下 → 选这条。

## 改提示词或换型号

- 改提示词：编辑 `prompt.txt` → 用 `check.sh` 试到满意 → 把全文重新粘到快捷指令第 3 步的 `system_instruction`。
- 换型号：改快捷指令第 3 步的 `model`。本地试用 `MODEL=gemini-3.7-flash ./check.sh ...`。当前可选型号见 <https://ai.google.dev/gemini-api/docs/models>。
- `thinking_level` 保持 `minimal`（gemini-3.5-flash-lite 的最低档，也是它的默认值）。这个任务不需要模型思考，思考只会拖慢响应。

## 费用与隐私

- gemini-3.5-flash-lite 有免费额度；付费档 $0.30 / 百万输入 token、$2.50 / 百万输出 token。一次 Check 约 500 个输入 token、30 个输出 token，一天用五十次一个月也不到一块钱人民币。
- 免费档的请求内容 Google 会用于改进产品；付费档不会。介意的话在 AI Studio 里开付费。
- `store: false` 让 Google 不在服务端保留这次交互。工具本身不保存任何记录。

## 接口参考

- Interactions API：<https://ai.google.dev/gemini-api/docs/interactions>
- 思考档位：<https://ai.google.dev/gemini-api/docs/thinking>
- 定价：<https://ai.google.dev/gemini-api/docs/pricing>
