import Foundation

@MainActor
@Observable
final class PipelineDetailViewModel {
    private(set) var jobs: [PipelineJob] = []
    private(set) var trace = ""
    private(set) var isLoadingJobs = false
    private(set) var isLoadingTrace = false
    private(set) var isMutating = false
    private(set) var error: Error?

    func loadJobs(projectID: Int, pipelineID: Int, client: GitLabAPIClient) async {
        isLoadingJobs = true
        error = nil

        do {
            jobs = try await client.pipelineJobs(projectID: projectID, pipelineID: pipelineID)
        } catch {
            self.error = error
        }

        isLoadingJobs = false
    }

    func loadTrace(projectID: Int, jobID: Int, client: GitLabAPIClient) async {
        isLoadingTrace = true
        error = nil

        do {
            trace = try await client.jobTrace(projectID: projectID, jobID: jobID)
        } catch {
            self.error = error
        }

        isLoadingTrace = false
    }

    func retryPipeline(projectID: Int, pipelineID: Int, client: GitLabAPIClient) async -> Bool {
        await mutate {
            try await client.retryPipeline(projectID: projectID, pipelineID: pipelineID)
        }
    }

    func cancelPipeline(projectID: Int, pipelineID: Int, client: GitLabAPIClient) async -> Bool {
        await mutate {
            try await client.cancelPipeline(projectID: projectID, pipelineID: pipelineID)
        }
    }

    func perform(_ action: PipelineJobAction, projectID: Int, jobID: Int, client: GitLabAPIClient) async -> Bool {
        await mutate {
            let updatedJob: PipelineJob
            switch action {
            case .play:
                updatedJob = try await client.playJob(projectID: projectID, jobID: jobID)
            case .retry:
                updatedJob = try await client.retryJob(projectID: projectID, jobID: jobID)
            case .cancel:
                updatedJob = try await client.cancelJob(projectID: projectID, jobID: jobID)
            }
            updateJob(updatedJob)
        }
    }

    private func mutate(_ operation: () async throws -> Void) async -> Bool {
        isMutating = true
        error = nil
        defer { isMutating = false }

        do {
            try await operation()
            return true
        } catch {
            self.error = error
            return false
        }
    }

    private func updateJob(_ job: PipelineJob) {
        guard let index = jobs.firstIndex(where: { $0.id == job.id }) else { return }
        jobs[index] = job
    }
}
