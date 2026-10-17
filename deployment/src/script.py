"""빌드된 장표 조각에서 발표 스크립트(script.md)를 만든다.

발화 속도는 공백 제외 분당 260자(공백 포함 약 330자)로 잡는다.
"""
import html
import re

CPM = 260
FIXED = {"데모": 300, "토론": 600}
# 청중 답을 기다리는 장표: 원고 시간에 더할 초
PAUSE = {"질문": 90, "배포 직후 에러가 났다": 30, "같은 버그, 세 번의 결과": 60, "3부 정리": 60}
MIN_SEC = 20

STATIONS = [
    ("표지", "서론", 7),
    ("1부 준비", "1부 준비", 17),
    ("2부 배포 전략", "2부 배포 전략 한눈에", 3),
    ("3부 같은 배포, 세 번", "3부 같은 배포, 세 번", 48),
    ("4부 되돌리기", "4부 되돌리기", 4),
    ("처음 질문으로", "정리", 1),
    ("토론", "토론", 10),
]

SKIP = [
    "깃옵스 4원칙",
    "롤링 업데이트가 끊기는 이유",
    "끊기지 않게 하려면",
    "7장 리전 이야기",
    "헬름으로 묶어서 되돌리기",
    "롤백도 미리 연습한다",
]

FLOW = [
    "**서론**: 제일 중요한 게 뭘까 → 흔한 답 → 금요일 6시 배포 사고 → 일단 되돌리고 싶다 → 처음부터 되돌리기 쉽게 내보내는 게 배포 전략",
    "**1부 준비**: 돌아갈 이름(태그, 다이제스트), 기록(깃옵스 pull), 레이블과 셀렉터, template이 바뀌면 새 RS",
    "**2부**: 전략 다섯 가지 한 그림, 쿠버네티스가 기본으로 주는 건 둘",
    "**3부**: 같은 조건(평소 5xx 0.1%) → 롤링(두 버전이 섞인다, 1만 4천 건, 롤아웃은 성공) → 블루/그린(5천 4백 건, 되돌리기 2초) → "
    "카나리(베이스라인 비교, 약 90건) → 비교표 → 파드 교체 때 끊김과 preStop → A/B와 다름 → 기능 플래그 → 확장/축소 → 데모 → 7장 리전 보충(시간 없으면 건너뜀)",
    "**4부**: 깃옵스에서 되돌리기, 돌아갈 곳, 데이터는 안 돌아간다, 헬름 훅, 체크리스트, 연습 → 처음 질문의 답",
]

QA = [
    ("Argo Rollouts를 쓰면 Deployment를 버려야 하나요?",
     "Rollout이 Deployment를 대신하는 게 기본입니다. 기존 Deployment를 그대로 두고 `workloadRef`로 가리키는 방식도 있어서 조금씩 옮길 수 있습니다."),
    ("깃옵스에서 급한 핫픽스는 어떻게 하나요?",
     "원칙은 같은 길(커밋 → 동기화)을 빨리 타는 겁니다. 정말 급하면 4부 순서대로 에이전트를 멈추고(`flux suspend`, Argo CD auto-sync 끄기) 직접 조치한 뒤, 깃을 맞추고 다시 켭니다. 이 절차는 미리 문서로 두고 연습해 둡니다."),
    ("깃옵스에서 DB 마이그레이션은 누가 돌리나요?",
     "많이 쓰는 건 셋입니다. 앱이 뜰 때 Flyway나 Liquibase로, Argo CD PreSync 훅이나 헬름 pre-upgrade 훅의 Job으로, Flux `dependsOn`으로 마이그레이션을 앱보다 먼저. 어느 쪽이든 확장/축소는 그대로 필요합니다."),
    ("helm rollback은 깃옵스에서 써도 되나요?",
     "rollout undo와 같은 문제가 있습니다. Flux helm-controller는 깃에 있는 HelmRelease 값으로 다시 올립니다. 깃을 되돌리는 게 맞습니다."),
    ("트래픽이 적은 서비스도 카나리 판정이 되나요?",
     "요청이 적으면 에러 몇 건으로 비율이 크게 흔들려서 판단이 어렵습니다. 카나리 기간을 늘리거나, 합성 트래픽을 더하거나, 비율 대신 에러 건수 조건을 같이 겁니다."),
    ("preStop sleep은 몇 초가 적당한가요?",
     "엔드포인트 제거가 끝까지 퍼지는 시간보다 길어야 합니다. 클러스터 안만이면 몇 초, 클라우드 LB가 타깃을 빼는 시간까지 치면 더 깁니다. terminationGracePeriodSeconds는 sleep과 앱 종료 시간을 합친 것보다 길게 둡니다. AWS Load Balancer Controller는 pod readiness gate로 타깃 등록 상태를 파드 Ready에 반영할 수도 있습니다."),
    ("쿠버네티스는 왜 실패한 롤아웃을 자동으로 되돌리지 않나요?",
     "진척이 없는 이유가 이미지 오류일 수도, 노드 부족이나 이미지 받는 게 느려서일 수도 있어서 컨트롤러가 실패로 단정하기 어렵습니다. 그래서 상태만 알리고 판단은 파이프라인이나 카나리 컨트롤러에 맡깁니다 (토론 Q2)."),
    ("블루/그린이면 DB 문제는 없는 것 아닌가요?",
     "DB는 대부분 두 환경이 같이 써서 두 버전이 같은 스키마를 봅니다. 확장/축소가 필요한 건 똑같습니다. 교재 5.7도 이걸 블루/그린 주의점으로 꼽습니다."),
]


