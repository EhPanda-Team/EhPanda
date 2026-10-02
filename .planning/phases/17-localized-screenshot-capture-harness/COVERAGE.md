# Phase 17 integration coverage

No external API integration: this phase uses a test-only SnapshotTesting library and installed local Xcode/simulator tools; acquisition reuses existing app service contracts, and there is no new external service API surface.

The deterministic API coverage detector examined the corrected Phase 17 roadmap plus all24 current plans after revision2 and returned detected:false. The Xcode bridge is an inspected local review aid, not a new application service integration. SnapshotTesting comparison, candidate recording, native image comparison and explicit baseline promotion are covered in plans 01 and 12–14. Full requirement, decision, research, edge and prohibition coverage is recorded in17-SOURCE-AUDIT.md.

Revision1 preserves this API scope. Public native dispatch is produced in17-11 before17-08–17-10 extend and capture each scenario. Fresh-checkout bootstrap in17-14 consumes committed PublicVisualFixtures/scenarios through17-01's deterministic export test and the tracked environment pin from17-24, verifies provenance/hashes and runs the complete offline hosted/native matrix. No acquisition service or credentials are introduced into CI.

Revision2 contains24 plans/53 tasks in24 waves.17-24 produces geometry first and the immutable pin second, before17-02 consumes it.17-14-T1 verifies real current-tree bootstrap,17-14-T2 verifies Release tooling, and17-14-T3 runs actual full clean-checkout acceptance only after both producer commits. Its evidence document is not an input to archived HEAD. The split adds no external API integration and preserves complete native/hosted coverage, hashes, negatives and Release isolation.
