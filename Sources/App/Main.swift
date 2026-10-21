import Foundation

@main
enum Main {
    static func main() {
        let arguments = Array(CommandLine.arguments.dropFirst())
        guard arguments.first == "--cli" else {
            MetadataRemoverApp.main()
            return
        }
        Task {
            let status = await CommandLineTool.run(Array(arguments.dropFirst()))
            exit(status)
        }
        // Keep the main thread alive (and serving the main actor) until the CLI task calls exit().
        dispatchMain()
    }
}
