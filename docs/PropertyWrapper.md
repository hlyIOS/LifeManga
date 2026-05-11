# Swift 中的 `@propertyWrapper`

分两层理解：**语言里的 `@propertyWrapper` 机制**，和**某个具体 wrapper（例如 `@Published`）的库代码**。

---

## `@propertyWrapper` 本身是否开源？

**是。** Swift 编译器与标准库在 [swift.org](https://www.swift.org/) 上开源（仓库如 [swiftlang/swift](https://github.com/swiftlang/swift)）。

`@propertyWrapper` 是**语言特性**：由编译器在类型检查、SIL 生成等阶段做展开与检查，实现分布在编译器源码里（语义分析、SILGen 等），而不是「一个单独的 `.swift` 文件叫 PropertyWrapper.swift 就写完所有 wrapper」。

行为与设计的权威文字说明可以看 Swift Evolution 里的提案，例如 [SE-0258: Property Wrappers](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0258-property-wrappers.md)。

---

## 「里面的实现」在说什么？

### 语言机制（所有 `@propertyWrapper` 共性）

编译器大致会做这些事（概念模型，与 SE-0258 一致）：

1. **合成或对接存储**  
   为被包装属性生成「真正的存储」（例如 `private var _foo: Wrapper`），对外仍用你写的名字 `foo`。

2. **访问器转发**  
   - `get` → 读 `wrapper.wrappedValue`（或等价逻辑）。  
   - `set` → 写 `wrapper.wrappedValue`（若有 `mutating` 等则按规则处理）。

3. **初始化**  
   支持 `init(wrappedValue:)`、`init(initialValue:)` 等约定，让 `var x: Int = 1` 能转成对 wrapper 的初始化。

4. **`$` 投影（可选）**  
   若类型提供 `projectedValue`，则 `foo` 用 `wrappedValue`，`$foo` 用 `projectedValue`（例如 `@Published` 的 `$x` 是 `Publisher`）。

5. **限制**  
   例如 `wrappedValue` 的类型、wrapper 是 struct/class、能否用在 static/local 等，都由编译器按规则检查。

因此：**「实现」的主体在编译器里**；每个具体 wrapper 只负责实现自己的 `struct SomeWrapper { var wrappedValue: ... }` 及可选的 `projectedValue` / 自定义 `init`。

### 具体 wrapper（如 `@Published`）

- **`@Published`** 属于 **Combine**（Apple SDK）。**是否有一份和 Xcode 里逐行一致的「完全开源实现」**，取决于平台：Apple 自带的 Combine 实现通常**不**像 Swift 编译器那样整仓公开；Linux 上若用 **swift-corelibs** 生态，情况又不同。
- 能确定的是：**语义**由 Apple 文档与语言规则约束；**机制**仍走上面的 property wrapper lowering，内部会连到 `ObservableObject` 的 `objectWillChange` 等（这是文档里说明的行为，而不是要求你必须看到闭源源码才能理解）。

---

## 简短结论

| 问题 | 答案 |
|------|------|
| `@propertyWrapper` 语言特性 | **开源**（Swift 编译器 + SE-0258 等文档描述行为与模型）。 |
| 「实现」指什么 | **主要是编译器对属性的重写**；各 wrapper 再提供自己的 `wrappedValue`（及 `projectedValue` 等）。 |
| `@Published` 等 SDK wrapper | **机制**与 Swift 一致；**Combine 源码**在 Apple 平台上通常不视为与编译器同级别的公开源码，但行为可查官方文档。 |

若要「对着源码读」，优先看：**swift 仓库里与 property wrapper 相关的编译器实现** + **SE-0258**；若要抠 `@Published` 每一行实现，则受限于 Combine 是否在你关心的平台上开源发布。
