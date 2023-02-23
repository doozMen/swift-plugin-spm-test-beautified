import Foundation
import PackagePlugin

@main
struct SPMTestBeautified: CommandPlugin {
    enum Error: Swift.Error {
        case failed
    }

    func performCommand(context: PackagePlugin.PluginContext, arguments: [String]) async throws {

        var extractor = ArgumentExtractor(arguments)
        let showAll = extractor.extractFlag(named: "show-all") == 1
        let help = (extractor.extractFlag(named: "h") == 1) || (extractor.extractFlag(named: "help") == 1)
        let json = extractor.extractFlag(named: "json") == 1

        guard !help else {
            print("""
            After tests have run shows output by default only when tests fail
            and only lists the failed tests

            Usage: `swift package plugin spm-test-beautified <flags>`

            Flags:

            --help, --h
            --show-all                Shows tests including succeeded
            --json                    Output in pretty printed json
            """)
            return
        }

        try await Task { try runAllTests(on: packageManager, showAll: showAll, json: json) }.value
    }

    private func runAllTests(on packageManager: PackageManager, showAll: Bool, json: Bool) throws {
        let result = try packageManager.test(.all, parameters: .init(enableCodeCoverage: true))
        guard result.succeeded else {
            let result = showAll ? result.all() : result.stripSuccesses()
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            if json, let jsonString = String(data: try encoder.encode(result), encoding: .utf8) {
                print(jsonString)
            } else {
                dump(result)
            }
            throw Error.failed
        }
        if showAll {
            dump(json ? result.all() : result.all())
        }
        print("✅ Did run \(result.testTargets.flatMap { $0.testCases }.count) test cases with success")
    }

}

extension PackagePlugin.PackageManager.TestResult.TestTarget {
    var containsFailedTests: Bool {
        testCases.first { $0.tests.contains { $0.result == .failed }} != nil
    }
}

extension PackagePlugin.PackageManager.TestResult {
    func all() -> TestResult {
        let testTargets = testTargets
            .map {
                let testCases = $0.testCases.map {
                    let tests = $0.tests
                        .map { TestResult.TestTarget.TestCase.Test(
                            name: $0.name,
                            result: $0.result.converted,
                            duration: $0.duration) }
                    return TestResult.TestTarget.TestCase(
                        name: $0.name,
                        tests: tests)
                }
                return TestResult.TestTarget(name: $0.name, testCases: testCases)
            }

        return .init(
            succeeded: succeeded,
            testTargets: testTargets,
            codeCoverageDataFile: codeCoverageDataFile?.string)
    }
    func stripSuccesses() -> TestResult {
        let failedTestTargets = self.testTargets
            .filter { $0.containsFailedTests }
            .map {
                let failedTestCases = $0.testCases.filter { $0.tests.contains { $0.result == .failed } }
                return TestResult.TestTarget(
                    name: $0.name,
                    testCases: failedTestCases
                        .map {
                            let failedTests = $0.tests
                                .filter { $0.result == .failed }
                                .map { TestResult.TestTarget.TestCase.Test(name: $0.name, result: .failed, duration: $0.duration) }
                            return TestResult.TestTarget.TestCase(name: $0.name, tests: failedTests)
                        }
                )
            }
        return TestResult(
            succeeded: false,
            testTargets: failedTestTargets,
            codeCoverageDataFile: codeCoverageDataFile?.string)
    }
}


struct TestResult: CustomStringConvertible, Encodable {
    let succeeded: Bool
    let testTargets: [TestTarget]
    let codeCoverageDataFile: String?
    var description: String { "TestResult" }

    struct TestTarget: CustomStringConvertible, Encodable {
        let name: String
        let testCases: [TestCase]
        var description: String { "TestTarget" }

        struct TestCase: CustomStringConvertible, Encodable {
            let name: String
            let tests: [Test]
            var description: String { "TestCase"}

            struct Test: CustomStringConvertible, Encodable {
                let name: String
                let result: Result
                let duration: Double
                var description: String { "Test" }

                enum Result: CustomStringConvertible, Encodable {
                    case succeeded
                    case skipped
                    case failed
                    case unknown(rawValue: String)

                    func encode(to encoder: Encoder) throws {
                        var container = encoder.singleValueContainer()
                        try container.encode(description)
                    }

                    var description: String {
                        switch self {
                            case .succeeded: return "✅"
                            case .skipped: return "⏭️"
                            case .failed: return "❌"
                            case .unknown(rawValue: let raw): return "unknown - \(raw)"
                        }
                    }
                }
            }
        }
    }
}

extension PackagePlugin.PackageManager.TestResult.TestTarget.TestCase.Test.Result {
    var converted: TestResult.TestTarget.TestCase.Test.Result {
        switch self {
            case .succeeded: return .succeeded
            case .skipped: return .skipped
            case .failed: return .failed
            @unknown default: return .unknown(rawValue: rawValue)
        }
    }
}
