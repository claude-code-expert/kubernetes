#!/usr/bin/env python3
"""3장 발표 자료 빌드.

slide-show.html 의 CSS·JS 를 그대로 쓰고, slides/*.html 의 슬라이드를 끼워 넣는다.
  {{FIG:이름.svg}}  figures/이름.svg 를 인라인으로 삽입
  {{PG}}            "현재/전체" 쪽 번호
출력: ../slides.html   (python3 src/build.py)
"""
import re
from pathlib import Path

ROOT = Path(__file__).parent
TEMPLATE = ROOT / "slide-show.html"
OUT = ROOT.parent / "slides.html"

lines = TEMPLATE.read_text(encoding="utf-8").splitlines(keepends=True)
deck_open = next(i for i, l in enumerate(lines) if '<div class="deck" id="deck"' in l)
deck_close = next(i for i, l in enumerate(lines) if l.startswith("</div></main>"))
head = "".join(lines[: deck_open + 1])
tail = "".join(lines[deck_close:])

head = re.sub(r"<title>.*?</title>",
              "<title>Kubernetes 3장 · 모니터링과 로깅</title>", head, count=1)
EXTRA_CSS = """<style id="ch03-styles">
  /* 장식 제거: 배경 원·그라데이션 대신 단색 */
  .deck::before,.cover::after{display:none}
  .card.blue,.card.teal,.card.yellow,.card.red,.card.green{background:var(--panel)}
  .card.teal{border-color:#B7DED4}.card.blue{border-color:#B8D3F5}.card.yellow{border-color:#E6C58E}
  h1 .hl{color:var(--teal)}
  .cover h1 .hl{color:var(--teal)}
  /* 16:9 도판 */
  .body.fig{align-items:center;justify-content:center}
  .body.fig svg{display:block;height:100%;max-height:560px;width:auto;max-width:100%;border:1px solid var(--line);border-radius:8px;background:#fff}
  /* 표: 제목을 덮지 않도록 밀도를 높인다 */
  .expanded .compare{font-size:16px}
  .expanded .compare th,.expanded .compare td{padding:9px 14px;line-height:1.4}
  .expanded .compare td:first-child{font:700 16px var(--sans)}
  .expanded .compare th:first-child{width:auto}
  /* 용어 표 */
  table.gloss{table-layout:fixed}
  .expanded table.gloss th,.expanded table.gloss td{padding:7px 14px}
  table.gloss col.c1{width:15%} table.gloss col.c2{width:27%}
  .expanded table.gloss td:nth-child(2){font:14.5px var(--mono);color:var(--muted)}
  /* 가독성 */
  .card p{font-size:17px}
  .flow .step-box{padding:20px 16px}
  .flow .step-box b{font:700 19px var(--sans);margin:6px 0 8px}
  .flow .step-box p{font-size:16px;line-height:1.45}
  .flow .step-box .num{font-size:13px}
  .flow.big .step-box{padding:26px 18px}
  .flow.big .step-box b{font-size:23px;letter-spacing:-.01em}
  .flow.big .step-box p{font-size:18px}
  .section-lead .quest{align-self:flex-start}
  /* 도판 아래 한 줄 설명 */
  .body.fig{flex-direction:column;gap:10px}
  .body.fig:has(.figcap) svg{max-height:470px}
  .figcap{font-size:17px;line-height:1.5;color:var(--ink);max-width:1148px;text-align:center}
  .figcap b{color:var(--teal-deep)}
  /* 표 안 묶음 제목 행 */
  /* 캡처 자리 */
  .capture{border:2px dashed var(--line-strong);border-radius:8px;background:var(--panel);display:flex;flex-direction:column;justify-content:center;align-items:center;gap:8px;min-height:260px;padding:18px;text-align:center;color:var(--muted)}
  .capture b{font:700 13px var(--mono);letter-spacing:.12em;color:var(--teal)}
  .capture span{font-size:17px;line-height:1.45;color:var(--ink)}
  .expanded table.compare td.it{font:400 15px var(--sans);color:var(--ink)}
  .expanded table.dense th,.expanded table.dense td{padding:6px 14px}
  .expanded table.compare tr.grp td{background:var(--panel-alt);font:700 15px var(--sans);color:var(--teal-deep);padding:6px 14px}
  /* 캡처 보기: images/sNN.png 가 있으면 NN 번 슬라이드에 붙는다. C 키 또는 버튼 */
  .cap-btn{position:absolute;right:66px;top:50px;z-index:5;font:600 12px var(--mono);letter-spacing:.04em;padding:5px 10px;border:1px solid var(--teal);border-radius:999px;background:var(--panel);color:var(--teal);cursor:pointer}
  .cap-btn:hover{background:var(--teal);color:#fff}
  .capview{position:absolute;inset:0;z-index:6;background:rgba(20,28,27,.88);display:flex;flex-direction:column;align-items:center;justify-content:center;gap:12px;padding:28px}
  .capview img{max-width:100%;max-height:640px;border-radius:6px;box-shadow:0 8px 30px rgba(0,0,0,.35);background:#fff}
  .capview[hidden]{display:none}
  .capview .cap-meta{font:600 13px var(--mono);color:#E0EFEB}
</style>
"""
head = head.replace("</head>", EXTRA_CSS + "</head>", 1)
# 클릭으로 넘어가지 않게 한다. 이동은 방향키(←→↑↓) · Space · PageUp/Down · Home/End 로만.
CLICK_NEXT = "if(Date.now()<suppressClickUntil||e.target.closest('#notes,button,a'))return;next()});"
assert CLICK_NEXT in tail, "template click handler changed"
tail = tail.replace(CLICK_NEXT, "});")
tail = tail.replace("k8s-ch09-notes-v1", "k8s-ch03-notes-v1")
tail = tail.replace("kubernetes-ch09-story-slides-mesh-expanded.html",
                    "kubernetes-ch03-monitoring-logging.html")


