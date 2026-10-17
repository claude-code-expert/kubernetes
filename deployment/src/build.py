#!/usr/bin/env python3
"""src/*.html 조각을 순서대로 합쳐 ../slides.html 을 만든다.

셸(스타일·발표자 화면 스크립트)은 week-06/slides.html 에서 가져온다.
"""
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from script import write_script  # noqa: E402

SRC = Path(__file__).resolve().parent
OUT = SRC.parent / "slides.html"
SHELL = SRC.parents[2] / "week-06" / "slides.html"

ORDER = [
    "표지",
    "질문",
    "흔히 나오는 답",
    "배포 직후 에러가 났다",
    "되돌리고 싶다",
    "앞의 답들을 롤백 쪽에서 다시 보면",
    "배포 전략이란",
    "예시 서비스",
    "전체 그림",
    "오늘의 흐름",
    "진행 순서",
    "1부 준비",
    "손으로 배포하면",
    "테스트가 실패하면",
    "이미지는 작게",
    "latest를 쓰면",
    "태그도 바뀔 수 있다",
    "CI가 직접 apply하면",
    "밀어 넣기와 당겨 가기",
    "깃옵스 4원칙",
    "CI는 커밋까지만",
    "Argo CD 셋업",
    "Application 설정값",
    "쿠버네티스에는 릴리스가 없다",
    "6.4 예제의 함정",
    "롤아웃은 template이 바뀔 때만",
    "1부 정리",
    "2부 배포 전략",
    "전략 다섯 가지",
    "쿠버네티스가 기본으로 주는 것",
    "3부 같은 배포, 세 번",
    "조건",
    "1회차 롤링",
    "롤링 설정 한눈에",
    "maxSurge와 maxUnavailable을 바꾸면",
    "롤링 중에는 두 버전이 섞인다",
    "섞여도 괜찮으려면",
    "1회차 결과",
    "1회차 타임라인 뜯어보기",
    "1회차 되돌리기",
    "실패해도 되돌리지 않는다",
    "2회차 블루/그린",
    "2회차 결과",
    "2회차 타임라인 뜯어보기",
    "블루는 언제 내리나",
    "Argo Rollouts 셋업",
    "블루/그린 설정값",
    "블루/그린 직접 돌려 보면",
    "3회차 카나리",
    "베이스라인",
    "무엇을 재나",
    "카나리는 어디서 나누나",
    "얼마나 기다리나",
    "카나리 설정값",
    "트래픽 나누기 설정",
    "AnalysisTemplate 설정값",
    "Argo Rollouts로 베이스라인 비교",
    "카나리 직접 돌려 보면",
    "3회차 결과",
    "3회차 타임라인 뜯어보기",
    "같은 버그, 세 번의 결과",
    "롤링 업데이트가 끊기는 이유",
    "끊기지 않게 하려면",
    "A/B 테스트는 카나리가 아니다",
    "기능 플래그였다면",
    "컬럼 추가는 세 번에 나눠서",
    "데모",
    "3부 정리",
    "7장 리전 이야기",
    "4부 되돌리기",
    "되돌리는 방법 세 가지",
    "Argo CD에서 되돌릴 때",
    "되돌아갈 곳이 남아 있나",
    "롤백해도 데이터는 안 돌아간다",
    "헬름으로 묶어서 되돌리기",
    "롤백 체크리스트",
    "롤백도 미리 연습한다",
    "전체 그림 다시 보기",
    "처음 질문으로",
    "토론",
    "참고 자료",
    "마무리",
]

EXTRA_CSS = """
  pre.code{background:#06101d;border:1px solid var(--line);border-radius:12px;padding:16px 20px;
    font:16px/1.5 ui-monospace,SFMono-Regular,Menlo,monospace;white-space:pre;color:#c8d9e7;overflow:hidden;margin:0}
  pre.code .k{color:#73b7ff} pre.code .c{color:#69849c} pre.code .y{color:#ffe08a}
  .slide ol{margin-top:6px}
  .slide p.note{font-size:16px;line-height:1.5;color:var(--dim);margin:0;right:64px}
  .slide ol li{padding-left:6px} .slide ol li::before{display:none}
"""


def sections(text):
    return re.findall(r'(  <section class="slide[^"]*" data-t="([^"]+)">.*?</section>\n)', text, re.S)


def main():
    pool = {}
    for f in sorted(SRC.glob("*.html")):
        for body, title in sections(f.read_text()):
            pool[title] = body

    missing = [t for t in ORDER if t not in pool]
    if missing:
        raise SystemExit(f"없는 장표: {missing}")

    out = []
    for n, title in enumerate(ORDER):
        body = pool[title]
        body = body.replace('class="slide on"', 'class="slide"')
        if n == 0:
            body = body.replace('class="slide"', 'class="slide on"', 1)
        out.append(f"  <!-- {n + 1} -->\n{body}\n")

    shell = SHELL.read_text()
    head = shell[: shell.index("</style>")]
    head = re.sub(r"<title>.*?</title>", "<title>7주차 · 릴리스 파이프라인</title>", head)
    tail = shell[shell.index('  <div id="toc">'):]
    html = head + EXTRA_CSS + "</style>\n</head>\n<body>\n\n<div id=\"wrap\">\n  <div id=\"pg\"></div>\n\n" + "".join(out) + tail
    OUT.write_text(html)
    write_script(out, SRC.parent / "script.md")
    print(f"{OUT.name}: {len(ORDER)}장, 안 쓰는 조각 {len(set(pool) - set(ORDER))}개")


if __name__ == "__main__":
    main()
