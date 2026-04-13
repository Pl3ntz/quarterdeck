# Patterns Applied

This document explains the patterns and techniques behind Quarterdeck. Each pattern was researched, validated with multiple sources, and tested in production.

---

## 1. Structured Communication (Inspired by the Golden Circle)

**Origin:** Simon Sinek — "Start with Why"

**Concept:** Communicate in the order impact → approach → result. Instead of starting with the "what" (found 3 bugs), start with the "why" (the system had a data loss risk).

**How we apply it:** Every agent ends with a `### SUMMARY` that flows naturally in this order:
1. What's the impact on the system/business
2. How it was analyzed/approached
3. What was found/delivered with concrete numbers

**Why it works:** The Captain understands the importance before the technical detail. They can stop reading at any point and already have enough context to decide.

---

## 2. Squad Model (Inspired by Spotify Squads)

**Origin:** Spotify's organizational model adapted for AI agents

**Concept:** Instead of a rigid hierarchy (Tier 1/2/3), organize by **function** in autonomous squads:
- **Planning & Design** — think before building
- **Quality Gate** — validate without modifying (read-only, always parallel)
- **Implementation** — write code (with zone assignment)
- **Operations** — keep the system running
- **Intelligence** — research and document

**Why it works:** Each squad has different rules. Quality Gate always runs in parallel because it's read-only. Implementation needs file zones to avoid conflicts. This separation is impossible with a generic hierarchy.

---

## 3. Crawler Protocol (Inspired by Web Crawlers)

**Origin:** Fan-out/fan-in pattern from web crawlers + wave execution from parallel computing

**Concept:** Instead of executing agents one after another (A → B → C → D), group into parallel waves:
- Wave 1: reconnaissance (multiple agents explore simultaneously)
- Wave 2: planning (sequential, based on Wave 1 results)
- Wave 3: validation (multiple reviewers in parallel)

**How we prevent conflicts:** Zone assignment — each agent that writes code receives an exclusive file zone. Two agents never edit the same file in the same wave.

**Why it works:** Reduces time by 40-60% for multi-agent tasks. 3 reviewers in parallel finish in the time of 1, not 3.

---

## 4. Ground Truth Protocol (Inspired by "Read Before Write")

**Origin:** Anthropic — "Effective Context Engineering for AI Agents" (2025)

**Concept:** Every agent must read existing code/configs BEFORE analyzing or recommending anything. Agents that assume code state hallucinate.

**Rules:**
1. Read before acting
2. Look for existing patterns in the project
3. Ask when in doubt — verify before asserting
4. Explain the reasoning behind each recommendation

**Why it works:** Eliminates recommendations based on assumptions. The agent adapts its suggestions to what the project ALREADY does, instead of proposing theoretical patterns.

---

## 5. Active Debate Protocol (Inspired by Red Team/Blue Team)

**Origin:** Military red teaming practice + adversarial machine learning approach

**Concept:** Strategic agents are not passive executors — they are **advisors that challenge decisions**:
- Search memory from previous sessions for historical context
- Challenge decisions when they identify conflicts with the past
- Present alternatives with clear trade-offs
- Flag patterns that caused problems before

**Why it works:** Prevents error repetition. If a pattern caused a bug before, the agent warns before repeating. Decisions are debated, not rubber-stamped.

---

## 6. Positive Instructions (Inspired by the "Pink Elephant Theory")

**Origin:** Ironic Process Theory (Daniel Wegner) + 16x Engineer research (2025)

**Concept:** Telling the model what NOT to do ("NEVER guess") can paradoxically increase the chance of the undesired behavior occurring. The alternative: positive instructions ("Always verify before asserting").

**How we apply it:** All agents use positive formulation:
- Instead of "NEVER assume" → "Always verify"
- Instead of "DO NOT guess" → "Ask when in doubt"
- Instead of "NEVER execute without approval" → "Present findings and wait for approval"

**Why it works:** LLMs respond better to clear instructions about what TO DO than to prohibitions about what NOT to do. Reduces ambiguity and improves consistency.

---

## 7. Context Engineering (Inspired by Anthropic 2025)

**Origin:** Anthropic — "Context Engineering" (2025, renamed from "Prompt Engineering")

**Concept:** It's not about writing longer prompts — it's about every token contributing to the desired behavior. High signal-to-noise ratio.

**How we apply it:**
- Agents have defined token budgets (200-800 tokens depending on type)
- Sections are ordered: Role → Ground Truth → Instructions → Output Format
- Tools are the minimum necessary (no blanket inheritance)
- Concrete examples (`<example>`) for output consistency

**Why it works:** Agents with lean, focused prompts produce more consistent outputs and consume fewer tokens.

---

## 8. Continuous Learning

**Origin:** Self-Improvement Protocol + Auto-Learning Protocol

**Concept:** The system learns from its own mistakes and successes:
- **Tips:** Success patterns extracted from sessions and saved to memory
- **Error Memory:** Errors detected automatically via hooks, resolutions logged, index consulted before retries
- **Debate Protocol:** Agents consult memory from previous sessions before recommending

**Why it works:** Instead of repeating the same mistakes, the system accumulates knowledge over time. An error corrected once is remembered forever.

---

## 9. Maker-Checker (Evaluator-Optimizer)

**Origin:** Banking dual-control pattern adapted for agents

**Concept:** For code changes, the agent that builds (maker) is different from the one that validates (checker):
```
tdd-guide (maker) → code-reviewer (checker) → PASS/FAIL
```

If the checker rejects, specific feedback goes back to the maker for retry (max 2x). If it fails after 2 retries, it escalates to the Captain.

**Why it works:** Prevents bugs from slipping through. The maker focuses on implementing; the checker focuses on finding problems. Different perspectives find problems that a single perspective would miss.

---

## 10. Explicit Hierarchy (Captain > PE > Agents)

**Origin:** Military chain of command adapted for AI orchestration

**Concept:** Three layers with clear responsibilities:
- **Captain:** Decides. Approves plans, directs work, chooses alternatives.
- **PE:** Orchestrates. Decomposes requests, spawns agents, synthesizes results, debates.
- **Agents:** Execute. Work within assigned scope, report to PE.

**Absolute rule:** Agents never act independently. Never override PE or Captain. The PE is the only one that synthesizes results from multiple agents.

**Why it works:** Eliminates ambiguity about who decides what. The Captain is never surprised by an unauthorized action.
