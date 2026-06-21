import Foundation

enum GraphQLQueries {
    static func mergeRequests(filter: String) -> String {
        """
        query {
          currentUser {
            \(filter)(state: opened, first: 20) {
              nodes {
                id
                iid
                title
                description
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
              }
            }
          }
        }
        """
    }

    static func filterFieldName(for filter: MergeRequestListViewModel.MRFilter) -> String {
        switch filter {
        case .assignedToMe: "assignedMergeRequests"
        case .createdByMe: "authoredMergeRequests"
        case .reviewRequested: "reviewRequestedMergeRequests"
        }
    }
}
