import Foundation

@main
struct ModelBehaviorTests {
    static func main() throws {
        try testNormalizesGitLabBaseURL()
        try testUpsertsAndRemovesGitLabInstances()
        try testDecodesPipelinesAcrossMergeRequestBuckets()
        try testCountsActionablePipelinesForLocalBadge()
        try testDecodesPipelineIdentifiersForInteraction()
        try testPipelineJobInteractionRules()
        try testGroupsPipelineJobsForStableStageDisclosure()
        try testDetectsPipelineStartAndCompletionNotifications()
        try testDecodesPipelineNotificationPayload()
        try testParsesUnifiedDiffLines()
        print("ModelBehaviorTests passed")
    }

    private static func testNormalizesGitLabBaseURL() throws {
        assertEqual(
            GitLabBaseURLNormalizer.normalize(" gitlab.example.com ")?.absoluteString,
            "https://gitlab.example.com",
            "bare hosts should default to https"
        )
        assertEqual(
            GitLabBaseURLNormalizer.normalize("http://gitlab.internal/group")?.absoluteString,
            "http://gitlab.internal/group",
            "explicit http URLs should be preserved"
        )
        assertNil(
            GitLabBaseURLNormalizer.normalize("ftp://gitlab.example.com"),
            "unsupported schemes should be rejected"
        )
    }

    private static func testUpsertsAndRemovesGitLabInstances() throws {
        let id = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
        let first = GitLabInstance(id: id, name: "GitLab A", baseURL: URL(string: "https://gitlab-a.example.com")!)
        let renamed = GitLabInstance(id: id, name: "GitLab Main", baseURL: URL(string: "https://gitlab.example.com")!)
        let second = GitLabInstance(
            id: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,
            name: "GitLab B",
            baseURL: URL(string: "https://gitlab-b.example.com")!
        )

        let inserted = GitLabInstanceList.upsert(first, in: [])
        let appended = GitLabInstanceList.upsert(second, in: inserted)
        let updated = GitLabInstanceList.upsert(renamed, in: appended)
        let removed = GitLabInstanceList.remove(renamed, from: updated)

        assertEqual(updated.count, 2, "upsert should add new instances")
        assertEqual(updated.first?.name, "GitLab Main", "upsert should update matching instance IDs")
        assertEqual(removed.map(\.id), [second.id], "remove should delete the selected instance")
    }

