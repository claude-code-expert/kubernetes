# M33 — JournalSite 오퍼레이터

kubebuilder v4.15.0 로 만든 뼈대에서 **직접 쓴 파일만** 담았다.
전체 프로젝트를 다시 만들려면:

```
kubebuilder init --domain example.com --repo example.com/journalsite-operator
kubebuilder create api --group study --version v1alpha1 --kind JournalSite --resource --controller
# 그다음 이 디렉터리의 두 파일로 덮어쓴다
cp api/v1alpha1/journalsite_types.go            <프로젝트>/api/v1alpha1/
cp internal/controller/journalsite_controller.go <프로젝트>/internal/controller/
make manifests generate install run
```

- `api/v1alpha1/journalsite_types.go` — 타입과 검증 마커 (Pattern · Enum · CEL)
- `internal/controller/journalsite_controller.go` — 조정 함수
- `config/crd/bases/` — 마커에서 생성된 CRD (직접 고치지 않는다)

손으로 쓴 CRD 는 `../../k8s/crd/00-journalsite-crd.yaml` 에 따로 있다.
둘을 비교하면 마커가 무엇으로 번역되는지 보인다.
