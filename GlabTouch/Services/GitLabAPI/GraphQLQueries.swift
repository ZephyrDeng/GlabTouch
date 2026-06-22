import Foundation

enum GraphQLQueries {
    static func mergeRequests(filter: String) -> String {
        """
        query {
          currentUser {
            \(filter)(state: opened, first: 20) {
              nodes {
                \(mergeRequestFields)
              }
            }
          }
        }
        """
    }

    static let pipelineDashboard = """
    query {
      currentUser {
        username
        assignedMergeRequests(state: opened, first: 20) {
          nodes {
            \(mergeRequestFields)
          }
        }
        authoredMergeRequests(state: opened, first: 20) {
          nodes {
            \(mergeRequestFields)
          }
        }
        reviewRequestedMergeRequests(state: opened, first: 20) {
          nodes {
            \(mergeRequestFields)
          }
        }
      }
    }
    """

    static func filterFieldName(for filter: MergeRequestListViewModel.MRFilter) -> String {
        switch filter {
        case .assignedToMe: "assignedMergeRequests"
        case .createdByMe: "authoredMergeRequests"
        case .reviewRequested: "reviewRequestedMergeRequests"
        }
    }

    private static let mergeRequestFields = """
    id
    iid
    title
    description
    descriptionHtml
    sourceBranch
    targetBranch
    state
    approved
    webUrl
    project {
      id
      fullPath
    }
    author {
      id
      username
      name
      avatarUrl
    }
    reviewers {
      nodes {
        id
        username
        name
        avatarUrl
      }
    }
    diffStats {
      path
      additions
      deletions
    }
    headPipeline {
      id
      status
      ref
      sha
      stages {
        nodes {
          id
          name
          status
          jobs {
            nodes {
              id
              name
              status
            }
          }
        }
      }
    }
    """
}
