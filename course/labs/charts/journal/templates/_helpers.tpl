{{/*
  이름 규칙을 한곳에 모은다. 릴리스 이름이 journal 이면 journal-api,
  prod 면 prod-api 가 되도록 모든 리소스가 이 함수를 통해 이름을 만든다.
  같은 클러스터에 같은 차트를 두 번 설치할 수 있는 이유다.
*/}}
{{- define "journal.fullname" -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/* 모든 리소스에 붙이는 공통 레이블. app.kubernetes.io/* 는 쿠버네티스 권장 레이블이다. */}}
{{- define "journal.labels" -}}
app.kubernetes.io/name: journal
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version }}
{{- end -}}

{{/* 셀렉터는 만든 뒤 바꿀 수 없다. 버전처럼 변하는 값을 여기에 넣으면 다음 upgrade 가 거부된다. */}}
{{- define "journal.selectorLabels" -}}
app.kubernetes.io/name: journal
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{- define "journal.apiImage" -}}
{{- printf "%s:%s" .Values.api.image.repository (include "journal.apiTag" .) -}}
{{- end -}}

{{/* 이미지 태그를 한 번만 계산한다. APP_VERSION 환경 변수와 이미지 태그가 어긋나지 않게. */}}
{{- define "journal.apiTag" -}}
{{- .Values.api.image.tag | default .Chart.AppVersion -}}
{{- end -}}