def inline_svg(m):
    svg = (ROOT / "figures" / m.group(1)).read_text(encoding="utf-8")
    return re.sub(r"^<\?xml[^>]*>\s*", "", svg).strip()


body = "".join(p.read_text(encoding="utf-8") for p in sorted((ROOT / "slides").glob("*.html")))
body = re.sub(r"\{\{FIG:([\w.-]+)\}\}", inline_svg, body)

sections = re.split(r"(?=<section class=\"slide)", body)
total = sum(1 for s in sections if s.startswith("<section"))
out, n = [], 0
for s in sections:
    if s.startswith("<section"):
        n += 1
        s = s.replace("{{PG}}", f"{n}/{total}")
        label = re.search(r'data-label="([^"]*)"', s).group(1)
        s = re.sub(r'data-label="[^"]*"', f'data-label="{n:02d} {label}" id="slide-{n}"', s, count=1)
    out.append(s)

# 캡처: images/키.png (슬라이드의 data-cap="키") 또는 images/s54.png(슬라이드 번호)로 붙는다.
IMG_DIR = ROOT.parent / "images"
caps_total = 0
for i, s in enumerate(out):
    m = re.search(r'id="slide-(\d+)"', s)
    if not m:
        continue
    n = int(m.group(1))
    capkey = lambda p: int(m2.group(1)) if (m2 := re.search(r"-(\d+)\.", p.name)) else 1
    imgs = sorted((p for p in IMG_DIR.glob(f"s{n}*") if re.fullmatch(rf"s{n}(-\d+)?\.(png|jpe?g|webp)", p.name)), key=capkey)
    # 슬라이드에 data-cap="키" 가 있으면 images/키.png, 키-2.png … 도 붙인다(순서가 바뀌어도 따라간다)
    k = re.search(r'data-cap="([a-z0-9-]+)"', s)
    if k:
        key = k.group(1)
        imgs += sorted((p for p in IMG_DIR.glob(f"{key}*") if re.fullmatch(rf"{key}(-\d+)?\.(png|jpe?g|webp)", p.name)), key=capkey)
    if not imgs:
        continue
    caps_total += len(imgs)
    views = "".join(
        f'<div class="capview" hidden data-idx="{k}"><img src="images/{p.name}" alt="캡처 {p.name}">'
        f'<div class="cap-meta">{p.name} · {k + 1}/{len(imgs)} · C 다음 · Esc 닫기</div></div>'
        for k, p in enumerate(imgs))
    btn = f'<button class="cap-btn" type="button">캡처 {len(imgs)} · C</button>'
    out[i] = s[: s.rindex("</section>")] + btn + views + "</section>" + s[s.rindex("</section>") + 10:]

CAP_JS = """<script>
(function(){
  function cur(){return document.querySelector('.slide.active');}
  function cycle(slide){
    var v=[].slice.call(slide.querySelectorAll('.capview')); if(!v.length)return;
    var i=v.findIndex(function(x){return !x.hidden;});
    v.forEach(function(x){x.hidden=true;});
    if(i<v.length-1)v[i+1].hidden=false;
  }
  function closeAll(){document.querySelectorAll('.capview').forEach(function(x){x.hidden=true;});}
  document.addEventListener('click',function(e){
    var b=e.target.closest('.cap-btn'); if(b){e.stopPropagation();cycle(b.closest('.slide'));return;}
    if(e.target.closest('.capview')){e.stopPropagation();closeAll();}
  },true);
  document.addEventListener('keydown',function(e){
    if(e.target.closest&&e.target.closest('[contenteditable],textarea,input'))return;
    var s=cur(); if(!s)return;
    if(e.key.toLowerCase()==='c'&&!e.metaKey&&!e.ctrlKey){cycle(s);e.preventDefault();}
    else if(e.key==='Escape'&&s.querySelector('.capview:not([hidden])')){closeAll();e.stopPropagation();}
    else if(/^(Arrow|Page|Home|End| )/.test(e.key)||e.key===' '){closeAll();}
  },true);
})();
</script>
"""
tail = tail.replace("</body>", CAP_JS + "</body>", 1)
OUT.write_text(head + "\n" + "".join(out) + "\n" + tail, encoding="utf-8")
print(f"captures attached: {caps_total}")
print(f"{OUT.name}: {total} slides")
