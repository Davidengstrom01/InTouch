import SwiftData
import SwiftUI

@main
struct InTouchApp: App {
    private let container: ModelContainer
    @State private var model: AppModel
    private let isUITesting: Bool

    @MainActor
    init() {
        let arguments = ProcessInfo.processInfo.arguments
        isUITesting = arguments.contains("-ui-testing")

        do {
            let container = try Self.makeContainer(inMemory: isUITesting)
            self.container = container
            let history = LocalHistoryStore(context: container.mainContext)

            #if DEBUG
            if isUITesting {
                _model = State(
                    initialValue: AppModel(
                        contacts: SeededContactProvider(),
                        callOpener: SeededCallOpener(),
                        history: history,
                        now: { Date(timeIntervalSince1970: 1_800_000_000) },
                        randomUnit: { 0 }
                    )
                )
                return
            }
            #endif

            _model = State(
                initialValue: AppModel(
                    contacts: SystemContactProvider(),
                    callOpener: SystemCallOpener(),
                    history: history
                )
            )
        } catch {
            fatalError("Unable to create InTouch's protected local store: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView(model: model, skipOnboarding: isUITesting)
        }
        .modelContainer(container)
    }

    private static func makeContainer(inMemory: Bool) throws -> ModelContainer {
        let schema = Schema([ExcludedContactRecord.self, CallHandoffRecord.self])
        if inMemory {
            return try ModelContainer(
                for: schema,
                configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            )
        }

        let fileManager = FileManager.default
        let applicationSupport = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let protectedDirectory = applicationSupport.appending(path: "InTouch", directoryHint: .isDirectory)
        try fileManager.createDirectory(
            at: protectedDirectory,
            withIntermediateDirectories: true,
            attributes: [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication]
        )
        try fileManager.setAttributes(
            [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
            ofItemAtPath: protectedDirectory.path
        )

        let configuration = ModelConfiguration(
            "InTouch",
            schema: schema,
            url: protectedDirectory.appending(path: "InTouch.store"),
            cloudKitDatabase: .none
        )
        return try ModelContainer(for: schema, configurations: configuration)
    }
}

#if DEBUG
@MainActor
private final class SeededContactProvider: ContactProviding {
    var accessState: ContactAccessState { .authorized }

    func requestAccess() async -> ContactAccessState { .authorized }

    func callableContacts() throws -> [CallableContact] {
        [
            CallableContact(id: "alex", displayName: "Alex Morgan", phoneNumber: "+46701234567"),
            CallableContact(id: "bea", displayName: "Beatrice Nilsson", phoneNumber: "+46707654321"),
            CallableContact(id: "chris", displayName: "Chris Lee", phoneNumber: "+46701112233")
        ]
    }
}

@MainActor
private struct SeededCallOpener: CallOpening {
    func openCall(to phoneNumber: String) async -> Bool { true }
}
#endif
