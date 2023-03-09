import Foundation
import PackagePlugin

@main
struct SPMTestBeautified: CommandPlugin {
  enum Error: Swift.Error {
    case failedTests, buildFailed
  }

  func performCommand(context: PackagePlugin.PluginContext, arguments: [String]) async throws {

    var extractor = ArgumentExtractor(arguments)
    let showAll = extractor.extractFlag(named: "show-all") == 1
    let help = (extractor.extractFlag(named: "h") == 1) || (extractor.extractFlag(named: "help") == 1)
    let json = extractor.extractFlag(named: "json") == 1
    let excludeOption = extractor.extractOption(named: "exclude")
    let exclude = excludeOption + extractor.remainingArguments

    guard !help else {
      print("""
            After tests have run shows output by default only when tests fail
            and only lists the failed tests

            Usage: `swift package plugin spm-test-beautified <flags>`

            Flags:

            --help, --h
            --show-all                Shows tests including succeeded
            --json                    Output in pretty printed json
            --exclude                 [has to be last!] Space separated list of test names to exclude running
            """)
      return
    }
    print("Starting tests for \(context.package.displayName)")

    if !exclude.isEmpty {
      print("""
      Will exclude tests with name

      \(exclude.map { " ‣ \($0)"}.joined(separator: "\n"))
      
      """)
    }

    let watchdog = Task.detached {
      var count: UInt32 = 0
      let seconds: UInt32 = 10
      while !Task.isCancelled {
        sleep(seconds)
        print("Still testing \(context.package.displayName) \(count * seconds)")
        count += 1
      }
    }

    try await runAllTests(in: context, showAll: showAll, json: json, exclude: exclude, watchdog: watchdog).value
  }

  fileprivate func showJsonOrResult(_ json: Bool, _ result: TestResult) throws {
    let encoder = JSONEncoder()
    encoder.outputFormatting = .prettyPrinted
    if json, let jsonString = String(data: try encoder.encode(result), encoding: .utf8) {
      print(jsonString)
    } else {
      dump(result)
    }
  }

  private func runAllTests(in context: PackagePlugin.PluginContext, showAll: Bool, json: Bool, exclude: [String], watchdog: Task<Void, Never>) -> Task<Void, Swift.Error> {
    Task {
      defer { watchdog.cancel() }
      let targets = context.package.targets.map { $0.name }.joined(separator: ", ")

      print("Building before testing [\(targets)] ...")
      let buildResult = try packageManager.build(.all(includingTests: true), parameters: .init(configuration: .debug))
      guard buildResult.succeeded else {
        print("❌ Building failed - dumping logtext")
        print("--- build log ---")
        print(buildResult.logText)
        print("--- build log ---")
        throw Error.buildFailed
      }
      print("✅ Did build [\(targets)]")

      print("Start testing ...")
      // have to disable code coverage for now as it randomly fails complaining a file does not exist
      let result = try packageManager.test(.filtered(["^((?!_skipped).)*$"]), parameters: .init(enableCodeCoverage: false))
      guard result.succeeded(excluding: exclude) else {
        let result = showAll ? result.all() : result.stripSuccesses(excluding: exclude)
        try showJsonOrResult(json, result)
        throw Error.failedTests
      }
      if showAll {
        try showJsonOrResult(json, result.all())
      }
      let testCases = result.testTargets.flatMap { $0.testCases }
      let tests = testCases.flatMap { $0.tests }
      print("✅ Did run \(testCases.count) test cases in total \(tests.count) tests with success")
    }
  }

}

extension PackagePlugin.PackageManager.TestResult.TestTarget {
  var containsFailedTests: Bool {
    testCases.first { $0.tests.contains { $0.result == .failed }} != nil
  }
}

extension PackagePlugin.PackageManager.TestResult {

  func succeeded(excluding skipped: [String]) -> Bool {
    let fails = stripSuccesses()
    return fails.testTargets
      .flatMap { $0.testCases }
      .flatMap { $0.tests }
      .filter { !skipped.contains($0.name) }
      .isEmpty
  }

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

  func stripSuccesses(excluding: [String] = []) -> TestResult {
    let failedTestTargets = self.testTargets
      .filter { $0.containsFailedTests }
      .compactMap { testTarget -> TestResult.TestTarget? in
        let failedTestCases = testTarget.testCases
          .filter {
            $0.tests.contains { $0.result == .failed && !excluding.contains($0.name) }
          }
        guard !failedTestCases.isEmpty else {
          return nil
        }
        return TestResult.TestTarget(
          name: testTarget.name,
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
