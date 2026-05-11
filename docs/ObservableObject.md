# `public typealias ObservableObject = ObservableObject` 说明

## 两种写法在做什么

| 写法 | 含义 |
|------|------|
| `public typealias ObservableObject = Combine.ObservableObject` | 公开别名**明确**指向 Combine 框架里的协议。 |
| `public typealias ObservableObject = ObservableObject` | 右侧是**未限定**的名字 `ObservableObject`，由编译器按**名字查找**解析到某个 `ObservableObject`（在常见项目里就是 `Combine.ObservableObject`）。 |

在已 `import Combine`（或能通过 SwiftUI 等让 Combine 的类型进入作用域）时，**很多情况下两种写法最终指向同一个类型**，但**可读性和稳健性不同**。

## 为什么右侧能写「自己 = 自己」还能编译？

- 声明 `typealias ObservableObject = …` 时，右侧的 `ObservableObject` **一般不会**被理解成「正在声明的这个别名本身」，否则会变成无效递归。
- 因此 RHS 的 `ObservableObject` 通常会被解析成**已导入模块里的**那个协议，例如 **`Combine.ObservableObject`**。

所以：**不是语法魔法**，而是**名字查找**规则让 RHS 落到 Combine 上。

## 未写 `Combine.` 是否就表示一定是 Combine 的？

**不保证由「Foundation 带了 Combine」来决定。**

- **`ObservableObject` 定义在 Combine**；你能用未限定名字，是因为**当前源文件的作用域里能查到** `Combine` 里的这个类型（例如你 `import Combine`，或 `import SwiftUI` 等带来的可见性）。
- **不是因为**：「Foundation 模块内部 import 了 Combine，所以我只写 Foundation 就等于 Combine」——你自己的文件仍以**你自己的 `import`** 和**名字查找结果**为准。

## 更推荐哪种？

- **推荐**：`public typealias ObservableObject = Combine.ObservableObject`  
  - 意图清晰；  
  - 避免以后同模块或其它 import 引入**同名**类型时产生歧义。
- **可编译但偏弱**：`… = ObservableObject`  
  - 读起来像自引用，依赖隐式解析；  
  - 在名字冲突时更容易出问题。

## 一句话结论

`public typealias ObservableObject = ObservableObject` 在多数 App 里**往往等价于**指向 `Combine.ObservableObject`，靠的是 **`import`/作用域下的名字查找**，不是 Foundation「替你代表 Combine」；要**明确、可维护**，应写成 **`Combine.ObservableObject`**。

---

## `ObservableObject` 是协议（protocol）

在 Xcode 里点进符号定义时，会看到类似：

```swift
@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
public protocol ObservableObject : AnyObject {
    associatedtype ObjectWillChangePublisher : Publisher = ObservableObjectPublisher
        where Self.ObjectWillChangePublisher.Failure == Never

    var objectWillChange: Self.ObjectWillChangePublisher { get }
}
```

这说明：

1. **`ObservableObject` 在 Combine 里是 `protocol`，不是 class、也不是 struct。**  
   文档里「带一个在对象变化**之前**会发事件的 publisher」的对象类型，指的就是遵守这份协议的类型。

2. **`ObservableObject : AnyObject`**  
   只有 **class（引用类型）** 能满足 `AnyObject`，所以常见写法是 `class Foo: ObservableObject`，而不是让 struct/enum 直接 conform（一般也不这么搭配 `@Published` 使用）。

3. **协议要求**  
   - **关联类型** `ObjectWillChangePublisher`（默认实现类型为 `ObservableObjectPublisher`）。  
   - **属性** `objectWillChange`：在 `@Published` 等变化发生**前**对外发信号，供 SwiftUI / Combine 订阅刷新。

4. **`@Published` 与编译器合成**  
   Apple 文档说明：在默认条件下，编译器会为类型**合成** `objectWillChange`，并在 `@Published` 属性即将变化前发出事件；因此类里常只写 `@Published`，不显式实现 `objectWillChange`。

5. **与前面 `typealias` 讨论的关系**  
   `public typealias ObservableObject = Combine.ObservableObject`（或右侧未限定的等价写法）都是在给 **Combine 里这个协议**起别名或重新导出；**别名的目标仍然是「协议」本身**，不是某个具体类。

**小结**：在源码里点进去看到 `protocol`，是正确且预期的；日常说的「可观察对象」指的就是遵守 `ObservableObject` 的类型（绝大多数是 class）。

---

## 官方声明与扩展：各段语法在说什么

Apple 在 Combine 里大致是「协议声明 + 带条件的协议扩展」两块一起用：前者定规矩，后者在默认关联类型下给出 `objectWillChange` 的默认实现。

### `@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)`

**可用性标注**：该 `protocol` / `extension` 从所列**最低系统版本**起才可用；更老的 SDK 或部署目标下可能不可见，或需在业务代码里用 `@available` 分支包一层。`*` 表示其它平台按默认规则处理。

### `public protocol ObservableObject : AnyObject`

- **`protocol`**：接口约定，不是某个具体 class/struct。
- **`: AnyObject`**：只有**引用类型（主要是 class）**能满足；与「可观察对象多为 class」一致。

### 关联类型一行

```swift
associatedtype ObjectWillChangePublisher : Publisher = ObservableObjectPublisher
    where Self.ObjectWillChangePublisher.Failure == Never
```

