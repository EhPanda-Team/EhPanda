---
type: retrospective-learnings
recorded: 2026-10-15
source: session-decisions-code-and-retained-verification
---

# Lessons from this session

> **Image evidence availability:** Image files were removed from this repository history at the owner's request. Screenshot descriptions, filenames and earlier visual checks below are historical records, not currently available image evidence. Written findings, measurements and source artifacts remain; visual review requires fresh captures.

## Durable decisions are part of delivery

The owner had to ask twice for GSD records, clarifying that **all session decisions** were required.
Ignored verification notes and a proposal page were insufficient. Record accepted choices, later
replacements and still-open choices as they occur, and update the tracked entry point before handoff.
Source: D54 and the source Git history, where only the scroll-edge inventory had changed under `.planning`.

## Native bars are controlled by navigation ownership

Disabling vertical toolbars on nested Home stacks propagated through native controllers and moved
tabs to the bottom. Keep pushed destinations' hosts against the display edge, split only Home root,
and attach global refresh to the edge-reaching host. Native compression is space-driven; failed
scroll-collapse experiments are not evidence that such behavior exists.
Source: D18/D21–D23, evidence/hinge.md and evidence/side-tabs.md.

## Geometry, capability and presentation are separate decisions

Window geometry and asymmetric safe areas determine physical pane sizes. Device capability gates
owner-requested automation; it must not replace measured geometry. A content arrangement does not
own navigation or automatically reverse sheet placement. Native split/inspector screenshots do not
prove exact hinge alignment. A stable presentation owner and retained navigation state matter during
rotation/folding. Source: D01–D03/D17/D26/D31–D33/D51, evidence/arrangement.md and proposal/PROPOSAL.md.

## A sheet's size class does not describe every visual proportion

The iPad NewDawn form sheet measured 580 pt wide but reported compact width. The owner selected 50%
after a real 60/50 comparison. Canvas width expresses the intended proportion without reintroducing
an iPad geometry assumption. Source: D28 and evidence/orientation-final.md.

## Slider editing callbacks are not a complete touch lifetime

A held native Slider emitted multiple begin/end editing pairs without its frame moving. Native
GestureState tracks the complete touch for preview lifetime while Slider still owns its value and
accessibility behavior. Source: D29 and evidence/reader-followup.md.

## Test cleanup is visible product behavior to the owner

Fixture mode intercepts HTTP(S), so a leftover test launch can make every real reader image fail.
After captures, terminate/relaunch normally and inspect for test flags; do not hand back a fixture
process. Also restore or explicitly agree on simulator accessibility settings: Reduce Motion can
hide a correctly implemented transition. Source: D37/D43 and evidence/orientation-final.md.

## Correct test drivers without weakening assertions

Duo bars and displays differ from classic navigation. Scope queries to the reader, support actual
native identifiers, choose unobstructed hit targets, and verify cover/inner viewport mapping. A passing
retry with mutated settings proves nothing about the original failing state. Cold-pose checks and
static screenshots must not be promoted into claims of continuous resize or retained state.
Source: D06/D44–D46 and evidence/reader-initial.md.

## Skills are complementary, with an SDK check

The requested Xcode resizability guidance covers local-window adaptation; the Duo skill adds hinge,
reserved-region, toolbar and arrangement details. Use both for this task. Check local SDK availability
and spelling: arrangement is 27.1 while this app also supports 27.0, and the installed toolbar API
uses `toolbarMinimizationBehavior`. Do not substitute a generic visual-design skill after the owner
has specified these sources. Source: D10/D24/D33/D47/D49.
