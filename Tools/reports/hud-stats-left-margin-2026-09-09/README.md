# Explicit left margin on HUD counters

The user rejected the preceding zero-layout-padding attempt: curved icon silhouettes and the rounded backing still produced an ambiguous partial margin. A numeric zero inset did not establish a visually flush edge. That appearance is not accepted.

This revision chooses the user's permitted noticeable-margin option. Lives and money receive three times statPlatePadding before the icon: 9.3pt at minimum size. The background is visibly present to the left of each icon. The row's occupied width grows by the same two insets. Icon heights, dark fill, white live counters and gaps between the plates retain their previous behavior.

At minimum gameplay size, the separate rounded left cap is now obvious beside both the heart and coin stack. Native 1× color and grayscale views plus terrain scenes were inspected before enlargement. Text and icon readability pass familiar-agent review, and the margin is deliberately visible. The existing readability lab was rerun, with input hashes and density exports retained. The supplemental wide-row sheet uses the lab's transformations with sufficient column spacing.

Lesson: for a requested flush visual edge, inspect the combined icon silhouette and background; frame alignment alone can leave an unintended sliver. Here the user explicitly allowed a noticeable margin, so an approximately 9pt inset removes that ambiguity.

The first reused device-capture build contained a stale call-wave view after another workspace change; the diagnostic copy was refreshed from the current production view. This does not change the production call-wave source. Independent user acceptance remains unmeasured.

Signed game and refreshed diagnostic builds passed. The iPhone 15 Pro gameplay capture was inspected at native size: there is an obvious dark left cap before both heart and coins, with the separate gaps intact. All readouts remain clear. PASS in these captured conditions. The regular game was installed and relaunched; the disposable capture app was removed. Installation, launch and cleanup records are saved alongside the screenshots. The user has not yet reviewed this revision.
