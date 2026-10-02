// swift-tools-version: 6.0
import PackageDescription

let package = Package(
	name: "ios-maps",
	platforms: [
		.iOS(.v17),
		.macOS(.v14),
	],
	products: [
		.executable(name: "ios-maps", targets: ["App"]),
	],
	targets: [
		.executableTarget(name: "App"),
	]
)