| 片段 | 含义 |
|------|------|
| `associatedtype ObjectWillChangePublisher` | 每个 `Self` 要指定「`objectWillChange` 用哪种 `Publisher`」 |
| `: Publisher` | 该关联类型必须遵循 `Publisher` |
| `= ObservableObjectPublisher` | **默认**关联类型；不显式指定时即为此类型 |
| `where ... Failure == Never` | 该 Publisher 的 **Failure 为 `Never`**（不会以 Failure 完成） |

语法上是：**关联类型 + 对关联类型的协议约束 + 默认值 + where 子句** 的组合。

### `var objectWillChange: Self.ObjectWillChangePublisher { get }`

协议中的**只读要求**：名为 `objectWillChange`，类型为当前 `Self` 上的 `ObjectWillChangePublisher`；`{ get }` 表示只要求可读，实现可以是计算属性或由编译器/库合成。

### 带 `where` 的协议扩展

```swift
@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
extension ObservableObject where Self.ObjectWillChangePublisher == ObservableObjectPublisher {
    public var objectWillChange: ObservableObjectPublisher { get }
}
```

这是 **受限的协议扩展（constrained protocol extension）**：

- `where Self.ObjectWillChangePublisher == ObservableObjectPublisher`：仅当关联类型**就是默认的** `ObservableObjectPublisher` 时，这段扩展才参与。
- 扩展里再次声明 `public var objectWillChange: ObservableObjectPublisher { get }`：在满足上述条件时，为协议提供 **`objectWillChange` 的默认实现**（具体发事件逻辑在标准库/编译器侧，并与 `@Published` 等配合）。

### 两段合在一起表达什么

1. **协议**：规定关联类型（含默认值与 `Failure == Never`）以及 `objectWillChange` 的存在与类型。
2. **扩展**：对「使用默认 `ObservableObjectPublisher`」的类型，提供 **`objectWillChange` 的默认实现**，从而常见 `class` + `@Published` 无需手写 `objectWillChange`。

若自定义 `ObjectWillChangePublisher`（不等于 `ObservableObjectPublisher`），则不会命中该扩展，需自行实现 `objectWillChange`。

---

## 为什么 Combine 里需要 `ObservableObject` 这份协议？

Combine 的核心是 `Publisher` / `Subscriber`（**离散的事件流**），而应用里大量是 **一个引用型 model（多为 class）** 上挂着**多个**会变的属性。若每个属性各做一个 Publisher，订阅方要么订阅很多次，要么自己再 merge、再封装「整颗模型更新了」的信号。

`ObservableObject` 做的是把这件事**标准化**：**不论内部有多少 `@Published`、多少字段，对外约定同一条「快要变了」的入口——`objectWillChange`**。关心该对象的一方只需订一处，就能与 Combine 的订阅模型对齐。

同时，它给 **`@Published` 与编译器合成**提供了类型层面的挂钩：属性在即将变化时要发通知，并汇总到同一个对外 publisher；没有这份协议约定，就很难在类型系统里统一表达「这种类型保证有 `objectWillChange`，且与 `@Published` 语义一致」。

声明式 UI（尤其是 SwiftUI 的 `@ObservedObject`、`@StateObject`、`@EnvironmentObject`）也需要知道 **model 何时应视为失效并重算**；「变化前发 Publisher」属于响应式层抽象，因此协议放在 Combine，UI 作为典型消费者使用。

**一句话**：不是为了多一个标签，而是为了在「引用型、多属性、反复变化」的状态上，约定一个**标准的、可组合的** `objectWillChange` 出口，让属性包装器、默认实现与上层框架能在同一套规则下协作，而不必每个项目各自发明「模型更新了」协议。

---

## 很多个属性时，是不是「每个属性一变对象就触发变化」？

**不一定会。** 取决于属性是否用 `@Published`、以及修改方式（是否走属性的 setter）。

### `@Published` 属性

每个 **`@Published`** 属性在**被赋值**（走该属性的 setter）时，在默认合成路径下，一般都会在**新值写入之前**触发**当前这个** `ObservableObject` 的 `objectWillChange`。

因此：**不是「类里任意存储属性变了都会通知」**，而是 **`@Published` 包着的那些属性**，在**通过 setter 修改**时才会自动参与。

### 普通属性（未使用 `@Published`）

普通 `var` **不会**自动触发 `objectWillChange`。若也要让界面或其它订阅方刷新，需在合适位置调用 `objectWillChange.send()`，或改为 `@Published` / 自行设计的发布方式。

### 嵌套引用类型时的常见误区

```swift
class Child { var name = "" }
class Parent: ObservableObject {
    @Published var child = Child()
}
```

执行 `parent.child.name = "a"` 时，修改的是 **`child` 所指向对象内部的字段**，**没有**对 `parent.child` 这个属性重新赋值，**通常不会**触发 `Parent` 的 `@Published` / `objectWillChange`（外层属性的「赋值」没有发生）。

若希望子对象内部变化也能驱动父对象刷新，可让子模型也采用 `ObservableObject` 并在父层组合订阅、或在修改后手动 `objectWillChange.send()`、或改用值类型/不可变数据等建模方式。

### 简短结论

- **不会**默认做到「每一个属性一变，对象就一定触发变化」。  
- **会**在默认路径下响应的，主要是各 **`@Published` 在赋值时**各自触发的 `objectWillChange`；其余需手写通知或 `send()`。
