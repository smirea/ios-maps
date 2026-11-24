import { $ } from "bun";
import { env } from "node:process";

const directory = env.SWIFT_DIRECTORY;
if (!directory) throw new Error("Missing SWIFT_DIRECTORY");

switch (Bun.argv[2]) {
  case "package": {
    // `swift test` compiles every target, the app's included, so it is the macOS compile check too.
    const pkg: { targets: { type: string }[] } = await $`swift package describe --type json`
      .cwd(directory)
      .json();
    if (pkg.targets.some((target) => target.type === "test")) await $`swift test`.cwd(directory);
    else await $`swift build`.cwd(directory);
    break;
  }
  case "app":
    await $`xcodebuild build -project PrivateMaps.xcodeproj -scheme PrivateMaps -derivedDataPath DerivedData/ci -clonedSourcePackagesDirPath .build/SourcePackages CODE_SIGNING_ALLOWED=NO -configuration Release -destination ${"generic/platform=iOS Simulator"}`.cwd(
      directory,
    );
    break;
  default:
    throw new Error(`Unknown Swift task: ${Bun.argv[2]}`);
}
