# TimingNote

> 자연어로 적은 메모를 AI가 할 일로 구조화하고, 사용자의 현재 위치와 가까운 실행 장소를 기준으로 "지금 할 수 있는 일"을 알려주는 위치 기반 할 일 앱

TimingNote는 단순한 Todo 앱이 아니라 **장소를 기억하는 할 일 앱**입니다.  
사용자는 "다이소에서 내일 저녁 치약 사기", "집 이번 주말 빨래하기"처럼 자연스럽게 입력하고, 서비스는 문장 속 시간과 장소를 구조화해 포괄 장소, 특정 장소, 내 장소 별칭으로 연결합니다. 이후 사용자가 해당 장소 근처에 도착하면 Geofence 기반으로 할 일을 다시 떠올려 줍니다.

| 구분 | 내용 |
| --- | --- |
| 서비스 유형 | AI 기반 메모 구조화 + 위치 알림 모바일 앱 |
| 핵심 가치 | 사용자가 기억해야 할 일을 현재 위치와 실행 가능성 중심으로 재배치 |
| 주요 입력 | 자연어 텍스트 메모 |
| 주요 출력 | 구조화된 Todo, 후보 장소, 위치 기반 추천, Geofence 알림 |
| 지원 장소 타입 | `SPECIFIC` 특정 장소, `GENERIC` 포괄 장소, `ALIAS` 내 장소 |

## Demo

데모 영상은 `exec/assets/demo/timingnote_demo.mp4` 경로로 추가하면 이 섹션 상단에 배치하는 것을 권장합니다.  
README에는 전체 시연 영상을 1개만 두고, 자세한 클릭 순서와 화면별 설명은 [서비스 시연 시나리오](./exec/TimingNote_서비스_시연_시나리오.md)에서 관리합니다.

<!-- 영상 파일을 추가한 뒤 이 위치에 video 태그를 배치합니다. -->

<p align="center">
  <img src="./exec/assets/demo/01_home_ready.png" width="19%" alt="홈 추천 화면">
  <img src="./exec/assets/demo/04_todo_list_ready.png" width="19%" alt="할 일 목록">
  <img src="./exec/assets/demo/08_detail_generic_candidates.png" width="19%" alt="포괄 장소 후보">
  <img src="./exec/assets/demo/12_my_places_list.png" width="19%" alt="내 장소 목록">
  <img src="./exec/assets/demo/14_map_overview.png" width="19%" alt="지도 화면">
</p>

## Why TimingNote

일반 Todo 앱은 "무엇을 해야 하는지"를 기록하는 데 집중합니다. 하지만 실제 생활에서는 할 일을 떠올리는 시점이 시간보다 **장소**에 묶이는 경우가 많습니다.

- 약국 근처에 왔을 때 처방약 수령을 떠올리고 싶다.
- 다이소 어느 지점이든 가까우면 생활용품을 사고 싶다.
- 집, 회사, 학교처럼 자주 가는 장소는 매번 주소를 입력하고 싶지 않다.
- "내일 저녁", "이번 주말", "퇴근 후" 같은 자연어 시간 표현을 직접 날짜/시간으로 바꾸고 싶지 않다.

TimingNote는 이 문제를 `AI 자연어 구조화`, `장소 타입 판별`, `위치 기반 후보 추천`, `Geofence 알림`으로 나누어 해결합니다.

## Core Flow

```text
┌──────────────────────┐
│  Flutter App          │
│  자연어 할 일 입력     │
└───────────┬──────────┘
            │
            ▼
┌──────────────────────┐
│  FastAPI AI Server    │
│  카테고리·장소어·시간 추출 │
└───────────┬──────────┘
            │
            ▼
┌──────────────────────────────┐
│  Spring Boot Backend          │
│  내 장소 대조 · Kakao 검색 · 장소 타입 판정 │
└───────┬──────────────────┬───┘
        │                  │
        ▼                  ▼
┌──────────────────┐   ┌──────────────────┐
│ PostgreSQL/PostGIS│   │ Redis Cache       │
│ Todo·장소·후보 저장 │   │ Kakao 검색 결과 공유 │
└───────┬──────────┘   └──────────────────┘
        │
        ├──> 홈 추천: 현재 위치에서 가능한 할 일 노출
        │
        └──> Geofence 슬롯 재계산 -> FCM 위치 알림
```

