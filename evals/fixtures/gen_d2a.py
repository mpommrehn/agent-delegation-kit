#!/usr/bin/env python3
"""Generator for the D2a fixtures (resume split and cap-hit). Synthetic data
only. Run from anywhere: `python evals/fixtures/gen_d2a.py`. It writes
d2a-*.jsonl and d2a-*.meta.json beside itself, and agents/ definitions used
only by the tests. The output is committed; rerun to regenerate.
"""

import json
import os

HERE = os.path.dirname(os.path.abspath(__file__))
MODEL = "claude-sonnet-5"
_n = [0]


def nid(prefix):
    _n[0] += 1
    return "%s_%04d" % (prefix, _n[0])


def user(text):
    return {"type": "user", "message": {"role": "user", "content": text}}


def meta_user(text, origin=None):
    rec = {"type": "user", "isMeta": True, "message": {"role": "user", "content": text}}
    if origin is not None:
        rec["origin"] = origin
    return rec


def resume(text="Continue."):
    return meta_user(text, {"kind": "coordinator"})


def reminder():
    """The hand-back system reminder: isMeta, string content, no origin."""
    return meta_user("Reminder: deliver your final report with SubagentHandback.")


def assistant(mid, blocks):
    return {
        "type": "assistant",
        "message": {"role": "assistant", "id": mid, "model": MODEL, "content": blocks},
    }


def tool(name="Bash", inp=None, tid=None):
    return {
        "type": "tool_use",
        "id": tid or nid("toolu"),
        "name": name,
        "input": inp if inp is not None else {"command": "ls"},
    }


def result(tid):
    return {
        "type": "user",
        "message": {
            "role": "user",
            "content": [{"type": "tool_result", "tool_use_id": tid, "content": "ok", "is_error": False}],
        },
    }


def turn(parallel=1, split=False):
    """One turn: `parallel` tool calls in one message id. With split, the
    message is written as a text line and then a tool-call line sharing the
    id (the way the real transcripts write it). Returns the lines: the
    assistant line(s) and one tool_result line per call."""
    mid = nid("msg")
    calls = [tool() for _ in range(parallel)]
    lines = []
    if split:
        lines.append(assistant(mid, [{"type": "text", "text": "working"}]))
        lines.append(assistant(mid, calls))
    else:
        lines.append(assistant(mid, calls))
    lines.extend(result(c["id"]) for c in calls)
    return lines


def turns(n, **kw):
    out = []
    for _ in range(n):
        out.extend(turn(**kw))
    return out


def handback():
    return [assistant(nid("msg"), [tool("SubagentHandback", {"message": "done"})])]


def text_reply():
    """A text-only reply: a message with no tool_use, ends the agent's loop."""
    return [assistant(nid("msg"), [{"type": "text", "text": "All done."}])]


def write(name, records, meta):
    with open(os.path.join(HERE, name + ".jsonl"), "w", encoding="utf-8", newline="\n") as fh:
        for r in records:
            fh.write(json.dumps(r) + "\n")
    with open(os.path.join(HERE, name + ".meta.json"), "w", encoding="utf-8", newline="\n") as fh:
        fh.write(json.dumps(meta) + "\n")


EXEC = {"agentType": "executor"}
BRIEF = user("Do the task.")


def main():
    # ---- decision 1: segment split on a coordinator resume
    write("d2a-split-resume-after-cutoff",
          [BRIEF] + turns(2) + [resume()] + turns(1) + handback(), EXEC)
    write("d2a-split-resume-after-handback",
          [BRIEF] + turns(1) + handback() + [resume()] + turns(1) + handback(), EXEC)
    # the reminder sits mid-segment: if it split, segment 1 would lack a hand-back
    write("d2a-split-reminder-no-split",
          [BRIEF] + turns(1) + [reminder()] + turns(1) + handback(), EXEC)
    write("d2a-split-notif-no-split",
          [BRIEF] + turns(1) + [meta_user("<task-notification/>", {"kind": "task-notification"})]
          + turns(1) + handback(), EXEC)

    # ---- decisions 2 to 4: cap-hit. cap5 is a test-only agent type with
    # maxTurns 5 (see agents/cap5.md), so the fixtures stay small.
    C5 = {"agentType": "cap5"}
    write("d2a-cap-exact", [BRIEF] + turns(5), C5)
    write("d2a-cap-below", [BRIEF] + turns(4) + handback(), C5)
    write("d2a-cap-handback-is-last-turn", [BRIEF] + turns(4) + handback(), C5)
    write("d2a-cap-two-handbacks",
          [BRIEF] + turns(4) + handback() + [resume()] + turns(4) + handback(), C5)
    write("d2a-cap-text-rounds",
          [BRIEF] + turns(3) + text_reply() + [resume()] + turns(3) + text_reply(), C5)
    write("d2a-cap-parallel", [BRIEF] + turns(3, parallel=2) + handback(), C5)
    write("d2a-cap-split-id", [BRIEF] + turns(5, split=True), C5)
    write("d2a-cap-split-id-below", [BRIEF] + turns(4, split=True) + handback(), C5)
    write("d2a-cap-two-cutoffs", [BRIEF] + turns(5) + [resume()] + turns(5), C5)
    # the resume marker removed: the same shape, but the resume line has no
    # origin key, so it is not a segment start. cap-hit must still fire twice.
    write("d2a-cap-no-marker", [BRIEF] + turns(5) + [meta_user("Continue.")] + turns(5), C5)
    write("d2a-cap-executor-60", [BRIEF] + turns(60), EXEC)
    # skip reasons
    write("d2a-cap-skip-unknown-type", [BRIEF] + turns(1) + handback(), {"agentType": "bad/type"})
    write("d2a-cap-skip-missing-file", [BRIEF] + turns(1) + handback(), {"agentType": "ghost"})
    write("d2a-cap-skip-no-maxturns", [BRIEF] + turns(1) + handback(), {"agentType": "nomax"})

    # ---- agent definitions for the tests (frontmatter only matters)
    os.makedirs(os.path.join(HERE, "agents"), exist_ok=True)
    defs = {"executor": 60, "scanner": 30, "reviewer": 40, "browser-checker": 25,
            "general-purpose": 100, "cap5": 5, "nomax": None}
    for name, n in defs.items():
        lines = ["---", "name: " + name, "model: sonnet"]
        if n is not None:
            lines.append("maxTurns: %d" % n)
        lines += ["---", "Test-only definition used by tests/run-tests.sh."]
        with open(os.path.join(HERE, "agents", name + ".md"), "w", encoding="utf-8", newline="\n") as fh:
            fh.write("\n".join(lines) + "\n")


if __name__ == "__main__":
    main()
