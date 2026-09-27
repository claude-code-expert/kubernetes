#!/usr/bin/env python3
"""검증 실행 로그로 실습 가이드의 실행 결과 블록을 채운다.

    python3 src/fill_outputs.py <검증 로그>

로그는 "##@ 키" 줄로 구간이 나뉘고, 각 구간에는 "$ 명령" 줄과 그 출력이 들어 있다.
src/lab-guide.src.html 의 OUT 자리표시자(@@OUT:키@@)를 해당 구간의 출력(명령 줄 제외)으로 바꾼다.
"""
import html
import re
import sys
from pathlib import Path

SRC = Path(__file__).parent / "lab-guide.src.html"

# 너무 긴 출력은 앞부분만 두고 줄였음을 표시한다
TRIM = {
    "3-2a": lambda t: t.split("NOTES:")[0] + "NOTES:\nkube-prometheus-stack has been installed. Check its status by running:\n  kubectl --namespace monitoring get pods -l \"release=kps\"\n…(Grafana 비밀번호 조회 안내, 줄임)",
    "7-1": lambda t: "…(6분 동안 진행 표시, 줄임)\n" + t,
    "10-3": lambda t: re.sub(r"(TEST SUITE: None)\n", r"\1\n…(안내문, 줄임)\n", t),
}


def sections(log: str) -> dict:
    out, key, buf = {}, None, []
    for line in log.splitlines():
        m = re.match(r"^##@ (\S+)", line)
        if m:
            if key:
                out[key] = buf
            key, buf = m.group(1), []
            continue
        if key and not line.startswith("$ "):
            buf.append(line.rstrip())
    if key:
        out[key] = buf
    return {k: "\n".join(v).strip("\n") for k, v in out.items()}


def main():
    log = Path(sys.argv[1]).read_text(encoding="utf-8")
    sec = sections(log)
    text = SRC.read_text(encoding="utf-8")
    missing = []

    def repl(m):
        k = m.group(1)
        if k not in sec:
            missing.append(k)
            return m.group(0)
        t = TRIM.get(k, lambda x: x)(sec[k])
        return html.escape(t, quote=False)

    n = len(re.findall(r"@@OUT:", text))
    text = re.sub(r"@@OUT:([\w-]+)@@", repl, text)
    SRC.write_text(text, encoding="utf-8")
    print("placeholders", n, "missing:", missing)


if __name__ == "__main__":
    main()