### 1. 자연어 입력

사용자는 정해진 폼을 채우지 않고 문장으로 입력합니다.

```text
다이소에서 내일 저녁 치약 사기
장덕도서관에서 내일 오전 책 빌리기
집 이번 주말 빨래하기
```

AI 서버는 문장에서 `할 일 내용`, `카테고리`, `장소 후보어`, `시간 조건`을 추출합니다. 이때 AI가 외부 API 코드나 최종 장소 타입을 추측하지 않도록 하고, 실제 검증은 백엔드가 담당합니다.

### 2. 장소 타입 판별

TimingNote의 핵심은 장소를 세 가지 타입으로 분리하는 것입니다.

| 타입 | 예시 | 처리 방식 |
| --- | --- | --- |
| `SPECIFIC` | 장덕도서관, 스타벅스 강남점 | 특정 좌표 1곳을 실행 장소로 확정 |
| `GENERIC` | 약국, 편의점, 다이소 | 주변 후보 장소 여러 개를 저장하고 가까운 곳을 추천 |
| `ALIAS` | 집, 회사, 학교 | 사용자가 등록한 내 장소 별칭과 직접 연결 |

이 구조 덕분에 "다이소"처럼 지점이 여러 개인 장소와 "장덕도서관"처럼 정확한 장소를 다르게 다룰 수 있습니다.

### 3. 추천과 알림

저장된 Todo 후보 장소는 사용자의 현재 위치와 비교됩니다.

- 홈 화면: 지금 위치에서 처리 가능한 할 일을 추천합니다.
- 지도 화면: 주변 Todo 후보와 내 장소를 마커로 확인합니다.
- Geofence: OS 위치 이벤트를 이용해 장소 진입 시 알림을 발송합니다.
- 쿨다운/스누즈/조용한 시간 정책으로 반복 알림과 불필요한 알림을 제어합니다.

## Main Features

| 기능 | 설명 |
| --- | --- |
| 자연어 Todo 등록 | 문장 입력만으로 할 일, 장소, 시간 조건을 구조화 |
| 포괄/특정/내 장소 처리 | 같은 장소 표현도 의도에 맞게 `GENERIC`, `SPECIFIC`, `ALIAS`로 분기 |
| 후보 장소 추천 | 포괄 장소일 때 Kakao Local 검색 결과를 후보로 저장하고 거리 기반 추천 |
| 수동 보정 UX | 잘못 구조화된 장소를 상세 화면, 지도 검색, 후보 선택으로 수정 |
| 내 장소 관리 | 집/회사/학교 같은 자주 가는 장소를 별칭으로 등록 |
| 위치 기반 홈 추천 | 현재 위치에서 가까운 할 일을 홈 화면에 노출 |
| 지도 탭 | 장소 마커, 필터, 마커 상세 바텀 시트 제공 |
| Todo 검색 | Elasticsearch + Nori 기반 한글 Todo 검색 |
| 위치 알림 | Geofence 슬롯과 FCM을 이용한 장소 진입 알림 |

## Architecture Highlights

### AI와 Backend 역할 분리

초기 설계처럼 AI가 검색어, 장소 타입, 외부 API 카테고리까지 모두 결정하면 LLM 환각과 디버깅 난도가 커집니다. TimingNote는 책임을 다음처럼 나눴습니다.

| 계층 | 책임 |
| --- | --- |
| AI 서버 | 자연어에서 카테고리, 장소어, 시간 표현만 추출 |
| Backend | 내 장소 별칭 대조, Kakao 검색, 장소 타입 판정, DB 저장 |
| Mobile | 입력/수정/권한/지도/알림 UX 제공 |

