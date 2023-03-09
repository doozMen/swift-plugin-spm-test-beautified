# swift-plugin-spm-test-beautified

After tests have run shows output by default only when tests fail
and only lists the failed tests

Usage: `swift package plugin spm-test-beautified <flags>`

Flags:

--help, --h
--show-all                Shows tests including succeeded
--json                    Output in pretty printed json
--exclude                 A space separated list of test function names to be excluded from tests


## example

In swift package add dependency

``` swift
.package(url: "https://github.com/doozMen/swift-plugin-spm-test-beautified.git", from: "<#version#>"),
```

To exclude some test in this project try running

`swift package plugin spm-test-beautified --exclude testBar testExtended testFail`

Which should show succeeded

`swift package plugin spm-test-beautified --exclude testBar`

would show

``` bash
Starting tests for swift-plugin-spm-test-beautified
Will exclude tests with name

 ‣ testBar

Building before testing [SPMTestBeautifiedTests, FooLib] ...
✅ Did build [SPMTestBeautifiedTests, FooLib]
Start testing ...
^((?!testBar).)*$
Compiling plugin SPMTestBeautified...
Building for debugging...
Build complete! (0.07s)
▿ TestResult
  - succeeded: false
  ▿ testTargets: 1 element
    ▿ TestTarget
      - name: "SPMTestBeautifiedTests"
      ▿ testCases: 1 element
        ▿ TestCase
          - name: "SPMTestBeautifiedTests.SPMTestBeautifiedTests"
          ▿ tests: 2 elements
            ▿ Test
              - name: "testExtended"
              - result: ❌
              - duration: 0.077
            ▿ Test
              - name: "testFail"
              - result: ❌
              - duration: 0.073
  - codeCoverageDataFile: nil
error: failedTests
```
