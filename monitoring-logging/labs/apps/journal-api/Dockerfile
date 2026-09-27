# 멀티스테이지 빌드 — 빌드 도구는 최종 이미지에 남기지 않는다.
# 1단계: 의존성 설치와 타입스크립트 컴파일
FROM node:24-alpine AS build
WORKDIR /app
# 의존성 파일만 먼저 복사한다. 소스가 바뀌어도 이 레이어의 캐시는 살아남는다.
COPY package.json package-lock.json* ./
RUN npm ci
COPY tsconfig.json ./
COPY src ./src
RUN npm run build

# 2단계: 테스트. 실패하면 여기서 빌드가 멈추고 이미지가 만들어지지 않는다 (책 5.3).
# 별도 스테이지로 둔 이유는 최종 이미지에 테스트 결과물이 섞이지 않게 하기 위해서다.
FROM build AS test
RUN npm test

# 3단계: 런타임 의존성만 다시 설치 (devDependencies 제외)
FROM node:24-alpine AS deps
WORKDIR /app
COPY package.json package-lock.json* ./
RUN npm ci --omit=dev

# 4단계: 실행 이미지 — 소스도 빌드 도구도 없다
FROM node:24-alpine
# 빌드할 때 버전을 새긴다: docker build --build-arg APP_VERSION=v2 ...
ARG APP_VERSION=v1
ENV NODE_ENV=production APP_VERSION=${APP_VERSION}
WORKDIR /app
# 넌루트로 실행한다 (M24 파드 시큐리티의 전제).
# 숫자로 지정한다. 이름(node)으로 두면 kubelet 이 runAsNonRoot 를 검증하지 못해
# CreateContainerConfigError 로 막힌다 (M24):
#   container has runAsNonRoot and image has non-numeric user (node), cannot verify user is non-root
USER 1000
# test 스테이지를 참조하지 않으면 buildkit 이 그 스테이지를 아예 건너뛴다.
# --target test 로 따로 돌리거나, 아래처럼 결과에 의존하게 만들어야 테스트가 게이트가 된다.
COPY --from=test  --chown=node:node /app/package.json ./package.json
COPY --from=deps  --chown=node:node /app/node_modules ./node_modules
COPY --from=build --chown=node:node /app/dist ./dist
EXPOSE 8080
CMD ["node", "dist/server.js"]
