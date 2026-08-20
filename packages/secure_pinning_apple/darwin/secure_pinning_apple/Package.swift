// swift-tools-version: 5.9
import PackageDescription

let package = Package(
  name: "secure_pinning_apple",
  platforms: [
    .iOS("16.0"),
    .macOS("12.0"),
  ],
  products: [
    // Flutter's tooling expects this product name hyphenated (it derives
    // the expected name from the pub package name with underscores
    // replaced by hyphens), even though the target/module name below must
    // stay underscored to match `import secure_pinning_apple`.
    .library(name: "secure-pinning-apple", targets: ["secure_pinning_apple"])
  ],
  targets: [
    .target(
      // Flutter's Swift Package Manager plugin support expects the
      // importable module name to match the plugin's pub package name
      // exactly — GeneratedPluginRegistrant.swift does `import
      // secure_pinning_apple`, not `import SecurePinningApple`.
      name: "secure_pinning_apple",
      path: "Sources/SecurePinningApple"
    )
  ]
)
