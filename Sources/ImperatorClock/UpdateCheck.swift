import Foundation

/// `ImperatorClock --update-check` runs the version comparison the update
/// checker decides on, against the six cases that have to come out right.
///
/// The comparison is the one piece of the checker that can be wrong without
/// anything looking wrong: a check that never fires looks exactly like an app
/// that is up to date. It is numeric per component for one reason, and the
/// negative control below is that reason: compared as strings, "1.0.10" sorts
/// before "1.0.9", so the one release where the patch number reaches double
/// figures is the one the user never hears about.
///
/// This runs the shipped function rather than a copy of it, and it runs before
/// `NSApplication.run()`, so it never opens a panel and never asks GitHub
/// anything.
enum UpdateCheck {
    static func run() -> Int32 {
        var failures: [String] = []
        let expect = { (ok: Bool, message: String) in if !ok { failures.append(message) } }

        let cases: [(candidate: String, current: String, newer: Bool)] = [
            ("1.0.10", "1.0.9", true),
            ("1.0.9", "1.0.10", false),
            ("1.1.1", "1.1.1", false),
            ("1.1", "1.0.9", true),
            ("1.0", "1.0.0", false),
            ("2.0.0", "1.9.9", true),
        ]
        for (candidate, current, newer) in cases {
            let answer = UpdateChecker.isNewer(candidate, than: current)
            expect(answer == newer,
                   "isNewer(\(candidate), than: \(current)) is \(answer), expected \(newer)")
        }

        // The positive control for the claim that a string comparison is not
        // good enough. If this ever stops disagreeing, the six cases above
        // have stopped discriminating and prove nothing.
        let stringAnswer = "1.0.10" > "1.0.9"
        expect(stringAnswer == false,
               "a string comparison now answers 1.0.10 > 1.0.9 correctly, so these cases no "
               + "longer tell a numeric comparison from a lexicographic one")

        if failures.isEmpty {
            print("\(cases.count) comparisons correct, string comparison fails the first one")
            print("G16_UPDATE_CHECK_OK")
            return 0
        }
        for failure in failures { print("FAIL \(failure)") }
        return 1
    }
}