    private static func testDecodesPipelinesAcrossMergeRequestBuckets() throws {
        let json = """
        {
          "currentUser": {
            "assignedMergeRequests": {
              "nodes": [
                {
                  "id": "gid://gitlab/MergeRequest/1",
                  "iid": "10",
                  "title": "Assigned MR",
                  "description": "Ready",
                  "sourceBranch": "feature/a",
                  "targetBranch": "main",
                  "state": "opened",
                  "approved": false,
                  "webUrl": "https://gitlab.example.com/project/-/merge_requests/10",
                  "project": { "id": "gid://gitlab/Project/123", "fullPath": "group/project" },
                  "author": { "id": "gid://gitlab/User/1", "username": "alice", "name": "Alice", "avatarUrl": null },
                  "reviewers": { "nodes": [] },
                  "diffStats": [{ "path": "Sources/App.swift", "additions": 4, "deletions": 1 }],
                  "headPipeline": {
                    "id": "gid://gitlab/Ci::Pipeline/100",
                    "status": "SUCCESS",
                    "ref": "feature/a",
                    "sha": "abcdef123456",
                    "stages": {
                      "nodes": [
                        {
                          "id": "gid://gitlab/Ci::Stage/200",
                          "name": "test",
                          "status": "SUCCESS",
                          "jobs": {
                            "nodes": [
                              { "id": "gid://gitlab/Ci::Build/300", "name": "unit", "status": "SUCCESS" }
                            ]
                          }
                        }
                      ]
                    }
                  }
                }
              ]
            },
            "authoredMergeRequests": {
              "nodes": [
                {
                  "id": "gid://gitlab/MergeRequest/2",
                  "iid": "11",
                  "title": "Authored MR",
                  "description": null,
                  "sourceBranch": "feature/b",
                  "targetBranch": "main",
                  "state": "opened",
                  "approved": true,
                  "webUrl": null,
                  "project": { "id": "gid://gitlab/Project/123", "fullPath": "group/project" },
                  "author": { "id": "gid://gitlab/User/2", "username": "bob", "name": "Bob", "avatarUrl": null },
                  "reviewers": { "nodes": [] },
                  "diffStats": null,
                  "headPipeline": {
                    "id": "gid://gitlab/Ci::Pipeline/101",
                    "status": "FAILED",
                    "ref": "feature/b",
                    "sha": null,
                    "stages": { "nodes": [] }
                  }
                }
              ]
            },
            "reviewRequestedMergeRequests": {
              "nodes": [
                {
                  "id": "gid://gitlab/MergeRequest/1",
                  "iid": "10",
                  "title": "Assigned MR",
                  "description": "Ready",
                  "sourceBranch": "feature/a",
                  "targetBranch": "main",
                  "state": "opened",
                  "approved": false,
                  "webUrl": "https://gitlab.example.com/project/-/merge_requests/10",
                  "project": { "id": "gid://gitlab/Project/123", "fullPath": "group/project" },
                  "author": { "id": "gid://gitlab/User/1", "username": "alice", "name": "Alice", "avatarUrl": null },
                  "reviewers": { "nodes": [] },
                  "diffStats": null,
                  "headPipeline": null
                }
              ]
            }
          }
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(CurrentUserResponse.self, from: json)
        let mergeRequests = response.currentUser.allMergeRequests.map { $0.toMergeRequest() }
        assertEqual(mergeRequests.count, 2, "duplicate merge requests should be removed across buckets")

        let pipeline = try unwrap(mergeRequests.first?.headPipeline, "first MR should include a pipeline")
        assertEqual(pipeline.status, .success, "pipeline status should decode case-insensitively")
        assertEqual(pipeline.ref, "feature/a", "pipeline ref should decode")
        assertEqual(pipeline.sha, "abcdef123456", "pipeline sha should decode")
        assertEqual(pipeline.stages.first?.jobs.first?.name, "unit", "stage jobs should decode")
    }

    private static func testCountsActionablePipelinesForLocalBadge() throws {
        let pipelines = [
            Pipeline(id: "success", status: .success),
            Pipeline(id: "failed", status: .failed),
            Pipeline(id: "running", status: .running),
            Pipeline(id: "pending", status: .pending),
            Pipeline(id: "skipped", status: .skipped),
            Pipeline(id: "canceled", status: .canceled)
        ]

        assertEqual(Pipeline.localBadgeCount(for: pipelines), 3, "local polling badge should count actionable pipeline states")
    }

    private static func testDecodesPipelineIdentifiersForInteraction() throws {
        let json = """
        {
          "currentUser": {
            "assignedMergeRequests": {
              "nodes": [
                {
                  "id": "gid://gitlab/MergeRequest/1",
                  "iid": "10",
                  "title": "Interactive pipeline MR",
                  "description": null,
                  "sourceBranch": "feature/a",
                  "targetBranch": "main",
                  "state": "opened",
                  "approved": false,
                  "webUrl": "https://gitlab.example.com/project/-/merge_requests/10",
                  "project": { "id": "gid://gitlab/Project/123", "fullPath": "group/project" },
                  "author": { "id": "gid://gitlab/User/1", "username": "alice", "name": "Alice", "avatarUrl": null },
                  "reviewers": { "nodes": [] },
                  "diffStats": null,
                  "headPipeline": {
                    "id": "gid://gitlab/Ci::Pipeline/456",
                    "status": "RUNNING",
                    "ref": "feature/a",
                    "sha": "abcdef123456",
                    "stages": { "nodes": [] }
                  }
                }
              ]
            },
            "authoredMergeRequests": { "nodes": [] },
            "reviewRequestedMergeRequests": { "nodes": [] }
          }
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(CurrentUserResponse.self, from: json)
        let pipeline = try unwrap(response.currentUser.allMergeRequests.first?.toMergeRequest().headPipeline, "MR should include a pipeline")

        assertEqual(pipeline.pipelineID, 456, "pipeline numeric ID should be extracted for REST interactions")
        assertEqual(pipeline.projectID, 123, "pipeline project ID should be carried for REST interactions")
    }

    private static func testPipelineJobInteractionRules() throws {
        assertEqual(
            PipelineJobAction.availableActions(for: PipelineJob(id: 1, name: "deploy", stage: "deploy", status: .manual)),
            [.play],
            "manual jobs should be playable"
        )
        assertEqual(
            PipelineJobAction.availableActions(for: PipelineJob(id: 2, name: "unit", stage: "test", status: .failed)),
            [.retry],
            "failed jobs should be retryable"
        )
        assertEqual(
            PipelineJobAction.availableActions(for: PipelineJob(id: 3, name: "lint", stage: "test", status: .running)),
            [.cancel],
            "running jobs should be cancellable"
        )
        assertEqual(
            PipelineJobAction.availableActions(for: PipelineJob(id: 4, name: "build", stage: "build", status: .success)),
            [],
            "completed successful jobs should expose no mutation action"
        )
    }

    private static func testGroupsPipelineJobsForStableStageDisclosure() throws {
        let jobs = [
            PipelineJob(id: 1, name: "source branch", stage: "merge checks", status: .success),
            PipelineJob(id: 2, name: "go test", stage: "merge checks", status: .success),
            PipelineJob(id: 3, name: "manual deploy", stage: "deploy", status: .manual)
        ]

        let groups = PipelineStageGroup.groups(for: jobs)

        assertEqual(groups.map(\.id), ["merge checks", "deploy"], "stage group identity should stay stable for disclosure rows")
        assertEqual(groups.first?.jobs.map(\.id), [1, 2], "stage groups should preserve job ordering")
        assertEqual(groups.first?.status, .success, "stage group status should summarize completed jobs")
        assertEqual(groups.last?.status, .manual, "stage group status should expose actionable manual jobs")
    }

    private static func testDetectsPipelineStartAndCompletionNotifications() throws {
        let previous = [
            Pipeline(id: "pipeline-a", status: .pending, pipelineID: 1, projectID: 10, mergeRequestTitle: "A"),
            Pipeline(id: "pipeline-b", status: .running, pipelineID: 2, projectID: 10, mergeRequestTitle: "B"),
            Pipeline(id: "pipeline-c", status: .success, pipelineID: 3, projectID: 10, mergeRequestTitle: "C")
        ]
        let current = [
            Pipeline(id: "pipeline-a", status: .running, pipelineID: 1, projectID: 10, mergeRequestTitle: "A"),
            Pipeline(id: "pipeline-b", status: .failed, pipelineID: 2, projectID: 10, mergeRequestTitle: "B"),
            Pipeline(id: "pipeline-c", status: .success, pipelineID: 3, projectID: 10, mergeRequestTitle: "C")
        ]

        let events = PipelineNotificationEvent.detect(previous: previous, current: current)

        assertEqual(events.map(\.kind), [.started, .completed], "status transitions should produce start and completion events")
        assertEqual(events.map(\.pipelineID), [1, 2], "events should identify the changed pipelines")
    }

    private static func testDecodesPipelineNotificationPayload() throws {
        let json = """
        {
          "type": "pipeline_started",
          "instance": "https://gitlab.example.com",
          "project": { "id": 123, "name": "project" },
          "pipeline": { "id": 456, "ref": "main", "status": "running" },
          "actor": { "username": "alice", "avatar_url": null },
          "timestamp": "2026-06-21T10:00:00Z"
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let payload = try decoder.decode(NotificationPayload.self, from: json)

        assertEqual(payload.type, .pipelineStarted, "pipeline started payload type should decode")
        assertEqual(payload.pipeline?.id, 456, "pipeline payload should include an id")
        assertEqual(payload.pipeline?.status, .running, "pipeline payload should decode status")
    }

    private static func testParsesUnifiedDiffLines() throws {
        let diff = """
        @@ -1,3 +1,4 @@
         context
        -old line
        +new line
        \\ No newline at end of file
        """

        let lines = DiffParser.parse(diff)
        assertEqual(lines.map(\.kind), [.hunk, .context, .deletion, .addition, .metadata], "line kinds should match unified diff markers")
        assertEqual(lines[2].content, "old line", "deletion should strip marker")
        assertEqual(lines[3].content, "new line", "addition should strip marker")
    }

    private static func assertEqual<T: Equatable>(_ actual: T, _ expected: T, _ message: String) {
        if actual != expected {
            fatalError("\\(message): expected \\(expected), got \\(actual)")
        }
    }

    private static func assertNil<T>(_ actual: T?, _ message: String) {
        if actual != nil {
            fatalError("\\(message): expected nil, got \\(String(describing: actual))")
        }
    }

    private static func unwrap<T>(_ value: T?, _ message: String) throws -> T {
        guard let value else {
            fatalError(message)
        }
        return value
    }
}
