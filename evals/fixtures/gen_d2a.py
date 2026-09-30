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


if __name__ == "__main__":
    main()
