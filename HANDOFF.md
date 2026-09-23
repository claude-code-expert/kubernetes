# 인수인계

이 저장소가 지금 어떤 상태이고, 이어서 무엇을 하면 되는지 적는다.
제작 규약은 `CLAUDE.md`, 커리큘럼 정본은 `CURRICULUM.md` 다. 그 둘을 먼저 읽는다.

최종 갱신 2026-09-23.

---

## 1. 저장소에 무엇이 있나

```
course/     도커 & 쿠버네티스 38편 + 치트시트 + 부록 A   ← 주력
study/      쿠버네티스 관측성 11장 + labs               ← 별도 축
google_docs/  구글 독스 원고(docx 2편)와 그 실습 파일
docs/       기존 자산. 참조·추출하되 요청 없이 수정하지 않는다
utils/      실습 도구 가이드
presentation/  추적 대상 아님(.gitignore)
```

| | 편수 | 버전 고정 | 검증일 |
|---|---|---|---|
| `course/` | 38편 + 치트시트 + 부록 A | K8s 1.37.0 · kind v0.33.0 · Helm 4.x | 2026-09-03 |
| `study/` | 11장 | K8s 1.36 · kind v0.32.0 · 차트 88.x | 2026-08-19 |

**두 과정은 버전이 다르다. 같은 클러스터에서 섞어 돌리지 않는다.**
`study/` 를 1.37 로 올리려면 11장의 명령과 출력을 전부 재검증해야 한다 — 아직 안 했다.

## 2. 배포

GitHub Pages. `.github/workflows/pages.yaml` 이 `course/` 와 `study/` 만 골라
`_site/` 로 조립해 올린다. `docs/` · `google_docs/` 는 배포 대상이 아니다.

```
https://claude-code-expert.github.io/kubernetes/          랜딩
                                        /course/          38편
                                        /study/           관측성 11장
```

`course/**` 나 `study/**` 를 고쳐 푸시하면 자동 재배포된다. 20초쯤 걸린다.

> **배포가 실패하면 먼저 재실행해 본다.** GitHub 쪽 OIDC 토큰 타임아웃
> (`Failed to get ID Token`)으로 간헐적으로 죽는다. 설정 문제가 아니다.
> `gh workflow run pages.yaml --ref main` 으로 다시 돌린다.

> **히스토리를 다시 쓰면 Pages 설정이 초기화된다.** 그러면 워크플로가
> `Get Pages site failed` 로 죽고, 그 틈에 GitHub 기본 Jekyll 빌드가 README 를
> 루트로 배포해 랜딩을 덮는다(2026-09-13 에 실제로 발생). `configure-pages` 에
> `enablement: true` 를 넣어 막아 두었지만, 루트가 이상하면 이것부터 의심한다.

## 3. 지금 클러스터 상태

```
컨텍스트  kind-study
노드      study-control-plane · study-worker · study-worker2   (v1.37.0 · 전부 Ready)
```

| 네임스페이스 | 무엇 |
|---|---|
| `journal` | M14 kustomize 배포. 인그레스가 `journal.local` 을 잡고 있다 |
| `journal-dev` | 헬름 릴리스 `dev`. 호스트는 `dev.journal.local` |
| `ingress-nginx` | 인그레스 컨트롤러 |
| `default` | google_docs 10·11장 실습 (`k8s-sample-boot` 3개) |

M19 이후(관측 스택 · 정책 · GitOps · 카오스)는 **올라가 있지 않다.** 9월 18일에
클러스터가 지워진 뒤 `rebuild.sh` 로 M14 시점까지만 복구했다.

## 4. 이어서 할 일

### 바로 할 수 있는 것

- **`study/` 를 1.37 라인으로 올릴지 결정.** 올리면 11장 전부 재검증이 필요하다.
  지금은 1.36 에 고정하고 차이를 문서에 밝혀 둔 상태다.
- **`docs/이미지참고/` 외 자산 정리.** 부록 A 가 7장을 편입했다. `docs/` 의
  chapter0~21, kubenetes 14일 로드맵, kubernetes-in-action 은 아직 손대지 않았다.
