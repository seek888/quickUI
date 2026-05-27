# QuickUI Stac 平台 Demo 设计

## 目标

这个 demo 用本地 JSON 模拟服务器下发配置，展示社交媒体客户端如何开放动态页面和受控平台能力。

当前不接服务器，配置文件放在 `assets/stac/`。后续接服务端时，可以把 `Stac.fromAssets` 替换为 `Stac.fromNetwork` 或自有配置下载缓存层。

## 客户端分层

### 固定 App 壳

位置：`lib/src/ui/demo_shell.dart`

职责：

- 提供主导航、配置下载按钮、配置版本提示。
- 管理动态页面切换。
- 承接登录态、IM、权限、支付、分享、埋点等原生能力。

### 动态页面层

位置：`assets/stac/*.json`

职责：

- 通过 Stac JSON 描述页面结构。
- 使用 Stac 内置 widget 组合内容流、专题页、表单页。
- 通过 action 调用客户端开放能力。

### 平台能力层

位置：`lib/src/actions/platform_action_parser.dart`

职责：

- 注册 `actionType: "platform"`。
- 按 `capability` 白名单分发能力。
- 当前 demo 支持：
  - `openChat`
  - `shareArticle`
  - `followAuthor`
  - `submitForm`
  - `requestPermission`

## 配置示例

```json
{
  "type": "filledButton",
  "onPressed": {
    "actionType": "platform",
    "capability": "shareArticle",
    "title": "分享到会话",
    "payload": {
      "contentId": "post_2401",
      "cardType": "post"
    }
  },
  "child": {
    "type": "text",
    "data": "分享"
  }
}
```

配置只表达“我要调用分享能力”，真正的权限判断、会话选择、确认弹窗、审计和失败处理由客户端完成。

## 未来接服务器的建议

### 配置下载

- 后台返回页面 JSON、版本号、签名、最低客户端版本。
- 客户端校验签名和 schemaVersion。
- 成功后缓存到本地，失败时回退到上一版。

### 能力开放

- 后台为第三方应用配置 scope。
- 客户端通过 `PlatformActionParser` 做白名单分发。
- 敏感能力必须经过 Permission Broker。

### 安全边界

- 配置不得执行任意 Dart 或 Native 代码。
- 配置不得直接访问相机、相册、定位、文件、通讯录、支付或 IM 发送。
- 配置只允许调用平台注册过的 action。

## 推荐演进

1. 本地 assets 演示动态页面。
2. 增加本地缓存配置包，模拟下载和回滚。
3. 增加 schema 校验和配置签名。
4. 接入配置服务和 CDN。
5. 建设后台编辑器、预览器、灰度发布和审核流。