이 구조는 AI의 강점인 자연어 이해와 백엔드의 강점인 검증 가능한 판단을 분리하기 위한 결정입니다.

### Kakao Local BE Proxy + Redis Cache

장소 검색은 외부 API 비용과 키 보안이 동시에 걸린 영역입니다.  
FE에서 Kakao REST API를 직접 호출하지 않고 백엔드 프록시를 경유하도록 구성했습니다.

- Kakao REST API 키를 모바일 앱에 포함하지 않음
- 동일 지역/동일 키워드 검색 결과를 Redis에서 공유
- 좌표를 약 1km grid로 정규화해 가까운 사용자의 중복 검색을 같은 캐시 키로 수렴
- Cache Stampede Lock으로 동시 Cold Miss 상황에서 외부 API 호출 폭증을 방지

운영 도메인 성능 테스트 문서 기준, 장소 검색은 Cold Miss 평균 `104.18ms`에서 Warm Hit 평균 `52.91ms`로 단축되었고, 100 VU Warm Hit 부하에서도 실패율 `0%`로 처리되었습니다. 자세한 조건과 한계는 [Redis 장소 검색 캐시 성능 테스트](./문서/발표/redis_카카오검색_성능테스트.md)에 정리되어 있습니다.

### 설치 단위 인증

로그인 없이 앱 설치 단위로 사용자를 식별합니다.

```text
앱 최초 실행
  -> POST /api/v1/users
  -> installationUuid + deviceSecret 발급
  -> 이후 모든 요청에 X-Device-Secret 포함
```

서버는 전달받은 raw secret을 HMAC-SHA256으로 해시한 뒤 DB 값과 비교합니다. 클라이언트가 임의로 `userId`를 보내는 구조가 아니므로 사용자 식별 책임이 서버 쪽에 있습니다.

### 비동기 구조화 파이프라인

AI 호출은 외부 네트워크 의존성이므로 Todo 생성 트랜잭션과 분리했습니다.

| 순서 | 처리 주체 | 동작 | 결과 |
| --- | --- | --- | --- |
| 1 | Flutter App | 자연어 Todo 생성 요청 | 사용자는 폼 없이 문장으로 입력 |
| 2 | Spring Boot | Todo를 `PENDING` 상태로 먼저 저장 | AI 응답을 기다리지 않고 원본 Todo 보존 |
| 3 | Spring Boot | 앱에 즉시 응답 | 입력 지연 최소화 |
| 4 | Spring Boot -> FastAPI AI | 자연어 구조화 요청 | 카테고리, 장소어, 시간 조건 추출 |
| 5 | FastAPI AI -> Spring Boot | 구조화 결과 반환 | 백엔드가 후속 검증 수행 |
| 6 | Spring Boot | 내 장소/Kakao 검색/장소 타입 판정 | `ALIAS`, `SPECIFIC`, `GENERIC` 결정 |
| 7 | Spring Boot -> PostgreSQL | TodoStructure, Place, Candidate 저장 | 추천/지도/알림에서 사용할 데이터 완성 |
| 8 | Spring Boot | Todo를 `READY` 상태로 전환 | 사용자에게 구조화 완료 상태 제공 |

AI 실패 시에는 Todo 자체를 잃지 않고 `FAILED` 상태로 남겨 사용자가 수동으로 보정할 수 있습니다.

### 검색 Read Model

Todo 원본 데이터는 PostgreSQL이 담당하고, 검색은 Elasticsearch 전용 문서로 분리했습니다.

- Nori 형태소 분석기로 한글 검색 대응
- Todo 제목, 장소명, 카테고리 기반 검색
- 원본 정합성과 검색 성능을 분리하는 read model 구조

## Tech Stack