def _text(fragment):
    return html.unescape(re.sub(r"<[^>]+>", "", fragment)).strip()


def _parse(body):
    title = re.search(r'data-t="([^"]+)"', body).group(1)
    kicker = _text(re.search(r'<div class="kicker">(.*?)</div>', body, re.S).group(1))
    head = re.search(r"<h[12][^>]*>(.*?)</h[12]>", body, re.S)
    heading = _text(head.group(1).replace("<br>", " ")) if head else title
    notes = re.search(r'<aside class="notes">(.*?)</aside>', body, re.S)
    bullets = [_text(li) for li in re.findall(r"<li>(.*?)</li>", notes.group(1), re.S)] if notes else []
    return title, kicker, heading, bullets


def _mmss(sec):
    sec = int(round(sec))
    return f"{sec // 60}:{sec % 60:02d}"


def write_script(sections, path):
    slides = [_parse(b) for b in sections]
    starts = {t: label for t, label, _ in STATIONS}
    plan = {label: m for _, label, m in STATIONS}

    rows, body = [], []
    total = 0.0
    station, station_sec, chars_total = None, 0.0, 0
    slide_sec = {}

    for n, (title, kicker, heading, bullets) in enumerate(slides, 1):
        if title in starts:
            if station:
                rows.append((station, plan[station], station_sec))
            station, station_sec = starts[title], 0.0
            body.append(f"\n---\n\n## {station} (계획 {plan[station]}분)\n")
        chars = sum(len(b.replace(" ", "")) for b in bullets)
        chars_total += chars
        sec = FIXED.get(title, max(MIN_SEC, chars / CPM * 60)) + PAUSE.get(title, 0)
        total += sec
        station_sec += sec
        slide_sec[title] = sec
        body.append(f"\n### {n}. {title}\n\n`{kicker}` · 예상 {_mmss(sec)} · 누적 {_mmss(total)}\n")
        body.append(f"\n**화면**: {heading}\n")
        if title == "데모":
            body.append("\n**할 것**: 터미널 두 개(왼쪽 poller 로그, 오른쪽 명령). 명령은 `examples/README.md` 순서대로.\n")
        body.append("\n**말할 것**\n")
        for b in bullets:
            body.append(f"\n> {b}\n")
    rows.append((station, plan[station], station_sec))

    talk = total - sum(FIXED.values()) - sum(PAUSE.values())
    plan_total = sum(m for _, _, m in STATIONS)
    labels = [label for _, label, _ in STATIONS]
    until_part2 = sum(m for _, _, m in STATIONS[: labels.index("2부 배포 전략 한눈에") + 1])
    head = [
        "# 7주차 발표 스크립트: 릴리스 파이프라인\n\n",
        "`slides.html` 각 장의 발표 노트를 뽑아 연습용으로 정리한 문서입니다. "
        "발표할 때는 `P` 키로 발표자 창을 띄우면 같은 원고와 다음 장, 시계가 같이 보입니다.\n\n",
        "원고를 고칠 때는 `src/`의 조각을 고치고 `python3 src/build.py`로 다시 만듭니다. 장표와 이 문서가 같이 바뀝니다.\n",
        "\n## 시간 계획\n",
        f"\n원고 {chars_total:,}자(공백 제외), 분당 {CPM}자로 치면 말하는 시간 약 {_mmss(talk)}. "
        f"청중 답 기다리는 시간 {round(sum(PAUSE.values()) / 60)}분, 데모 {FIXED['데모'] // 60}분, "
        f"토론 {FIXED['토론'] // 60}분을 더하면 **약 {round(total / 60)}분**입니다. "
        f"표를 설명하고 중간 질문을 받으면 보통 10% 정도 늘어서 {round(total * 1.1 / 60)}분 안팎이 됩니다. "
        f"구간별 계획을 더하면 {plan_total}분이고, 90분까지 {90 - plan_total}분 남습니다.\n",
        "\n| 구간 | 계획 | 원고 기준 |\n| --- | ---: | ---: |\n",
    ]
    head += [f"| {s} | {p}분 | {_mmss(e)} |\n" for s, p, e in rows]
    head += ["\n### 흐름\n\n"] + [f"- {x}\n" for x in FLOW]
    head += [
        "\n### 시간이 모자라면 건너뛸 장표\n\n",
        "".join(f"- {t} ({_mmss(slide_sec.get(t, 0))})\n" for t in SKIP),
        f"\n다 건너뛰면 원고 기준 약 {_mmss(sum(slide_sec.get(t, 0) for t in SKIP))} 줄어듭니다.\n",
        f"\n발표자 창 시계로 2부가 끝날 때 **누적 {until_part2}분**을 넘겼다면 위 목록부터 건너뜁니다.\n",
        "\n### 발표 전 체크\n\n",
        "- [ ] kind 클러스터 미리 만들고 `examples/01-rolling` 적용, `nginx:1.26`, `nginx:1.27`, `curlimages/curl` 이미지 미리 받아 두기\n",
        "- [ ] 터미널 글자 키우기, 창 두 개 배치 (poller 로그 / 명령)\n",
        "- [ ] 데모가 막히면 데모 장표의 표와 `examples/README.md` 출력으로 설명\n",
        "- [ ] 발표자 창(`P`)은 노트북 화면, 본 창은 공유 화면\n",
    ]
    tail = ["\n---\n\n## 예상 질문\n"]
    for q, a in QA:
        tail.append(f"\n**Q. {q}**\n\n{a}\n")
    path.write_text("".join(head) + "".join(body) + "".join(tail))