- **M19~M38 실습 복구.** 클러스터에 관측 스택부터 다시 올려야 뒤쪽 모듈을 검증할 수 있다.

### 판단이 필요한 것

- **`google_docs/` 의 나머지 장.** 10·11장만 이 환경에서 돌아가게 고쳤다. 12장 이후는
  같은 문제(레지스트리 포트 · port-forward · 로컬 JDK)가 남아 있을 가능성이 높다.
- **`study/ppt/` 가 유실됐다.** 장표 아웃라인 56장표 · 도판 5종 · 제작 규약을 만들어
  두었는데, 2026-09-13 히스토리 재작성 때 사라졌고 현재 히스토리에 기록조차 없다.
  `study/README.md` 와 `CLAUDE.md` 가 아직 그 경로를 가리킨다. 다시 만들거나
  두 문서의 참조를 걷어내야 한다.
- **`presentation/`** 이 `.gitignore` 로 빠져 있다. 위 키트와 어떤 관계인지 정리되지 않았다.

## 5. 이 저장소에서 반복해서 걸린 것

같은 실수를 되풀이하지 않게 남긴다. 실습 중 에러는 `course/labs/TROUBLESHOOTING.md`
(8가지, 에러 메시지별)를 먼저 본다.

### 문서 작업

**도판은 `figures/` 파일과 문서 인라인본을 둘 다 고친다.** 한쪽만 고치면 다음 검사에서
걸린다. `course/` 만 해당하고 `study/` 는 인라인만 쓴다.

```
# 일치 검사
python3 - <<'PY'
import re,glob,os
for f in sorted(glob.glob('course/m*.html')):
    t=open(f,encoding='utf-8').read(); m=os.path.basename(f)[:3]
    for s,fp in zip(re.findall(r'<svg\b.*?</svg>',t,re.S), sorted(glob.glob('course/figures/%s-fig*.svg'%m))):
        if re.sub(r'\s+','',s)!=re.sub(r'\s+','',open(fp,encoding='utf-8').read()):
            print('불일치', fp)
PY
```

**스타일 블록은 41편(course) · 13편(study)이 공유한다.** 한 편만 고치지 않는다.
고친 뒤 고유 스타일이 1종인지 확인한다.

**일괄 치환은 두 번 사고를 냈다.**
- 마스크 자리표시자를 한 번만 복원해 53편 795곳에서 목차·헤더가 사라졌다.
  복원은 남지 않을 때까지 반복하고, 남으면 실패하도록 단언을 건다.
- 삽입한 텍스트가 다시 스캔 대상이 되어 중첩 태그가 생겼다.
  원본 기준으로 자리를 먼저 모은 뒤 역순으로 치환한다.

**태그 균형 검사만으로는 손상을 못 잡는다.** `<nav>…</nav>` 가 통째로 사라지면
여는 수와 닫는 수가 같이 줄어 균형이 맞아 버린다. 넣은 마크업만 걷어내고
**원본과 바이트 단위로 대조**하는 검사를 쓴다.

```
git show <직전커밋>:<파일> | diff - <(내가 넣은 마크업만 제거한 결과)
```

**`rect` 등 자기닫힘 SVG 태그는 균형 검사에서 제외**한다. 오탐이 난다.

### 이 환경의 제약

**헤드리스 크롬은 뷰포트를 500px 미만으로 못 잡는다.** `--window-size=390` 을 줘도
500 으로 렌더한다. 모바일 레이아웃은 이 도구로 검증할 수 없다 — 잘려 보이면
촬영 artifact 인지 먼저 의심한다.

**여러 줄 heredoc 이 터미널에 붙여넣기로 전달되지 않는다.** 첫 줄만 가고 본문과
`EOF` 가 사라져 빈 파일이 남는다. 파일 편집은 도구로 직접 하거나 `printf` 한 줄로 한다.