| 영역 | 기술 |
| --- | --- |
| Mobile | Flutter, Dart, Riverpod, GoRouter, Dio, Geolocator, Permission Handler, Firebase Messaging |
| Backend | Java 17, Spring Boot 3.5.13, Spring MVC/WebFlux, Spring Data JPA, Validation, Actuator |
| AI | Python 3.11, FastAPI, Pydantic, Instructor, OpenAI SDK, GPT-4.1 Mini via GMS |
| Database | PostgreSQL 17, PostGIS, Flyway |
| Cache/Queue/Search | Redis, RabbitMQ, Elasticsearch 8.14.3 + Nori |
| External APIs | Kakao Local API, Google Places API, Firebase Cloud Messaging, AWS S3 |
| Infra | Docker Compose, Nginx, Jenkins, HTTPS 운영 배포 |

## Repository Structure

```text
S14P31C101
├─ TimingNote_BE/          # Spring Boot API 서버
├─ TimingNote_AI/          # FastAPI 자연어 구조화 서버
├─ TimingNote_FE/          # Flutter 모바일 앱
├─ infra/                  # PostgreSQL/PostGIS, Elasticsearch 등 인프라 설정
├─ exec/                   # 제출 산출물, 포팅 매뉴얼, 시연 시나리오, 데모 이미지
└─ 문서/                   # 기획, API, AI/BE 설계, 발표, 학습 문서
```

## Getting Started

상세한 환경 변수와 배포 절차는 [포팅 매뉴얼](./exec/포팅매뉴얼.md)을 기준으로 확인합니다. 실제 시크릿 값은 저장소에 커밋하지 않습니다.

### 1. 인프라 실행

```bash
docker compose -f docker-compose.local.yml up -d
```

### 2. Backend 실행

```bash
cd TimingNote_BE
./gradlew bootRun
```

Windows 환경에서는 `gradlew.bat`을 사용할 수 있습니다.

### 3. AI 서버 실행

```bash
cd TimingNote_AI
pip install -r requirements.txt
python run.py
```

### 4. Flutter 앱 실행

```bash
cd TimingNote_FE/timing_note
flutter pub get
sh run.sh
```

## Documentation

| 문서 | 설명 |
| --- | --- |
| [포팅 매뉴얼](./exec/포팅매뉴얼.md) | 실행 환경, 환경 변수, 배포 특이사항 |
| [서비스 시연 시나리오](./exec/TimingNote_서비스_시연_시나리오.md) | 화면별 시연 순서, 클릭 위치, 설명 멘트 |
| [요구사항 명세서](./문서/기획/TimingNote_요구사항명세서_v3.md) | 서비스 요구사항과 기능 범위 |
| [BE/AI 발표 핵심 정리](./문서/발표/강산천_BE_AI_발표핵심정리.md) | AI-BE 역할 분리, 장소 판별, 비동기 구조화 설명 |
| [Redis 성능 테스트](./문서/발표/redis_카카오검색_성능테스트.md) | Kakao 검색 캐시 성능 측정과 해석 |
| [Elasticsearch 검색 정리](./문서/발표/강산천_Elasticsearch_Todo검색_발표정리.md) | Todo 검색 read model과 Nori 분석기 설계 |

## Team

| 이름 | 역할 |
| --- | --- |
| 강산천 | Backend, AI 서버, 장소 판별 파이프라인, Kakao/Redis 캐시, Todo 검색, FE 일부 |
| 정우주 | Flutter Frontend, Infra, 지도/알림 UX, Geofence/FCM 알림 백엔드 |

## Key Takeaways

TimingNote에서 가장 중요한 설계 기준은 "AI가 모든 것을 맞힌다"가 아니라 **AI가 의미를 추출하고, 백엔드가 검증 가능한 데이터로 판단한다**는 분리입니다.

이 기준으로 다음 문제를 해결했습니다.

- LLM 환각 가능성이 있는 외부 API 코드/장소 타입 판단을 백엔드로 이동
- 포괄 장소와 특정 장소를 분리해 위치 추천 정확도 개선
- Kakao API 호출을 백엔드 프록시와 Redis 공유 캐시로 제어
- AI 분석 실패에도 Todo를 잃지 않는 비동기 구조화 파이프라인 구성
- Geofence 기반 추천/알림으로 "지금 이 장소에서 할 수 있는 일"을 서비스의 중심 경험으로 제공
