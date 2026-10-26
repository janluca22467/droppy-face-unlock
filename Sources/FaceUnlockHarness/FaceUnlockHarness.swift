import DroppyKit
import DroppyKitHarness
import FaceUnlock

@main
struct FaceUnlockHarness: DropletHarnessApp {
    static func makeDroplet() -> any Droplet { FaceUnlockDroplet() }
}