**`grep` 이 간헐적으로 출력 없이 종료한다.** 중요한 검사는 `python3` 로 센다.

**로컬에 JDK 가 PATH 에 없다.** brew 로 17·21·26 이 깔려 있지만 keg-only 다.
Gradle 빌드는 Dockerfile 의 빌더 스테이지에 맡긴다.

```
export JAVA_HOME=/opt/homebrew/opt/openjdk@21
export PATH="$JAVA_HOME/bin:$PATH"
```

**로컬 레지스트리는 5001 이다**(컨테이너 안 5000). 문서의 `localhost:5000` 은 그대로
쓸 수 없고, kind 노드는 `localhost` 로 그 레지스트리에 닿지도 못한다.
실습은 `kind load docker-image` 로 간다.

### 내용 검토에서 반복해서 나온 지적

- **그림이 결론만 말하고 메커니즘을 안 보여 준다.** M11 두 장을 그래서 다시 그렸다.
  "이게 왜 여기서 나오지" 싶은 그림은 전제가 빠진 것이다.
- **캡션을 지우고 그림만 남겼을 때 읽히는가** 를 기준으로 본다. 제목이 상자 라벨이면
  주장으로 바꾼다. 8장을 그래서 고쳤다.
- **약어는 그 문서에서 처음 나오는 자리에 풀이를 붙인다.** `<dfn class="term">` +
  `<span class="en">`. 484곳 적용돼 있다.
- **출력을 지어내지 않는다.** docx 11장을 고칠 때 명령을 전부 실제로 돌려 출력을
  갈아 끼웠다. "요청 실패 없이" 같은 단정이 실측과 다르면 실측을 적는다.

## 6. 자주 쓰는 명령

```
# 배포 상태
gh run list --workflow=pages --limit 3
curl -s -o /dev/null -w '%{http_code}\n' https://claude-code-expert.github.io/kubernetes/

# 실습 복구 (빈 클러스터 → M14 시점)
bash course/labs/scripts/rebuild.sh

# 복구 확인
kubectl config current-context                       # kind-study
kubectl get nodes                                    # 3개 Ready
kubectl -n journal get pods                          # 전부 Running
curl -H 'Host: journal.local' http://localhost:18080/api/entries

# 문서 전수 검사 (앵커·링크·태그)
python3 - <<'PY'
import re,glob,os
bad=0
for f in sorted(glob.glob('course/*.html'))+sorted(glob.glob('study/*.html')):
    t=open(f,encoding='utf-8').read(); d=os.path.dirname(f)
    if '\x00' in t: print('NUL',f); bad+=1
    ids=set(re.findall(r'id="([^"]+)"',t))
    for a in re.findall(r'href="#([^"]+)"',t):
        if a not in ids: print('앵커',f,a); bad+=1
    for h in set(re.findall(r'href="([^"#:]+\.html)"',t)):
        if not os.path.exists(os.path.normpath(os.path.join(d,h))): print('링크',f,h); bad+=1
    for tag in ['section','figure','table','td','th','p','div','a','li','dfn','span','style','svg']:
        o=len(re.findall(r'<%s[\s>]'%tag,t)); c=len(re.findall(r'</%s>'%tag,t))
        if o!=c: print('태그',f,tag,o,c); bad+=1
print('문제:', bad or '없음')
PY
```

## 7. docx 편집

`python-docx` 가 시스템에 없다. venv 로 쓴다.

```
python3 -m venv /tmp/docxvenv && /tmp/docxvenv/bin/pip install -q python-docx
```

문서 구조는 **문단과 표가 섞인 본문 흐름**이고, 코드 블록은 1×1 표다.
한 줄이 한 문단이며 런 서식은 Consolas 11.4pt. 표를 새로 만들기보다
**기존 칸의 내용을 줄 단위로 다시 쓰는 편**이 서식을 지키기 쉽다.
콜아웃과 비교표는 1×1 이 아니거나 여러 행이므로 구분해서 건드린다.

**편집 전에 원본을 백업한다.** 되돌릴 방법이 git 뿐이다.
