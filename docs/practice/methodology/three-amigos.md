---
title: Three Amigos
description: The Three Amigos collaboration pattern — how business, development, and testing roles work together before a story starts to reach shared understanding.
sources:
  - web-cucumber-bdd-overview-three-practices
  - web-monday-bdd-guide-what-is-behavior-driven-development
  - web-monday-bdd-guide-5-steps-to-implement-bdd-in-your-organization
  - web-bdd-living-documentation-aligning-stakeholders-through-collaboration
  - web-example-mapping-intro-who-should-come
---

# Three Amigos

"Three Amigos" names the minimum set of perspectives that must be present in a BDD discovery session: **business**, **development**, and **testing**. The name does not mean exactly three people — it means three *viewpoints* are represented. On larger teams, you might have five or six people covering these three angles.

The session happens **before** the story starts development. Not during sprint planning. Not after the developer has started coding. Before.

## The three roles and why each matters

### Business (Product Owner, Business Analyst)

The business perspective owns the *why* and the *what*. The product person knows what problem this feature solves, who is affected, and what outcomes they need. They are the source of business rules and edge cases that developers would not know to ask about.

Without this perspective: developers build what they think was intended, not what was actually needed. Bugs are discovered in review, not in conversation.

### Development (Developer, Architect)

The development perspective brings knowledge of technical constraints, existing system behavior, and implementation cost. Developers often identify missing information — "what happens if the user has no email address on file?" — because they have to handle every case in code.

Without this perspective: specifications are written without regard for technical feasibility or existing behavior. Scope is underestimated.

### Testing (QA Engineer, Tester)

The testing perspective thinks adversarially. Testers ask "what could go wrong?" and "what does this look like from the edge?" They surface negative cases, error paths, and boundary conditions that neither business nor development naturally think to cover.

Without this perspective: happy path scenarios dominate. Error handling and edge cases are discovered late, often in production.

## Timing: before the story starts

The Three Amigos session has one timing rule: it happens before the developer writes a line of code. In practice, this means:

- Run it during the sprint before the story is planned (refinement-driven approach)
- Or run it as the first activity when a story is pulled into a sprint, before any development begins
- Never run it after development has started — at that point you are writing scenarios to match code, not to drive code

!!! warning "After-the-fact Three Amigos"
    If a Three Amigos session happens after the developer has already built the feature, it is not BDD — it is documentation. The value of BDD comes from the conversation changing what gets built, not from the conversation describing what was built.

## Running a session

### Duration

A well-understood, well-sized story should be mappable in **25 minutes**. If the session runs longer, the story is probably too large or has too many open questions. Treat a long session as a signal: either slice the story or park it until the product person does more homework.

### Format

The [Example Mapping](example-mapping.md) technique gives a structured format for the session. Without that structure, Three Amigos sessions drift into general discussion. Example Mapping keeps the output concrete and visible.

### Who facilitates

Designate a facilitator — often the tester or a delivery lead — whose job is to ensure that everything said is captured. Conversations move fast. Questions and examples fly around the room. The facilitator's job is to slow things down enough that nothing is lost.

### Output

At the end of a Three Amigos session, the team should have:

- A shared understanding of what "done" looks like for this story
- A set of concrete examples that cover the main business rules and edge cases
- A list of open questions that need answers before development can start
- (Optionally) a draft Gherkin scenario or two, if the team finds it useful

The output is not required to be a Gherkin file. It can be index cards, a Miro board, or bullet points. The shared understanding is the deliverable.

```gherkin
# Example output from a Three Amigos session on "user suspension"
Feature: Account suspension

  Rule: Suspended accounts cannot log in

    Example: Suspended user is denied access at login
      Given Alice's account has been suspended
      When she attempts to log in with valid credentials
      Then she sees an error message explaining the suspension
      And she is not granted access to the application

    Example: Suspension takes effect immediately
      Given Alice is currently logged in
      When an administrator suspends her account
      Then her active session is terminated within 30 seconds
```

## When the product owner is unavailable

Product owners are often busy. A Three Amigos session without the business perspective produces technically coherent specifications that may miss business intent. Options when the product owner cannot attend:

- Reschedule. A 25-minute session is worth protecting.
- Use a proxy: a business analyst or another product person who knows the domain well enough to make binding decisions.
- Run the session anyway with development and testing, and explicitly flag every rule as "unconfirmed" — then get product sign-off on the draft Gherkin before development starts.

!!! tip "Asynchronous review"
    For teams where scheduling is genuinely difficult, draft the Gherkin scenarios first and send them to the product owner for async review. The review conversation often surfaces the same misunderstandings the session would have caught. It is slower but better than no review at all.

## Remote Three Amigos

Remote sessions work well when the team uses a structured format. Options:

- **[Example Mapping](example-mapping.md) on Miro or FigJam** — digital sticky notes map directly to the card system (yellow story, blue rule, green example, red question)
- **Shared Google Doc** — one person types, others comment in real time; works for smaller stories
- **Video call + physical cards** — one person holds up cards to the camera; surprisingly effective

The key constraint for remote sessions: someone must own the document and ensure that every example and question raised in conversation gets written down before moving on.

## Scaling to multiple teams

In organizations with multiple teams contributing to a shared product, the Three Amigos model scales by making vocabulary explicit:

- [Custom parameter types](../../gherkin/reference/custom-parameter-types.md) encode shared vocabulary in code, so teams use the same terms
- Shared step definitions live in a common package, preventing vocabulary drift
- A vocabulary review process (who approves new step patterns) prevents synonym sprawl

The deeper challenge at scale is that "three amigos" becomes "three groups of people, each with internal alignment to achieve first." Teams that run their own internal Three Amigos before cross-team sessions tend to arrive more prepared.

## The goal: shared understanding, not a meeting

The Three Amigos pattern is not about holding a meeting. It is about ensuring that three perspectives — business intent, technical constraint, and adversarial testing — have been applied to a feature before anyone writes code. The meeting is the mechanism; shared understanding is the goal.

When a team has genuinely shared understanding of a story, the feature file that results is obvious. When they do not, the feature file is either wrong or so abstract it cannot be automated.

## Cross-references

- [Example Mapping](example-mapping.md) — the structured technique for running a Three Amigos session
- [Discovery to Automation](discovery-to-automation.md) — how Three Amigos fits into the three phases
- [BDD Overview](bdd-overview.md) — why the collaboration aspect gets lost and how to preserve it
