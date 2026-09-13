# M31 — 실습용 깃 서버. git daemon 은 별도 패키지(git-daemon)로 들어 있다.
# alpine/git 이미지에는 없어서 직접 만든다.
FROM alpine:3.22
RUN apk add --no-cache git git-daemon && \
    adduser -D -u 1000 -h /repos git && \
    mkdir -p /repos && chown -R 1000:1000 /repos
USER 1000
EXPOSE 9418
# --export-all: 저장소마다 git-daemon-export-ok 파일을 두지 않아도 내보낸다 (실습용)
ENTRYPOINT ["git", "daemon", "--verbose", "--export-all", "--base-path=/repos", \
            "--reuseaddr", "--enable=upload-pack", "--port=9418"]
