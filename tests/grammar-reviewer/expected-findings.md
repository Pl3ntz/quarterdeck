# Expected Findings — grammar-reviewer

30 errors across 8 categories. Agent should detect 90%+ with correct severity.

## Section 1: Spelling and Homophones (5 errors)

| # | Line | Wrong | Correct | Rule | Severity |
|---|---|---|---|---|---|
| 1 | 7 | occured | occurred | Double C, double R | CRITICAL |
| 2 | 7 | it's performance | its performance | Possessive "its" has no apostrophe | CRITICAL |
| 3 | 7 | effected | affected | "affect" = verb (influence); "effect" = noun | CRITICAL |
| 4 | 8 | definately | definitely | Rooted in "finite" | CRITICAL |
| 5 | 8 | looses it's | loses its | "lose" (misplace) vs "loose" (not tight); possessive "its" | CRITICAL |

## Section 2: British vs American Spelling (4 errors)

| # | Line | Wrong | Correct | Rule | Severity |
|---|---|---|---|---|---|
| 6 | 12 | programme | program | AmE spelling | MEDIUM |
| 7 | 12 | optimised | optimized | AmE: -ize not -ise | MEDIUM |
| 8 | 12 | centralise | centralize | AmE: -ize not -ise | MEDIUM |
| 9 | 12 | colour | color | AmE: -or not -our | MEDIUM |

Note: line 13 contains "analysed" → "analyzed" as an additional error.

## Section 3: Subject-Verb Agreement (5 errors)

| # | Line | Wrong | Correct | Rule | Severity |
|---|---|---|---|---|---|
| 10 | 17 | Everyone have | Everyone has | Indefinite pronoun = singular | HIGH |
| 11 | 17 | servers are down | servers is down... | "One of" = subject is "one" (singular) | HIGH |
| 12 | 18 | data shows | data show | "data" is plural in formal writing | HIGH |
| 13 | 18 | There is many | There are many | Verb agrees with postponed subject "problems" | HIGH |
| 14 | 19 | He don't | He doesn't | Third-person singular requires "doesn't" | HIGH |

## Section 4: Pronoun Case and Usage (3 errors)

| # | Line | Wrong | Correct | Rule | Severity |
|---|---|---|---|---|---|
| 15 | 23 | Me and him went | He and I went | Subject position requires nominative case | HIGH |
| 16 | 23 | Between you and I | Between you and me | Object of preposition requires objective case | HIGH |
| 17 | 24 | Contact...myself | Contact...me | Reflexive "myself" is nonstandard as object | MEDIUM |

## Section 5: Sentence Errors (4 errors)

| # | Line | Wrong | Correct | Rule | Severity |
|---|---|---|---|---|---|
| 18 | 28 | crashed, the database | crashed; the database | Comma splice: two independent clauses | HIGH |
| 19 | 28 | Because the tests failed. | (fragment) | Sentence fragment: no independent clause | HIGH |
| 20 | 29 | Running through the CI pipeline. | (fragment) | Sentence fragment: no subject | HIGH |
| 21 | 29 | was fast, however, it | was fast; however, it | Comma splice with conjunctive adverb | HIGH |

## Section 6: Dangling Modifiers and Parallel Structure (3 errors)

| # | Line | Wrong | Correct | Rule | Severity |
|---|---|---|---|---|---|
| 22 | 33 | Walking...rain started | Walking...I got caught | Dangling modifier: rain didn't walk | HIGH |
| 23 | 34 | reading, swimming, and to hike | reading, swimming, and hiking | Parallel structure: consistent gerunds | MEDIUM |
| 24 | 34 | both challenging and a reward | both challenging and rewarding | Parallel structure: matching adjectives | MEDIUM |

## Section 7: Punctuation (3 errors)

| # | Line | Wrong | Correct | Rule | Severity |
|---|---|---|---|---|---|
| 25 | 38 | well known author | well-known author | Compound adjective before noun requires hyphen | MEDIUM |
| 26 | 38 | two year old bug | two-year-old bug | Age compound adjective requires hyphens | MEDIUM |
| 27 | 39 | "the deploy failed". | "the deploy failed." | AmE: period inside quotation marks | MEDIUM |

## Section 8: Word Usage and Redundancies (3 errors)

| # | Line | Wrong | Correct | Rule | Severity |
|---|---|---|---|---|---|
| 28 | 43 | could of | could have | "of" is not "have" | CRITICAL |
| 29 | 43 | Irregardless | Regardless | "irregardless" is nonstandard | MEDIUM |
| 30 | 44 | revert back | revert | "revert" already means "go back"; redundancy | LOW |

## Section 9: Scope

The agent **MUST NOT** report errors in the Portuguese text in Section 9.
Any finding in that section is a false positive.

## Summary

| Category | Errors | Predominant severity |
|---|---|---|
| Spelling/Homophones | 5 | CRITICAL |
| British vs American | 4+ | MEDIUM |
| Subject-verb agreement | 5 | HIGH |
| Pronoun case | 3 | HIGH/MEDIUM |
| Sentence errors | 4 | HIGH |
| Modifiers/Parallel structure | 3 | HIGH/MEDIUM |
| Punctuation | 3 | MEDIUM |
| Word usage/Redundancies | 3 | CRITICAL/MEDIUM/LOW |
| **Total** | **30+** | — |
