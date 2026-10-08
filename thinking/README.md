# Thinking

One thinking partner that finds the real question before you spend a project on the wrong one. It interviews you on a decision one question at a time, widens a brainstorm that has narrowed to one idea, and checks a plan or report against what you're actually deciding.

## The Team

| Agent | What they do | Deliverables |
|-------|--------------|--------------|
| `@thought_partner` *(thinking)* | Asks the questions that sharpen what you're really deciding. Ships with the `grill-me` and `broaden-options` skills | One-page decision brief, a project request ready to paste, best 3 options each with a cheap test, the riskiest assumption and how to check it |

The start view of any agent named exactly `thought_partner` shows six starter requests under **Think it through**, **Brainstorm** and **Pressure-test**, however the agent was registered. Keep the name exact.

## Install

```bash
clawmeets agent-team register https://<your-server>/templates/thinking/setup.json
clawmeets start
```

## Example Requests

- **Grill me on a decision I keep putting off.** "Grill me: [Decision: should I hire my first salesperson or keep selling myself for another quarter?]. One question at a time, build on my answers, and end with a one-page brief: what I'm really deciding, my current bet, and what would make me bet the other way."
- **Frame a research project before I start it.** "I'm about to ask the team to [Research: compare 10 CRMs]. Grill me first so the project ends in a recommendation for my decision, not a comparison table. Finish with a brief I can paste in as the project request."
- **I only have one idea, so widen it.** "Brainstorm with me: [Problem: churn is 8% a month] and all I can think of is [Current idea: discounts]. Ask for my ideas first, then go wide across angles I haven't tried. Cut to the best 3, each with the cheapest test I could run this week."
- **All my options look the same.** "Brainstorm with me: my options for [Goal: launching] are [Options: a blog post, a Product Hunt launch, a newsletter], and they feel like the same idea. List the assumptions they share, flip each one, and show me options that are actually different."
- **Find the assumption I'm most likely wrong about.** "Here's a plan I already like: [Plan: paste it]. Name the one assumption most likely to be wrong, and the cheapest way to check it before I commit."
- **Check a plan or report against what I'm deciding.** "I'm deciding [Decision: whether to expand to a second city]. Here's the [Plan or report: paste it]. Tell me where it doesn't serve that decision, for example researching 10 options when my decision is yes or no."
