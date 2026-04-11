import Foundation
import Testing
@testable import iDocsApp

@Suite("Benchmark Record Schema Tests")
struct BenchmarkRecordSchemaTests {
    @Test("Evaluation record should decode with required fields")
    func decodeRecord() throws {
        let json = """
        {
          "run_id":"run-1",
          "target_id":"idocs",
          "scenario_id":"S001",
          "attempt_index":1,
          "sample_class":"cold",
          "status":"success",
          "started_at":"2026-03-19T00:00:00Z",
          "finished_at":"2026-03-19T00:00:01Z",
          "duration_ms":1000,
          "call_count":2,
          "output_length":900,
          "avg_token_per_call":120,
          "total_token_per_task":240,
          "token_observability":"partial",
          "tokenizer_spec":"cl100k_base",
          "driver_profile":"controlled-agent-v1",
          "truth_baseline":"xcode-16.0-ios-18.0",
          "overfetch_flag":false,
          "evidence_refs":["artifacts/evidence/s001.json"],
          "accuracy_verdict":"correct",
          "completeness_verdict":"partial",
          "claim_rate":0.8,
          "slot_rate":0.6,
          "format_extractability":5,
          "format_density":3,
          "format_task_fit":5,
          "format_noise":3,
          "format_citability":5,
          "format_notes":"stable extraction"
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let record = try decoder.decode(BenchmarkExecutionRecord.self, from: json)
        #expect(record.targetID == "idocs")
        #expect(record.tokenizerSpec == "cl100k_base")
        #expect(record.sampleClass == .cold)
    }
}
