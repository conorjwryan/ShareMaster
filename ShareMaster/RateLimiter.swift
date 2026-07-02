//
//  RateLimiter.swift
//  ShareMaster
//
//  Debt-based token bucket used to cap upload/download bandwidth.
//  Callers `acquire(bytes:)` before sending/receiving that many bytes; when
//  the bucket runs dry the call sleeps just long enough for the average rate
//  to converge on the cap. A single oversized acquire (e.g. a 16 MiB upload
//  part) can push the balance negative rather than deadlocking — the debt is
//  paid off by the next caller's wait.
//

import Foundation

actor RateLimiter {
    /// Bytes per second. 0 (or negative) means unlimited.
    private var bytesPerSecond: Double = 0
    private var balance: Double = 0
    private var lastRefill: ContinuousClock.Instant = .now

    /// Cap on how much unused budget can accumulate, in seconds of traffic.
    /// Keeps a long idle period from being followed by a huge burst.
    private let burstSeconds: Double = 2

    /// Sets the current cap. Called at the start of each transfer with the
    /// resolved per-destination value; last writer wins when transfers with
    /// different caps overlap (acceptable for a single-user menu bar app).
    func setRate(bytesPerSecond: Double) {
        refill()
        self.bytesPerSecond = max(0, bytesPerSecond)
        balance = min(balance, self.bytesPerSecond * burstSeconds)
    }

    /// Blocks (cooperatively) until `bytes` fit within the configured rate.
    func acquire(bytes: Int) async {
        guard bytesPerSecond > 0, bytes > 0 else { return }
        refill()
        balance -= Double(bytes)
        if balance < 0 {
            let waitSeconds = -balance / bytesPerSecond
            try? await Task.sleep(for: .seconds(waitSeconds))
            refill()
        }
    }

    private func refill() {
        let now = ContinuousClock.now
        let elapsed = lastRefill.duration(to: now)
        lastRefill = now
        guard bytesPerSecond > 0 else { return }
        let seconds = Double(elapsed.components.seconds) +
            Double(elapsed.components.attoseconds) / 1e18
        balance = min(balance + seconds * bytesPerSecond, bytesPerSecond * burstSeconds)
    }
}
