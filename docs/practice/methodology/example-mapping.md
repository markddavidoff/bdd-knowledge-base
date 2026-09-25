---
title: Example Mapping
description: A structured card-based technique for running BDD discovery sessions — turns vague user stories into concrete, agreed examples ready for Gherkin.
sources:
  - web-example-mapping-intro-how-it-works
  - web-example-mapping-intro-instant-feedback
  - web-example-mapping-intro-thinking-inside-the-time-box
  - web-example-mapping-intro-benefits
  - web-example-mapping-intro-known-unknowns
  - web-example-mapping-intro-who-should-come
  - web-example-mapping-intro-so-when-do-we-write-gherkin
  - web-example-mapping-intro-how-often-should-we-do-this
  - web-example-mapping-intro-but-my-team-is-distributed
  - web-example-mapping-intro-some-final-tips
---

# Example Mapping

Example Mapping is a structured discovery technique invented by Matt Wynne at Cucumber. It uses colored index cards to capture four distinct types of information as a team discusses a user story, producing a visual map of the story's scope, rules, examples, and open questions.

It is the most widely used format for [Three Amigos](three-amigos.md) sessions.

## The card system

Four card colors, four types of information:

| Color | Represents | Content |
|---|---|---|
| Yellow | **Story** | The user story being discussed — one per session |
| Blue | **Rule** | An acceptance criterion or business constraint |
| Green | **Example** | A concrete scenario illustrating a rule |
| Red | **Question** | Something nobody in the room can answer |

### How they relate

A yellow story card sits at the top. Under it, blue rule cards spread across the table — one per business rule. Under each rule, green example cards illustrate how that rule behaves in specific situations. Red question cards float to the side: open items that need follow-up before the story can start.

## Running a session

### Before you start

Bring the story in writing. The product person should be able to summarize in one sentence what the story is trying to accomplish. If they cannot, that is useful information — the story needs more definition before it can be mapped.

Invite at minimum: one business person (product owner or BA), one developer, one tester. Others who can contribute domain knowledge or answer questions are welcome.

### The process

1. Write the story on a yellow card. Place it at the top.
2. Ask the product person: "What are the rules that govern this story?" Write each rule on a blue card. Place them across the table.
3. For each rule, ask: "Can you give me an example of this rule being satisfied?" Write concrete examples on green cards. Place them under the relevant rule.
4. When disagreement or confusion arises — write the question on a red card and move on. Do not let unknown answers block the conversation.
5. Keep going until everyone agrees the story is understood, or you run out of time.

!!! example "What a completed map looks like"
    A well-mapped story has: one yellow card at top; three to five blue rule cards; two to four green example cards per rule; zero to three red question cards. If you have more than five blue cards, the story is probably too large to deliver in one sprint. If you have more than three red cards, the story needs more product research before development starts.

### Duration

A well-sized story should map out in **25 minutes** for an experienced team. Use this as a diagnostic:

- Session under 25 minutes: the story is well understood and appropriately sized
- Session hits 25 minutes with a full map: ready to vote on whether to proceed
- Session runs over 25 minutes: the story is too large, has too many unknowns, or the team needs more practice with the technique

After 25 minutes, Cucumber's recommended practice is a quick thumb vote: up (ready), sideways (unsure), down (not ready). Even with open questions, the group may decide the questions are minor enough to resolve during development.

### When to stop

Stop when you reach any of these:

- Everyone in the room agrees they understand what "done" looks like
- You run out of time (25 minutes) and decide to proceed despite remaining questions
- The story is clearly too large — take a yellow card and write a sliced sub-story for the backlog

## Reading the map

The visual pattern of the map is feedback about the story's health:

- **Many red (question) cards**: the story has too many unknowns. Park it and get answers first.
- **Many blue (rule) cards**: the story is large and complex. Consider slicing.
- **A rule with many green (example) cards**: that rule may be over-complex. Are there multiple rules disguised as one?
- **Rules with no examples**: the rule might be so obvious everyone agrees. That is fine — not every rule needs examples.

!!! tip "Unknown unknowns become known unknowns"
    The most valuable outcome of Example Mapping is discovering what you do *not* know. Capturing a question on a red card transforms an unknown unknown (a surprise during development) into a known unknown (a tracked question to answer before coding). This alone often justifies the session.

## From Example Map to feature file

Example Mapping and Gherkin authoring are separate activities. During the session, stay low-tech — index cards or sticky notes. Do not open an IDE during the session; it slows down the conversation.

After the session, the developer and tester draft Gherkin scenarios from the green example cards. The product owner reviews the draft and answers: "Is that how I would have written it?" This check tests whether the session actually transferred understanding.

```gherkin
# Drafted after an Example Mapping session on "account suspension"
# Green card: "Alice logs in while suspended → denied, sees message"

Feature: Account suspension
  Rule: Suspended accounts cannot log in

    Example: Suspended user sees an explanation at login
      Given Alice's account has been suspended by an administrator
      When she attempts to log in with valid credentials
      Then she sees "Your account has been suspended. Contact support to appeal."
      And she remains on the login page
```

Red question cards become backlog items or answers sought from domain experts. Blue rule cards map to `Rule:` keywords in the feature file. Green example cards map to `Example:` scenarios.

## Questions as backlog items

Questions that remain open after a session should not be forgotten. Options:

- Add them to the story ticket as comments or sub-tasks
- Create separate discovery tasks for research that needs to happen before development
- Schedule a follow-up Example Mapping session once answers are available

!!! warning "Never start development with open red cards"
    If there are unanswered questions (red cards) about the core behavior of the story, do not start coding. Questions become assumptions in code. Assumptions become bugs.

## Remote Example Mapping

For distributed teams, the physical card system moves well to digital tools:

- **Miro or FigJam**: virtual sticky notes in four colors; supports real-time collaboration and camera-off participation
- **Google Slides or Sheets**: colored cells or slides; lower fidelity but accessible without a Miro account
- **Dedicated tools**: Cucumber's own Example Mapping tool at mapping.cucumber.io

The most important constraint for remote sessions: designate one person to ensure every example and question that is raised verbally gets captured on a card. In person, people naturally write things down. Remote, conversations disappear if nobody captures them.

## How often to run sessions

Short, frequent sessions outperform infrequent long sessions:

- **Recommended cadence**: every other day, one story per session, 25 minutes
- **Anti-pattern**: weekly 2-hour batch sessions covering multiple stories; energy drains and quality drops
- **Product owner time**: respect their calendar by running predictable, short sessions they can plan around

## Cross-references

- [Three Amigos](three-amigos.md) — who should be in the room
- [Discovery to Automation](discovery-to-automation.md) — where Example Mapping fits in the BDD cycle
- [BDD Overview](bdd-overview.md) — the Discovery phase context
- [Specification by Example](specification-by-example.md) — the broader framework Example Mapping supports
