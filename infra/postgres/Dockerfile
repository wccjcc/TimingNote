FROM postgres:17

# 1. 패키지 리스트 업데이트 및 필수 도구 설치
# ca-certificates를 추가하고, git이 인증서를 인식할 수 있게 합니다.
RUN apt-get update && apt-get install -y --no-install-recommends \
    postgresql-17-postgis-3 \
    postgresql-17-postgis-3-scripts \
    build-essential \
    postgresql-server-dev-17 \
    git \
    ca-certificates \
    && update-ca-certificates

# 2. pgvector 빌드 (SSL 인증서 에러 방지를 위해 git config 설정 추가)
RUN cd /tmp \
    && git config --global http.sslVerify false \
    && git clone --branch v0.7.0 https://github.com/pgvector/pgvector.git \
    && cd pgvector \
    && make OPTFLAGS="" \
    && make install \
    && rm -rf /tmp/pgvector

# 3. 불필요한 패키지 삭제 및 정리
RUN apt-get remove -y build-essential postgresql-server-dev-17 git \
    && apt-get autoremove -y \
    && rm -rf /var/lib/apt/lists/*