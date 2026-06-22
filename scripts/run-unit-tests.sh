#!/bin/sh
set -eu

BUILD_DIR="${TMPDIR:-/tmp}/glabtouch-tests"
mkdir -p "$BUILD_DIR"
mkdir -p "$BUILD_DIR/ModuleCache"

MARKDOWN_WEBVIEW_SOURCE=""
if [ -f GlabTouch/Views/MergeRequests/MarkdownWebView.swift ]; then
  MARKDOWN_WEBVIEW_SOURCE="GlabTouch/Views/MergeRequests/MarkdownWebView.swift"
fi

xcrun swiftc -parse-as-library \
  -module-cache-path "$BUILD_DIR/ModuleCache" \
  GlabTouch/Models/GitLabInstance.swift \
  GlabTouch/Models/MergeRequest.swift \
  GlabTouch/Models/Pipeline.swift \
  GlabTouch/Models/NotificationPayload.swift \
  GlabTouch/Services/GitLabAPI/GraphQLResponses.swift \
  GlabTouch/Support/GitLabBaseURLNormalizer.swift \
  GlabTouch/Models/Diff.swift \
  $MARKDOWN_WEBVIEW_SOURCE \
  GlabTouchTests/ModelBehaviorTests.swift \
  -o "$BUILD_DIR/ModelBehaviorTests"

"$BUILD_DIR/ModelBehaviorTests"
