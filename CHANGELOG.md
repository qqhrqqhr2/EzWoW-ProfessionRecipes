# Changelog - EzWoW - Profession Recipes

## v1.6.1
- 드래그 시 마우스 포인터와 아이콘/프레임 좌표가 어긋나거나 벌어지는 스케일 오차(`EffectiveScale`) 및 초기 점프 현상 수정
- **모듈 구조 재설계 (`Core/`, `Data/`, `Modules/`, `UI/`) 및 인덱싱 최적화**:
  - `Core/Init.lua`, `Core/Locales.lua`, `Core/UIKit.lua`, `Data/RecipeData.lua`(2,232개 제조법)
  - `Modules/RecipeIndex.lua`(역방향 재료 인덱스 및 통합 검색 엔진), `Modules/QuickAction.lua`(원클릭 보안 액션 버튼)
  - `UI/RecipeBrowser.lua`, `UI/OptionsWindow.lua`
- **신규 연동 및 편의 기능**:
  - 제조법 및 재료 아이템 우클릭 시 `EzWoW-MapFinder`를 호출해 판매 상인·퀘스트·채집 위치를 월드맵에서 즉시 검색하는 기능 추가
  - 단독 창 열람 시 12개 전문 기술을 즉시 오갈 수 있는 전환 스위처 바 보강
  - 슬래시 명령어 `/ezpr`, `/제조법`, `/전문기술` 및 `EzWoW_ProfessionRecipesDB` 정비

## v1.6.0
- 원클릭 가방 아이템 실행(`Modules/QuickAction.lua`) 내장: 보조키(`Alt` / `Alt+Ctrl` / `Alt+Shift` / `끄기`) + 좌클릭으로 마력 추출, 자물쇠 따기(거래창 포함), 해골 열쇠/잠금 해제 두루마리, 포에버 두루마리 해독, 사냥꾼 야수 먹이 주기 지원
- 8개 국어(`Auto` 포함) 실시간 전환 및 `EzWoWStyle` 다크 테마 적용

## v1.5.1
- 제조법 74개 및 한·영 아이템 명칭, 필요 숙련도, 상인의 호의 가격, 진영 전용 제조법(얼라이언스 113개 / 호드 22개) 필터 반영
