---
name: create-ticket
description: Find or create the Trello card for a piece of Robotalia work, give it a Description and Acceptance criteria, move it to In progress and check it is assigned to the signed-in Trello user. Use at the start of any task, feature, fix or step, before writing code, even if Trello is not mentioned - for example "let's work on…", "start on…", "empiezo con…", "vamos con…" - and whenever the user asks to create, find or start a ticket or card.
argument-hint: "<what you are about to work on>"
---

Get the Trello card ready for this work: $ARGUMENTS

Every piece of work has exactly one card, and it is in **In progress** while the work happens. If
you don't know what the work is, ask. This skill only handles the card: do not start the task
itself unless the user also asked for it.

## 1. Find the board
Find the board named "Robotalia" with the Trello MCP tools (`trelloSearch`, `search_boards`), then
read its lists (`trelloReadList`, `list_by_board`). Match list names ignoring case. Never write
the board's link or IDs into a file in this repo, which is public. If the Trello tools are not
available or a list is missing, say so and stop.

## 2. Look for the card first
A duplicate card splits the history of a task, so search properly before creating one:
- `trelloSearch` `search_cards`, limited to this board, with a few different keywords. Card names
  are in English, so translate the request if it is in another language.
- Also read the board's open cards (`trelloReadCard`, `list_by_board`; follow the pages). Search
  matches words, not meaning, and the card may be worded differently.

| What you find | What to do |
|---|---|
| One card that is clearly this work | Use it (step 4) |
| Several that could be it, or one that only partly covers it | Show them with their lists and ask |
| Only a card in Done, or an archived one | Ask: reopen it, or make a new one |
| A card already in Review | Say so and ask before moving it back |
| Nothing | Create it (step 3) |

When you ask, stop there and change nothing until the user answers.

## 3. Create the card
Create it directly in **In progress** (`trelloWriteCard`, `create`). Name it in English in the
board's style, with an area or day prefix when one fits ("Dashboard: …", "Integration: …"). Write
the description in English with this layout:

```
**Description:**
<what changes and why, in 1–4 sentences, and where in the app>

**Acceptance criteria:**
- <an outcome someone can check>
- <another one>
- Specs cover the change; RuboCop and CI are green.
- Flow: branch → PR → CI + Claude review → merge → card to Done.
```

Draft the criteria from the request, `CLAUDE.md`, `docs/PLAN.md` and, when it helps, the code the
task touches. Each one should be something a reviewer can answer yes or no to: "an empty filter
result shows —", not "handles edge cases". Do not add scope the user did not ask for. If the work
changes no code (an account setting, a LinkedIn edit), leave out the last two lines.

## 4. Prepare an existing card
Read it (`trelloReadCard`, `get`). It needs both sections, below one another as in step 3.
- `update` replaces the whole description, so send the existing text along, unchanged. Text with
  no heading is the description: put `**Description:**` above it.
- Add only what is missing. If both sections are there, do not rewrite them. If they no longer
  match what the user is asking for, point it out and ask.

Then move it to **In progress** (`trelloWriteCard`, `move`), unless it is already there.

## 5. Check the assignee
Every card must be assigned to the board owner, who is the signed-in Trello user. Get that user with
`trelloReadMember`, `get_me`, then look for the same member id in `list_by_card`. The Trello MCP has
no action that adds a member to a card; a board automation (Butler rule) does it, and can take a few
seconds. If the user is missing, check once more, then report the card as **not assigned** and ask
them to assign it and to check the rule: "when a card is added to the board, add the board owner to
the card". Do not report the assignment as done without seeing it. This repo is public, so never
write the user's name, handle or member id into a file in it.

## 6. Report
Keep it short: whether the card was found or created, the list it moved from and to, its link,
whether the user is assigned, and the acceptance criteria. Say which criteria or sections you
wrote, so the user can correct them.

## Rules
- Cards follow the repo's privacy rules: no real account figures, broker details, credentials,
  strategy logic or TradingView data.
- Touch only this task's card.
- Later moves (Review when the pull request opens, Done when it is merged) are in `CLAUDE.md`.

## Dry run
If the request says "dry run", do all the reading but call no Trello tool that writes. Instead,
write `trello_plan.md` (where the request says) with the decision, then each write you would make:
action, card name, list it is in now, target list and the complete description. If you would ask
the user something first, write the question and list no writes. Say what you could not verify.
