#!/bin/sh
set -eu

BUILD_DIR="${TMPDIR:-/tmp}/glabtouch-tests"
mkdir -p "$BUILD_DIR"

xcrun swiftc -parse-as-library \
  GlabTouch/Models/GitLabInstance.swift \
  GlabTouch/Models/MergeRequest.swift \
  GlabTouch/Models/Pipeline.swift \
  GlabTouch/Models/NotificationPayload.swift \
  GlabTouch/Services/GitLabAPI/GraphQLResponses.swift \
  GlabTouch/Support/GitLabBaseURLNormalizer.swift \
  GlabTouch/Models/Diff.swift \
  GlabTouchTests/ModelBehaviorTests.swift \
  -o "$BUILD_DIR/ModelBehaviorTests"

"$BUILD_DIR/ModelBehaviorTests"
