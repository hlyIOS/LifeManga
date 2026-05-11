//
//  AppSettings.swift
//  LifeManga
//
//  全局可观察的应用设置。API Key 不在这里 —— 它存在 Keychain。
//
//  本文件涉及的主要知识点（便于阅读代码时对照）：
//  - ObservableObject：将 AppSettings 作为可被 SwiftUI 观察的全局设置对象。
//  - @MainActor：约束类型在主线程 / UI 线程上使用，与界面读写一致。
//  - @AppStorage：用户偏好自动读写 UserDefaults（如张数、尺寸、质量、故事模式等）。
//  - @Published：hasAPIKey 变化时通知视图刷新，与 @AppStorage 的发布机制互补。
//  - 计算属性 defaultStyle：底层用 String 存枚举 rawValue，对外暴露 MangaStyle。
//  - static let：全局复用的选项表（气泡模式、尺寸、质量等），供 UI 与业务共用。
//  - Keychain：敏感信息（API Key）不落 UserDefaults，通过 KeychainService 判断是否已配置。
//  - 元组数组：bubbleTextModes 用 (id, label, hint) 描述可选配置与说明文案。
//  - init()：构造时同步一次 Keychain 中的 API Key 状态。
//  - refreshAPIKeyStatus()：Key 增删后手动刷新，保持 UI 与 Keychain 一致。
//
//  为何使用 class 而非 struct：
//  - ObservableObject 受 AnyObject 约束，只有 class 等引用类型可遵循；struct 无法写成
//    `struct AppSettings: ObservableObject`。
//  - 全局一份设置（如根视图 @StateObject / environmentObject）需要稳定身份：多处引用
//    同一实例；struct 为值类型，拷贝易导致状态分裂，除非换一套状态容器 API。
//  - @AppStorage、@Published 与 objectWillChange 按「同一实例上的属性变化 → 通知视图」
//    工作，与 class 的引用语义一致，是 SwiftUI 里常见写法。
//  - 若将来弃用 ObservableObject，可考虑 iOS 17+ 的 @Observable 等；但不能在仍采用
//    ObservableObject 的前提下把本类型改为 struct。
//

import Foundation
import SwiftUI

@MainActor
final class AppSettings: ObservableObject {
    // MARK: - 用户偏好（持久化到 UserDefaults）

    @AppStorage("defaultStyle")    private var defaultStyleRaw: String = MangaStyle.shonenJump.rawValue
    @AppStorage("imageCount")      var imageCount: Int = 1
    @AppStorage("imageSize")       var imageSize: String = "1024x1536"
    @AppStorage("imageQuality")    var imageQuality: String = "medium"
    /// 故事模式开关
    @AppStorage("storyModeOn")     var storyModeOn: Bool = false
    /// 故事模式分镜格数
    @AppStorage("panelCount")      var panelCount: Int = 6
    /// 故事模式使用的视觉/编剧模型（GPT-5 系列，2026 年最新）
    @AppStorage("scriptModel")     var scriptModel: String = "gpt-5.4-mini"
    /// 气泡内文字渲染模式: "chinese" / "japanese" / "english" / "empty" / "none"
    /// gpt-image-2 已经能很好地渲染中文，所以默认用 "chinese"
    @AppStorage("bubbleTextMode")  var bubbleTextMode: String = "chinese"
    /// 全局色彩开关：true 彩色 / false 黑白
    @AppStorage("colorMode")       var isColor: Bool = false

    static let bubbleTextModes: [(id: String, label: String, hint: String)] = [
        ("chinese",  "中文",      "气泡里画中文台词（推荐）"),
        ("japanese", "日文假名",   "气泡里画日文假名，怀旧 manga 感"),
        ("english",  "英文",      "气泡里画英文台词（最稳，海外漫画感）"),
        ("empty",    "留空",      "气泡画出来但里面不写字"),
        ("none",     "无对话框",   "完全不画对话框，纯视觉漫画")
    ]
    /// 是否在 Keychain 已经存了 API Key（仅用于 UI 展示）
    @Published var hasAPIKey: Bool = false

    var defaultStyle: MangaStyle {
        get { MangaStyle(rawValue: defaultStyleRaw) ?? .shonenJump }
        set { defaultStyleRaw = newValue.rawValue }
    }

    /// gpt-image-2 支持的常用尺寸
    static let availableSizes = [
        "1024x1024",   // 1:1 标准
        "1024x1536",   // 2:3 漫画页（推荐）
        "1536x1024",   // 3:2 横幅
        "2048x2048",   // 2K 方形
        "2160x3840",   // 4K 漫画页（实验性）
        "3840x2160",   // 4K 横幅（实验性）
        "auto"
    ]
    static let availableQualities = ["low", "medium", "high", "auto"]

    init() {
        self.hasAPIKey = (KeychainService.shared.loadAPIKey() ?? "").isEmpty == false
    }

    func refreshAPIKeyStatus() {
        hasAPIKey = (KeychainService.shared.loadAPIKey() ?? "").isEmpty == false
    }
}
