#include <Foundation/Foundation.h>
#include <Metal/Metal.h>
#include <MetalKit/MetalKit.h>
#include <map>
#include <set>
#include <unordered_map>
#include <unordered_set>
#include <vector>

#import "imgui/AovWidgets.h"
#import "imgui/fontAwesome.h"
#import "imgui/imgui.h"
#import "imgui/imgui_impl_metal.h"
#import "imgui/stb_image.h"
#import "imgui/zzz.h"
#import "load/ImGuiDrawView.h"

#import "hook/Macros.h"
#import "hook/hook.h"
#import "hook/il2cpp-aov-1.61.h"

#import "helper/ModFile.h"
#import "helper/Obfuscate.h"
#import "helper/Obfuscatee.h"
#import "helper/Unity.h"
#import "helper/VideoSanh.h"

static CGFloat _cachedScreenW = 0, _cachedScreenH = 0, _cachedScreenScale = 0;
static inline void CacheScreenMetrics() {
  static dispatch_once_t tok;
  dispatch_once(&tok, ^{
    _cachedScreenW = [UIScreen mainScreen].bounds.size.width;
    _cachedScreenH = [UIScreen mainScreen].bounds.size.height;
    _cachedScreenScale = [UIScreen mainScreen].scale;
  });
}
#undef kWidth
#undef kHeight
#undef kScale
#define kWidth _cachedScreenW
#define kHeight _cachedScreenH
#define kScale _cachedScreenScale
#define UF "Frameworks/UnityFramework.framework/UnityFramework"
#define ANO "Frameworks/anogs.framework/anogs"
#define MethodOffset(dll, ns, cls, method)                                     \
  Unity::FindMethodOffset(OBFUSCATE(dll), OBFUSCATE(ns), OBFUSCATE(cls),       \
                          OBFUSCATE(method))
#define MethodAddr(dll, ns, cls, method)                                       \
  ({                                                                           \
    uint64_t _off = MethodOffset(dll, ns, cls, method);                        \
    _off ? getRealOffset(_off) : 0;                                            \
  })
#define MethodAddrN(dll, ns, cls, method, nparams)                             \
  ({                                                                           \
    uint64_t _off =                                                            \
        Unity::FindMethodOffsetN(OBFUSCATE(dll), OBFUSCATE(ns),                \
                                 OBFUSCATE(cls), OBFUSCATE(method), nparams);  \
    _off ? getRealOffset(_off) : 0;                                            \
  })
#define FieldOffset(dll, ns, cls, field)                                       \
  Unity::FindFieldOffset(OBFUSCATE(dll), OBFUSCATE(ns), OBFUSCATE(cls),        \
                         OBFUSCATE(field))

#define MetadataUsageAddr(dll, ns, cls, method)                                \
  Unity::FindMetadataUsage(OBFUSCATE(dll), OBFUSCATE(ns), OBFUSCATE(cls),      \
                           OBFUSCATE(method))

#define PatchBytes(offset, hex) ActiveCodePatch(UF, offset, (char *)(hex))

#define PatchBytesANO(offset, hex) ActiveCodePatch(ANO, offset, (char *)(hex))

#define timer(sec, block)                                                      \
  dispatch_after(                                                              \
      dispatch_time(DISPATCH_TIME_NOW, (int64_t)(sec * NSEC_PER_SEC)),         \
      dispatch_get_main_queue(), block)

#ifndef USECODEVA
#define USECODEVA 0
#endif

#if USECODEVA
#import "hook/Ryoma.h"
#define HookMethod(dll, ns, cls, method, hookFn, origFn)                       \
  {                                                                            \
    NSString *result_##origFn = StaticInlineHookPatch(                         \
        UF, MethodOffset(dll, ns, cls, method), nullptr);                      \
    if (result_##origFn) {                                                     \
      *(void **)(&origFn) = StaticInlineHookFunction(                          \
          UF, MethodOffset(dll, ns, cls, method), (void *)hookFn);             \
    }                                                                          \
  }
#define VaPatchBytes(offset, hex)                                              \
  StaticInlineHookPatch(UF, offset, (char *)(hex))
#define VaANO(offset, hex) StaticInlineHookPatch(ANO, offset, (char *)(hex))
#else
#import "hook/RyomaTF.h"
#undef HookMethod
#define HookMethod(dll, ns, cls, method, hookFn, origFn)                       \
  {                                                                            \
    uint64_t _off = MethodOffset(dll, ns, cls, method);                        \
    if (_off) {                                                                \
      *(void **)(&origFn) =                                                    \
          StaticInlineHookFunction(UF, _off, (void *)hookFn);                  \
    }                                                                          \
  }
#define VaPatchBytes(offset, hex) ((void)0)
#define VaANO(offset, hex) ((void)0)
#endif

#ifndef DEBUG_AIM_ANHVU
#define DEBUG_AIM_ANHVU 0
#endif
#if DEBUG_AIM_ANHVU
#define LOG_ANHVU(fmt, ...) NSLog((@"ANHVU " fmt), ##__VA_ARGS__)
#else
#define LOG_ANHVU(fmt, ...)
#endif
#pragma mark - Types
struct EquipSkill {
  int id, cooldown, index;
};
enum EquipID {
  CauBangSuong = 1242,
  ThuanNhamThach = 1340,
  ThuongKhungKiem = 1149,
  GiapHoiSinh = 1337,
  LiemDoatMenh = 11271,
  HerculesThinhNo = 1328,
  CungTaMa = 1145,
  XaNhatCung = 1148,
  DaiDiaThanKhien = 16211,
  DaiDiaMaNhan = 16212,
  DaiDiaThanToc = 16213,
  DaiDiaMoTroi = 16214,
  DaiDiaHoiHuyet = 16215,
  LietHoaThanKhien = 16231,
  LietHoaMaNhan = 16232,
  LietHoaThanToc = 16233,
  LietHoaMoTroi = 16234,
  LietHoaHoiHuyet = 16235,
};
struct ItemData {
  int stt, id, cost, sellPrice, cd, lastSold, cdRemain, index, lastbuy;
  bool shouldBuy;
  int cdmax;
};
#pragma mark - Interface
@interface ImGuiDrawView () <MTKViewDelegate>
@property(nonatomic, strong) id<MTLDevice> device;
@property(nonatomic, strong) id<MTLCommandQueue> commandQueue;
@property(nonatomic, strong) UIButton *aimToggleBtn;
@property(nonatomic, strong) UIButton *autoToggleBtn;
@property(nonatomic, strong) UIButton *autoTTToggleBtn;
@property(nonatomic, strong) UIButton *menuToggleBtn;
@end

static std::unordered_map<int, id<MTLTexture>> g_btIconTextures;
static std::unordered_map<int, id<MTLTexture>> g_ultIconTextures;
static std::unordered_map<int, id<MTLTexture>> g_c1IconTextures;
static std::unordered_map<int, id<MTLTexture>> g_c2IconTextures;
@implementation ImGuiDrawView
#pragma mark - Globals
static bool MenDeal = false;
static bool g_initReady = false; // true khi initial_setup() hoàn thành
static bool showQuickToggle = false;
static bool qtShowAim = true;
static bool qtShowAuto = true;
static bool qtShowAutoTT = true;
static bool g_langVI = true;
#define LS(vi, en)                                                             \
  (g_langVI ? (const char *)OBFUSCATE(vi) : (const char *)OBFUSCATE(en))
bool HackMap = false, lockCam = false, unlockSkin = false, AimbotEnable = false;
bool muaitem = false, doiitem = false, fullslot = false, checktime = false;
bool hiencooldowns = false;
float espIconScale = 1.0f;
float espOffsetX = 0.0f;
float espOffsetY = 0.0f;
float CameraZoom = 1.2f;
bool AutoBS = false;
bool AutoBP = false;
bool AutoTT = false;
bool AutoWin = false;
int AutoTTMode = 0; // 0 = tất cả quái, 1 = chỉ Rồng Tà
float AutoBSHp = 40.0f;
float AutoBPHp = 20.0f;
bool fakerank = false;
bool ChangeName = false;
int NameMode = 0; // 0=gốc 2=tất cả 3=tên tướng 4=chỉ mình
std::string customname = "Name";
int topnumber = 1;  // top 1 – 100
int rankStar = 500; // điểm sao (0-1200)
struct RewardOption {
  const char *name;
  int dwIsTop;
  int dwAdCode;
};
static const RewardOption rewardOptions[] = {
    {"Không", 0, 0},   {"Cục Vàng", 6, 1},       {"Cục Đỏ", 5, 0},
    {"Cục Tím", 4, 0}, {"Cục Xanh Dương", 3, 0}, {"Cục Xanh Lá", 2, 0},
    {"Cục Xóm", 1, 0},
};
static const int kRewardOptionCount =
    (int)(sizeof(rewardOptions) / sizeof(rewardOptions[0]));
static int rewardOptionIndex = 1; // default: Vàng
bool logoutTriggered = false;
bool showLogoutConfirm = false;
double logoutTime = 0;
bool deleteModTriggered = false;
bool showDeleteModConfirm = false;
double deleteModTime = 0;

// ─── RenderConfirmAction ─────────────────────
static bool RenderConfirmAction(const char *label, const char *confirmMsg,
                                const char *successMsg, bool &showConfirm,
                                bool &triggered, double &triggerTime,
                                const char *icon = nullptr) {
  ImGui::PushID(label);
  bool confirmed = false;

  if (triggered) {
    // ── Success state: green text + shrinking progress bar ──
    ImGui::Spacing();
    ImDrawList *dl = ImGui::GetWindowDrawList();
    ImVec2 p = ImGui::GetCursorScreenPos();
    float barW = ImGui::GetContentRegionAvail().x;
    // success icon + text
    char buf[256];
    snprintf(buf, sizeof(buf), ICON_FA_CHECK_CIRCLE "  %s", successMsg);
    ImVec2 tSz = ImGui::CalcTextSize(buf);
    float cx = p.x + (barW - tSz.x) * 0.5f;
    dl->AddText(ImVec2(cx, p.y), IM_COL32(45, 210, 90, 245), buf);
    ImGui::Dummy(ImVec2(barW, tSz.y + 6.f));
    // progress bar
    ImVec2 bp = ImGui::GetCursorScreenPos();
    float elapsed = (float)(CACurrentMediaTime() - triggerTime);
    float frac = aov_clamp(elapsed / 3.f, 0.f, 1.f);
    dl->AddRectFilled(bp, ImVec2(bp.x + barW, bp.y + 3.f),
                      IM_COL32(30, 35, 55, 160), 2.f);
    dl->AddRectFilled(bp, ImVec2(bp.x + barW * (1.f - frac), bp.y + 3.f),
                      IM_COL32(45, 190, 80, 220), 2.f);
    ImGui::Dummy(ImVec2(barW, 5.f));
    if (elapsed > 3.0)
      exit(0);
  } else if (showConfirm) {
    // ── Confirm state: warning text + OK / Cancel ──
    ImGui::Spacing();
    ImDrawList *dl = ImGui::GetWindowDrawList();
    ImVec2 p = ImGui::GetCursorScreenPos();
    float fullW = ImGui::GetContentRegionAvail().x;
    char buf[256];
    snprintf(buf, sizeof(buf), ICON_FA_EXCLAMATION_TRIANGLE "  %s", confirmMsg);
    ImVec2 tSz = ImGui::CalcTextSize(buf);
    float cx = p.x + (fullW - tSz.x) * 0.5f;
    dl->AddText(ImVec2(cx, p.y), IM_COL32(255, 210, 50, 240), buf);
    ImGui::Dummy(ImVec2(fullW, tSz.y + 6.f));

    float halfW = ImGui::GetContentRegionAvail().x * 0.5f - 4.f;
    if (AovButton(LS("Xác Nhận##cfm", "Confirm##cfm"), ICON_FA_CHECK, 2,
                  ImVec2(halfW, 32.f))) {
      confirmed = true;
    }
    ImGui::SameLine(0, 8.f);
    if (AovButton(LS("Hủy##ccl", "Cancel##ccl"), ICON_FA_TIMES, 1,
                  ImVec2(halfW, 32.f))) {
      showConfirm = false;
    }
  } else {
    // ── Default state: danger button ──
    if (AovButton(label, icon, 1)) {
      showConfirm = true;
    }
  }

  ImGui::PopID();
  return confirmed;
}
bool enableSkin = false;
int cspHeroID = 0, cspSkinID = 0;
struct SSSSkinEntry {
  int heroID;
  int skinID;
};
static std::vector<SSSSkinEntry> gSSSkins;
static int g_sss_fix_skin = 0;
static bool IsSSSSkin(int heroID, int skinID) {
  for (auto &e : gSSSkins) {
    if (e.heroID == heroID && e.skinID == skinID) {
      g_sss_fix_skin = (heroID == 599 && skinID == 1) ? 2 : 1;
      return true;
    }
  }
  return false;
}
uint64_t playerUid = 0;
int buttonID = 0, broadcastID = 0, soldierID = 0;
int selectedButtonIndex = 0, selectedBroadcastIndex = 0,
    selectedSoldierIndex = 0;
struct ModEntry {
  std::string name;
  int id;
};
static std::vector<ModEntry> gButtons = {{"Mặc Định", 0}};
static std::vector<ModEntry> gBroadcast = {{"Mặc Định", 0}};
static std::vector<ModEntry> gSoldier = {{"lính thường", 0}};
static bool gOnlineConfigLoaded = false;
static void FetchOnlineConfig() {
  NSURL *url =
      [NSURL URLWithString:NSOBFUSCATE("https://aov.anhvu.cc/api/config")];
  NSURLSession *session = [NSURLSession sharedSession];
  [[session dataTaskWithURL:url
          completionHandler:^(NSData *data, NSURLResponse *, NSError *err) {
            if (err || !data)
              return;
            NSError *jsonErr = nil;
            NSDictionary *root =
                [NSJSONSerialization JSONObjectWithData:data
                                                options:0
                                                  error:&jsonErr];
            if (jsonErr || ![root isKindOfClass:[NSDictionary class]])
              return;
            auto parseArray = [](NSArray *arr) {
              std::vector<ModEntry> v;
              if (![arr isKindOfClass:[NSArray class]])
                return v;
              for (NSDictionary *item in arr) {
                NSString *n = item[NSOBFUSCATE("name")];
                NSNumber *d = item[NSOBFUSCATE("id")];
                if (n && d)
                  v.push_back({[n UTF8String], [d intValue]});
              }
              return v;
            };
            auto newButtons = parseArray(root[NSOBFUSCATE("buttons")]);
            auto newBroadcast = parseArray(root[NSOBFUSCATE("billboards")]);
            auto newSoldier = parseArray(root[NSOBFUSCATE("soldierSkins")]);
            std::vector<SSSSkinEntry> newSSSkins;
            NSDictionary *excluded = root[NSOBFUSCATE("excludedSkins")];
            if ([excluded isKindOfClass:[NSDictionary class]]) {
              for (NSString *heroKey in excluded) {
                int hid = [heroKey intValue];
                NSArray *skinArr = excluded[heroKey];
                if (![skinArr isKindOfClass:[NSArray class]])
                  continue;
                for (NSNumber *snum in skinArr)
                  newSSSkins.push_back({hid, [snum intValue]});
              }
            }
            dispatch_async(dispatch_get_main_queue(), ^{
              if (!newButtons.empty())
                gButtons = std::move(newButtons);
              if (!newBroadcast.empty())
                gBroadcast = std::move(newBroadcast);
              if (!newSoldier.empty())
                gSoldier = std::move(newSoldier);
              if (!newSSSkins.empty())
                gSSSkins = std::move(newSSSkins);
              auto findIdx = [](const std::vector<ModEntry> &v,
                                int savedId) -> int {
                for (int i = 0; i < (int)v.size(); i++)
                  if (v[i].id == savedId)
                    return i;
                return 0;
              };
              selectedButtonIndex = findIdx(gButtons, buttonID);
              selectedBroadcastIndex = findIdx(gBroadcast, broadcastID);
              selectedSoldierIndex = findIdx(gSoldier, soldierID);
              gOnlineConfigLoaded = true;
            });
          }] resume];
}
void *CBattleSystem_instance = nullptr;
bool ingame = false;
void *myActorLinker = nullptr, *myLactorRoot = nullptr;
void *enemyActorLinker = nullptr, *enemyLactorRoot = nullptr;
bool isFliped = false;
size_t ActorLinker_ObjLinker = 0;
size_t ActorConfig_ConfigID = 0;
size_t LActorRoot_ObjLinker = 0;
size_t LActorRoot_ValueComponent = 0;
size_t LActorRoot_ActorControl = 0;
size_t ActorLinker_ValueComponent = 0;
size_t ActorLinker_HudControl = 0;
static int myObjID = 0;
size_t LActorRoot_SkillControl = 0;
size_t bt_SkillSlot_CurSkillCD = 0;
size_t bt_BaseSkill_SkillID = 0;
size_t bt_SkillSlot_skillLevel = 0;
static void *(*bt_GetSkillSlot)(void *, int) = nullptr;
static void *(*bt_get_RealSkillObj)(void *) = nullptr;
static inline int GetObscuredIntValue(uint64_t addr) {
  return *(int *)(addr + 4) ^ *(int *)(addr + 0);
}
struct SkillInfo {
  int skillcd;
  int skillID;
  int skillLevel;
};
static SkillInfo Skillcd_bt(void *skillComp, int slot) {
  SkillInfo r = {0, 0, 0};
  if (!skillComp || !bt_GetSkillSlot)
    return r;
  void *slotObj = bt_GetSkillSlot(skillComp, slot);
  if (!slotObj)
    return r;
  if (bt_SkillSlot_CurSkillCD)
    r.skillcd =
        GetObscuredIntValue((uint64_t)slotObj + bt_SkillSlot_CurSkillCD);
  if (bt_SkillSlot_skillLevel)
    r.skillLevel = *(int *)((uint64_t)slotObj + bt_SkillSlot_skillLevel);
  if (bt_get_RealSkillObj) {
    void *real = bt_get_RealSkillObj(slotObj);
    if (real && bt_BaseSkill_SkillID)
      r.skillID = *(int *)((uint64_t)real + bt_BaseSkill_SkillID);
  }
  return r;
}
struct AimbotTargetInfo {
  Vector3 myPos;
  Vector3 enemyPos;
  Vector3 moveForward;
  int currentSpeed;
  float bullettime;
  float Ranger;
  int ConfigID;
  int myHeroConfigID;
  void *enemyActor;
  void *enemyLactor;
};
static AimbotTargetInfo EnemyTarget;
static int skillSlot = 0;
static int tagid = 0;
static float Rangeskill1 = 0.0f;
static float Rangeskill2 = 0.0f;
static float Rangeskill3 = 0.0f;
static std::unordered_set<int> targetConfigIDs = {};
static int targetIdInput = 0;
static int selectedTargetIndex = -1;
static int aimType = 0;
static bool aimRequireVisible = false;
struct AimHeroConfig {
  int heroID;
  float bt[4];
};
static const AimHeroConfig kAimHeroConfigs[] = {
    // heroID,  {0,     slot1,  slot2,  slot3  }  // name [id]
    {196, {0, 0.00f, 0.44f, 0.00f}}, // Elsu
    {545, {0, 0.60f, 0.77f, 0.00f}}, // Yue
    {142, {0, 0.84f, 0.87f, 0.00f}}, // Natalya
    {106, {0, 1.00f, 0.37f, 0.00f}}, // Krixi
    {108, {0, 0.00f, 0.80f, 0.00f}}, // Gildur
    {111, {0, 0.00f, 0.00f, 0.80f}}, // Violet
    {118, {0, 0.87f, 0.00f, 0.00f}}, // Alice
    {121, {0, 0.00f, 0.57f, 0.00f}}, // Marja
    {124, {0, 0.77f, 0.40f, 1.17f}}, // Ignis
    {127, {0, 0.84f, 0.00f, 1.12f}}, // Azzen'Ka
    {130, {0, 1.04f, 0.00f, 0.00f}}, // Airi
    {136, {0, 1.04f, 0.00f, 0.00f}}, // Ilumia
    {152, {0, 0.37f, 1.14f, 0.00f}}, // Điêu Thuyền
    {153, {0, 0.00f, 0.67f, 0.00f}}, // Kaine
    {157, {0, 0.00f, 0.75f, 0.00f}}, // Raz
    {168, {0, 0.00f, 0.00f, 1.04f}}, // Lumburr
    {169, {0, 1.67f, 0.00f, 0.00f}}, // Slimz
    {174, {0, 0.55f, 0.00f, 0.00f}}, // Stuart
    {175, {0, 0.00f, 0.67f, 0.00f}}, // Grakk
    {195, {0, 0.00f, 0.27f, 0.00f}}, // Enzo
    {206, {0, 0.90f, 0.00f, 0.00f}}, // Charlotte
    {501, {0, 0.00f, 0.70f, 0.77f}}, // Tel'Annas
    {504, {0, 0.00f, 0.44f, 0.00f}}, // Wonder Woman
    {510, {0, 0.40f, 0.60f, 0.00f}}, // Liliana
    {521, {0, 0.44f, 0.00f, 0.00f}}, // Florentino
    {526, {0, 0.70f, 0.00f, 0.00f}}, // Ishar
    {529, {0, 0.00f, 0.72f, 0.00f}}, // Volkath
    {538, {0, 0.87f, 0.00f, 0.00f}}, // Iggy
    {540, {0, 0.74f, 0.00f, 0.00f}}, // Bright
    {563, {0, 0.87f, 0.00f, 0.00f}}, // Heino
    {567, {0, 0.64f, 0.00f, 0.00f}}, // Erin
};
static std::unordered_set<int> aimHeroIDs = []() {
  std::unordered_set<int> s;
  for (const auto &c : kAimHeroConfigs)
    s.insert(c.heroID);
  return s;
}();
static inline const AimHeroConfig *FindAimHeroCfg(int heroID) {
  for (const auto &c : kAimHeroConfigs)
    if (c.heroID == heroID)
      return &c;
  return nullptr;
}
struct EnemyEntry {
  void *lactor;
  void *actorLinker;
  int objID;
  int configID;
  int lastSeenFrame;
  int hp;
  int hpTotal;
  int maxC1CD;
  int maxC2CD;
  int maxUltCD;
  int maxBtCD;
};
static EnemyEntry enemyEntries[16] = {};
static int enemyFrame = 0;
static int s_myPlayerCamp = 0;
// All monsters that can be smited
static const int kMonsterConfigIDs[] = {7010,  7011, 7012, 70093,
                                        70092, 7024, 7009};
static const int kMonsterConfigIDCount = 7;
// Rồng Tà only (ids that are evil dragon variants)
static const int kDragonConfigIDs[] = {7012, 70093, 70092, 7024, 7009};
static const int kDragonConfigIDCount = 5;
struct MonsterEntry {
  void *actorLinker;
  int configID;
  int lastSeenFrame;
};
static MonsterEntry monsterEntries[8] = {};
uint16_t ItemID[8];
int solan = 0, lastId = -1;
const int COMBO_COUNT = 8;
static int selectedIndices[COMBO_COUNT] = {0, 1, 2, 3, 4, 5, 6, 7};
static bool isEnabled[COMBO_COUNT] = {true, true, true, true,
                                      true, true, true, true};
vector<ItemData> items = {
    {1, EquipID::GiapHoiSinh, 2400, 1440, 0, 0, 0, -1, 0, true, 150},
    {2, EquipID::CauBangSuong, 2200, 1320, 0, 0, 0, -1, 0, true, 75},
    {3, EquipID::LiemDoatMenh, 2000, 1200, 0, 0, 0, -1, 0, true, 120},
    {4, EquipID::ThuongKhungKiem, 2120, 1272, 0, 0, 0, -1, 0, true, 90},
    {5, EquipID::ThuanNhamThach, 1980, 1188, 0, 0, 0, -1, 0, true, 60},
    {6, EquipID::HerculesThinhNo, 2080, 1248, 0, 0, 0, -1, 0, true, 60},
    {7, EquipID::CungTaMa, 2250, 1350, 0, 0, 0, -1, 0, true, 60},
    {8, EquipID::XaNhatCung, 2000, 1200, 0, 0, 0, -1, 0, true, 60},
};
id<MTLTexture> itemIconTextures[8] = {nullptr};
int (*GetGameTime)(void *);
void *(*get_talentSystem)(void *);
int (*GetGoldCoinInBattle)(void *);
void (*SendBuyEquipFrameCommand)(void *, int, bool);
void (*SendSellEquipFrameCommand)(void *, int);
void (*SendPlayerChoseEquipSkillCommand)(void *, int);
int (*GetEquipActiveSkillCD)(void *, int);
int (*GetTalentCDTime)(void *, int);
void *(*LEquipComponent_GetEquips)(void *);
bool (*ActorLinker_IsHostPlayer)(void *);
int (*ActorLinker_COM_PLAYERCAMP)(void *);
Vector3 (*ActorLinker_getPosition)(void *);
int (*ActorLinker_get_ObjID)(void *);
bool (*ActorLinker_get_bVisible)(void *);
int (*ActorLinker_ActorTypeDef)(void *);
int (*ValueLinkerComponent_get_actorEp)(void *);
int (*ValueLinkerComponent_get_actorSoulLevel)(void *);
void *(*LActorRoot_LHeroWrapper)(void *);
int (*LActorRoot_COM_PLAYERCAMP)(void *);
int (*LActorRoot_get_ObjID)(void *);
VInt3 (*LActorRoot_get_location)(void *);
VInt3 (*LActorRoot_get_forward)(void *);
void *(*LActorRoot_get_PlayerMovement)(void *);
int (*get_speed)(void *);
int (*ValuePropertyComponent_get_actorHp)(void *);
int (*ValuePropertyComponent_get_actorHpTotal)(void *);
bool (*LObjWrapper_get_IsDeadState)(void *);
void (*CSkillButtonManager_Update)(void *);
int (*GetCurSkillSlotType)(void *);
void (*SkillSlot_LateUpdate)(void *, int);
static bool (*g_CanRequestSkill)(void *, int) = nullptr;
static bool (*g_RequestUseSkillSlot)(void *, int, int, unsigned int,
                                     int) = nullptr;
static bool (*SkillSlot_RequestUseSkill)(void *) = nullptr;
static bool (*SkillSlot_ReadyUseSkill)(void *, bool) = nullptr;
static void *g_Req5 = nullptr;
size_t SkillSlot_skillIndicator = 0;
size_t SkillSlot_SlotType = 0;
size_t SkillControlIndicator_curindicatorDistance = 0;
size_t SkillControlIndicator_skillSlot = 0;
void *(*Camera_get_main)();
Vector3 (*Camera_WorldToScreenPoint)(void *, Vector3);
Vector3 (*Camera_WorldToViewportPoint)(void *, Vector3);
bool (*SetVisible)(void *, int, bool, bool);
float (*GetZoomRate)(void *);
void (*CameraSystem_Update_orig)(void *);
void (*OnCameraHeightChanged)(void *);
bool (*get_IsHostProfile)(void *);
void (*FrameSyncRet)(void *);
void (*SyncReportRet)(void *);
bool (*IsHaveHeroSkin)(void *, int, int, bool);
bool (*CanUseSkin)(void *, int, int);
int (*GetHeroWearSkinId)(void *, int);
void *(*UnpackOrig)(void *, void *, unsigned int);
void (*OnClickSelectHeroSkin_orig)(void *, int, int);
void (*RefreshHeroPanel)(void *, bool, bool, bool);
void (*RefreshSelectHeroInfo)(void *);
void (*HeroSelect_OnSkinSelect_orig)(void *, void *);
static void *(*_GetHeroSkin)(int heroID, int skinID) = nullptr;
static bool (*_IsSkinAvailable)(void *, int skinCfgId) = nullptr;
static int (*old_GetSkinCfg)(int heroId, int skinId) = nullptr;
static uint (*old_GetHeroSkinID)(uint heroId, uint skinId) = nullptr;
static void *(*_GetSkinOrig)(void *, int skinId) = nullptr;
static void *(*_Unpack_CommonInfo)(void *, void *, unsigned int) = nullptr;
void (*LobbyLogic_Updatelogic_orig)(void *, int);
void *(*LobbyLogic_PlayerBase_orig)(void *, unsigned int);
void (*CBattleSystem_Update)(void *);
void (*LActorRoot_UpdateLogic)(void *, int);
void (*ActorLinker_Update)(void *);
void (*ForceKillCrystal)(int camp);
static void *(*get_VHostLogic)() = nullptr;
struct MonoString;
void (*SetPlayerName)(void *, MonoString *, MonoString *, bool,
                      MonoString *) = nullptr;
#pragma mark - Helpers
id<MTLTexture> LoadImageFromMemory(id<MTLDevice> device, unsigned char *data,
                                   size_t size) {
  CFDataRef cfData = CFDataCreate(kCFAllocatorDefault, data, size);
  CGDataProviderRef provider = CGDataProviderCreateWithCFData(cfData);
  CGImageRef cgImage = CGImageCreateWithPNGDataProvider(
      provider, NULL, false, kCGRenderingIntentDefault);
  CFRelease(cfData);
  CGDataProviderRelease(provider);
  if (!cgImage)
    return nil;
  NSError *err = nil;
  MTKTextureLoader *loader = [[MTKTextureLoader alloc] initWithDevice:device];
  id<MTLTexture> tex =
      [loader newTextureWithCGImage:cgImage
                            options:@{
                              MTKTextureLoaderOptionSRGB : @(NO)
                            }
                              error:&err];
  CGImageRelease(cgImage);
  return err ? nil : tex;
}
#include "icon/UltHeroIconLib.h"
#pragma mark - UIKit Quick Toggle
static UIImage *UIImageFromRawPNG(const unsigned char *data, size_t len) {
  NSData *nsData = [NSData dataWithBytes:data length:len];
  return [UIImage imageWithData:nsData];
}
- (void)setupQuickToggleButtons {
  UIImage *aimImg = UIImageFromRawPNG((const unsigned char *)Aim_icon_data,
                                      Aim_icon_data_len);
  UIImage *autoImg = UIImageFromRawPNG(
      (const unsigned char *)AutoEquip_icon_data, AutoEquip_icon_data_len);
  const CGFloat kBtnSize = 52.0;
  NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
  CGFloat screenH = UIScreen.mainScreen.bounds.size.height;
  CGFloat aimX = [d objectForKey:NSOBFUSCATE("qtX")]
                     ? [d floatForKey:NSOBFUSCATE("qtX")]
                     : 30.0;
  CGFloat aimY = [d objectForKey:NSOBFUSCATE("qtY")]
                     ? [d floatForKey:NSOBFUSCATE("qtY")]
                     : screenH * 0.42;
  CGFloat autoX = [d objectForKey:NSOBFUSCATE("qtX2")]
                      ? [d floatForKey:NSOBFUSCATE("qtX2")]
                      : 30.0;
  CGFloat autoY = [d objectForKey:NSOBFUSCATE("qtY2")]
                      ? [d floatForKey:NSOBFUSCATE("qtY2")]
                      : screenH * 0.42 + kBtnSize + 10;
  self.aimToggleBtn = [UIButton buttonWithType:UIButtonTypeCustom];
  self.aimToggleBtn.frame = CGRectMake(0, 0, kBtnSize, kBtnSize);
  self.aimToggleBtn.center = CGPointMake(aimX, aimY);
  self.aimToggleBtn.layer.cornerRadius = kBtnSize / 2.0;
  self.aimToggleBtn.clipsToBounds = YES;
  [self.aimToggleBtn setImage:aimImg forState:UIControlStateNormal];
  self.aimToggleBtn.alpha = AimbotEnable ? 1.0 : 0.35;
  [self.aimToggleBtn addTarget:self
                        action:@selector(aimBtnTapped:)
              forControlEvents:UIControlEventTouchUpInside];
  UIPanGestureRecognizer *pan1 =
      [[UIPanGestureRecognizer alloc] initWithTarget:self
                                              action:@selector(btnPanned:)];
  [self.aimToggleBtn addGestureRecognizer:pan1];
  self.aimToggleBtn.hidden = !(showQuickToggle && qtShowAim);
  UIWindow *window = [UIApplication sharedApplication].windows.firstObject;
  [window addSubview:self.aimToggleBtn];
  self.autoToggleBtn = [UIButton buttonWithType:UIButtonTypeCustom];
  self.autoToggleBtn.frame = CGRectMake(0, 0, kBtnSize, kBtnSize);
  self.autoToggleBtn.center = CGPointMake(autoX, autoY);
  self.autoToggleBtn.layer.cornerRadius = kBtnSize / 2.0;
  self.autoToggleBtn.clipsToBounds = YES;
  [self.autoToggleBtn setImage:autoImg forState:UIControlStateNormal];
  self.autoToggleBtn.alpha = muaitem ? 1.0 : 0.35;
  [self.autoToggleBtn addTarget:self
                         action:@selector(autoBtnTapped:)
               forControlEvents:UIControlEventTouchUpInside];
  UIPanGestureRecognizer *pan2 =
      [[UIPanGestureRecognizer alloc] initWithTarget:self
                                              action:@selector(btnPanned:)];
  [self.autoToggleBtn addGestureRecognizer:pan2];
  self.autoToggleBtn.hidden = !(showQuickToggle && qtShowAuto);
  [window addSubview:self.autoToggleBtn];
  UIImage *autoTTImg =
      UIImageFromRawPNG((const unsigned char *)autott_data, autott_data_len);
  CGFloat autoTTX = [d objectForKey:NSOBFUSCATE("qtX3")]
                        ? [d floatForKey:NSOBFUSCATE("qtX3")]
                        : 30.0;
  CGFloat autoTTY = [d objectForKey:NSOBFUSCATE("qtY3")]
                        ? [d floatForKey:NSOBFUSCATE("qtY3")]
                        : screenH * 0.42 + (kBtnSize + 10) * 2;
  self.autoTTToggleBtn = [UIButton buttonWithType:UIButtonTypeCustom];
  self.autoTTToggleBtn.frame = CGRectMake(0, 0, kBtnSize, kBtnSize);
  self.autoTTToggleBtn.center = CGPointMake(autoTTX, autoTTY);
  self.autoTTToggleBtn.layer.cornerRadius = kBtnSize / 2.0;
  self.autoTTToggleBtn.clipsToBounds = YES;
  [self.autoTTToggleBtn setImage:autoTTImg forState:UIControlStateNormal];
  self.autoTTToggleBtn.alpha = AutoTT ? 1.0 : 0.35;
  [self.autoTTToggleBtn addTarget:self
                           action:@selector(autoTTBtnTapped:)
                 forControlEvents:UIControlEventTouchUpInside];
  UIPanGestureRecognizer *pan3 =
      [[UIPanGestureRecognizer alloc] initWithTarget:self
                                              action:@selector(btnPanned:)];
  [self.autoTTToggleBtn addGestureRecognizer:pan3];
  self.autoTTToggleBtn.hidden = !(showQuickToggle && qtShowAutoTT);
  [window addSubview:self.autoTTToggleBtn];
  UIImage *menuImg = UIImageFromRawPNG(aovcheat_data, aovcheat_data_len);
  CGFloat screenW = UIScreen.mainScreen.bounds.size.width;
  CGFloat menuX = [d objectForKey:NSOBFUSCATE("menuBtnX")]
                      ? [d floatForKey:NSOBFUSCATE("menuBtnX")]
                      : screenW - 36.0;
  CGFloat menuY = [d objectForKey:NSOBFUSCATE("menuBtnY")]
                      ? [d floatForKey:NSOBFUSCATE("menuBtnY")]
                      : screenH * 0.30;
  self.menuToggleBtn = [UIButton buttonWithType:UIButtonTypeCustom];
  self.menuToggleBtn.frame = CGRectMake(0, 0, kBtnSize, kBtnSize);
  self.menuToggleBtn.center = CGPointMake(menuX, menuY);
  self.menuToggleBtn.layer.cornerRadius = kBtnSize / 2.0;
  self.menuToggleBtn.clipsToBounds = YES;
  [self.menuToggleBtn setImage:menuImg forState:UIControlStateNormal];
  self.menuToggleBtn.imageView.layer.cornerRadius = kBtnSize / 2.0;
  self.menuToggleBtn.imageView.clipsToBounds = YES;
  self.menuToggleBtn.alpha = 0.90;
  [self.menuToggleBtn addTarget:self
                         action:@selector(menuBtnTapped:)
               forControlEvents:UIControlEventTouchUpInside];
  UIPanGestureRecognizer *pan4 =
      [[UIPanGestureRecognizer alloc] initWithTarget:self
                                              action:@selector(btnPanned:)];
  [self.menuToggleBtn addGestureRecognizer:pan4];
  [window addSubview:self.menuToggleBtn];
}
static void HapticLight() {
  dispatch_async(dispatch_get_main_queue(), ^{
    UISelectionFeedbackGenerator *g = [UISelectionFeedbackGenerator new];
    [g selectionChanged];
  });
}
// Bind widget haptic callback (AovWidgets.h declares AovHapticFn)
static bool _aovHapticBound = (AovHapticFn = HapticLight, true);
- (void)aimBtnTapped:(UIButton *)btn {
  AimbotEnable = !AimbotEnable;
  btn.alpha = AimbotEnable ? 1.0 : 0.35;
  SaveConfig();
  HapticLight();
}
- (void)autoBtnTapped:(UIButton *)btn {
  muaitem = !muaitem;
  btn.alpha = muaitem ? 1.0 : 0.35;
  SaveConfig();
}
- (void)autoTTBtnTapped:(UIButton *)btn {
  AutoTT = !AutoTT;
  btn.alpha = AutoTT ? 1.0 : 0.35;
  SaveConfig();
  HapticLight();
}
- (void)menuBtnTapped:(UIButton *)btn {
  MenDeal = !MenDeal;
  UIImpactFeedbackGenerator *hap = [[UIImpactFeedbackGenerator alloc]
      initWithStyle:UIImpactFeedbackStyleMedium];
  [hap prepare];
  [hap impactOccurred];
  CABasicAnimation *pulse =
      [CABasicAnimation animationWithKeyPath:@"transform.scale"];
  pulse.fromValue = @(1.0);
  pulse.toValue = @(0.82);
  pulse.duration = 0.10;
  pulse.autoreverses = YES;
  pulse.timingFunction = [CAMediaTimingFunction
      functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
  [btn.layer addAnimation:pulse forKey:@"menuPulse"];
}
- (void)btnPanned:(UIPanGestureRecognizer *)pan {
  UIButton *btn = (UIButton *)pan.view;
  UIView *container = btn.superview ?: btn;
  CGPoint delta = [pan translationInView:container];
  CGPoint center = btn.center;
  center.x += delta.x;
  center.y += delta.y;
  CGSize screen = container.bounds.size;
  CGFloat half = btn.bounds.size.width / 2.0;
  center.x = MAX(half, MIN(center.x, screen.width - half));
  center.y = MAX(half, MIN(center.y, screen.height - half));
  btn.center = center;
  [pan setTranslation:CGPointZero inView:container];
  NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
  if (btn == self.aimToggleBtn) {
    [d setFloat:center.x forKey:NSOBFUSCATE("qtX")];
    [d setFloat:center.y forKey:NSOBFUSCATE("qtY")];
  } else if (btn == self.menuToggleBtn) {
    [d setFloat:center.x forKey:NSOBFUSCATE("menuBtnX")];
    [d setFloat:center.y forKey:NSOBFUSCATE("menuBtnY")];
  } else if (btn == self.autoTTToggleBtn) {
    [d setFloat:center.x forKey:NSOBFUSCATE("qtX3")];
    [d setFloat:center.y forKey:NSOBFUSCATE("qtY3")];
  } else {
    [d setFloat:center.x forKey:NSOBFUSCATE("qtX2")];
    [d setFloat:center.y forKey:NSOBFUSCATE("qtY2")];
  }
}
- (void)updateQuickToggleVisibility {
  self.aimToggleBtn.hidden = !(showQuickToggle && qtShowAim);
  self.autoToggleBtn.hidden = !(showQuickToggle && qtShowAuto);
  self.autoTTToggleBtn.hidden = !(showQuickToggle && qtShowAutoTT);
}
const char *GetLocalizedItemName(int idx) {
  static const char *n[] = {"Giáp Hồi sinh",    "Cầu Băng Sương",
                            "Liềm Đoạt Mệnh",   "Thương Khung Kiếm",
                            "Thuẫn Nham Thạch", "Hercules Thịnh Nộ",
                            "Cung Tà Ma",       "Xạ Nhật Cung"};
  return (idx >= 0 && idx < 8) ? n[idx] : "Unknown";
}
vector<ItemData> BuildSelectedItemsVector(vector<ItemData> &items, int sel[],
                                          bool en[]) {
  vector<ItemData> r;
  for (int i = 0; i < COMBO_COUNT; ++i) {
    int idx = sel[i];
    if (idx >= 0 && idx < COMBO_COUNT && en[idx] && idx < (int)items.size())
      r.push_back(items[idx]);
  }
  return r;
}
static inline int cdToSeconds(int ms) {
  return max(0, (int)ceil(ms / 1000.0 - 1));
}
static inline int cdToSecondsCeil(int ms) {
  return max(0, (int)ceil(ms / 1000.0));
}
static void SyncItemState(int id, int cd, int t, int idx) {
  for (auto &it : items)
    if (it.id == id) {
      it.cdRemain = cd;
      it.lastSold = t;
      it.index = idx;
      break;
    }
}
#pragma mark - Item Selection UI
void SettingItemEquip() {
  static bool init = false;
  if (!init) {
    NSArray *e = [[NSUserDefaults standardUserDefaults]
        arrayForKey:NSOBFUSCATE("itemEnabledStates")];
    if (e && e.count == COMBO_COUNT)
      for (int i = 0; i < COMBO_COUNT; ++i)
        isEnabled[i] = [e[i] boolValue];
    NSArray *s = [[NSUserDefaults standardUserDefaults]
        arrayForKey:NSOBFUSCATE("itemSelectedIndices")];
    if (s && s.count == COMBO_COUNT)
      for (int i = 0; i < COMBO_COUNT; ++i)
        selectedIndices[i] = [s[i] intValue];
    init = true;
  }
  bool stChanged = false;
  static bool idxChanged = false;
  static int order[COMBO_COUNT] = {0, 1, 2, 3, 4, 5, 6, 7};
  static bool orderInit = false;
  if (!orderInit) {
    for (int i = 0; i < COMBO_COUNT; ++i)
      order[i] = selectedIndices[i];
    orderInit = true;
  }
  for (int p = 0; p < COMBO_COUNT; ++p) {
    int idx = order[p];
    ImGui::PushID(p);
    if (itemIconTextures[idx]) {
      ImVec4 t =
          isEnabled[idx] ? ImVec4(1, 1, 1, 1) : ImVec4(.5f, .5f, .5f, .5f);
      if (ImGui::ImageButton(GetLocalizedItemName(idx),
                             (ImTextureID)(uintptr_t)itemIconTextures[idx],
                             ImVec2(20, 20), ImVec2(0, 0), ImVec2(1, 1),
                             ImVec4(0, 0, 0, 0), t)) {
        isEnabled[idx] = !isEnabled[idx];
        stChanged = true;
      }
      if (ImGui::BeginDragDropSource(ImGuiDragDropFlags_None)) {
        ImGui::SetDragDropPayload("ITEM_REORDER", &p, sizeof(int));
        ImGui::Text(OBFUSCATE("Pull %s"), GetLocalizedItemName(idx));
        ImGui::EndDragDropSource();
      }
      if (ImGui::BeginDragDropTarget()) {
        if (auto *pl = ImGui::AcceptDragDropPayload("ITEM_REORDER")) {
          int f = *(const int *)pl->Data;
          if (f != p) {
            std::swap(order[f], order[p]);
            for (int i = 0; i < COMBO_COUNT; ++i)
              selectedIndices[i] = order[i];
            idxChanged = true;
          }
        }
        ImGui::EndDragDropTarget();
      }
    } else {
      if (ImGui::Checkbox(GetLocalizedItemName(idx), &isEnabled[idx]))
        stChanged = true;
    }
    ImGui::PopID();
    if (p < COMBO_COUNT - 1)
      ImGui::SameLine();
  }
  if (stChanged) {
    NSMutableArray *a = [NSMutableArray arrayWithCapacity:COMBO_COUNT];
    for (int i = 0; i < COMBO_COUNT; ++i)
      [a addObject:@(isEnabled[i])];
    [[NSUserDefaults standardUserDefaults]
        setObject:a
           forKey:NSOBFUSCATE("itemEnabledStates")];
    [[NSUserDefaults standardUserDefaults] synchronize];
  }
  if (idxChanged) {
    NSMutableArray *a = [NSMutableArray arrayWithCapacity:COMBO_COUNT];
    for (int i = 0; i < COMBO_COUNT; ++i)
      [a addObject:@(selectedIndices[i])];
    [[NSUserDefaults standardUserDefaults]
        setObject:a
           forKey:NSOBFUSCATE("itemSelectedIndices")];
    [[NSUserDefaults standardUserDefaults] synchronize];
    idxChanged = false;
  }
}
// ── Fake Name ─────────────────────────────────────────────────────────────
// Generation counter: tăng khi settings thay đổi, mỗi HudControl chỉ update 1
// lần/gen
static uint32_t s_fnGen = 1;
static std::unordered_map<void *, uint32_t> s_hudNameGen;

#include "helper/HeroNameMap.h"

// Lazy MonoString factory (System.String.CreateString)
static MonoString *MakeMonoStr(const char *s) {
  static MonoString *(*fn)(void *, const char *, int, int) = nullptr;
  if (!fn) {
    uint64_t a =
        MethodAddrN("mscorlib.dll", "System", "String", "CreateString", 3);
    if (a)
      fn = (MonoString * (*)(void *, const char *, int, int)) a;
  }
  if (!fn || !s)
    return nullptr;
  return fn(nullptr, s, 0, (int)strlen(s));
}
// ─────────────────────────────────────────────────────────────────────────

#pragma mark - Hook Callbacks
void _CBattleSystem_Update(void *i) {
  enemyFrame++;
  if (i && CBattleSystem_instance != i) {
    ResetEnemyTracking();
  }
  if (i)
    CBattleSystem_instance = i;
  if (i) {
    static size_t off_isInBattle =
        FieldOffset("Project_d.dll", "Assets.Scripts.GameSystem",
                    "CBattleSystem", "m_isInBattle");
    ingame = off_isInBattle ? *(bool *)((uintptr_t)i + off_isInBattle) : false;
    if (ingame && AutoWin) {
      ForceKillCrystal(2); // kill enemy crystal
    }
  }
  if ((enemyFrame & 127) == 0) {
    for (int k = 0; k < 16; ++k)
      if (enemyEntries[k].lactor &&
          enemyFrame - enemyEntries[k].lastSeenFrame > 120)
        enemyEntries[k] = {};
    for (int k = 0; k < 8; ++k)
      if (monsterEntries[k].actorLinker &&
          enemyFrame - monsterEntries[k].lastSeenFrame > 120)
        monsterEntries[k] = {};
  }
  CBattleSystem_Update(CBattleSystem_instance);
}
void _LActorRoot_UpdateLogic(void *i, int d) {
  if (!i)
    return;
  if (LActorRoot_UpdateLogic)
    LActorRoot_UpdateLogic(i, d);
  if (myObjID != 0 && LActorRoot_get_ObjID) {
    int objID = LActorRoot_get_ObjID(i);
    if (objID == myObjID) {
      myLactorRoot = i;
      return;
    }
  }
  if (myActorLinker && LActorRoot_LHeroWrapper && LActorRoot_COM_PLAYERCAMP &&
      ActorLinker_COM_PLAYERCAMP) {
    if (LActorRoot_LHeroWrapper(i) &&
        LActorRoot_COM_PLAYERCAMP(i) ==
            ActorLinker_COM_PLAYERCAMP(myActorLinker)) {
      enemyLactorRoot = i;
      TrackEnemyLactorRoot(i);
    }
  }
}
void _ActorLinker_Update(void *i) {
  if (!i)
    return;
  if (ActorLinker_Update)
    ActorLinker_Update(i);
  if (ActorLinker_IsHostPlayer && ActorLinker_IsHostPlayer(i)) {
    myActorLinker = i;
    if (ActorLinker_get_ObjID) {
      myObjID = ActorLinker_get_ObjID(i);
    }
    if (ActorLinker_COM_PLAYERCAMP) {
      s_myPlayerCamp = ActorLinker_COM_PLAYERCAMP(i);
      isFliped = (s_myPlayerCamp == 2);
    }
    if (ActorLinker_ObjLinker && ActorConfig_ConfigID) {
      void *objLinker = *(void **)((uintptr_t)i + ActorLinker_ObjLinker);
      if (objLinker) {
        int cfgID = *(int *)((uintptr_t)objLinker + ActorConfig_ConfigID);
        if (cfgID != 0)
          EnemyTarget.myHeroConfigID = cfgID;
      }
    }
  } else if (s_myPlayerCamp != 0 && ActorLinker_COM_PLAYERCAMP &&
             ActorLinker_COM_PLAYERCAMP(i) != s_myPlayerCamp) {
    enemyActorLinker = i;
    MatchEnemyActorLinker(i);
  }
  // Fake Name: chỉ gọi khi gen thay đổi, không gọi lại mỗi frame
  if (ChangeName && SetPlayerName && ActorLinker_HudControl && NameMode != 0) {
    void *hud = *(void **)((uintptr_t)i + ActorLinker_HudControl);
    if (hud) {
      auto &lastGen = s_hudNameGen[hud];
      if (lastGen != s_fnGen) {
        MonoString *empty = MakeMonoStr("");
        if (NameMode == 2) {
          MonoString *name = MakeMonoStr(customname.c_str());
          if (name) {
            SetPlayerName(hud, name, empty, false, empty);
            lastGen = s_fnGen;
          }
        } else if (NameMode == 3 && ActorLinker_ObjLinker &&
                   ActorConfig_ConfigID) {
          void *obj = *(void **)((uintptr_t)i + ActorLinker_ObjLinker);
          if (obj) {
            int cfg = *(int *)((uintptr_t)obj + ActorConfig_ConfigID);
            const char *heroName = "Hero";
            if (cfg != 0) {
              auto hn = kHeroNameMap.find(cfg);
              if (hn != kHeroNameMap.end())
                heroName = hn->second;
            }
            MonoString *name = MakeMonoStr(heroName);
            if (name) {
              SetPlayerName(hud, name, empty, false, empty);
              lastGen = s_fnGen;
            }
          }
        } else if (NameMode == 4 && ActorLinker_IsHostPlayer &&
                   ActorLinker_IsHostPlayer(i)) {
          MonoString *name = MakeMonoStr(customname.c_str());
          if (name) {
            SetPlayerName(hud, name, empty, false, empty);
            lastGen = s_fnGen;
          }
        }
      }
    }
  }
  if (AutoTT && ActorLinker_ActorTypeDef && ActorLinker_ActorTypeDef(i) == 1 &&
      ActorLinker_ObjLinker && ActorConfig_ConfigID &&
      ActorLinker_getPosition && myActorLinker) {
    void *objLnk = *(void **)((uintptr_t)i + ActorLinker_ObjLinker);
    if (!objLnk)
      return;
    int cfgID = *(int *)((uintptr_t)objLnk + ActorConfig_ConfigID);
    const int *idList =
        (AutoTTMode == 1) ? kDragonConfigIDs : kMonsterConfigIDs;
    int idCount =
        (AutoTTMode == 1) ? kDragonConfigIDCount : kMonsterConfigIDCount;
    bool isTarget = false;
    for (int k = 0; k < idCount; ++k) {
      if (cfgID == idList[k]) {
        isTarget = true;
        break;
      }
    }
    if (!isTarget)
      return;
    // Chỉ tính khoảng cách khi đã biết đúng quái cần trừng trị
    Vector3 myP = ActorLinker_getPosition(myActorLinker);
    Vector3 monP = ActorLinker_getPosition(i);
    if (Vector3::Distance(myP, monP) >= 20.0f)
      return;
    bool found = false;
    for (int m = 0; m < 8; ++m) {
      if (monsterEntries[m].actorLinker == i) {
        monsterEntries[m].lastSeenFrame = enemyFrame;
        found = true;
        break;
      }
    }
    if (!found) {
      int useSlot = -1;
      for (int m = 0; m < 8; ++m) {
        if (!monsterEntries[m].actorLinker) {
          useSlot = m;
          break;
        }
      }
      if (useSlot < 0) {
        for (int m = 0; m < 8; ++m) {
          if (enemyFrame - monsterEntries[m].lastSeenFrame > 60) {
            useSlot = m;
            break;
          }
        }
      }
      if (useSlot >= 0)
        monsterEntries[useSlot] = {i, cfgID, enemyFrame};
    }
  }
}
void _CSkillButtonManager_Update(void *i) {
  if (i && GetCurSkillSlotType) {
    skillSlot = GetCurSkillSlotType(i);
  }
  if (AimbotEnable) {
    UpdateAimParamsForMyHero();
    UpdateAimbotTargetInfo();
    if (aimType != 3)
      g_aimDraw.drawLactor = EnemyTarget.enemyLactor;
    g_aimDraw.bullettime = EnemyTarget.bullettime;
    g_aimDraw.Ranger = EnemyTarget.Ranger;
  }
  if (i && g_CanRequestSkill && g_RequestUseSkillSlot) {
    Vector3 myPos = (myLactorRoot && LActorRoot_get_location)
                        ? Vector3(LActorRoot_get_location(myLactorRoot))
                        : Vector3::zero();
    if (AutoBS && myLactorRoot && LActorRoot_ValueComponent &&
        ValuePropertyComponent_get_actorHp &&
        ValuePropertyComponent_get_actorHpTotal) {
      void *vc =
          *(void **)((uintptr_t)myLactorRoot + LActorRoot_ValueComponent);
      if (vc) {
        int mHp = ValuePropertyComponent_get_actorHp(vc);
        int mTot = ValuePropertyComponent_get_actorHpTotal(vc);
        float pct = (mTot > 0) ? (float)mHp / (float)mTot : 1.0f;
        if (mHp > 0 && pct <= AutoBSHp / 100.0f && g_CanRequestSkill(i, 9))
          g_RequestUseSkillSlot(i, 9, 0, 0, 0);
      }
    }
    if (AutoBP && myPos != Vector3::zero() && LActorRoot_get_location &&
        g_CanRequestSkill(i, 5)) {
      for (int k = 0; k < 16; ++k) {
        if (!enemyEntries[k].lactor)
          continue;
        if (enemyFrame - enemyEntries[k].lastSeenFrame > 60)
          continue;
        if (enemyEntries[k].hpTotal <= 0)
          continue;
        float epPct =
            (float)enemyEntries[k].hp / (float)enemyEntries[k].hpTotal;
        if (epPct <= 0.0f || epPct > AutoBPHp / 100.0f)
          continue;
        Vector3 ePos = Vector3(LActorRoot_get_location(enemyEntries[k].lactor));
        if (Vector3::Distance(myPos, ePos) <= 5.1f) {
          g_RequestUseSkillSlot(i, 5, 0, 0, 0);
          break;
        }
      }
    }
    if (AutoTT && myPos != Vector3::zero() && ActorLinker_getPosition &&
        ActorLinker_ValueComponent && ValueLinkerComponent_get_actorEp &&
        ValueLinkerComponent_get_actorSoulLevel && g_CanRequestSkill(i, 5)) {
      int minHealthToKill = 1500;
      if (myActorLinker) {
        void *myVC =
            *(void **)((uintptr_t)myActorLinker + ActorLinker_ValueComponent);
        if (myVC) {
          int myLevel = ValueLinkerComponent_get_actorSoulLevel(myVC) - 1;
          minHealthToKill = 1350 + 100 * myLevel;
        }
      }
      for (int k = 0; k < 8; ++k) {
        if (!monsterEntries[k].actorLinker)
          continue;
        if (enemyFrame - monsterEntries[k].lastSeenFrame > 60) {
          monsterEntries[k].actorLinker = nullptr;
          continue;
        }
        void *mVC = *(void **)((uintptr_t)monsterEntries[k].actorLinker +
                               ActorLinker_ValueComponent);
        if (!mVC)
          continue;
        int mHp = ValueLinkerComponent_get_actorEp(mVC);
        if (mHp < 1 || mHp > minHealthToKill)
          continue;
        Vector3 mPos = ActorLinker_getPosition(monsterEntries[k].actorLinker);
        if (Vector3::Distance(myPos, mPos) <= 5.0f) {
          if (g_Req5 && SkillSlot_ReadyUseSkill && SkillSlot_RequestUseSkill) {
            SkillSlot_ReadyUseSkill(g_Req5, false);
            SkillSlot_RequestUseSkill(g_Req5);
          } else {
            int mObjID =
                ActorLinker_get_ObjID
                    ? ActorLinker_get_ObjID(monsterEntries[k].actorLinker)
                    : 0;
            g_RequestUseSkillSlot(i, 5, 0, (unsigned int)mObjID, 0);
          }
          break;
        }
      }
    }
  }
  if (CSkillButtonManager_Update)
    CSkillButtonManager_Update(i);
}
void _SkillSlot_LateUpdate(void *instance, int deltaTime) {
  if (instance && SkillSlot_SlotType && SkillSlot_skillIndicator &&
      SkillControlIndicator_curindicatorDistance) {
    int slotType = *(int *)((uintptr_t)instance + SkillSlot_SlotType);
    void *indicator =
        *(void **)((uintptr_t)instance + SkillSlot_skillIndicator);
    if (indicator) {
      int range = *(int *)((uintptr_t)indicator +
                           SkillControlIndicator_curindicatorDistance);
      float rangeValue = (float)range / 1000.0f;
      if (slotType == 1)
        Rangeskill1 = rangeValue;
      else if (slotType == 2)
        Rangeskill2 = rangeValue;
      else if (slotType == 3)
        Rangeskill3 = rangeValue;
      else if (slotType == 5)
        g_Req5 = instance;
    }
  }
  if (SkillSlot_LateUpdate)
    SkillSlot_LateUpdate(instance, deltaTime);
}
bool _SetVisible(void *i, int camp, bool vis, bool sync) {
  if (i && HackMap)
    vis = true;
  return SetVisible(i, camp, vis, sync);
}

bool _get_IsHostProfile(void *i) {
  if (i && HackMap) {
    static size_t off_intimacyInfoIsLock =
        FieldOffset("Project_d.dll", "Assets.Scripts.GameSystem",
                    "CPlayerProfile", "_intimacyInfoIsLock");
    *(bool *)((uintptr_t)i + off_intimacyInfoIsLock) = false;
    return true;
  }
  return get_IsHostProfile(i);
}
void _SyncReportRet(void *i) {
  if (i && HackMap)
    return;
  SyncReportRet(i);
}
float _GetZoomRate(void *i) {
  float o = GetZoomRate(i);
  return i ? (lockCam ? CameraZoom : o + CameraZoom) : o;
}
void _CameraSystem_Update(void *i) {
  if (i)
    OnCameraHeightChanged(i);
  CameraSystem_Update_orig(i);
}
bool _IsHaveHeroSkin(void *i, int h, int s, bool inc) {
  return (i && unlockSkin) ? true : IsHaveHeroSkin(i, h, s, inc);
}
bool _CanUseSkin(void *i, int h, int s) {
  if (i && unlockSkin) {
    enableSkin = true;
    cspHeroID = h;
    cspSkinID = s;
    return true;
  }
  return CanUseSkin(i, h, s);
}
int _GetHeroWearSkinId(void *i, int h) {
  if (i && unlockSkin && enableSkin && cspHeroID == h) {
    if (IsSSSSkin(cspHeroID, cspSkinID))
      return g_sss_fix_skin;
    return cspSkinID;
  }
  return GetHeroWearSkinId(i, h);
}
void *_Unpack(void *i, void *buf, unsigned int ver) {
  static size_t off_stBaseInfo =
      FieldOffset("AovTdr.dll", "CSProtocol", "COMDT_CHOICEHERO", "stBaseInfo");
  static size_t off_stCommonInfo =
      FieldOffset("AovTdr.dll", "CSProtocol", "COMDT_HEROINFO", "stCommonInfo");
  static size_t off_dwHeroID = FieldOffset(
      "AovTdr.dll", "CSProtocol", "COMDT_HERO_COMMON_INFO", "dwHeroID");
  static size_t off_bSkinWakeLevel = FieldOffset(
      "AovTdr.dll", "CSProtocol", "COMDT_CHOICEHERO", "bSkinWakeLevel");
  static size_t off_ullSkinWakeFeatureMask = FieldOffset(
      "AovTdr.dll", "CSProtocol", "COMDT_CHOICEHERO", "ullSkinWakeFeatureMask");
  static size_t off_wSkinID = FieldOffset("AovTdr.dll", "CSProtocol",
                                          "COMDT_HERO_COMMON_INFO", "wSkinID");
  if (i && unlockSkin) {
    void *r = UnpackOrig(i, buf, ver);
    void *hi = *(void **)((uintptr_t)i + off_stBaseInfo);
    if (hi) {
      void *ci = *(void **)((uintptr_t)hi + off_stCommonInfo);
      if (ci && enableSkin &&
          *(uint32_t *)((uintptr_t)ci + off_dwHeroID) == cspHeroID) {
        *(uint8_t *)((uintptr_t)i + off_bSkinWakeLevel) = 5;
        *(uint64_t *)((uintptr_t)i + off_ullSkinWakeFeatureMask) =
            0xFFFFFFFFFFFFFFFFULL;
        uint16_t patchSkin = IsSSSSkin(cspHeroID, cspSkinID)
                                 ? (uint16_t)g_sss_fix_skin
                                 : (uint16_t)cspSkinID;
        *(uint16_t *)((uintptr_t)ci + off_wSkinID) = patchSkin;
      }
    }
    return r;
  }
  enableSkin = false;
  return UnpackOrig(i, buf, ver);
}
void _OnClickSelectHeroSkin(void *i, int h, int s) {
  if (i && unlockSkin)
    RefreshHeroPanel(i, true, true, true);
  OnClickSelectHeroSkin_orig(i, h, s);
}
void _HeroSelect_OnSkinSelect(void *i, void *ev) {
  if (i && unlockSkin)
    RefreshSelectHeroInfo(i);
  HeroSelect_OnSkinSelect_orig(i, ev);
}
int _GetSkinCfg_hook(int heroId, int skinId) {
  if (unlockSkin && IsSSSSkin(heroId, skinId))
    return heroId * 100 + skinId;
  return old_GetSkinCfg(heroId, skinId);
}
void *_GetSkin_hook(void *instance, int skinId) {
  if (instance && unlockSkin && enableSkin && cspHeroID != 0) {
    if (skinId == cspSkinID && IsSSSSkin(cspHeroID, cspSkinID) &&
        _GetHeroSkin) {
      void *serverSkin = _GetHeroSkin(cspHeroID, g_sss_fix_skin);
      if (serverSkin) {
        static size_t off_dwID = 0;
        if (!off_dwID)
          off_dwID =
              FieldOffset("AovTdr.dll", "ResData", "ResHeroSkin", "dwID");
        if (off_dwID)
          *(int *)((uintptr_t)serverSkin + off_dwID) =
              cspHeroID * 100 + cspSkinID;
      }
    }
    if (skinId == g_sss_fix_skin && g_sss_fix_skin > 0 &&
        IsSSSSkin(cspHeroID, cspSkinID))
      return _GetSkinOrig(instance, cspSkinID);
  }
  return _GetSkinOrig(instance, skinId);
}
void *_Unpack_CommonInfo_hook(void *instance, void *buf, unsigned int ver) {
  void *result = _Unpack_CommonInfo(instance, buf, ver);
  if (result && instance && unlockSkin && enableSkin) {
    static size_t off_h = 0, off_s = 0;
    if (!off_h) {
      off_h = FieldOffset("AovTdr.dll", "CSProtocol", "COMDT_HERO_COMMON_INFO",
                          "dwHeroID");
      off_s = FieldOffset("AovTdr.dll", "CSProtocol", "COMDT_HERO_COMMON_INFO",
                          "wSkinID");
    }
    if (off_h && off_s) {
      uint32_t hid = *(uint32_t *)((uintptr_t)instance + off_h);
      if (hid == (uint32_t)cspHeroID) {
        uint16_t fixSkin = IsSSSSkin(cspHeroID, cspSkinID)
                               ? (uint16_t)g_sss_fix_skin
                               : (uint16_t)cspSkinID;
        *(uint16_t *)((uintptr_t)instance + off_s) = fixSkin;
      }
    }
  }
  return result;
}
void _LobbyLogic_Updatelogic(void *i, int d) {
  if (i) {
    static size_t off_ulAccountUid =
        FieldOffset("Project_d.dll", "Assets.Scripts.GameLogic", "LobbyLogic",
                    "ulAccountUid");
    playerUid = *(uint64_t *)((uintptr_t)i + off_ulAccountUid);
  }
  LobbyLogic_Updatelogic_orig(i, d);
}
void *_LobbyLogic_PlayerBase(void *i, unsigned int pid) {
  void *p = LobbyLogic_PlayerBase_orig(i, pid);
  if (p && (buttonID > 0 || broadcastID > 0 || soldierID > 0)) {
    static size_t off_PlayerUId = FieldOffset(
        "Project.Plugins_d.dll", "LDataProvider", "PlayerBase", "PlayerUId");
    static size_t off_PersonalButtonID =
        FieldOffset("Project.Plugins_d.dll", "LDataProvider", "PlayerBase",
                    "PersonalButtonID");
    static size_t off_broadcastID = FieldOffset(
        "Project.Plugins_d.dll", "LDataProvider", "PlayerBase", "broadcastID");
    static size_t off_usingSoldierSkinID =
        FieldOffset("Project.Plugins_d.dll", "LDataProvider", "PlayerBase",
                    "usingSoldierSkinID");
    if (*(uint64_t *)((uint64_t)p + off_PlayerUId) == playerUid) {
      *(int *)((uint64_t)p + off_PersonalButtonID) = buttonID;
      *(int *)((uint64_t)p + off_broadcastID) = broadcastID;
      *(int *)((uint64_t)p + off_usingSoldierSkinID) = soldierID;
    }
  }
  return p;
}
static inline float Dot3(const Vector3 &a, const Vector3 &b) {
  return a.x * b.x + a.y * b.y + a.z * b.z;
}
static inline float LenSq3(const Vector3 &v) {
  return v.x * v.x + v.y * v.y + v.z * v.z;
}
static inline float DistSq3(const Vector3 &a, const Vector3 &b) {
  float dx = a.x - b.x;
  float dy = a.y - b.y;
  float dz = a.z - b.z;
  return dx * dx + dy * dy + dz * dz;
}
static inline float ClosestDistanceEnemy(const Vector3 &myPos,
                                         const Vector3 &enemyPos,
                                         const Vector3 &direction) {
  Vector3 AC = enemyPos - myPos;
  Vector3 AB = direction * -1.0f;
  float t = Dot3(AC, AB);
  float px = myPos.x + AB.x * t;
  float py = myPos.y + AB.y * t;
  float pz = myPos.z + AB.z * t;
  float ex = enemyPos.x - px, ey = enemyPos.y - py, ez = enemyPos.z - pz;
  return sqrtf(ex * ex + ey * ey + ez * ez);
}
static void ResetEnemyTracking() {
  for (int i = 0; i < 16; ++i) {
    enemyEntries[i].lactor = nullptr;
    enemyEntries[i].actorLinker = nullptr;
    enemyEntries[i].objID = 0;
    enemyEntries[i].lastSeenFrame = 0;
  }
  myActorLinker = nullptr;
  myLactorRoot = nullptr;
  enemyActorLinker = nullptr;
  enemyLactorRoot = nullptr;
  myObjID = 0;
  s_myPlayerCamp = 0;
  EnemyTarget = {};
}
static void TrackEnemyLactorRoot(void *lactor) {
  if (!lactor)
    return;
  int objID = (LActorRoot_get_ObjID) ? LActorRoot_get_ObjID(lactor) : 0;
  int cfgID = 0;
  int curHp = 0, curHpTotal = 1;
  bool needHP = AutoBP || (AimbotEnable && (aimType == 1 || aimType == 2));
  if (needHP && LActorRoot_ValueComponent &&
      ValuePropertyComponent_get_actorHp &&
      ValuePropertyComponent_get_actorHpTotal) {
    void *vc = *(void **)((uintptr_t)lactor + LActorRoot_ValueComponent);
    if (vc) {
      curHp = ValuePropertyComponent_get_actorHp(vc);
      curHpTotal = ValuePropertyComponent_get_actorHpTotal(vc);
      if (curHpTotal <= 0)
        curHpTotal = 1;
    }
  }
  for (int i = 0; i < 16; ++i) {
    if (enemyEntries[i].lactor == lactor) {
      enemyEntries[i].lastSeenFrame = enemyFrame;
      if (objID != 0)
        enemyEntries[i].objID = objID;
      if (cfgID != 0)
        enemyEntries[i].configID = cfgID;
      if (curHp > 0 || curHpTotal > 1) {
        enemyEntries[i].hp = curHp;
        enemyEntries[i].hpTotal = curHpTotal;
      }
      return;
    }
  }
  for (int i = 0; i < 16; ++i) {
    if (!enemyEntries[i].lactor) {
      enemyEntries[i].lactor = lactor;
      enemyEntries[i].objID = objID;
      enemyEntries[i].configID = cfgID;
      enemyEntries[i].lastSeenFrame = enemyFrame;
      enemyEntries[i].hp = curHp;
      enemyEntries[i].hpTotal = curHpTotal;
      return;
    }
  }
  int oldestIndex = 0;
  for (int i = 1; i < 16; ++i) {
    if (enemyEntries[i].lastSeenFrame <
        enemyEntries[oldestIndex].lastSeenFrame) {
      oldestIndex = i;
    }
  }
  enemyEntries[oldestIndex].lactor = lactor;
  enemyEntries[oldestIndex].actorLinker = nullptr;
  enemyEntries[oldestIndex].objID = objID;
  enemyEntries[oldestIndex].configID = cfgID;
  enemyEntries[oldestIndex].lastSeenFrame = enemyFrame;
  enemyEntries[oldestIndex].hp = curHp;
  enemyEntries[oldestIndex].hpTotal = curHpTotal;
}
static void MatchEnemyActorLinker(void *actorLinker) {
  if (!actorLinker || !ActorLinker_get_ObjID)
    return;
  int objID = ActorLinker_get_ObjID(actorLinker);
  if (objID == 0)
    return;
  for (int i = 0; i < 16; ++i) {
    if (enemyEntries[i].lactor && enemyEntries[i].objID == objID) {
      enemyEntries[i].actorLinker = actorLinker;
      if (ActorLinker_ObjLinker && ActorConfig_ConfigID) {
        void *objLinker =
            *(void **)((uintptr_t)actorLinker + ActorLinker_ObjLinker);
        if (objLinker)
          enemyEntries[i].configID =
              *(int *)((uintptr_t)objLinker + ActorConfig_ConfigID);
      }
      return;
    }
  }
}
static void *SelectEnemyLactorRoot(const Vector3 &myPos,
                                   const Vector3 &myForward) {
  void *best = nullptr;
  float bestScore = 1e30f;
  for (int i = 0; i < 16; ++i) {
    if (!enemyEntries[i].lactor)
      continue;
    if (enemyFrame - enemyEntries[i].lastSeenFrame > 60)
      continue;
    void *lactor = enemyEntries[i].lactor;
    if (!targetConfigIDs.empty() && LActorRoot_ObjLinker &&
        ActorConfig_ConfigID) {
      void *objLinker = *(void **)((uintptr_t)lactor + LActorRoot_ObjLinker);
      if (objLinker) {
        int cfgID = *(int *)((uintptr_t)objLinker + ActorConfig_ConfigID);
        if (targetConfigIDs.count(cfgID) == 0)
          continue;
      }
    }
    if (LActorRoot_ActorControl && LObjWrapper_get_IsDeadState) {
      void *lw = *(void **)((uintptr_t)lactor + LActorRoot_ActorControl);
      if (lw && LObjWrapper_get_IsDeadState(lw))
        continue;
    }
    if (aimRequireVisible && ActorLinker_get_bVisible &&
        enemyEntries[i].actorLinker) {
      if (!ActorLinker_get_bVisible(enemyEntries[i].actorLinker))
        continue;
    }
    if (!LActorRoot_get_location)
      continue;
    Vector3 enemyPos = Vector3(LActorRoot_get_location(lactor));
    if (enemyPos == Vector3::zero())
      continue;
    if (EnemyTarget.Ranger > 0.0f) {
      float dist = Vector3::Distance(myPos, enemyPos);
      if (dist > EnemyTarget.Ranger)
        continue;
    }
    float score = 0.0f;
    if (aimType == 1 || aimType == 2) {
      int hp = enemyEntries[i].hp;
      int hpTotal = (enemyEntries[i].hpTotal > 0) ? enemyEntries[i].hpTotal : 1;
      if (hp > 0 || hpTotal > 1) {
        score = (aimType == 1) ? (float)hp : (float)hp / (float)hpTotal;
      } else {
        score = DistSq3(myPos, enemyPos);
      }
    } else {
      score = DistSq3(myPos, enemyPos);
    }
    if (score < bestScore) {
      bestScore = score;
      best = lactor;
    }
  }
  return best;
}
static bool UpdateAimbotTargetInfo() {
  if (!myActorLinker && !myLactorRoot) {
    return false;
  }
  if (!enemyActorLinker && !enemyLactorRoot) {
    return false;
  }
  Vector3 myPos = Vector3::zero();
  if (myActorLinker && ActorLinker_getPosition) {
    myPos = ActorLinker_getPosition(myActorLinker);
  } else if (myLactorRoot && LActorRoot_get_location) {
    myPos = Vector3(LActorRoot_get_location(myLactorRoot));
  }
  Vector3 myForward = Vector3::zero();
  if (myLactorRoot && LActorRoot_get_forward) {
    myForward = Vector3(LActorRoot_get_forward(myLactorRoot));
  }
  void *chosenLactor = SelectEnemyLactorRoot(myPos, myForward);
  void *chosenActor = enemyActorLinker;
  if (!chosenLactor)
    chosenLactor = enemyLactorRoot;
  Vector3 enemyPos = Vector3::zero();
  if (chosenLactor && LActorRoot_get_location) {
    enemyPos = Vector3(LActorRoot_get_location(chosenLactor));
  } else if (chosenActor && ActorLinker_getPosition) {
    enemyPos = ActorLinker_getPosition(chosenActor);
  }
  EnemyTarget.myPos = myPos;
  EnemyTarget.enemyPos = enemyPos;
  EnemyTarget.moveForward = Vector3::zero();
  EnemyTarget.currentSpeed = 0;
  EnemyTarget.enemyActor = chosenActor;
  EnemyTarget.enemyLactor = chosenLactor;
  if (chosenLactor && LActorRoot_get_forward) {
    EnemyTarget.moveForward = Vector3(LActorRoot_get_forward(chosenLactor));
  }
  if (chosenLactor && LActorRoot_get_PlayerMovement && get_speed) {
    void *pm = LActorRoot_get_PlayerMovement(chosenLactor);
    if (pm)
      EnemyTarget.currentSpeed = get_speed(pm) / 1000;
  }
  EnemyTarget.ConfigID = 0;
  if (chosenLactor && LActorRoot_ObjLinker && ActorConfig_ConfigID) {
    void *objLinker =
        *(void **)((uintptr_t)chosenLactor + LActorRoot_ObjLinker);
    if (objLinker) {
      EnemyTarget.ConfigID =
          *(int *)((uintptr_t)objLinker + ActorConfig_ConfigID);
    }
  } else if (chosenActor && ActorLinker_ObjLinker && ActorConfig_ConfigID) {
    void *objLinker =
        *(void **)((uintptr_t)chosenActor + ActorLinker_ObjLinker);
    if (objLinker) {
      EnemyTarget.ConfigID =
          *(int *)((uintptr_t)objLinker + ActorConfig_ConfigID);
    }
  }
  if (EnemyTarget.myHeroConfigID == 0) {
    if (myActorLinker && ActorLinker_ObjLinker && ActorConfig_ConfigID) {
      void *objLinker =
          *(void **)((uintptr_t)myActorLinker + ActorLinker_ObjLinker);
      if (objLinker)
        EnemyTarget.myHeroConfigID =
            *(int *)((uintptr_t)objLinker + ActorConfig_ConfigID);
    }
    if (EnemyTarget.myHeroConfigID == 0 && myLactorRoot &&
        LActorRoot_ObjLinker && ActorConfig_ConfigID) {
      void *objLinker =
          *(void **)((uintptr_t)myLactorRoot + LActorRoot_ObjLinker);
      if (objLinker)
        EnemyTarget.myHeroConfigID =
            *(int *)((uintptr_t)objLinker + ActorConfig_ConfigID);
    }
  }
  if (enemyFrame % 60 == 0) {
    if (EnemyTarget.myHeroConfigID == 0) {
      LOG_ANHVU("AimNoHeroConfig myActor=%p myLactor=%p", myActorLinker,
                myLactorRoot);
    } else {
      LOG_ANHVU("AimInfo myHero=%d enemyCfg=%d myPos(%.2f %.2f %.2f) ePos(%.2f "
                "%.2f %.2f) spd=%d fwd(%.2f %.2f %.2f)",
                EnemyTarget.myHeroConfigID, EnemyTarget.ConfigID,
                EnemyTarget.myPos.x, EnemyTarget.myPos.y, EnemyTarget.myPos.z,
                EnemyTarget.enemyPos.x, EnemyTarget.enemyPos.y,
                EnemyTarget.enemyPos.z, EnemyTarget.currentSpeed,
                EnemyTarget.moveForward.x, EnemyTarget.moveForward.y,
                EnemyTarget.moveForward.z);
    }
  }
  return EnemyTarget.myPos != Vector3::zero() &&
         EnemyTarget.enemyPos != Vector3::zero();
}
static void UpdateAimParamsForMyHero() {
  EnemyTarget.Ranger = 0.0f;
  EnemyTarget.bullettime = 0.0f;
  tagid = 0;
  if (!AimbotEnable)
    return;
  if (EnemyTarget.myHeroConfigID == 0)
    return;
  const AimHeroConfig *cfg = FindAimHeroCfg(EnemyTarget.myHeroConfigID);
  if (!cfg) {
    if (enemyFrame % 120 == 0)
      LOG_ANHVU("AimSkip hero=%d not in list", EnemyTarget.myHeroConfigID);
    return;
  }
  tagid = 1;
  float s1 = (Rangeskill1 > 0.f) ? Rangeskill1 : 0.f;
  float s2 = (Rangeskill2 > 0.f) ? Rangeskill2 : 0.f;
  float s3 = (Rangeskill3 > 0.f) ? Rangeskill3 : 0.f;
  if (s2 > 0.f && cfg->bt[2] > 0.f) {
    EnemyTarget.Ranger = s2;
    EnemyTarget.bullettime = cfg->bt[2];
    tagid = 2;
  } else if (s1 > 0.f && cfg->bt[1] > 0.f) {
    EnemyTarget.Ranger = s1;
    EnemyTarget.bullettime = cfg->bt[1];
    tagid = 1;
  } else if (s3 > 0.f && cfg->bt[3] > 0.f) {
    EnemyTarget.Ranger = s3;
    EnemyTarget.bullettime = cfg->bt[3];
    tagid = 3;
  }
  if (enemyFrame % 60 == 0)
    LOG_ANHVU("AimHero hero=%d tagid=%d range=%.2f bullet=%.2f",
              EnemyTarget.myHeroConfigID, tagid, EnemyTarget.Ranger,
              EnemyTarget.bullettime);
}
Vector3 calculateSkillDirection(Vector3 myPosi, Vector3 enemyPosi,
                                Vector3 moveForward, int currentSpeed,
                                float bullettime, float Ranger) {
  Vector3 futureEnemyPos = Vector3::zero();
  Vector3 toEnemy = enemyPosi - myPosi;
  float distanceToEnemy = Vector3::Magnitude(toEnemy);
  float defaultBulletSpeed = Ranger / bullettime;
  float timeToHit = distanceToEnemy / defaultBulletSpeed;
  futureEnemyPos = enemyPosi + moveForward * currentSpeed * timeToHit;
  Vector3 shootingDirection = futureEnemyPos - myPosi;
  return Vector3::Normalized(shootingDirection);
}
Vector3 (*GetUseSkillPosition)(void *instance, bool isTouchUse);
Vector3 _GetUseSkillPosition(void *instance, bool isTouchUse) {
  Vector3 origPos = GetUseSkillPosition(instance, isTouchUse);
  int curSlot = 0;
  if (instance && SkillControlIndicator_skillSlot && SkillSlot_SlotType) {
    void *slotObj =
        *(void **)((uintptr_t)instance + SkillControlIndicator_skillSlot);
    if (slotObj)
      curSlot = *(int *)((uintptr_t)slotObj + SkillSlot_SlotType);
  }
  if (curSlot > 0 && curSlot < 4)
    skillSlot = curSlot;
  if (!AimbotEnable || curSlot <= 0 || curSlot >= 4)
    return origPos;
  const AimHeroConfig *s_acfg = FindAimHeroCfg(EnemyTarget.myHeroConfigID);
  if (!s_acfg || s_acfg->bt[curSlot] <= 0.0f)
    return origPos;
  {
    float sr = (curSlot == 1)   ? Rangeskill1
               : (curSlot == 2) ? Rangeskill2
                                : Rangeskill3;
    if (sr > 0.f)
      EnemyTarget.Ranger = sr;
  }
  EnemyTarget.bullettime = s_acfg->bt[curSlot];
  if (EnemyTarget.myPos == Vector3::zero())
    return origPos;
  if (EnemyTarget.Ranger <= 0.0f)
    return origPos;
  if (EnemyTarget.enemyPos == Vector3::zero())
    return origPos;
  float dist = Vector3::Distance(EnemyTarget.myPos, EnemyTarget.enemyPos);
  if (dist > EnemyTarget.Ranger)
    return origPos;
  float defaultBulletSpeed = (EnemyTarget.bullettime > 0.f)
                                 ? EnemyTarget.Ranger / EnemyTarget.bullettime
                                 : 0.f;
  Vector3 predictedPos = EnemyTarget.enemyPos;
  if (defaultBulletSpeed > 0.f && EnemyTarget.currentSpeed > 0) {
    float timeToHit = dist / defaultBulletSpeed;
    predictedPos = EnemyTarget.enemyPos + EnemyTarget.moveForward *
                                              (float)EnemyTarget.currentSpeed *
                                              timeToHit;
  }
  LOG_ANHVU("AREA_AIM pos=(%.1f,%.1f,%.1f) slot=%d", predictedPos.x,
            predictedPos.y, predictedPos.z, curSlot);
  return predictedPos;
}

Vector3 (*GetUseSkillDirection)(void *instance, bool isUseSkill);
Vector3 _GetUseSkillDirection(void *instance, bool isUseSkill) {
  Vector3 origDir = GetUseSkillDirection(instance, isUseSkill);
  int curSlot = 0;
  if (instance && SkillControlIndicator_skillSlot && SkillSlot_SlotType) {
    void *slotObj =
        *(void **)((uintptr_t)instance + SkillControlIndicator_skillSlot);
    if (slotObj)
      curSlot = *(int *)((uintptr_t)slotObj + SkillSlot_SlotType);
  }
  if (curSlot > 0 && curSlot < 4)
    skillSlot = curSlot;
  if (!AimbotEnable || curSlot <= 0 || curSlot >= 4)
    return origDir;
  const AimHeroConfig *d_acfg = FindAimHeroCfg(EnemyTarget.myHeroConfigID);
  if (!d_acfg || d_acfg->bt[curSlot] <= 0.0f)
    return origDir;
  {
    float sr = (curSlot == 1)   ? Rangeskill1
               : (curSlot == 2) ? Rangeskill2
                                : Rangeskill3;
    if (sr > 0.f)
      EnemyTarget.Ranger = sr;
  }
  EnemyTarget.bullettime = d_acfg->bt[curSlot];
  if (EnemyTarget.myPos == Vector3::zero())
    return origDir;
  if (EnemyTarget.Ranger <= 0.0f)
    return origDir;
  if (aimType == 3 && LActorRoot_get_location) {
    void *bestLactor = nullptr;
    float bestDist = 1e30f;
    for (int i = 0; i < 16; ++i) {
      if (!enemyEntries[i].lactor)
        continue;
      if (enemyFrame - enemyEntries[i].lastSeenFrame > 60)
        continue;
      if (LActorRoot_ActorControl && LObjWrapper_get_IsDeadState) {
        void *lw = *(void **)((uintptr_t)enemyEntries[i].lactor +
                              LActorRoot_ActorControl);
        if (lw && LObjWrapper_get_IsDeadState(lw))
          continue;
      }
      if (aimRequireVisible && ActorLinker_get_bVisible &&
          enemyEntries[i].actorLinker)
        if (!ActorLinker_get_bVisible(enemyEntries[i].actorLinker))
          continue;
      Vector3 ePos = Vector3(LActorRoot_get_location(enemyEntries[i].lactor));
      if (ePos == Vector3::zero())
        continue;
      if (EnemyTarget.Ranger > 0.0f &&
          Vector3::Distance(EnemyTarget.myPos, ePos) > EnemyTarget.Ranger)
        continue;
      float d = ClosestDistanceEnemy(EnemyTarget.myPos, ePos, origDir);
      if (d < bestDist) {
        bestDist = d;
        bestLactor = enemyEntries[i].lactor;
      }
    }
    if (bestLactor) {
      EnemyTarget.enemyLactor = bestLactor;
      g_aimDraw.drawLactor = bestLactor;
      EnemyTarget.enemyPos = Vector3(LActorRoot_get_location(bestLactor));
      EnemyTarget.moveForward = Vector3::zero();
      EnemyTarget.currentSpeed = 0;
      if (LActorRoot_get_forward)
        EnemyTarget.moveForward = Vector3(LActorRoot_get_forward(bestLactor));
      if (LActorRoot_get_PlayerMovement && get_speed) {
        void *pm = LActorRoot_get_PlayerMovement(bestLactor);
        if (pm)
          EnemyTarget.currentSpeed = get_speed(pm) / 1000;
      }
    }
  }
  if (EnemyTarget.enemyPos == Vector3::zero())
    return origDir;
  float dist = Vector3::Distance(EnemyTarget.myPos, EnemyTarget.enemyPos);
  if (dist > EnemyTarget.Ranger) {
    LOG_ANHVU("AimOutOfRange dist=%.2f range=%.2f", dist, EnemyTarget.Ranger);
    return origDir;
  }
  LOG_ANHVU("AIM_FIRE! cfg=%d dist=%.2f range=%.2f slot=%d type=%d",
            EnemyTarget.ConfigID, dist, EnemyTarget.Ranger, curSlot, aimType);
  return calculateSkillDirection(
      EnemyTarget.myPos, EnemyTarget.enemyPos, EnemyTarget.moveForward,
      EnemyTarget.currentSpeed, EnemyTarget.bullettime, EnemyTarget.Ranger);
}
struct AimDrawState {
  void *drawLactor;
  float bullettime;
  float Ranger;
};
static AimDrawState g_aimDraw = {};

static void *(*GetMasterRoleInfo_orig)(void *) = nullptr;
static void *(*GetCurrentRankDetail_orig)(void *) = nullptr;

static void *(*unpackTop_orig)(void *, void *, long) = nullptr;
static void *_unpackTop(void *instance, void *srcBuf, long cutVer) {
  void *ret = unpackTop_orig(instance, srcBuf, cutVer);
  if (!instance || !fakerank)
    return ret;
  static size_t off_dwIsTop = 0, off_dwAdCode = 0, off_dwRank = 0;
  static bool topOffsLoaded = false;
  if (!topOffsLoaded) {
    off_dwIsTop =
        FieldOffset("AovTdr.dll", "CSProtocol", "COMDT_RANKDETAIL", "dwIsTop");
    off_dwAdCode =
        FieldOffset("AovTdr.dll", "CSProtocol", "COMDT_RANKDETAIL", "dwAdCode");
    off_dwRank =
        FieldOffset("AovTdr.dll", "CSProtocol", "COMDT_RANKDETAIL", "dwRank");
    if (off_dwIsTop && off_dwAdCode && off_dwRank)
      topOffsLoaded = true;
  }
  if (!topOffsLoaded)
    return ret;
  *(int *)((uintptr_t)instance + off_dwIsTop) =
      rewardOptions[rewardOptionIndex].dwIsTop;
  *(int *)((uintptr_t)instance + off_dwAdCode) =
      rewardOptions[rewardOptionIndex].dwAdCode;
  *(int *)((uintptr_t)instance + off_dwRank) = topnumber;
  return ret;
}

static bool (*TryShowLegendRank_orig)(void *, bool, void *, void *, uint32_t,
                                      uint32_t, int32_t) = nullptr;
static bool _TryShowLegendRank(void *instance, bool canShowProficiency,
                               void *elementGo, void *playerData,
                               uint32_t adCode, uint32_t rankNo,
                               int32_t medalType) {
  if (instance && fakerank) {
    adCode = rewardOptions[rewardOptionIndex].dwAdCode ? 505
                                                       : 0; // 505 = top Vietnam
    rankNo = (uint32_t)topnumber;
    medalType = rewardOptions[rewardOptionIndex].dwIsTop;
  }
  return TryShowLegendRank_orig(instance, canShowProficiency, elementGo,
                                playerData, adCode, rankNo, medalType);
}

// ── IsShowLegendRankMode hook: bật chế độ hiển cục top ──
static bool (*IsShowLegendRankMode_orig)(void *, void *) = nullptr;
static bool _IsShowLegendRankMode(void *instance, void *levelContext) {
  if (instance && fakerank)
    return true;
  return IsShowLegendRankMode_orig(instance, levelContext);
}

// ── CanPlayerShowLegendRank hook: chỉ hiển cục top cho host player của mình ──
static bool (*CanPlayerShowLegendRank_orig)(void *, void *, void *, int32_t,
                                            bool, void **, int *, int *,
                                            int *) = nullptr;
static bool _CanPlayerShowLegendRank(void *instance, void *playerData,
                                     void *dataProvider, int32_t targetCampId,
                                     bool isWarmBattle, void **actorMeta,
                                     int *adCode, int *rankNo, int *medalType) {
  if (instance && fakerank) {
    if (!get_VHostLogic)
      get_VHostLogic = (void *(*)())MethodAddr(
          "Project_d.dll", "Kyrios", "KyriosFramework", "get_hostLogic");
    int playerID = 0;
    if (get_VHostLogic) {
      void *vhl = get_VHostLogic();
      if (vhl) {
        static size_t off_HostPlayerId = 0;
        if (!off_HostPlayerId)
          off_HostPlayerId =
              FieldOffset("Project_d.dll", "Kyrios", "VHostLogic",
                          "<HostPlayerId>k__BackingField");
        playerID = *(int *)((uintptr_t)vhl + off_HostPlayerId);
      }
    }
    if (playerData) {
      static size_t off_PlayerId = 0;
      if (!off_PlayerId)
        off_PlayerId = FieldOffset("Project.Plugins_d.dll", "LDataProvider",
                                   "PlayerBase", "PlayerId");
      int PlayerID = *(int *)((uintptr_t)playerData + off_PlayerId);
      if (PlayerID == playerID)
        return true;
    }
  }
  return CanPlayerShowLegendRank_orig(instance, playerData, dataProvider,
                                      targetCampId, isWarmBattle, actorMeta,
                                      adCode, rankNo, medalType);
}

static void *_GetMasterRoleInfo_hook(void *instance) {
  void *CRoleInfo = GetMasterRoleInfo_orig(instance);
  if (CRoleInfo && fakerank) {
    static size_t off_rankScore = 0, off_rankHistScore = 0;
    static size_t off_rankShowGrade = 0, off_rankHistShowGrade = 0,
                  off_rankSeasonHighShowGrade = 0;
    static size_t off_totalReachRankS = 0, off_rankClass = 0;
    static size_t off_rankHistClass = 0, off_rankSeasonClass = 0, off_vip = 0;
    static bool loaded = false;
    if (!loaded) {
      off_rankScore = FieldOffset("Project_d.dll", "Assets.Scripts.GameSystem",
                                  "CRoleInfo", "m_rankScore");
      off_rankHistScore =
          FieldOffset("Project_d.dll", "Assets.Scripts.GameSystem", "CRoleInfo",
                      "m_rankHistoryHighestScore");
      off_rankShowGrade =
          FieldOffset("Project_d.dll", "Assets.Scripts.GameSystem", "CRoleInfo",
                      "m_rankShowGrade");
      off_rankHistShowGrade =
          FieldOffset("Project_d.dll", "Assets.Scripts.GameSystem", "CRoleInfo",
                      "m_rankHistoryHighestShowGrade");
      off_rankSeasonHighShowGrade =
          FieldOffset("Project_d.dll", "Assets.Scripts.GameSystem", "CRoleInfo",
                      "m_rankSeasonHighestShowGrade");
      off_totalReachRankS =
          FieldOffset("Project_d.dll", "Assets.Scripts.GameSystem", "CRoleInfo",
                      "mTotalReachRankSTimes");
      off_rankClass = FieldOffset("Project_d.dll", "Assets.Scripts.GameSystem",
                                  "CRoleInfo", "m_rankClass");
      off_rankHistClass =
          FieldOffset("Project_d.dll", "Assets.Scripts.GameSystem", "CRoleInfo",
                      "m_rankHistoryHighestClass");
      off_rankSeasonClass =
          FieldOffset("Project_d.dll", "Assets.Scripts.GameSystem", "CRoleInfo",
                      "m_rankSeasonHighestClass");
      off_vip = FieldOffset("Project_d.dll", "Assets.Scripts.GameSystem",
                            "CRoleInfo", "m_GameVipLevel");
      if (off_rankScore && off_rankShowGrade && off_vip)
        loaded = true;
    }
    if (loaded) {
      *(int *)((uintptr_t)CRoleInfo + off_rankScore) = rankStar;
      *(int *)((uintptr_t)CRoleInfo + off_rankHistScore) = rankStar;
      *(uint8_t *)((uintptr_t)CRoleInfo + off_rankShowGrade) = 32;
      *(uint8_t *)((uintptr_t)CRoleInfo + off_rankHistShowGrade) = 32;
      *(uint8_t *)((uintptr_t)CRoleInfo + off_rankSeasonHighShowGrade) = 32;
      *(int *)((uintptr_t)CRoleInfo + off_totalReachRankS) = 30;
      *(int *)((uintptr_t)CRoleInfo + off_rankClass) = 1;
      *(int *)((uintptr_t)CRoleInfo + off_rankHistClass) = 1;
      *(int *)((uintptr_t)CRoleInfo + off_rankSeasonClass) = 1;
      *(int *)((uintptr_t)CRoleInfo + off_vip) = 10;
    }
  }
  return CRoleInfo;
}
static void *_GetCurrentRankDetail_hook(void *instance) {
  void *rankDetail = GetCurrentRankDetail_orig(instance);
  if (rankDetail && fakerank) {
    static size_t off_dwScore = 0;
    if (!off_dwScore)
      off_dwScore = FieldOffset("AovTdr.dll", "CSProtocol", "COMDT_RANKDETAIL",
                                "dwScore");
    if (off_dwScore)
      *(int *)((uintptr_t)rankDetail + off_dwScore) = rankStar;
  }
  return rankDetail;
}
bool _Return1(void *_this) { return false; }
void _Return2(void *_this) { return; }
void _Return3(void *_this) { return; }
void _Return4(void *_this) { return; }
void _Return5(void *_this) { return; }
void _Return6(void *_this) { return; }

#pragma mark - Hook Setup
void initial_setup() {
  static dispatch_once_t once;
  dispatch_once(&once, ^{
    hook(
        (void *[]){
            (bool *)getAbsoluteAddress("anort",
                                       ENCRYPTOFFSET("0x30CA8")), // Fix crash
        },
        (void *[]){(void *)_Return1}, 1);
    GetGameTime = (int (*)(void *))MethodAddr(
        "Project.Plugins_d.dll", "NucleusDrive.Logic.Battle.CommunicateSignal",
        "CommunicateAgent", "GetGameTime");
    get_talentSystem = (void *(*)(void *))MethodAddr(
        "Project.Plugins_d.dll", "NucleusDrive.Logic", "LSkillComponent",
        "get_talentSystem");
    GetGoldCoinInBattle = (int (*)(void *))MethodAddr(
        "Project.Plugins_d.dll", "NucleusDrive.Logic", "ValuePropertyComponent",
        "GetGoldCoinInBattle");
    SendBuyEquipFrameCommand = (void (*)(void *, int, bool))MethodAddr(
        "Project_d.dll", "Assets.Scripts.GameSystem", "CBattleEquipSystem",
        "SendBuyEquipFrameCommand");
    SendSellEquipFrameCommand = (void (*)(void *, int))MethodAddr(
        "Project_d.dll", "Assets.Scripts.GameSystem", "CBattleEquipSystem",
        "SendSellEquipFrameCommand");
    SendPlayerChoseEquipSkillCommand = (void (*)(void *, int))MethodAddr(
        "Project_d.dll", "Assets.Scripts.GameSystem", "CBattleEquipSystem",
        "SendPlayerChoseEquipSkillCommand");
    GetEquipActiveSkillCD = (int (*)(void *, int))MethodAddr(
        "Project_d.dll", "Kyrios.Actor", "VEquipLinkerComponent",
        "GetEquipActiveSkillCD");
    GetTalentCDTime = (int (*)(void *, int))MethodAddr(
        "Project.Plugins_d.dll", "NucleusDrive.Logic", "TalentSystem",
        "GetTalentCDTime");
    LEquipComponent_GetEquips = (void *(*)(void *))MethodAddr(
        "Project.Plugins_d.dll", "NucleusDrive.Logic", "LEquipComponent",
        "GetEquips");
    ActorLinker_IsHostPlayer = (bool (*)(void *))MethodAddr(
        "Project_d.dll", "Kyrios.Actor", "ActorLinker", "IsHostPlayer");
    ActorLinker_COM_PLAYERCAMP = (int (*)(void *))MethodAddr(
        "Project_d.dll", "Kyrios.Actor", "ActorLinker", "get_objCamp");
    ActorLinker_getPosition = (Vector3(*)(void *))MethodAddr(
        "Project_d.dll", "Kyrios.Actor", "ActorLinker", "get_position");
    ActorLinker_get_ObjID = (int (*)(void *))MethodAddr(
        "Project_d.dll", "Kyrios.Actor", "ActorLinker", "get_ObjID");
    ActorLinker_get_bVisible = (bool (*)(void *))MethodAddr(
        "Project_d.dll", "Kyrios.Actor", "ActorLinker", "get_bVisible");
    ActorLinker_ActorTypeDef = (int (*)(void *))MethodAddr(
        "Project_d.dll", "Kyrios.Actor", "ActorLinker", "get_objType");
    ValueLinkerComponent_get_actorEp = (int (*)(void *))MethodAddr(
        "Project_d.dll", "Kyrios.Actor", "ValueLinkerComponent", "get_actorHp");
    ValueLinkerComponent_get_actorSoulLevel = (int (*)(void *))MethodAddr(
        "Project_d.dll", "Kyrios.Actor", "ValueLinkerComponent",
        "get_actorSoulLevel");
    SkillSlot_RequestUseSkill = (bool (*)(void *))MethodAddr(
        "Project_d.dll", "Assets.Scripts.GameLogic", "SkillSlot",
        "RequestUseSkill");
    SkillSlot_ReadyUseSkill = (bool (*)(void *, bool))MethodAddr(
        "Project_d.dll", "Assets.Scripts.GameLogic", "SkillSlot",
        "ReadyUseSkill");
    LActorRoot_LHeroWrapper = (void *(*)(void *))MethodAddr(
        "Project.Plugins_d.dll", "NucleusDrive.Logic", "LActorRoot", "AsHero");
    LActorRoot_COM_PLAYERCAMP = (int (*)(void *))MethodAddr(
        "Project.Plugins_d.dll", "NucleusDrive.Logic", "LActorRoot",
        "GiveMyEnemyCamp");
    LActorRoot_get_ObjID = (int (*)(void *))MethodAddr(
        "Project.Plugins_d.dll", "NucleusDrive.Logic", "LActorRoot",
        "get_ObjID");
    LActorRoot_get_location = (VInt3(*)(void *))MethodAddr(
        "Project.Plugins_d.dll", "NucleusDrive.Logic", "LActorRoot",
        "get_location");
    LActorRoot_get_forward = (VInt3(*)(void *))MethodAddr(
        "Project.Plugins_d.dll", "NucleusDrive.Logic", "LActorRoot",
        "get_forward");
    LActorRoot_get_PlayerMovement = (void *(*)(void *))MethodAddr(
        "Project.Plugins_d.dll", "NucleusDrive.Logic", "LActorRoot",
        "get_PlayerMovement");
    get_speed = (int (*)(void *))MethodAddr("Project.Plugins_d.dll",
                                            "NucleusDrive.Logic",
                                            "PlayerMovement", "get_speed");
    ValuePropertyComponent_get_actorHp = (int (*)(void *))MethodAddr(
        "Project.Plugins_d.dll", "NucleusDrive.Logic", "ValuePropertyComponent",
        "get_actorHp");
    ValuePropertyComponent_get_actorHpTotal = (int (*)(void *))MethodAddr(
        "Project.Plugins_d.dll", "NucleusDrive.Logic", "ValuePropertyComponent",
        "get_actorHpTotal");
    ActorLinker_ObjLinker = FieldOffset("Project_d.dll", "Kyrios.Actor",
                                        "ActorLinker", "ObjLinker");
    ActorConfig_ConfigID = FieldOffset(
        "Project_d.dll", "Assets.Scripts.GameLogic", "ActorConfig", "ConfigID");
    LActorRoot_ObjLinker =
        FieldOffset("Project.Plugins_d.dll", "NucleusDrive.Logic", "LActorRoot",
                    "ObjLinker");
    LActorRoot_ValueComponent =
        FieldOffset("Project.Plugins_d.dll", "NucleusDrive.Logic", "LActorRoot",
                    "ValueComponent");
    LActorRoot_ActorControl =
        FieldOffset("Project.Plugins_d.dll", "NucleusDrive.Logic", "LActorRoot",
                    "ActorControl");
    ActorLinker_ValueComponent = FieldOffset("Project_d.dll", "Kyrios.Actor",
                                             "ActorLinker", "ValueComponent");
    ActorLinker_HudControl = FieldOffset("Project_d.dll", "Kyrios.Actor",
                                         "ActorLinker", "HudControl");
    SetPlayerName =
        (void (*)(void *, MonoString *, MonoString *, bool,
                  MonoString *))MethodAddr("Project_d.dll",
                                           "Assets.Scripts.GameLogic",
                                           "HudComponent3D", "SetPlayerName");
    LActorRoot_SkillControl =
        FieldOffset("Project.Plugins_d.dll", "NucleusDrive.Logic", "LActorRoot",
                    "SkillControl");
    bt_SkillSlot_CurSkillCD =
        FieldOffset("Project.Plugins_d.dll", "NucleusDrive.Logic", "SkillSlot",
                    "<CurSkillCD>k__BackingField");
    bt_BaseSkill_SkillID = FieldOffset(
        "Project.Plugins_d.dll", "NucleusDrive.Logic", "BaseSkill", "SkillID");
    bt_SkillSlot_skillLevel =
        FieldOffset("Project.Plugins_d.dll", "NucleusDrive.Logic", "SkillSlot",
                    "skillLevel");
    bt_GetSkillSlot = (void *(*)(void *, int))MethodAddr(
        "Project.Plugins_d.dll", "NucleusDrive.Logic", "LSkillComponent",
        "GetSkillSlot");
    bt_get_RealSkillObj = (void *(*)(void *))MethodAddr(
        "Project.Plugins_d.dll", "NucleusDrive.Logic", "SkillSlot",
        "get_RealSkillObj");
    LObjWrapper_get_IsDeadState = (bool (*)(void *))MethodAddr(
        "Project.Plugins_d.dll", "NucleusDrive.Logic", "LObjWrapper",
        "get_IsDeadState");
    CSkillButtonManager_Update = (void (*)(void *))MethodAddr(
        "Project_d.dll", "Assets.Scripts.GameSystem", "CSkillButtonManager",
        "Update");
    GetCurSkillSlotType = (int (*)(void *))MethodAddr(
        "Project_d.dll", "Assets.Scripts.GameSystem", "CSkillButtonManager",
        "GetCurSkillSlotType");
    SkillSlot_LateUpdate = (void (*)(void *, int))MethodAddr(
        "Project_d.dll", "Assets.Scripts.GameLogic", "SkillSlot", "LateUpdate");
    SkillSlot_skillIndicator =
        FieldOffset("Project_d.dll", "Assets.Scripts.GameLogic", "SkillSlot",
                    "skillIndicator");
    SkillSlot_SlotType = FieldOffset(
        "Project_d.dll", "Assets.Scripts.GameLogic", "SkillSlot", "SlotType");
    SkillControlIndicator_curindicatorDistance =
        FieldOffset("Project_d.dll", "Assets.Scripts.GameLogic",
                    "SkillControlIndicator", "curindicatorDistance");
    SkillControlIndicator_skillSlot =
        FieldOffset("Project_d.dll", "Assets.Scripts.GameLogic",
                    "SkillControlIndicator", "skillSlot");
    OnCameraHeightChanged = (void (*)(void *))MethodAddr(
        "Project_d.dll", "", "CameraSystem", "OnCameraHeightChanged");
    Camera_get_main = (void *(*)())MethodAddr(
        "UnityEngine.CoreModule.dll", "UnityEngine", "Camera", "get_main");
    Camera_WorldToScreenPoint = (Vector3(*)(void *, Vector3))MethodAddr(
        "UnityEngine.CoreModule.dll", "UnityEngine", "Camera",
        "WorldToScreenPoint");
    Camera_WorldToViewportPoint = (Vector3(*)(void *, Vector3))MethodAddrN(
        "UnityEngine.CoreModule.dll", "UnityEngine", "Camera",
        "WorldToViewportPoint", 1);
    g_CanRequestSkill = (bool (*)(void *, int))MethodAddr(
        "Project_d.dll", "Assets.Scripts.GameSystem", "CSkillButtonManager",
        "CanRequestSkill");
    g_RequestUseSkillSlot =
        (bool (*)(void *, int, int, unsigned int, int))MethodAddr(
            "Project_d.dll", "Assets.Scripts.GameSystem", "CSkillButtonManager",
            "RequestUseSkillSlot");
    RefreshHeroPanel = (void (*)(void *, bool, bool, bool))MethodAddr(
        "Project_d.dll", "Assets.Scripts.GameSystem", "HeroSelectNormalWindow",
        "RefreshHeroPanel");
    GetMasterRoleInfo_orig = (void *(*)(void *))MethodAddr(
        "Project_d.dll", "Assets.Scripts.GameSystem", "CRoleInfoManager",
        "GetMasterRoleInfo");
    RefreshSelectHeroInfo = (void (*)(void *))MethodAddr(
        "Project_d.dll", "Assets.Scripts.GameSystem", "HeroSelectBanPickWindow",
        "RefreshSelectHeroInfo");

    timer(0.0, ^{
      PatchBytesANO(0xF2444, "C0035FD6");
      PatchBytesANO(0xF24DC, "C0035FD6");
      PatchBytesANO(0xF24E0, "C0035FD6");
      PatchBytesANO(0xF24E8, "C0035FD6");
      PatchBytesANO(0xF247C, "C0035FD6");
      PatchBytesANO(0xF24F0, "C0035FD6");
      PatchBytesANO(0xF24F4, "C0035FD6");
      PatchBytesANO(0xF24D0, "C0035FD6");
      PatchBytesANO(0xF2338, "C0035FD6");
      PatchBytesANO(0xF2364, "C0035FD6");
      PatchBytesANO(0xF2368, "C0035FD6");
      PatchBytesANO(0xF23B4, "C0035FD6");
      PatchBytesANO(0xF2404, "C0035FD6");
      PatchBytesANO(0xF2424, "C0035FD6");
      PatchBytesANO(0xF2460, "C0035FD6");
    });
    timer(1.0, ^{
      PatchBytesANO(0xF24E4, "C0035FD6");
      PatchBytesANO(0xF24D8, "C0035FD6");
      PatchBytesANO(0x2C9B20, "C0035FD6");
      PatchBytesANO(0x1DDB74, "C0035FD6");
      PatchBytesANO(0x1ACCD8, "C0035FD6");
      PatchBytesANO(0x1111B0, "C0035FD6");
      PatchBytesANO(0x1920A4, "C0035FD6");
      PatchBytesANO(0x111F30, "C0035FD6");
      PatchBytesANO(0x107AB4, "C0035FD6");
      PatchBytesANO(0x1122B0, "C0035FD6");
      PatchBytesANO(0x112570, "C0035FD6");
      PatchBytesANO(0x32B14, "C0035FD6");
      PatchBytesANO(0x11682C, "C0035FD6");
      PatchBytesANO(0x23CAF0, "C0035FD6");
    });
    timer(2.0, ^{
      PatchBytesANO(0x6CF44, "C0035FD6");
      PatchBytesANO(0x7286C, "C0035FD6");
      PatchBytesANO(0x959B4, "C0035FD6");
      PatchBytesANO(0x728BC, "C0035FD6");
      PatchBytesANO(0x26FE4, "C0035FD6");
    });

    timer(3.0, ^{
      PatchBytes(MethodOffset("Project.Plugins_d.dll", "NucleusDrive.Logic",
                              "LFramework", "set_SynchrReport"),
                 "C0035FD6");
      PatchBytes(MethodOffset("Project.Plugins_d.dll", "NucleusDrive.Logic",
                              "LFramework", "set_BattleDebugger"),
                 "C0035FD6");
      PatchBytes(MethodOffset("Project.Plugins_d.dll",
                              "NucleusDrive.Statistics", "BattleStatistic",
                              "VerifyReportData"),
                 "C0035FD6");
    });
    timer(4.0, ^{
      PatchBytes(MethodOffset("Project_d.dll", "Assets.Scripts.GameSystem",
                              "OfflineModeBattleEntry", "SendOfflineDataToSvr"),
                 "C0035FD6");
    });
    timer(5.0, ^{
      PatchBytes(MethodOffset("Project.Plugins_d.dll", "NucleusDrive.Logic",
                              "LSynchrReport", "EnqueHashValueByFrameNum"),
                 "000080D2C0035FD6");
      PatchBytes(MethodOffset("Project_d.dll", "GCloud.AnoSDK", "AnoSDK",
                              "AnoSDKSetUserInfo"),
                 "000080D2C0035FD6");
    });
    timer(6.0, ^{
      PatchBytes(MethodOffset("Project_d.dll", "GCloud.AnoSDK", "AnoSDK",
                              "AnoSDKGetReportData"),
                 "000080D2C0035FD6");
      PatchBytes(MethodOffset("Project_d.dll", "GCloud.AnoSDK", "AnoSDK",
                              "ReadIntPtr"),
                 "000080D2C0035FD6");
      PatchBytes(MethodOffset("Project_d.dll", "GCloud.AnoSDK", "AnoSDK",
                              "AnoSDKDelReportData"),
                 "000080D2C0035FD6");
    });
    timer(7.0, ^{
      PatchBytes(MethodOffset("Project_d.dll", "GCloud.AnoSDK", "AnoSDK",
                              "OnRecvData"),
                 "000080D2C0035FD6");
      PatchBytes(MethodOffset("Project_d.dll", "GCloud.AnoSDK", "AnoSDK",
                              "AnoSDKOnResume"),
                 "000080D2C0035FD6");
      PatchBytes(MethodOffset("Project_d.dll", "GCloud.AnoSDK", "AnoSDK",
                              "AnoSDKOnRecvData"),
                 "000080D2C0035FD6");
    });
    timer(8.0, ^{
      PatchBytes(MethodOffset("Project_d.dll", "GCloud.AnoSDK", "AnoSDK",
                              "AnoSDKGetReportData2"),
                 "000080D2C0035FD6");
      PatchBytes(MethodOffset("Project_d.dll", "GCloud.AnoSDK", "AnoSDK",
                              "AnoSDKGetReportData3"),
                 "000080D2C0035FD6");
      PatchBytes(MethodOffset("Project_d.dll", "GCloud.AnoSDK", "AnoSDK",
                              "AnoSDKDelReportData4"),
                 "000080D2C0035FD6");
    });
    timer(9.0, ^{
      PatchBytes(MethodOffset("Project_d.dll", "GCloud.AnoSDK", "AnoSDK",
                              "OnRecvSignature"),
                 "000080D2C0035FD6");
      PatchBytes(MethodOffset("Project_d.dll", "GCloud.AnoSDK", "AnoSDK",
                              "AnoSDKOnRecvSignature"),
                 "000080D2C0035FD6");
      PatchBytes(MethodOffset("Project.Plugins_d.dll",
                              "NucleusDrive.Statistics", "BattleStatistic",
                              "CreateDestroyReportData"),
                 "C0035FD6");
    });
    timer(10.0, ^{
      PatchBytes(MethodOffset("Mono.Security.dll", "Mono.Security.Authenticode",
                              "AuthenticodeDeformatter",
                              "VerifyCounterSignature"),
                 "C0035FD6");
      PatchBytes(MethodOffset("mscorlib.dll", "Mono.Security.Cryptography",
                              "PKCS1", "Verify_v15"),
                 "C0035FD6");
    });
    timer(11.0, ^{
      PatchBytes(MethodOffset("Project.Plugins_d.dll",
                              "NucleusDrive.Statistics", "BattleStatistic",
                              "CreateAttrReportData"),
                 "C0035FD6");
      PatchBytes(MethodOffset("Project.Plugins_d.dll",
                              "NucleusDrive.Statistics", "BattleStatistic",
                              "GenerateShenFuData"),
                 "C0035FD6");
      PatchBytes(MethodOffset("Project.Plugins_d.dll",
                              "NucleusDrive.Statistics", "BattleStatistic",
                              "VerifyCondition"),
                 "C0035FD6");
    });

    timer(0.0, ^{
      HookMethod("Project.Plugins_d.dll", "NucleusDrive.Logic", "LActorRoot",
                 "UpdateLogic", _LActorRoot_UpdateLogic,
                 LActorRoot_UpdateLogic);
    });
    timer(0.5, ^{
      HookMethod("Project_d.dll", "Assets.Scripts.GameSystem", "CBattleSystem",
                 "Update", _CBattleSystem_Update, CBattleSystem_Update);
    });
    timer(1.0, ^{
      HookMethod("Project_d.dll", "Kyrios.Actor", "ActorLinker", "LateUpdate",
                 _ActorLinker_Update, ActorLinker_Update);
    });
    timer(1.5, ^{
      HookMethod("Project_d.dll", "Assets.Scripts.GameSystem",
                 "CSkillButtonManager", "Update", _CSkillButtonManager_Update,
                 CSkillButtonManager_Update);
    });
    timer(2.0, ^{
      HookMethod("Project_d.dll", "Assets.Scripts.GameLogic", "SkillSlot",
                 "LateUpdate", _SkillSlot_LateUpdate, SkillSlot_LateUpdate);
    });
    timer(2.5, ^{
      HookMethod("Project_d.dll", "Assets.Scripts.GameLogic",
                 "SkillControlIndicator", "GetUseSkillPosition",
                 _GetUseSkillPosition, GetUseSkillPosition);
    });
    timer(2.7, ^{
      HookMethod("Project_d.dll", "Assets.Scripts.GameLogic",
                 "SkillControlIndicator", "GetUseSkillDirection",
                 _GetUseSkillDirection, GetUseSkillDirection);
    });
    timer(3.0, ^{
      HookMethod("Project.Plugins_d.dll", "NucleusDrive.Logic", "LVActorLinker",
                 "SetVisible", _SetVisible, SetVisible);
    });
    timer(3.5, ^{
      HookMethod("Project_d.dll", "", "CameraSystem", "GetZoomRate",
                 _GetZoomRate, GetZoomRate);
    });
    timer(4.0, ^{
      HookMethod("Project_d.dll", "", "CameraSystem", "Update",
                 _CameraSystem_Update, CameraSystem_Update_orig);
    });
    timer(4.5, ^{
      HookMethod("Project_d.dll", "Assets.Scripts.GameSystem", "CPlayerProfile",
                 "get_IsHostProfile", _get_IsHostProfile, get_IsHostProfile);
    });
    timer(5.5, ^{
      HookMethod("Project.Plugins_d.dll", "NucleusDrive.Logic", "LSynchrReport",
                 "SampleFrameSyncData", _SyncReportRet, SyncReportRet);
    });
    timer(6.0, ^{
      HookMethod("Project_d.dll", "Assets.Scripts.GameSystem", "CRoleInfo",
                 "IsHaveHeroSkin", _IsHaveHeroSkin, IsHaveHeroSkin);
    });
    timer(6.5, ^{
      HookMethod("Project_d.dll", "Assets.Scripts.GameSystem", "CRoleInfo",
                 "IsCanUseSkin", _CanUseSkin, CanUseSkin);
    });
    timer(7.0, ^{
      HookMethod("Project_d.dll", "Assets.Scripts.GameSystem", "CRoleInfo",
                 "GetHeroWearSkinId", _GetHeroWearSkinId, GetHeroWearSkinId);
    });
    timer(7.5, ^{
      HookMethod("AovTdr.dll", "CSProtocol", "COMDT_CHOICEHERO", "unpack",
                 _Unpack, UnpackOrig);
    });
    timer(8.0, ^{
      HookMethod("Project_d.dll", "Assets.Scripts.GameSystem",
                 "HeroSelectNormalWindow", "OnClickSelectHeroSkin",
                 _OnClickSelectHeroSkin, OnClickSelectHeroSkin_orig);
    });
    timer(8.5, ^{
      HookMethod("Project_d.dll", "Assets.Scripts.GameSystem",
                 "HeroSelectBanPickWindow", "HeroSelect_OnSkinSelect",
                 _HeroSelect_OnSkinSelect, HeroSelect_OnSkinSelect_orig);
    });
    timer(8.6, ^{
      uint64_t addr = MethodAddrN("Project_d.dll", "Assets.Scripts.GameSystem",
                                  "CSkinInfo", "GetHeroSkin", 2);
      if (addr)
        _GetHeroSkin = (void *(*)(int, int))addr;
    });
    timer(15.6, ^{
      uint64_t addr = MethodAddrN("Project_d.dll", "Assets.Scripts.GameLogic",
                                  "LobbyMsgHandler", "ForceKillCrystal", 1);
      if (addr)
        ForceKillCrystal = (void (*)(int))addr;
    });
    timer(8.7, ^{
      HookMethod("Project_d.dll", "Assets.Scripts.GameSystem", "CSkinInfo",
                 "GetSkinCfgId", _GetSkinCfg_hook, old_GetSkinCfg);
    });
    timer(8.8, ^{
      HookMethod("Project_d.dll", "Assets.Scripts.GameLogic", "CActorInfo",
                 "GetSkin", _GetSkin_hook, _GetSkinOrig);
    });
    timer(8.9, ^{
      HookMethod("AovTdr.dll", "CSProtocol", "COMDT_HERO_COMMON_INFO", "unpack",
                 _Unpack_CommonInfo_hook, _Unpack_CommonInfo);
    });
    timer(9.0, ^{
      HookMethod("Project_d.dll", "Assets.Scripts.GameLogic", "LobbyLogic",
                 "UpdateLogic", _LobbyLogic_Updatelogic,
                 LobbyLogic_Updatelogic_orig);
    });
    timer(9.5, ^{
      HookMethod("Project.Plugins_d.dll", "NucleusDrive.Logic.GameKernal",
                 "GamePlayerCenter", "GetPlayer", _LobbyLogic_PlayerBase,
                 LobbyLogic_PlayerBase_orig);
    });
    timer(10.0, ^{
      HookMethod("AovTdr.dll", "CSProtocol", "COMDT_RANKDETAIL", "unpack",
                 _unpackTop, unpackTop_orig);
    });
    timer(1.0, ^{
      HookMethod("Project_d.dll", "Assets.Scripts.GameSystem", "PVPLoadingView",
                 "TryShowLegendRank", _TryShowLegendRank,
                 TryShowLegendRank_orig);
    });
    timer(1.3, ^{
      HookMethod("Project_d.dll", "Assets.Scripts.GameSystem", "PVPLoadingView",
                 "IsShowLegendRankMode", _IsShowLegendRankMode,
                 IsShowLegendRankMode_orig);
    });
    timer(1.5, ^{
      HookMethod("Project_d.dll", "Assets.Scripts.GameSystem", "PVPLoadingView",
                 "CanPlayerShowLegendRank", _CanPlayerShowLegendRank,
                 CanPlayerShowLegendRank_orig);
    });
    timer(2.8, ^{
      HookMethod("Project_d.dll", "Assets.Scripts.GameSystem",
                 "CRoleInfoManager", "GetMasterRoleInfo",
                 _GetMasterRoleInfo_hook, GetMasterRoleInfo_orig);
    });
    timer(3.5, ^{
      HookMethod("Project_d.dll", "Assets.Scripts.GameSystem", "CLadderSystem",
                 "GetCurrentRankDetail", _GetCurrentRankDetail_hook,
                 GetCurrentRankDetail_orig);
    });
    PatchBytes(MethodOffset("Project_d.dll", "Assets.Scripts.GameSystem",
                            "PVPLoadingView", "OnEnter") +
                   0x1834,
               "1F2003D5");
    VaPatchBytes(MethodOffset("Project_d.dll", "Assets.Scripts.GameSystem",
                              "PVPLoadingView", "OnEnter") +
                     0x1834,
                 "1F2003D5");

    timer(13.0, ^{
      VaPatchBytes(MethodOffset("Project.Plugins_d.dll", "NucleusDrive.Logic",
                                "LFramework", "set_SynchrReport"),
                   "C0035FD6");
      VaPatchBytes(MethodOffset("Project.Plugins_d.dll", "NucleusDrive.Logic",
                                "LFramework", "set_BattleDebugger"),
                   "C0035FD6");
      VaPatchBytes(MethodOffset("Project.Plugins_d.dll",
                                "NucleusDrive.Statistics", "BattleStatistic",
                                "VerifyReportData"),
                   "C0035FD6");
    });
    timer(14.0, ^{
      VaPatchBytes(MethodOffset("Project_d.dll", "Assets.Scripts.GameSystem",
                                "OfflineModeBattleEntry",
                                "SendOfflineDataToSvr"),
                   "C0035FD6");
    });
    timer(15.0, ^{
      VaPatchBytes(MethodOffset("Project.Plugins_d.dll", "NucleusDrive.Logic",
                                "LSynchrReport", "EnqueHashValueByFrameNum"),
                   "000080D2C0035FD6");
      VaPatchBytes(MethodOffset("Project_d.dll", "GCloud.AnoSDK", "AnoSDK",
                                "AnoSDKSetUserInfo"),
                   "000080D2C0035FD6");
    });
    timer(16.0, ^{
      VaPatchBytes(MethodOffset("Project_d.dll", "GCloud.AnoSDK", "AnoSDK",
                                "AnoSDKGetReportData"),
                   "000080D2C0035FD6");
      VaPatchBytes(MethodOffset("Project_d.dll", "GCloud.AnoSDK", "AnoSDK",
                                "ReadIntPtr"),
                   "000080D2C0035FD6");
      VaPatchBytes(MethodOffset("Project_d.dll", "GCloud.AnoSDK", "AnoSDK",
                                "AnoSDKDelReportData"),
                   "000080D2C0035FD6");
    });
    timer(17.0, ^{
      VaPatchBytes(MethodOffset("Project_d.dll", "GCloud.AnoSDK", "AnoSDK",
                                "OnRecvData"),
                   "000080D2C0035FD6");
      VaPatchBytes(MethodOffset("Project_d.dll", "GCloud.AnoSDK", "AnoSDK",
                                "AnoSDKOnResume"),
                   "000080D2C0035FD6");
      VaPatchBytes(MethodOffset("Project_d.dll", "GCloud.AnoSDK", "AnoSDK",
                                "AnoSDKOnRecvData"),
                   "000080D2C0035FD6");
    });
    timer(18.0, ^{
      VaPatchBytes(MethodOffset("Project_d.dll", "GCloud.AnoSDK", "AnoSDK",
                                "AnoSDKGetReportData2"),
                   "000080D2C0035FD6");
      VaPatchBytes(MethodOffset("Project_d.dll", "GCloud.AnoSDK", "AnoSDK",
                                "AnoSDKGetReportData3"),
                   "000080D2C0035FD6");
      VaPatchBytes(MethodOffset("Project_d.dll", "GCloud.AnoSDK", "AnoSDK",
                                "AnoSDKDelReportData4"),
                   "000080D2C0035FD6");
    });
    timer(19.0, ^{
      VaPatchBytes(MethodOffset("Project_d.dll", "GCloud.AnoSDK", "AnoSDK",
                                "OnRecvSignature"),
                   "000080D2C0035FD6");
      VaPatchBytes(MethodOffset("Project_d.dll", "GCloud.AnoSDK", "AnoSDK",
                                "AnoSDKOnRecvSignature"),
                   "000080D2C0035FD6");
      VaPatchBytes(MethodOffset("Project.Plugins_d.dll",
                                "NucleusDrive.Statistics", "BattleStatistic",
                                "CreateDestroyReportData"),
                   "C0035FD6");
    });
    timer(20.0, ^{
      VaPatchBytes(
          MethodOffset("Mono.Security.dll", "Mono.Security.Authenticode",
                       "AuthenticodeDeformatter", "VerifyCounterSignature"),
          "C0035FD6");
      VaPatchBytes(MethodOffset("mscorlib.dll", "Mono.Security.Cryptography",
                                "PKCS1", "Verify_v15"),
                   "C0035FD6");
    });
    timer(21.0, ^{
      VaPatchBytes(MethodOffset("Project.Plugins_d.dll",
                                "NucleusDrive.Statistics", "BattleStatistic",
                                "CreateAttrReportData"),
                   "C0035FD6");
      VaPatchBytes(MethodOffset("Project.Plugins_d.dll",
                                "NucleusDrive.Statistics", "BattleStatistic",
                                "GenerateShenFuData"),
                   "C0035FD6");
      VaPatchBytes(MethodOffset("Project.Plugins_d.dll",
                                "NucleusDrive.Statistics", "BattleStatistic",
                                "VerifyCondition"),
                   "C0035FD6");
    });
  });
}
#pragma mark - Save/Load Config
#pragma mark - Config
void SaveConfig() {
  NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
  [d setBool:HackMap forKey:NSOBFUSCATE("HackMap")];
  [d setBool:unlockSkin forKey:NSOBFUSCATE("unlockSkin")];
  [d setBool:lockCam forKey:NSOBFUSCATE("lockCam")];
  [d setFloat:CameraZoom forKey:NSOBFUSCATE("CameraZoom")];
  [d setBool:AimbotEnable forKey:NSOBFUSCATE("AimbotEnable")];
  [d setInteger:aimType forKey:NSOBFUSCATE("aimType")];
  [d setBool:aimRequireVisible forKey:NSOBFUSCATE("aimRequireVisible")];
  [d setInteger:selectedButtonIndex forKey:NSOBFUSCATE("selectedButtonIndex")];
  [d setInteger:selectedBroadcastIndex
         forKey:NSOBFUSCATE("selectedBroadcastIndex")];
  [d setInteger:selectedSoldierIndex
         forKey:NSOBFUSCATE("selectedSoldierIndex")];
  [d setInteger:buttonID forKey:NSOBFUSCATE("buttonID")];
  [d setInteger:broadcastID forKey:NSOBFUSCATE("broadcastID")];
  [d setInteger:soldierID forKey:NSOBFUSCATE("soldierID")];
  [d setBool:doiitem forKey:NSOBFUSCATE("doiitem")];
  [d setBool:muaitem forKey:NSOBFUSCATE("muaitem")];
  [d setBool:fullslot forKey:NSOBFUSCATE("fullslot")];
  [d setBool:checktime forKey:NSOBFUSCATE("checktime")];
  [d setBool:showQuickToggle forKey:NSOBFUSCATE("showQuickToggle")];
  [d setBool:qtShowAim forKey:NSOBFUSCATE("qtShowAim")];
  [d setBool:qtShowAuto forKey:NSOBFUSCATE("qtShowAuto")];
  [d setBool:qtShowAutoTT forKey:NSOBFUSCATE("qtShowAutoTT")];
  [d setFloat:AutoBSHp forKey:NSOBFUSCATE("AutoBSHp")];
  [d setFloat:AutoBPHp forKey:NSOBFUSCATE("AutoBPHp")];
  [d setBool:hiencooldowns forKey:NSOBFUSCATE("hiencooldowns")];
  [d setInteger:AutoTTMode forKey:NSOBFUSCATE("AutoTTMode")];
  [d setFloat:espIconScale forKey:NSOBFUSCATE("espIconScale")];
  [d setFloat:espOffsetX forKey:NSOBFUSCATE("espOffsetX")];
  [d setFloat:espOffsetY forKey:NSOBFUSCATE("espOffsetY")];
  [d setBool:fakerank forKey:NSOBFUSCATE("fakerank")];
  [d setInteger:topnumber forKey:NSOBFUSCATE("topnumber")];
  [d setInteger:rewardOptionIndex forKey:NSOBFUSCATE("rewardOptionIndex")];
  [d setInteger:rankStar forKey:NSOBFUSCATE("rankStar")];
  [d setBool:ChangeName forKey:NSOBFUSCATE("ChangeName")];
  [d setInteger:NameMode forKey:NSOBFUSCATE("NameMode")];
  [d setObject:[NSString stringWithUTF8String:customname.c_str()]
        forKey:NSOBFUSCATE("customname")];
  [d synchronize];
}
void LoadConfig() {
  NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
  if ([d objectForKey:NSOBFUSCATE("HackMap")])
    HackMap = [d boolForKey:NSOBFUSCATE("HackMap")];
  if ([d objectForKey:NSOBFUSCATE("unlockSkin")])
    unlockSkin = [d boolForKey:NSOBFUSCATE("unlockSkin")];
  if ([d objectForKey:NSOBFUSCATE("lockCam")])
    lockCam = [d boolForKey:NSOBFUSCATE("lockCam")];
  if ([d objectForKey:NSOBFUSCATE("CameraZoom")])
    CameraZoom = [d floatForKey:NSOBFUSCATE("CameraZoom")];
  if ([d objectForKey:NSOBFUSCATE("AimbotEnable")])
    AimbotEnable = [d boolForKey:NSOBFUSCATE("AimbotEnable")];
  if ([d objectForKey:NSOBFUSCATE("aimType")])
    aimType = (int)[d integerForKey:NSOBFUSCATE("aimType")];
  if ([d objectForKey:NSOBFUSCATE("aimRequireVisible")])
    aimRequireVisible = [d boolForKey:NSOBFUSCATE("aimRequireVisible")];
  if ([d objectForKey:NSOBFUSCATE("selectedButtonIndex")])
    selectedButtonIndex =
        (int)[d integerForKey:NSOBFUSCATE("selectedButtonIndex")];
  if ([d objectForKey:NSOBFUSCATE("selectedBroadcastIndex")])
    selectedBroadcastIndex =
        (int)[d integerForKey:NSOBFUSCATE("selectedBroadcastIndex")];
  if ([d objectForKey:NSOBFUSCATE("selectedSoldierIndex")])
    selectedSoldierIndex =
        (int)[d integerForKey:NSOBFUSCATE("selectedSoldierIndex")];
  if ([d objectForKey:NSOBFUSCATE("buttonID")])
    buttonID = (int)[d integerForKey:NSOBFUSCATE("buttonID")];
  if ([d objectForKey:NSOBFUSCATE("broadcastID")])
    broadcastID = (int)[d integerForKey:NSOBFUSCATE("broadcastID")];
  if ([d objectForKey:NSOBFUSCATE("soldierID")])
    soldierID = (int)[d integerForKey:NSOBFUSCATE("soldierID")];
  if ([d objectForKey:NSOBFUSCATE("doiitem")])
    doiitem = [d boolForKey:NSOBFUSCATE("doiitem")];
  if ([d objectForKey:NSOBFUSCATE("muaitem")])
    muaitem = [d boolForKey:NSOBFUSCATE("muaitem")];
  if ([d objectForKey:NSOBFUSCATE("fullslot")])
    fullslot = [d boolForKey:NSOBFUSCATE("fullslot")];
  if ([d objectForKey:NSOBFUSCATE("checktime")])
    checktime = [d boolForKey:NSOBFUSCATE("checktime")];
  if ([d objectForKey:NSOBFUSCATE("showQuickToggle")])
    showQuickToggle = [d boolForKey:NSOBFUSCATE("showQuickToggle")];
  if ([d objectForKey:NSOBFUSCATE("qtShowAim")])
    qtShowAim = [d boolForKey:NSOBFUSCATE("qtShowAim")];
  if ([d objectForKey:NSOBFUSCATE("qtShowAuto")])
    qtShowAuto = [d boolForKey:NSOBFUSCATE("qtShowAuto")];
  if ([d objectForKey:NSOBFUSCATE("qtShowAutoTT")])
    qtShowAutoTT = [d boolForKey:NSOBFUSCATE("qtShowAutoTT")];
  if ([d objectForKey:NSOBFUSCATE("AutoBSHp")])
    AutoBSHp = [d floatForKey:NSOBFUSCATE("AutoBSHp")];
  if ([d objectForKey:NSOBFUSCATE("AutoBPHp")])
    AutoBPHp = [d floatForKey:NSOBFUSCATE("AutoBPHp")];
  if ([d objectForKey:NSOBFUSCATE("hiencooldowns")])
    hiencooldowns = [d boolForKey:NSOBFUSCATE("hiencooldowns")];
  if ([d objectForKey:NSOBFUSCATE("AutoTTMode")])
    AutoTTMode = (int)[d integerForKey:NSOBFUSCATE("AutoTTMode")];
  if (AutoTTMode < 0 || AutoTTMode > 1)
    AutoTTMode = 0;
  if ([d objectForKey:NSOBFUSCATE("espIconScale")])
    espIconScale = [d floatForKey:NSOBFUSCATE("espIconScale")];
  if ([d objectForKey:NSOBFUSCATE("espOffsetX")])
    espOffsetX = [d floatForKey:NSOBFUSCATE("espOffsetX")];
  if ([d objectForKey:NSOBFUSCATE("espOffsetY")])
    espOffsetY = [d floatForKey:NSOBFUSCATE("espOffsetY")];
  if ([d objectForKey:NSOBFUSCATE("fakerank")])
    fakerank = [d boolForKey:NSOBFUSCATE("fakerank")];
  if ([d objectForKey:NSOBFUSCATE("topnumber")])
    topnumber = (int)[d integerForKey:NSOBFUSCATE("topnumber")];
  if ([d objectForKey:NSOBFUSCATE("rewardOptionIndex")])
    rewardOptionIndex = (int)[d integerForKey:NSOBFUSCATE("rewardOptionIndex")];
  if (rewardOptionIndex < 0 || rewardOptionIndex >= kRewardOptionCount)
    rewardOptionIndex = 1;
  if ([d objectForKey:NSOBFUSCATE("rankStar")])
    rankStar = (int)[d integerForKey:NSOBFUSCATE("rankStar")];
  if (rankStar < 0 || rankStar > 1200)
    rankStar = 500;
  if ([d objectForKey:NSOBFUSCATE("ChangeName")])
    ChangeName = [d boolForKey:NSOBFUSCATE("ChangeName")];
  if ([d objectForKey:NSOBFUSCATE("NameMode")])
    NameMode = (int)[d integerForKey:NSOBFUSCATE("NameMode")];
  if (NameMode < 0 || NameMode > 4)
    NameMode = 0;
  if ([d objectForKey:NSOBFUSCATE("customname")]) {
    NSString *s = [d stringForKey:NSOBFUSCATE("customname")];
    if (s)
      customname = std::string([s UTF8String]);
  }
}
#pragma mark - Botro ESP
static void DrawBotroESP() {
  if (!hiencooldowns)
    return;
  if (!Camera_get_main || !Camera_WorldToViewportPoint)
    return;
  void *cam = Camera_get_main();
  if (!cam)
    return;
  ImDrawList *draw = ImGui::GetForegroundDrawList();
  float iconSize = (kHeight / 30.0f) * espIconScale;
  float gap = 3.0f * espIconScale;
  for (int i = 0; i < 16; ++i) {
    void *lactor = enemyEntries[i].lactor;
    if (!lactor)
      continue;
    if (enemyFrame - enemyEntries[i].lastSeenFrame > 60)
      continue;
    if (LActorRoot_ActorControl && LObjWrapper_get_IsDeadState) {
      void *lw = *(void **)((uintptr_t)lactor + LActorRoot_ActorControl);
      if (lw && LObjWrapper_get_IsDeadState(lw))
        continue;
    }
    void *actorLinker = enemyEntries[i].actorLinker;
    Vector3 worldPos;
    if (actorLinker && ActorLinker_getPosition)
      worldPos = ActorLinker_getPosition(actorLinker);
    else if (LActorRoot_get_location)
      worldPos = Vector3(LActorRoot_get_location(lactor));
    else
      continue;
    Vector3 sc = Camera_WorldToViewportPoint(cam, worldPos);
    if (sc.z <= 0)
      continue;
    ImVec2 rootPos = ImVec2(sc.x * kWidth + espOffsetX,
                            kHeight - sc.y * kHeight + espOffsetY);
    // Kiểm tra viewport bounds TRƯỚC khi đọc skill CDs → tránh gọi hàm thừa cho
    // enemy ngoài màn hình
    float iconSize_check = (kHeight / 30.0f) * espIconScale;
    if (rootPos.x < -(iconSize_check * 4) ||
        rootPos.x > kWidth + (iconSize_check * 4) ||
        rootPos.y < -(iconSize_check * 4) ||
        rootPos.y > kHeight + (iconSize_check * 4))
      continue;

    // ── Read all skill CDs ──
    int c1MS = 0, c2MS = 0, ultMS = 0, btMS = 0, btID = 0;
    bool c1Unlocked = false, c2Unlocked = false, ultUnlocked = false;
    if (LActorRoot_SkillControl && bt_GetSkillSlot) {
      void *skillCtrl = *(void **)((uint64_t)lactor + LActorRoot_SkillControl);
      if (skillCtrl) {
        SkillInfo s1 = Skillcd_bt(skillCtrl, 1); // c1
        SkillInfo s2 = Skillcd_bt(skillCtrl, 2); // c2
        SkillInfo s3 = Skillcd_bt(skillCtrl, 3); // ult
        SkillInfo s5 = Skillcd_bt(skillCtrl, 5); // bổ trợ
        c1Unlocked = (s1.skillLevel > 0);
        c2Unlocked = (s2.skillLevel > 0);
        ultUnlocked = (s3.skillLevel > 0);
        c1MS = s1.skillcd;
        c2MS = s2.skillcd;
        ultMS = s3.skillcd;
        btMS = s5.skillcd;
        btID = s5.skillID;
      }
    }
    // Track max CD for fraction calc
    if (c1MS > enemyEntries[i].maxC1CD)
      enemyEntries[i].maxC1CD = c1MS;
    if (c2MS > enemyEntries[i].maxC2CD)
      enemyEntries[i].maxC2CD = c2MS;
    if (ultMS > enemyEntries[i].maxUltCD)
      enemyEntries[i].maxUltCD = ultMS;
    if (btMS > enemyEntries[i].maxBtCD)
      enemyEntries[i].maxBtCD = btMS;

    auto CalcFrac = [](int ms, int maxCD) -> float {
      if (maxCD <= 0)
        return 0.f;
      float f = (float)ms / (float)maxCD;
      return f > 1.f ? 1.f : f;
    };
    float c1Frac = CalcFrac(c1MS, enemyEntries[i].maxC1CD);
    float c2Frac = CalcFrac(c2MS, enemyEntries[i].maxC2CD);
    float ultFrac = CalcFrac(ultMS, enemyEntries[i].maxUltCD);
    float btFrac = CalcFrac(btMS, enemyEntries[i].maxBtCD);

    auto DrawCDReveal = [&](ImVec2 center, float radius, float fraction) {
      if (fraction <= 0.0f)
        return;
      float top = center.y - radius;
      float bottom = center.y + radius;
      float splitY = top + (1.0f - fraction) * 2.0f * radius;
      draw->PushClipRect(ImVec2(center.x - radius, splitY),
                         ImVec2(center.x + radius, bottom), true);
      draw->AddCircleFilled(center, radius, IM_COL32(0, 0, 0, 185), 32);
      draw->PopClipRect();
    };

    // ── Draw icon helper ──
    float r = iconSize / 2.0f;
    float half = iconSize * 0.88f / 2.0f;
    int cfgID = enemyEntries[i].configID;

    auto DrawSkillIcon = [&](ImVec2 center, float frac,
                             std::unordered_map<int, id<MTLTexture>> &texMap,
                             int key) {
      draw->AddCircleFilled(center, r, IM_COL32(10, 10, 10, 210), 32);
      auto it = texMap.find(key);
      if (it != texMap.end() && it->second != nil) {
        draw->AddImage((ImTextureID)(uintptr_t)(__bridge void *)it->second,
                       ImVec2(center.x - half, center.y - half),
                       ImVec2(center.x + half, center.y + half));
      }
      DrawCDReveal(center, r, frac);
    };

    // ── Layout: c1 c2 ult bt (left → right), centered on rootPos ──
    int iconCount = (c1Unlocked ? 1 : 0) + (c2Unlocked ? 1 : 0) +
                    (ultUnlocked ? 1 : 0) + 1; // bt always shown
    float totalW = iconCount * iconSize + (iconCount - 1) * gap;
    float anchorY = rootPos.y - iconSize * 1.5f - 5.0f;
    float cx = rootPos.x - totalW * 0.5f + r;

    if (c1Unlocked) {
      DrawSkillIcon(ImVec2(cx, anchorY), c1Frac, g_c1IconTextures, cfgID);
      cx += iconSize + gap;
    }
    if (c2Unlocked) {
      DrawSkillIcon(ImVec2(cx, anchorY), c2Frac, g_c2IconTextures, cfgID);
      cx += iconSize + gap;
    }
    if (ultUnlocked) {
      DrawSkillIcon(ImVec2(cx, anchorY), ultFrac, g_ultIconTextures, cfgID);
      cx += iconSize + gap;
    }
    DrawSkillIcon(ImVec2(cx, anchorY), btFrac, g_btIconTextures, btID);
  }
}
#pragma mark - ViewController
- (instancetype)initWithNibName:(nullable NSString *)nibNameOrNil
                         bundle:(nullable NSBundle *)nibBundleOrNil {
  self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
  CacheScreenMetrics();
  _device = MTLCreateSystemDefaultDevice();
  _commandQueue = [_device newCommandQueue];
  if (!self.device)
    abort();
  IMGUI_CHECKVERSION();
  ImGui::CreateContext();
  LoadItemIcons(_device);
  ImGuiIO &io = ImGui::GetIO();
  (void)io;
  ImGui::StyleColorsClassic();
  io.Fonts->AddFontFromMemoryCompressedTTF(
      (void *)zzz_compressed_data, zzz_compressed_size, 60.0f, NULL,
      io.Fonts->GetGlyphRangesVietnamese());
  {
    ImFontConfig cfg;
    cfg.MergeMode = true;
    cfg.GlyphMinAdvanceX = 60.0f;
    cfg.GlyphMaxAdvanceX = 60.0f;
    cfg.PixelSnapH = true;
    static const ImWchar icon_ranges[] = {0xe000, 0xf8ff, 0};
    io.Fonts->AddFontFromMemoryCompressedTTF(
        (void *)font_awesome_data, font_awesome_size, 60.0f, &cfg, icon_ranges);
  }
  ImGui_ImplMetal_Init(_device);
  return self;
}
+ (void)showChange:(BOOL)open {
  MenDeal = open;
}
- (MTKView *)mtkView {
  return (MTKView *)self.view;
}
- (void)loadView {
  CGRect rootFrame = [UIApplication sharedApplication]
                         .windows[0]
                         .rootViewController.view.frame;
  self.view =
      [[MTKView alloc] initWithFrame:CGRectMake(0, 0, rootFrame.size.width,
                                                rootFrame.size.height)];
}
- (void)viewDidLoad {
  [super viewDidLoad];
  self.mtkView.device = self.device;
  self.mtkView.delegate = self;
  self.mtkView.preferredFramesPerSecond = 60;
  self.mtkView.clearColor = MTLClearColorMake(0, 0, 0, 0);
  self.mtkView.backgroundColor = [UIColor colorWithRed:0
                                                 green:0
                                                  blue:0
                                                 alpha:0];
  self.mtkView.clipsToBounds = YES;
  LoadConfig();
  FetchOnlineConfig();
  // Chuyển initial_setup sang background thread để tránh lag main thread khi
  // game khởi động
  dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
    initial_setup();
    dispatch_async(dispatch_get_main_queue(), ^{
      [self setupQuickToggleButtons];
      g_initReady = true;
    });
  });
}
#pragma mark - Touch
- (void)updateIOWithTouchEvent:(UIEvent *)event {
  UITouch *any = event.allTouches.anyObject;
  ImGuiIO &io = ImGui::GetIO();
  CGPoint loc = [any locationInView:self.view];
  io.MousePos = ImVec2(loc.x, loc.y);
  BOOL active = NO;
  for (UITouch *t in event.allTouches)
    if (t.phase != UITouchPhaseEnded && t.phase != UITouchPhaseCancelled) {
      active = YES;
      break;
    }
  io.MouseDown[0] = active;
}
- (void)touchesBegan:(NSSet<UITouch *> *)t withEvent:(UIEvent *)e {
  [self updateIOWithTouchEvent:e];
}
- (void)touchesMoved:(NSSet<UITouch *> *)t withEvent:(UIEvent *)e {
  [self updateIOWithTouchEvent:e];
}
- (void)touchesCancelled:(NSSet<UITouch *> *)t withEvent:(UIEvent *)e {
  [self updateIOWithTouchEvent:e];
}
- (void)touchesEnded:(NSSet<UITouch *> *)t withEvent:(UIEvent *)e {
  [self updateIOWithTouchEvent:e];
}
#pragma mark - MTKViewDelegate
- (void)drawInMTKView:(MTKView *)view {
  ImGuiIO &io = ImGui::GetIO();
  io.DisplaySize.x = view.bounds.size.width;
  io.DisplaySize.y = view.bounds.size.height;
  static CGFloat cachedScale = 0;
  if (cachedScale == 0)
    cachedScale = view.window.screen.scale ?: UIScreen.mainScreen.scale;
  io.DisplayFramebufferScale = ImVec2(cachedScale, cachedScale);
  io.DeltaTime = 1.f / 60.f;
  id<MTLCommandBuffer> cmd = [self.commandQueue commandBuffer];
  [self.view setUserInteractionEnabled:MenDeal];
  MTLRenderPassDescriptor *rpd = view.currentRenderPassDescriptor;
  if (!rpd) {
    [cmd commit];
    return;
  }
  id<MTLRenderCommandEncoder> enc =
      [cmd renderCommandEncoderWithDescriptor:rpd];
  [enc pushDebugGroup:@"ImGui"];
  ImGui_ImplMetal_NewFrame(rpd);
  ImGui::NewFrame();
  static bool fontScaleSet = false;
  if (!fontScaleSet) {
    ImGui::GetFont()->Scale = 15.f / ImGui::GetFont()->FontSize;
    fontScaleSet = true;
  }
  // Chờ initial_setup hoàn thành, hiển thị loading indicator
  if (!g_initReady) {
    ImDrawList *dl = ImGui::GetForegroundDrawList();
    static float dotAnim = 0.f;
    dotAnim += io.DeltaTime * 3.0f;
    int dots = ((int)dotAnim) % 4;
    char loadBuf[32];
    snprintf(loadBuf, sizeof(loadBuf), "Initializing%.*s", dots, "...");
    ImVec2 sz = ImGui::CalcTextSize(loadBuf);
    float cx = (io.DisplaySize.x - sz.x) * 0.5f;
    float cy = io.DisplaySize.y * 0.5f - sz.y * 0.5f;
    dl->AddRectFilled(ImVec2(cx - 8, cy - 4),
                      ImVec2(cx + sz.x + 8, cy + sz.y + 4),
                      IM_COL32(0, 0, 0, 160), 6.0f);
    dl->AddText(ImVec2(cx, cy), IM_COL32(200, 200, 220, 255), loadBuf);
    ImGui::Render();
    ImGui_ImplMetal_RenderDrawData(ImGui::GetDrawData(), cmd, enc);
    [enc popDebugGroup];
    [enc endEncoding];
    [cmd presentDrawable:view.currentDrawable];
    [cmd commit];
    return;
  }
  static CGFloat wx = 0, wy = 0;
  static bool winPosInit = false;
  if (!winPosInit) {
    CGRect rootFrame = [UIApplication sharedApplication]
                           .windows[0]
                           .rootViewController.view.frame;
    wx = (rootFrame.size.width - 360) / 2;
    wy = 30;
    winPosInit = true;
  }
  ImGui::SetNextWindowPos(ImVec2(wx, wy), ImGuiCond_FirstUseEver);
  static bool showEspSettings = false;
  static bool showRankSettings = false;
  static bool showFakeNameSettings = false;
  static bool showQtSettings = false;
  if (MenDeal && !showEspSettings && !showRankSettings &&
      !showFakeNameSettings && !showQtSettings) {
    static int s_activeTab = 0;
    static float s_tabAlpha = 1.0f;
    static bool s_wantHaptic = false;
    ImGui::SetNextWindowSizeConstraints(ImVec2(360, 0), ImVec2(360, FLT_MAX));
    ImGui::PushStyleVar(ImGuiStyleVar_WindowRounding, 10.0f);
    ImGui::PushStyleVar(ImGuiStyleVar_WindowPadding, ImVec2(10, 8));
    ImGui::PushStyleVar(ImGuiStyleVar_WindowMinSize, ImVec2(290, 10));
    ImGui::PushStyleColor(ImGuiCol_WindowBg,
                          ImVec4(0.06f, 0.06f, 0.11f, 0.97f));
    ImGui::PushStyleColor(ImGuiCol_Border, ImVec4(0.18f, 0.38f, 0.82f, 0.50f));
    ImGui::Begin("##aovmenu", &MenDeal,
                 ImGuiWindowFlags_NoTitleBar | ImGuiWindowFlags_NoScrollbar |
                     ImGuiWindowFlags_AlwaysAutoResize);
    ImGui::PopStyleColor(2);
    ImGui::PopStyleVar(3);
    {
      ImDrawList *dl = ImGui::GetWindowDrawList();
      ImVec2 wpos = ImGui::GetWindowPos();
      float ww = ImGui::GetWindowWidth();
      const float hdrH = 26.0f;
      dl->AddRectFilled(wpos, ImVec2(wpos.x + ww, wpos.y + hdrH),
                        IM_COL32(10, 10, 20, 200), 10.0f,
                        ImDrawFlags_RoundCornersTop);
      const char *ico = ICON_FA_TELEGRAM;
      ImVec2 icoSz = ImGui::CalcTextSize(ico);
      float icoX = wpos.x + 8.f;
      float icoY = wpos.y + (hdrH - icoSz.y) * 0.5f;
      ImVec2 tgMin(icoX - 2.f, wpos.y);
      ImVec2 tgMax(icoX + icoSz.x + 4.f, wpos.y + hdrH);
      bool tgHov = ImGui::IsMouseHoveringRect(tgMin, tgMax, false);
      dl->AddText(ImVec2(icoX, icoY),
                  tgHov ? IM_COL32(100, 200, 255, 255)
                        : IM_COL32(80, 160, 255, 200),
                  ico);
      if (tgHov && ImGui::IsMouseReleased(0) &&
          fabsf(ImGui::GetMouseDragDelta(0).x) < 3.f &&
          fabsf(ImGui::GetMouseDragDelta(0).y) < 3.f) {
        NSURL *url =
            [NSURL URLWithString:NSOBFUSCATE("https://t.me/anhvu99ers")];
        [[UIApplication sharedApplication] openURL:url
                                           options:@{}
                                 completionHandler:nil];
      }
      const char *title = OBFUSCATE("AovCheat Lite");
      ImVec2 tSz = ImGui::CalcTextSize(title);
      dl->AddText(
          ImVec2(wpos.x + (ww - tSz.x) * 0.5f, wpos.y + (hdrH - tSz.y) * 0.5f),
          IM_COL32(210, 225, 255, 220), title);
      {
        const char *langIco = ICON_FA_LANGUAGE;
        const char *langBadge = g_langVI ? "VI" : "EN";
        ImVec2 icoSzL = ImGui::CalcTextSize(langIco);
        ImVec2 bdgSz = ImGui::CalcTextSize(langBadge);
        float gap = 3.f;
        float padX = 5.f;
        float btnW = padX + icoSzL.x + gap + bdgSz.x + padX;
        float btnH = hdrH - 6.f;
        ImVec2 lMin(wpos.x + ww - 18.f - 5.f - btnW - 4.f,
                    wpos.y + (hdrH - btnH) * 0.5f);
        ImVec2 lMax(lMin.x + btnW, lMin.y + btnH);
        bool lHov = ImGui::IsMouseHoveringRect(lMin, lMax, false);
        dl->AddRectFilled(lMin, lMax,
                          lHov ? IM_COL32(55, 130, 230, 220)
                               : IM_COL32(30, 70, 160, 160),
                          4.f);
        float cy = lMin.y + (btnH - icoSzL.y) * 0.5f;
        dl->AddText(ImVec2(lMin.x + padX, cy), IM_COL32(180, 215, 255, 230),
                    langIco);
        dl->AddText(ImVec2(lMin.x + padX + icoSzL.x + gap,
                           lMin.y + (btnH - bdgSz.y) * 0.5f),
                    g_langVI ? IM_COL32(100, 220, 140, 255)
                             : IM_COL32(255, 200, 80, 255),
                    langBadge);
        if (lHov && ImGui::IsMouseReleased(0) &&
            fabsf(ImGui::GetMouseDragDelta(0).x) < 3.f &&
            fabsf(ImGui::GetMouseDragDelta(0).y) < 3.f) {
          g_langVI = !g_langVI;
          HapticLight();
        }
      }
      const float btnSz = 18.f;
      ImVec2 closeMin(wpos.x + ww - btnSz - 5.f,
                      wpos.y + (hdrH - btnSz) * 0.5f);
      ImVec2 closeMax(closeMin.x + btnSz, closeMin.y + btnSz);
      bool closeHov = ImGui::IsMouseHoveringRect(closeMin, closeMax, false);
      dl->AddCircleFilled(ImVec2((closeMin.x + closeMax.x) * 0.5f,
                                 (closeMin.y + closeMax.y) * 0.5f),
                          btnSz * 0.5f,
                          closeHov ? IM_COL32(200, 50, 50, 220)
                                   : IM_COL32(160, 40, 40, 160));
      float pad = 5.f;
      dl->AddLine(ImVec2(closeMin.x + pad, closeMin.y + pad),
                  ImVec2(closeMax.x - pad, closeMax.y - pad),
                  IM_COL32(255, 255, 255, 230), 1.5f);
      dl->AddLine(ImVec2(closeMax.x - pad, closeMin.y + pad),
                  ImVec2(closeMin.x + pad, closeMax.y - pad),
                  IM_COL32(255, 255, 255, 230), 1.5f);
      ImGui::SetCursorScreenPos(wpos);
      ImGui::InvisibleButton("##hdrdrag", ImVec2(ww, hdrH));
      {
        static ImVec2 s_dragOrigin;
        if (ImGui::IsItemActivated())
          s_dragOrigin = wpos;
        if (ImGui::IsItemActive() && ImGui::IsMouseDragging(0, 0.f)) {
          ImVec2 delta = ImGui::GetMouseDragDelta(0, 0.f);
          ImGui::SetWindowPos(
              ImVec2(s_dragOrigin.x + delta.x, s_dragOrigin.y + delta.y));
        }
      }
      if (ImGui::IsMouseReleased(0) && closeHov &&
          fabsf(ImGui::GetMouseDragDelta(0).x) < 3.f &&
          fabsf(ImGui::GetMouseDragDelta(0).y) < 3.f) {
        MenDeal = false;
      }
    }
    // ── Sidebar + Content layout ──
    ImGui::Columns(2, "##sblayout", false);
    ImGui::SetColumnWidth(0, 64.f);
    {
      // ── LEFT: Vertical sidebar tabs ──
      ImDrawList *sdl = ImGui::GetWindowDrawList();
      float sbW = 60.f;
      ImVec2 sbOrig = ImGui::GetCursorScreenPos();
      // Sidebar background
      sdl->AddRectFilled(ImVec2(sbOrig.x - 2.f, sbOrig.y - 4.f),
                         ImVec2(sbOrig.x + sbW, sbOrig.y + 240.f),
                         IM_COL32(8, 10, 22, 220), 8.f);
      const char *kIco[] = {ICON_FA_FIRE, ICON_FA_PAINT_BRUSH,
                             ICON_FA_CROSSHAIRS, ICON_FA_COG};
      const char *kLbl[] = {OBFUSCATE("Hack"), OBFUSCATE("Mod"),
                             OBFUSCATE("Auto"), OBFUSCATE("Other")};
      for (int i = 0; i < 4; i++) {
        ImVec2 sp = ImGui::GetCursorScreenPos();
        const float tH = 54.f;
        bool active = (s_activeTab == i);
        bool hov = ImGui::IsMouseHoveringRect(sp, ImVec2(sp.x + sbW, sp.y + tH));
        if (active)
          sdl->AddRectFilled(sp, ImVec2(sp.x + sbW, sp.y + tH),
                             IM_COL32(22, 75, 185, 220), 8.f);
        else if (hov)
          sdl->AddRectFilled(sp, ImVec2(sp.x + sbW, sp.y + tH),
                             IM_COL32(20, 35, 80, 140), 8.f);
        // Active indicator bar on right edge
        if (active)
          sdl->AddRectFilled(ImVec2(sp.x + sbW - 3.f, sp.y + 10.f),
                             ImVec2(sp.x + sbW, sp.y + tH - 10.f),
                             IM_COL32(110, 190, 255, 255), 2.f);
        ImVec2 iSz = ImGui::CalcTextSize(kIco[i]);
        ImVec2 lSz = ImGui::CalcTextSize(kLbl[i]);
        float bH = iSz.y + 3.f + lSz.y;
        float topY = sp.y + (tH - bH) * 0.5f;
        ImU32 col = active ? IM_COL32(255, 255, 255, 255)
                           : IM_COL32(110, 130, 175, 200);
        sdl->AddText(ImVec2(sp.x + (sbW - iSz.x) * 0.5f, topY), col, kIco[i]);
        sdl->AddText(ImVec2(sp.x + (sbW - lSz.x) * 0.5f, topY + iSz.y + 3.f),
                     col, kLbl[i]);
        ImGui::PushID(i);
        ImGui::InvisibleButton("##sb", ImVec2(sbW, tH));
        if (ImGui::IsItemClicked() && s_activeTab != i) {
          s_activeTab = i;
          s_tabAlpha = 0.f;
        }
        ImGui::PopID();
        ImGui::SetCursorScreenPos(ImVec2(sp.x, sp.y + tH + 3.f));
      }
    }
    ImGui::NextColumn();
    // Vertical divider
    {
      ImVec2 dvTop = ImGui::GetCursorScreenPos();
      dvTop.x -= 4.f;
      ImGui::GetWindowDrawList()->AddLine(
          dvTop, ImVec2(dvTop.x, dvTop.y + 230.f),
          IM_COL32(40, 80, 180, 120), 1.f);
    }
    ImGui::Spacing();
    {
      float dt = ImGui::GetIO().DeltaTime;
      s_tabAlpha = fminf(s_tabAlpha + dt * 6.0f, 1.0f);
    }
    ImGui::PushStyleVar(ImGuiStyleVar_Alpha, s_tabAlpha);
    if (s_activeTab == 0) {
      if (AovToggle(OBFUSCATE("HackMap"), &HackMap)) {
        SaveConfig();
        s_wantHaptic = true;
      }
      AovHint(LS("Hiện icon CD skill địch trên màn hình",
                 "Show enemy skill CD icons on screen"),
              "##hint_esp");
      ImGui::SameLine(0, 4.f);
      {
        float sz = ImGui::GetFrameHeight() * 0.72f;
        float fh = ImGui::GetFrameHeight();
        ImVec2 p = ImGui::GetCursorScreenPos();
        ImVec2 cp = ImVec2(p.x + sz * 0.5f, p.y + fh * 0.5f);
        bool hov = ImGui::IsMouseHoveringRect(p, ImVec2(p.x + sz, p.y + fh));
        ImDrawList *dl = ImGui::GetWindowDrawList();
        dl->AddCircleFilled(cp, sz * 0.5f,
                            hov ? IM_COL32(60, 130, 230, 220)
                                : IM_COL32(35, 50, 90, 160));
        ImVec2 ico = ImGui::CalcTextSize(ICON_FA_COG);
        dl->AddText(ImVec2(cp.x - ico.x * 0.5f, cp.y - ico.y * 0.5f),
                    hov ? IM_COL32(255, 255, 255, 255)
                        : IM_COL32(160, 190, 255, 200),
                    ICON_FA_COG);
        if (ImGui::InvisibleButton("##espcfg", ImVec2(sz, fh))) {
          showEspSettings = !showEspSettings;
          s_wantHaptic = true;
        }
        ImGui::SameLine(0, 6.f);
      }
      if (AovToggle(LS("Xem Bổ Trợ / Ult", "Show BT / Ult"), &hiencooldowns)) {
        SaveConfig();
        s_wantHaptic = true;
      }
      ImGui::Separator();
      if (AovSlider(LS("Camera Height", "Camera Height"), &CameraZoom, -1.0f,
                    10.0f, "%.1fx")) {
        SaveConfig();
      }
      if (AovToggle(LS("Khóa Camera", "Lock Camera"), &lockCam)) {
        SaveConfig();
        s_wantHaptic = true;
      }
      // ── Fake Name ──
      {
        float sz2 = ImGui::GetFrameHeight() * 0.72f;
        float fh2 = ImGui::GetFrameHeight();
        ImVec2 p2 = ImGui::GetCursorScreenPos();
        ImVec2 cp2 = ImVec2(p2.x + sz2 * 0.5f, p2.y + fh2 * 0.5f);
        bool hov2 =
            ImGui::IsMouseHoveringRect(p2, ImVec2(p2.x + sz2, p2.y + fh2));
        ImDrawList *dl2 = ImGui::GetWindowDrawList();
        dl2->AddCircleFilled(cp2, sz2 * 0.5f,
                             hov2 ? IM_COL32(60, 130, 230, 220)
                                  : IM_COL32(35, 50, 90, 160));
        ImVec2 ico2 = ImGui::CalcTextSize(ICON_FA_FONT);
        dl2->AddText(ImVec2(cp2.x - ico2.x * 0.5f, cp2.y - ico2.y * 0.5f),
                     hov2 ? IM_COL32(255, 255, 255, 255)
                          : IM_COL32(160, 190, 255, 200),
                     ICON_FA_FONT);
        if (ImGui::InvisibleButton("##fakenamecfg", ImVec2(sz2, fh2))) {
          showFakeNameSettings = !showFakeNameSettings;
          s_wantHaptic = true;
        }
        ImGui::SameLine(0, 6.f);
      }
      if (AovToggle(LS("Fake Name", "Fake Name"), &ChangeName)) {
        if (!ChangeName)
          NameMode = 0;
        s_fnGen++;
        s_hudNameGen.clear();
        SaveConfig();
        s_wantHaptic = true;
      }
      ImGui::Separator();
    }
    // (ESP overlay rendered after main menu End, below)
    if (s_activeTab == 1) {
      AovHint(LS("Mở khóa toàn bộ skin, EVO5. Skin 3s có thể bị lỗi hiệu ứng, "
                 "tìm file mod trên YouTube để tránh sự cố.",
                 "Unlock full skin, EVO5. 3s skins may have effect bugs, find "
                 "a mod file on YouTube to avoid issues."),
              "##hint_fullskin");
      ImGui::SameLine(0, 4.f);
      if (AovToggle(LS("Mod Full Skin", "Unlock Skin"), &unlockSkin)) {
        SaveConfig();
        s_wantHaptic = true;
      }
      if (!gOnlineConfigLoaded)
        ImGui::TextColored(ImVec4(1, 1, 0, 1), LS("Đang Tải...", "Loading..."));
      {
        std::vector<const char *> btnNames;
        for (auto &b : gButtons)
          btnNames.push_back(b.name.c_str());
        if (!btnNames.empty()) {
          if (selectedButtonIndex >= (int)btnNames.size())
            selectedButtonIndex = 0;
          if (AovCombo(LS("Mod Nút##skin", "Mod Button##skin"),
                       &selectedButtonIndex, btnNames.data(),
                       (int)btnNames.size())) {
            buttonID = gButtons[selectedButtonIndex].id;
            SaveConfig();
          }
        }
      }
      ImGui::Spacing();
      {
        std::vector<const char *> bcNames;
        for (auto &b : gBroadcast)
          bcNames.push_back(b.name.c_str());
        if (!bcNames.empty()) {
          if (selectedBroadcastIndex >= (int)bcNames.size())
            selectedBroadcastIndex = 0;
          if (AovCombo(LS("Mod Hạ##skin", "Mod Notify##skin"),
                       &selectedBroadcastIndex, bcNames.data(),
                       (int)bcNames.size())) {
            broadcastID = gBroadcast[selectedBroadcastIndex].id;
            SaveConfig();
          }
        }
      }
      ImGui::Spacing();
      {
        std::vector<const char *> solNames;
        for (auto &s : gSoldier)
          solNames.push_back(s.name.c_str());
        if (!solNames.empty()) {
          if (selectedSoldierIndex >= (int)solNames.size())
            selectedSoldierIndex = 0;
          if (AovCombo(LS("Mod Lính##skin", "Mod Soldier##skin"),
                       &selectedSoldierIndex, solNames.data(),
                       (int)solNames.size())) {
            soldierID = gSoldier[selectedSoldierIndex].id;
            SaveConfig();
          }
        }
      }
      ImGui::Spacing();

      // ── Action Buttons ──
      if (AovButton(LS("Mod Skin Qua File", "Mod Skin From File"),
                    ICON_FA_FOLDER_OPEN)) {
        [[main sharemain] modskinquafile];
        s_wantHaptic = true;
      }
      ImGui::Spacing();

      { // Video buttons – side by side
        float halfW = ImGui::GetContentRegionAvail().x * 0.5f - 4.f;
        if (AovButton(LS("Mod Video Sảnh", "Mod Lobby Video"), ICON_FA_VIDEO, 0,
                      ImVec2(halfW, 36.f))) {
          [VideoSanh pickVideo];
          s_wantHaptic = true;
        }
        ImGui::SameLine(0, 8.f);
        if (AovButton(LS("Khôi Phục Video", "Restore Video"), ICON_FA_UNDO, 0,
                      ImVec2(halfW, 36.f))) {
          [VideoSanh restoreVideo];
          s_wantHaptic = true;
        }
      }

      ImGui::Spacing();
      ImGui::Separator();
      ImGui::Spacing();

      // ── Danger Zone ──
      if (RenderConfirmAction(LS("Xóa Mod", "Delete Mod"),
                              LS("Bạn có chắc muốn xóa mod?",
                                 "Are you sure you want to delete mod?"),
                              LS("Xóa mod thành công! Đang thoát...",
                                 "Mod deleted! Exiting..."),
                              showDeleteModConfirm, deleteModTriggered,
                              deleteModTime, ICON_FA_TRASH)) {
        NSString *modPath =
            [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,
                                                 NSUserDomainMask, YES)
                    .firstObject stringByAppendingPathComponent:@"Resources"];
        if ([[NSFileManager defaultManager] fileExistsAtPath:modPath]) {
          [[NSFileManager defaultManager] removeItemAtPath:modPath error:nil];
        }
        deleteModTriggered = true;
        deleteModTime = CACurrentMediaTime();
        s_wantHaptic = true;
      }
    }
    if (s_activeTab == 2) {
      if (AovToggle(OBFUSCATE("Aim 3.0"), &AimbotEnable)) {
        SaveConfig();
        s_wantHaptic = true;
      }
      ImGui::SameLine(0, 4.f);
      ImGui::TextColored(ImVec4(1.0f, 0.0f, 0.0f, 1.0f),
                         OBFUSCATE("Hạn chế SD ( có thể 3 year)"));
      if (AimbotEnable) {
        const char *aimTypeItems[] = {LS("Gần Nhất", "Nearest"),
                                      LS("Máu Thấp Nhất", "Lowest HP"),
                                      LS("% Máu Thấp Nhất", "% Lowest HP"),
                                      LS("Gần Tia Nhất", "Nearest Ray")};
        if (AovCombo(LS("Kiểu Nhắm##aim", "Aim Type##aim"), &aimType,
                     aimTypeItems, IM_ARRAYSIZE(aimTypeItems))) {
          SaveConfig();
          s_wantHaptic = true;
        }
      }
      ImGui::Separator();
      if (AovToggle(LS("Auto Băng Sương", "Auto Frost"), &AutoBS)) {
        SaveConfig();
        s_wantHaptic = true;
      }
      if (AutoBS) {
        if (AovSlider(LS("Khi Máu Còn", "When HP Remains"), &AutoBSHp, 10.0f,
                      80.0f, "%.0f%%")) {
          SaveConfig();
        }
      }
      ImGui::Separator();
      if (AovToggle(LS("Auto Bộc Phá", "Auto Execute"), &AutoBP)) {
        SaveConfig();
        s_wantHaptic = true;
      }
      if (AutoBP) {
        if (AovSlider(LS("Khi Máu Dưới", "When HP Under"), &AutoBPHp, 5.0f,
                      50.0f, "%.0f%%")) {
          SaveConfig();
        }
      }
      ImGui::Separator();
      if (AovToggle(LS("Auto Trừng Trị", "Auto Punish"), &AutoTT)) {
        if (self.autoTTToggleBtn)
          self.autoTTToggleBtn.alpha = AutoTT ? 1.0 : 0.35;
        SaveConfig();
        s_wantHaptic = true;
      }
      if (AutoTT) {
        static const char *ttModeItemsVI[] = {"Tất Cả Quái", "Chỉ Rồng Tà"};
        static const char *ttModeItemsEN[] = {"All Monsters",
                                              "Evil Dragon Only"};
        const char *const *ttModeItems =
            g_langVI ? ttModeItemsVI : ttModeItemsEN;
        if (AovCombo(LS("Mục Tiêu TT##tt", "TT Target##tt"), &AutoTTMode,
                     ttModeItems, 2)) {
          SaveConfig();
          s_wantHaptic = true;
        }
      }
      ImGui::Separator();
      if (AovToggle(LS("Auto Mua Bán Đồ", "Auto Equip"), &muaitem)) {
        doiitem = muaitem;
        fullslot = muaitem;
        checktime = muaitem;
        SaveConfig();
        s_wantHaptic = true;
      }
      if (muaitem) {
        SettingItemEquip();
      }
    }
    if (s_activeTab == 3) {
      {
        float sz = ImGui::GetFrameHeight() * 0.72f;
        float fh = ImGui::GetFrameHeight();
        ImVec2 p = ImGui::GetCursorScreenPos();
        ImVec2 cp = ImVec2(p.x + sz * 0.5f, p.y + fh * 0.5f);
        bool hov = ImGui::IsMouseHoveringRect(p, ImVec2(p.x + sz, p.y + fh));
        ImDrawList *dl = ImGui::GetWindowDrawList();
        dl->AddCircleFilled(cp, sz * 0.5f,
                            hov ? IM_COL32(60, 130, 230, 220)
                                : IM_COL32(35, 50, 90, 160));
        ImVec2 ico = ImGui::CalcTextSize(ICON_FA_COG);
        dl->AddText(ImVec2(cp.x - ico.x * 0.5f, cp.y - ico.y * 0.5f),
                    hov ? IM_COL32(255, 255, 255, 255)
                        : IM_COL32(160, 190, 255, 200),
                    ICON_FA_COG);
        if (ImGui::InvisibleButton("##rankcfg", ImVec2(sz, fh))) {
          showRankSettings = !showRankSettings;
          s_wantHaptic = true;
        }
        ImGui::SameLine(0, 6.f);
      }
      if (AovToggle(LS("Mod Rank", "Mod Rank"), &fakerank)) {
        SaveConfig();
        s_wantHaptic = true;
      }
      AovHint(LS("Chức năng nổ trụ, bật trước phút thứ 3. Dùng cho việc xoá "
                 "lsđ game đang chơi ( Áp dụng trong Buff Rank, Vô Hạn Bot)",
                 "AutoWin bot"),
              "##hint_autowin");
      ImGui::SameLine(0, 4.f);
      if (AovToggle(LS("Auto Win", "Auto Win"), &AutoWin)) {
        s_wantHaptic = true;
      }
      ImGui::Separator();

      {
        ImDrawList *dl = ImGui::GetWindowDrawList();
        float fh = ImGui::GetFrameHeight();
        float sz = fh * 0.72f;
        ImVec2 p = ImGui::GetCursorScreenPos();
        ImVec2 cp = ImVec2(p.x + sz * 0.5f, p.y + fh * 0.5f);
        bool hov = ImGui::IsMouseHoveringRect(p, ImVec2(p.x + sz, p.y + fh));
        dl->AddCircleFilled(cp, sz * 0.5f,
                            hov ? IM_COL32(60, 130, 230, 220)
                                : IM_COL32(35, 50, 90, 160));
        dl->AddText(ImVec2(cp.x - ImGui::CalcTextSize(ICON_FA_COG).x * 0.5f,
                           cp.y - ImGui::GetTextLineHeight() * 0.5f),
                    IM_COL32(200, 220, 255, 230), ICON_FA_COG);
        if (ImGui::InvisibleButton("##qtcfg", ImVec2(sz, fh)))
          showQtSettings = !showQtSettings;
        ImGui::SameLine(0, 6.f);
      }
      if (AovToggle(LS("Bật Tắt Chức Năng Nhanh", "Quick Toggle Buttons"),
                    &showQuickToggle)) {
        SaveConfig();
        [self updateQuickToggleVisibility];
        s_wantHaptic = true;
      }

      ImGui::Separator();

      ImGui::Spacing();

      if (RenderConfirmAction(LS("Đăng Xuất Acc Nhanh", "Quick Logout"),
                              LS("Bạn có chắc muốn đăng xuất?",
                                 "Are you sure you want to logout?"),
                              LS("Đăng xuất thành công! Đang thoát...",
                                 "Logout success! Exiting..."),
                              showLogoutConfirm, logoutTriggered, logoutTime,
                              ICON_FA_SIGN_OUT)) {
        NSString *filePath = [NSSearchPathForDirectoriesInDomains(
                                  NSDocumentDirectory, NSUserDomainMask, YES)
                                  .firstObject
            stringByAppendingPathComponent:@"beetalk_session.db"];
        if ([[NSFileManager defaultManager] fileExistsAtPath:filePath]) {
          [[NSFileManager defaultManager] removeItemAtPath:filePath error:nil];
        }
        logoutTriggered = true;
        logoutTime = CACurrentMediaTime();
        s_wantHaptic = true;
      }
    }
    if (s_wantHaptic) {
      s_wantHaptic = false;
      HapticLight();
    }
    ImGui::PopStyleVar(); // tab alpha
    ImGui::Columns(1);
    ImGui::End();         // main menu
  }
  // ── Rank Settings Overlay (slide-up animation) ──
  {
    static float s_rkAnim = 0.f;
    static float s_rankWinH = 160.f;
    static bool s_rkPrev = false;
    static bool s_rkJustOpened = false;
    float dt = ImGui::GetIO().DeltaTime;
    bool rkOpen = (MenDeal && showRankSettings);
    if (rkOpen && !s_rkPrev)
      s_rkJustOpened = true; // just toggled on
    else
      s_rkJustOpened = false;
    s_rkPrev = rkOpen;
    float rkTarget = rkOpen ? 1.f : 0.f;
    s_rkAnim += (rkTarget - s_rkAnim) * fminf(1.f, dt * 22.f);
    if (s_rkAnim > 0.01f) {
      ImGuiIO &io = ImGui::GetIO();
      // backdrop
      ImGui::GetBackgroundDrawList()->AddRectFilled(
          ImVec2(0, 0), io.DisplaySize,
          IM_COL32(0, 0, 0, (int)(80 * s_rkAnim)));
      float slideY = (1.f - s_rkAnim) * (s_rankWinH + 80.f);
      float rX = 100.f;
      float rY = io.DisplaySize.y - s_rankWinH - 8.f + slideY;
      ImGui::SetNextWindowPos(ImVec2(rX, rY), ImGuiCond_Always);
      ImGui::SetNextWindowSizeConstraints(
          ImVec2(io.DisplaySize.x - 200.f, 0),
          ImVec2(io.DisplaySize.x - 200.f, FLT_MAX));
      ImGui::SetNextWindowBgAlpha(0.93f * s_rkAnim);
      ImGui::PushStyleVar(ImGuiStyleVar_Alpha, s_rkAnim);
      ImGui::PushStyleVar(ImGuiStyleVar_WindowRounding, 14.f);
      ImGui::PushStyleVar(ImGuiStyleVar_WindowBorderSize, 1.f);
      ImGui::PushStyleVar(ImGuiStyleVar_WindowPadding, ImVec2(10.f, 10.f));
      ImGui::PushStyleColor(ImGuiCol_WindowBg,
                            ImVec4(0.06f, 0.09f, 0.18f, 0.93f));
      ImGui::PushStyleColor(ImGuiCol_Border,
                            ImVec4(0.20f, 0.45f, 0.90f, 0.60f));
      ImGui::Begin(
          "##RankSettings", nullptr,
          ImGuiWindowFlags_NoTitleBar | ImGuiWindowFlags_NoMove |
              ImGuiWindowFlags_NoCollapse | ImGuiWindowFlags_NoSavedSettings |
              ImGuiWindowFlags_NoScrollbar | ImGuiWindowFlags_AlwaysAutoResize);
      ImGui::TextColored(ImVec4(0.55f, 0.82f, 1.f, 1.f), "%s  %s",
                         ICON_FA_TROPHY,
                         LS("Cài Đặt Mod Rank", "Mod Rank Settings"));
      ImGui::SameLine();
      float rCloseX = ImGui::GetContentRegionAvail().x -
                      ImGui::CalcTextSize(ICON_FA_TIMES).x - 2.f;
      if (rCloseX > 0)
        ImGui::SetCursorPosX(ImGui::GetCursorPosX() + rCloseX);
      if (ImGui::InvisibleButton(
              "##rkclose", ImVec2(ImGui::CalcTextSize(ICON_FA_TIMES).x + 8.f,
                                  ImGui::GetFrameHeight())))
        showRankSettings = false;
      ImGui::GetWindowDrawList()->AddText(
          ImVec2(ImGui::GetItemRectMin().x + 4.f,
                 ImGui::GetItemRectMin().y +
                     (ImGui::GetFrameHeight() - ImGui::GetTextLineHeight()) *
                         0.5f),
          ImGui::IsItemHovered() ? IM_COL32(255, 100, 100, 255)
                                 : IM_COL32(180, 180, 200, 200),
          ICON_FA_TIMES);
      ImGui::Separator();
      ImGui::Spacing();
      static bool s_rkHaptic = false;
      if (AovToggle(LS("Mod Rank", "Mod Rank"), &fakerank)) {
        SaveConfig();
        s_rkHaptic = true;
      }
      if (fakerank) {
        ImGui::Spacing();
        // ── Loại Cục Top: inline buttons (tránh vấn đề combo iOS) ──
        {
          const char *lbl = LS("Loại Cục Top", "Top Badge");
          ImGui::TextColored(ImVec4(0.55f, 0.75f, 1.f, 0.9f), "%s", lbl);
          float btnW = (ImGui::GetContentRegionAvail().x -
                        4.f * (kRewardOptionCount - 1)) /
                       kRewardOptionCount;
          ImGui::PushStyleVar(ImGuiStyleVar_FrameRounding, 6.f);
          ImGui::PushStyleVar(ImGuiStyleVar_ItemSpacing, ImVec2(4.f, 4.f));
          for (int ri = 0; ri < kRewardOptionCount; ri++) {
            bool sel = (rewardOptionIndex == ri);
            if (sel)
              ImGui::PushStyleColor(ImGuiCol_Button,
                                    ImVec4(0.09f, 0.40f, 0.95f, 0.90f));
            else
              ImGui::PushStyleColor(ImGuiCol_Button,
                                    ImVec4(0.10f, 0.12f, 0.25f, 0.80f));
            ImGui::PushStyleColor(ImGuiCol_ButtonHovered,
                                  ImVec4(0.15f, 0.50f, 1.00f, 0.85f));
            ImGui::PushStyleColor(ImGuiCol_ButtonActive,
                                  ImVec4(0.06f, 0.30f, 0.80f, 1.00f));
            char bid[32];
            snprintf(bid, sizeof(bid), "%s##rw%d", rewardOptions[ri].name, ri);
            if (ImGui::Button(bid, ImVec2(btnW, 28.f))) {
              rewardOptionIndex = ri;
              SaveConfig();
            }
            ImGui::PopStyleColor(3);
            if (ri < kRewardOptionCount - 1)
              ImGui::SameLine();
          }
          ImGui::PopStyleVar(2);
        }
        ImGui::Spacing();
        {
          float v = (float)topnumber;
          if (AovSlider(LS("Vị Trí Top", "Top Position"), &v, 1.f, 100.f,
                        "%.0f")) {
            topnumber = (int)v;
            SaveConfig();
          }
        }
        ImGui::Spacing();
        {
          float v = (float)rankStar;
          if (AovSlider(LS("Số Sao", "Stars"), &v, 0.f, 1200.f, "%.0f")) {
            rankStar = (int)v;
            SaveConfig();
          }
        }
      }
      if (s_rkHaptic) {
        s_rkHaptic = false;
        HapticLight();
      }
      // close on tap outside (skip the very first frame to avoid self-closing)
      if (!s_rkJustOpened && showRankSettings && ImGui::IsMouseReleased(0) &&
          !ImGui::IsWindowHovered(ImGuiHoveredFlags_RootAndChildWindows))
        showRankSettings = false;
      s_rankWinH = ImGui::GetWindowHeight();
      ImGui::End();
      ImGui::PopStyleColor(2);
      ImGui::PopStyleVar(4);
    }
  }
  // ── Quick Toggle Settings Overlay (slide-up) ──
  {
    static float s_qtAnim = 0.f;
    static float s_qtWinH = 120.f;
    static bool s_qtPrev = false;
    static bool s_qtJustOpened = false;
    float dt = ImGui::GetIO().DeltaTime;
    bool qtOpen = (MenDeal && showQtSettings);
    if (qtOpen && !s_qtPrev)
      s_qtJustOpened = true;
    else
      s_qtJustOpened = false;
    s_qtPrev = qtOpen;
    float qtTarget = qtOpen ? 1.f : 0.f;
    s_qtAnim += (qtTarget - s_qtAnim) * fminf(1.f, dt * 22.f);
    if (s_qtAnim > 0.01f) {
      ImGuiIO &io = ImGui::GetIO();
      ImGui::GetBackgroundDrawList()->AddRectFilled(
          ImVec2(0, 0), io.DisplaySize,
          IM_COL32(0, 0, 0, (int)(80 * s_qtAnim)));
      float slideY = (1.f - s_qtAnim) * (s_qtWinH + 80.f);
      float qtX = 100.f;
      float qtY = io.DisplaySize.y - s_qtWinH - 8.f + slideY;
      ImGui::SetNextWindowPos(ImVec2(qtX, qtY), ImGuiCond_Always);
      ImGui::SetNextWindowSizeConstraints(
          ImVec2(io.DisplaySize.x - 200.f, 0),
          ImVec2(io.DisplaySize.x - 200.f, FLT_MAX));
      ImGui::SetNextWindowBgAlpha(0.93f * s_qtAnim);
      ImGui::PushStyleVar(ImGuiStyleVar_Alpha, s_qtAnim);
      ImGui::PushStyleVar(ImGuiStyleVar_WindowRounding, 14.f);
      ImGui::PushStyleVar(ImGuiStyleVar_WindowBorderSize, 1.f);
      ImGui::PushStyleVar(ImGuiStyleVar_WindowPadding, ImVec2(10.f, 10.f));
      ImGui::PushStyleColor(ImGuiCol_WindowBg,
                            ImVec4(0.06f, 0.09f, 0.18f, 0.93f));
      ImGui::PushStyleColor(ImGuiCol_Border,
                            ImVec4(0.20f, 0.45f, 0.90f, 0.60f));
      ImGui::Begin(
          "##QtSettings", nullptr,
          ImGuiWindowFlags_NoTitleBar | ImGuiWindowFlags_NoMove |
              ImGuiWindowFlags_NoCollapse | ImGuiWindowFlags_NoSavedSettings |
              ImGuiWindowFlags_NoScrollbar | ImGuiWindowFlags_AlwaysAutoResize);
      ImGui::TextColored(ImVec4(0.55f, 0.82f, 1.f, 1.f), "%s  %s", ICON_FA_COG,
                         LS("Chọn Icon Nút Nhanh", "Quick Button Icons"));
      ImGui::SameLine();
      float qtCloseX = ImGui::GetContentRegionAvail().x -
                       ImGui::CalcTextSize(ICON_FA_TIMES).x - 2.f;
      if (qtCloseX > 0)
        ImGui::SetCursorPosX(ImGui::GetCursorPosX() + qtCloseX);
      if (ImGui::InvisibleButton(
              "##qtclose", ImVec2(ImGui::CalcTextSize(ICON_FA_TIMES).x + 8.f,
                                  ImGui::GetFrameHeight())))
        showQtSettings = false;
      ImGui::GetWindowDrawList()->AddText(
          ImVec2(ImGui::GetItemRectMin().x + 4.f,
                 ImGui::GetItemRectMin().y +
                     (ImGui::GetFrameHeight() - ImGui::GetTextLineHeight()) *
                         0.5f),
          ImGui::IsItemHovered() ? IM_COL32(255, 100, 100, 255)
                                 : IM_COL32(180, 180, 200, 200),
          ICON_FA_TIMES);
      ImGui::Separator();
      ImGui::Spacing();
      ImGui::TextColored(
          ImVec4(0.65f, 0.80f, 1.f, 0.80f), "%s",
          LS("Bật/tắt từng icon trên màn hình:", "Toggle each button icon:"));
      ImGui::Spacing();
      if (AovToggle(LS("Aim Bot", "Aim Bot"), &qtShowAim)) {
        SaveConfig();
        [self updateQuickToggleVisibility];
        HapticLight();
      }
      if (AovToggle(LS("Auto Trang Bị", "Auto Equip"), &qtShowAuto)) {
        SaveConfig();
        [self updateQuickToggleVisibility];
        HapticLight();
      }
      if (AovToggle(LS("Auto Tiêu Thụ", "Auto Use"), &qtShowAutoTT)) {
        SaveConfig();
        [self updateQuickToggleVisibility];
        HapticLight();
      }
      if (!s_qtJustOpened && showQtSettings && ImGui::IsMouseReleased(0) &&
          !ImGui::IsWindowHovered(ImGuiHoveredFlags_RootAndChildWindows))
        showQtSettings = false;
      s_qtWinH = ImGui::GetWindowHeight();
      ImGui::End();
      ImGui::PopStyleColor(2);
      ImGui::PopStyleVar(4);
    }
  }
  // ── ESP Icon Settings Overlay (slide-up animation) ──
  {
    static float s_espAnim = 0.f;
    static float s_espWinH = 120.f;
    static bool s_espPrev = false;
    static bool s_espJustOpened = false;
    float dt = ImGui::GetIO().DeltaTime;
    bool espOpen = (MenDeal && showEspSettings);
    if (espOpen && !s_espPrev)
      s_espJustOpened = true;
    else
      s_espJustOpened = false;
    s_espPrev = espOpen;
    float espTarget = espOpen ? 1.f : 0.f;
    s_espAnim += (espTarget - s_espAnim) * fminf(1.f, dt * 22.f);
    if (s_espAnim > 0.01f) {
      ImGuiIO &io = ImGui::GetIO();
      // backdrop
      ImGui::GetBackgroundDrawList()->AddRectFilled(
          ImVec2(0, 0), io.DisplaySize,
          IM_COL32(0, 0, 0, (int)(80 * s_espAnim)));
      float slideY = (1.f - s_espAnim) * (s_espWinH + 80.f);
      float overlayX = 100.f;
      float overlayY = io.DisplaySize.y - s_espWinH - 8.f + slideY;
      ImGui::SetNextWindowPos(ImVec2(overlayX, overlayY), ImGuiCond_Always);
      ImGui::SetNextWindowSizeConstraints(
          ImVec2(io.DisplaySize.x - 200.f, 0),
          ImVec2(io.DisplaySize.x - 200.f, FLT_MAX));
      ImGui::SetNextWindowBgAlpha(0.93f * s_espAnim);
      ImGui::PushStyleVar(ImGuiStyleVar_Alpha, s_espAnim);
      ImGui::PushStyleVar(ImGuiStyleVar_WindowRounding, 14.f);
      ImGui::PushStyleVar(ImGuiStyleVar_WindowBorderSize, 1.f);
      ImGui::PushStyleVar(ImGuiStyleVar_WindowPadding, ImVec2(10.f, 10.f));
      ImGui::PushStyleColor(ImGuiCol_WindowBg,
                            ImVec4(0.06f, 0.09f, 0.18f, 0.93f));
      ImGui::PushStyleColor(ImGuiCol_Border,
                            ImVec4(0.20f, 0.45f, 0.90f, 0.60f));
      ImGui::Begin(
          "##ESPIconSettings", nullptr,
          ImGuiWindowFlags_NoTitleBar | ImGuiWindowFlags_NoMove |
              ImGuiWindowFlags_NoCollapse | ImGuiWindowFlags_NoSavedSettings |
              ImGuiWindowFlags_NoScrollbar | ImGuiWindowFlags_AlwaysAutoResize);
      ImGui::TextColored(ImVec4(0.55f, 0.82f, 1.f, 1.f), "%s  %s", ICON_FA_COG,
                         LS("Cài Đặt Icon Bổ Trợ", "ESP Icon Settings"));
      ImGui::SameLine();
      float closeX = ImGui::GetContentRegionAvail().x -
                     ImGui::CalcTextSize(ICON_FA_TIMES).x - 2.f;
      if (closeX > 0)
        ImGui::SetCursorPosX(ImGui::GetCursorPosX() + closeX);
      if (ImGui::InvisibleButton(
              "##esclose", ImVec2(ImGui::CalcTextSize(ICON_FA_TIMES).x + 8.f,
                                  ImGui::GetFrameHeight())))
        showEspSettings = false;
      ImGui::GetWindowDrawList()->AddText(
          ImVec2(ImGui::GetItemRectMin().x + 4.f,
                 ImGui::GetItemRectMin().y +
                     (ImGui::GetFrameHeight() - ImGui::GetTextLineHeight()) *
                         0.5f),
          ImGui::IsItemHovered() ? IM_COL32(255, 100, 100, 255)
                                 : IM_COL32(180, 180, 200, 200),
          ICON_FA_TIMES);
      ImGui::Separator();
      ImGui::Spacing();
      ImGui::Columns(3, "espcols", false);
      bool espChanged = false;
      espChanged |= AovSlider(LS("Kích Thước", "Size"), &espIconScale, 0.5f,
                              2.5f, "%.1fx");
      ImGui::NextColumn();
      espChanged |= AovSlider(LS("Ngang", "Offset X"), &espOffsetX, -200.f,
                              200.f, "%.0f");
      ImGui::NextColumn();
      espChanged |=
          AovSlider(LS("Dọc", "Offset Y"), &espOffsetY, -200.f, 200.f, "%.0f");
      ImGui::Columns(1);
      if (espChanged)
        SaveConfig();
      // close on tap outside (skip the very first frame to avoid self-closing)
      if (!s_espJustOpened && showEspSettings && ImGui::IsMouseReleased(0) &&
          !ImGui::IsWindowHovered(ImGuiHoveredFlags_RootAndChildWindows))
        showEspSettings = false;
      s_espWinH = ImGui::GetWindowHeight();
      ImGui::End();
      ImGui::PopStyleColor(2);
      ImGui::PopStyleVar(4);
    }
  }
  // ── Fake Name Settings Overlay (slide-up animation) ──
  {
    static float s_fnAnim = 0.f;
    static float s_fnWinH = 160.f;
    static bool s_fnPrev = false;
    static bool s_fnJustOpened = false;
    static char s_nameInputBuf[128] = {};
    static bool s_nameInputSynced = false;
    float dt = ImGui::GetIO().DeltaTime;
    bool fnOpen = (MenDeal && showFakeNameSettings);
    if (fnOpen && !s_fnPrev) {
      s_fnJustOpened = true;
      s_nameInputSynced = false;
    } else {
      s_fnJustOpened = false;
    }
    s_fnPrev = fnOpen;
    // sync buffer with customname when opening
    if (fnOpen && !s_nameInputSynced) {
      strncpy(s_nameInputBuf, customname.c_str(), sizeof(s_nameInputBuf) - 1);
      s_nameInputBuf[sizeof(s_nameInputBuf) - 1] = '\0';
      s_nameInputSynced = true;
    }
    float fnTarget = fnOpen ? 1.f : 0.f;
    s_fnAnim += (fnTarget - s_fnAnim) * fminf(1.f, dt * 22.f);
    if (s_fnAnim > 0.01f) {
      ImGuiIO &io = ImGui::GetIO();
      ImGui::GetBackgroundDrawList()->AddRectFilled(
          ImVec2(0, 0), io.DisplaySize,
          IM_COL32(0, 0, 0, (int)(80 * s_fnAnim)));
      float slideY = (1.f - s_fnAnim) * (s_fnWinH + 80.f);
      float fnX = 100.f;
      float fnY = io.DisplaySize.y - s_fnWinH - 8.f + slideY;
      ImGui::SetNextWindowPos(ImVec2(fnX, fnY), ImGuiCond_Always);
      ImGui::SetNextWindowSizeConstraints(
          ImVec2(io.DisplaySize.x - 200.f, 0),
          ImVec2(io.DisplaySize.x - 200.f, FLT_MAX));
      ImGui::SetNextWindowBgAlpha(0.93f * s_fnAnim);
      ImGui::PushStyleVar(ImGuiStyleVar_Alpha, s_fnAnim);
      ImGui::PushStyleVar(ImGuiStyleVar_WindowRounding, 14.f);
      ImGui::PushStyleVar(ImGuiStyleVar_WindowBorderSize, 1.f);
      ImGui::PushStyleVar(ImGuiStyleVar_WindowPadding, ImVec2(10.f, 10.f));
      ImGui::PushStyleColor(ImGuiCol_WindowBg,
                            ImVec4(0.06f, 0.09f, 0.18f, 0.93f));
      ImGui::PushStyleColor(ImGuiCol_Border,
                            ImVec4(0.20f, 0.45f, 0.90f, 0.60f));
      ImGui::Begin(
          "##FakeNameSettings", nullptr,
          ImGuiWindowFlags_NoTitleBar | ImGuiWindowFlags_NoMove |
              ImGuiWindowFlags_NoCollapse | ImGuiWindowFlags_NoSavedSettings |
              ImGuiWindowFlags_NoScrollbar | ImGuiWindowFlags_AlwaysAutoResize);
      ImGui::TextColored(ImVec4(0.55f, 0.82f, 1.f, 1.f), "%s  %s", ICON_FA_FONT,
                         LS("Cài Đặt Fake Name", "Fake Name Settings"));
      ImGui::SameLine();
      float fnCloseX = ImGui::GetContentRegionAvail().x -
                       ImGui::CalcTextSize(ICON_FA_TIMES).x - 2.f;
      if (fnCloseX > 0)
        ImGui::SetCursorPosX(ImGui::GetCursorPosX() + fnCloseX);
      if (ImGui::InvisibleButton(
              "##fnclose", ImVec2(ImGui::CalcTextSize(ICON_FA_TIMES).x + 8.f,
                                  ImGui::GetFrameHeight())))
        showFakeNameSettings = false;
      ImGui::GetWindowDrawList()->AddText(
          ImVec2(ImGui::GetItemRectMin().x + 4.f,
                 ImGui::GetItemRectMin().y +
                     (ImGui::GetFrameHeight() - ImGui::GetTextLineHeight()) *
                         0.5f),
          ImGui::IsItemHovered() ? IM_COL32(255, 100, 100, 255)
                                 : IM_COL32(180, 180, 200, 200),
          ICON_FA_TIMES);
      ImGui::Separator();
      ImGui::Spacing();
      static bool s_fnHaptic = false;
      float btnW = (ImGui::GetContentRegionAvail().x - 8.f) * 0.5f;
      ImVec2 bSz(btnW, 34.f);
      auto FnModeBtn = [&](const char *label, int mode) -> bool {
        bool active = (NameMode == mode);
        ImVec4 col = active ? ImVec4(0.14f, 0.48f, 0.88f, 0.92f)
                            : ImVec4(0.10f, 0.14f, 0.28f, 0.80f);
        ImGui::PushStyleColor(ImGuiCol_Button, col);
        ImGui::PushStyleColor(
            ImGuiCol_ButtonHovered,
            ImVec4(col.x + 0.08f, col.y + 0.10f, col.z + 0.12f, 1.f));
        ImGui::PushStyleColor(
            ImGuiCol_ButtonActive,
            ImVec4(col.x + 0.14f, col.y + 0.18f, col.z + 0.22f, 1.f));
        bool clicked = ImGui::Button(label, bSz);
        ImGui::PopStyleColor(3);
        if (clicked) {
          NameMode = mode;
          s_fnGen++;
          SaveConfig();
          s_fnHaptic = true;
        }
        return clicked;
      };
      // Row 1: Đổi Tên Tất Cả | Đổi Tên Chỉ Mình
      FnModeBtn(LS("Đổi Tên Tất Cả##fn1", "Change All##fn1"), 2);
      ImGui::SameLine(0, 8.f);
      FnModeBtn(LS("Chỉ Mình##fn2", "Only Self##fn2"), 4);
      // Row 2: Đổi Tên Hero | Về Tên Gốc
      FnModeBtn(LS("Đổi Tên Hero##fn3", "Hero Name##fn3"), 3);
      ImGui::SameLine(0, 8.f);
      {
        // "Về Tên Gốc" uses green accent when active
        bool active = (NameMode == 0);
        ImVec4 col = active ? ImVec4(0.10f, 0.54f, 0.28f, 0.92f)
                            : ImVec4(0.10f, 0.14f, 0.28f, 0.80f);
        ImGui::PushStyleColor(ImGuiCol_Button, col);
        ImGui::PushStyleColor(
            ImGuiCol_ButtonHovered,
            ImVec4(col.x + 0.08f, col.y + 0.10f, col.z + 0.08f, 1.f));
        ImGui::PushStyleColor(
            ImGuiCol_ButtonActive,
            ImVec4(col.x + 0.14f, col.y + 0.18f, col.z + 0.14f, 1.f));
        if (ImGui::Button(LS("Về Tên Gốc##fn4", "Original##fn4"), bSz)) {
          NameMode = 0;
          s_fnGen++;
          s_hudNameGen.clear();
          SaveConfig();
          s_fnHaptic = true;
        }
        ImGui::PopStyleColor(3);
      }
      // Text input for custom name shown for modes that use it
      if (NameMode == 2 || NameMode == 4) {
        ImGui::Spacing();
        ImGui::TextColored(ImVec4(0.7f, 0.9f, 1.f, 0.9f),
                           LS("Tên Tùy Chỉnh:", "Custom Name:"));
        ImGui::PushItemWidth(-1);
        if (AovInputText("##fnnameinput", s_nameInputBuf,
                         sizeof(s_nameInputBuf),
                         LS("Nhập tên hiển thị", "Enter display name"),
                         LS("Name", "Name"))) {
          customname = std::string(s_nameInputBuf);
          s_fnGen++;
          SaveConfig();
        }
        ImGui::PopItemWidth();
      }
      if (s_fnHaptic) {
        s_fnHaptic = false;
        HapticLight();
      }
      if (!s_fnJustOpened && showFakeNameSettings &&
          ImGui::IsMouseReleased(0) &&
          !ImGui::IsWindowHovered(ImGuiHoveredFlags_RootAndChildWindows))
        showFakeNameSettings = false;
      s_fnWinH = ImGui::GetWindowHeight();
      ImGui::End();
      ImGui::PopStyleColor(2);
      ImGui::PopStyleVar(4);
    }
  }
  if (AimbotEnable && skillSlot > 0 && skillSlot == tagid &&
      g_aimDraw.Ranger > 0.0f && g_aimDraw.drawLactor != nullptr &&
      myLactorRoot != nullptr && LActorRoot_get_location && Camera_get_main &&
      Camera_WorldToViewportPoint) {

    // ── Velocity tracker: sample delta-position every frame per lactor ──
    // Accurate hơn get_forward vì bắt được cả hướng di chuyển ngang (strafe)
    struct VelocitySample {
      Vector3 pos;
      float time;
      Vector3 velocity;
    };
    static std::unordered_map<void *, VelocitySample> s_velMap;
    float now = (float)CACurrentMediaTime();

    void *cam = Camera_get_main();
    if (cam) {
      bool _dead = false;
      if (LActorRoot_ActorControl && LObjWrapper_get_IsDeadState) {
        void *lw = *(void **)((uintptr_t)g_aimDraw.drawLactor +
                              LActorRoot_ActorControl);
        if (lw && LObjWrapper_get_IsDeadState(lw))
          _dead = true;
      }
      if (!_dead) {
        Vector3 myPos = Vector3(LActorRoot_get_location(myLactorRoot));
        Vector3 enemyPos =
            Vector3(LActorRoot_get_location(g_aimDraw.drawLactor));

        // Update velocity sample for this target
        void *key = g_aimDraw.drawLactor;
        auto &vs = s_velMap[key];
        float dt = now - vs.time;
        if (dt > 0.005f && dt < 0.5f) {
          // EMA smooth: 70% new sample, 30% old to reduce jitter
          Vector3 rawVel = (enemyPos - vs.pos) * (1.0f / dt);
          vs.velocity.x = rawVel.x * 0.7f + vs.velocity.x * 0.3f;
          vs.velocity.y = rawVel.y * 0.7f + vs.velocity.y * 0.3f;
          vs.velocity.z = rawVel.z * 0.7f + vs.velocity.z * 0.3f;
        } else if (dt >= 0.5f) {
          // Target changed or stale — reset velocity
          vs.velocity = Vector3::zero();
        }
        vs.pos = enemyPos;
        vs.time = now;
        // Clean up stale entries (dead / off-screen targets)
        for (auto it = s_velMap.begin(); it != s_velMap.end();) {
          if (now - it->second.time > 2.0f)
            it = s_velMap.erase(it);
          else
            ++it;
        }

        auto toImGui = [](Vector3 v) -> ImVec2 {
          return ImVec2(v.x * kWidth, kHeight - v.y * kHeight);
        };
        Vector3 mySc = Camera_WorldToViewportPoint(cam, myPos);
        Vector3 enSc = Camera_WorldToViewportPoint(cam, enemyPos);
        float dist3D = Vector3::Distance(myPos, enemyPos);
        if (mySc.z > 0 && enSc.z > 0 && dist3D <= g_aimDraw.Ranger) {
          ImDrawList *dl = ImGui::GetBackgroundDrawList();
          ImVec2 p1 = toImGui(mySc); // my screen pos
          ImVec2 p2 = toImGui(enSc); // enemy current screen pos

          if (g_aimDraw.bullettime > 0.0f && g_aimDraw.Ranger > 0.0f) {
            float bulletSpeed = g_aimDraw.Ranger / g_aimDraw.bullettime;
            float timeToHit =
                (bulletSpeed > 0.0f) ? dist3D / bulletSpeed : 0.0f;

            // Use sampled velocity for prediction (real-time, handles strafe)
            Vector3 vel = vs.velocity;
            // Fallback to get_forward * speed when velocity not yet warmed up
            float velMag = sqrtf(vel.x * vel.x + vel.y * vel.y + vel.z * vel.z);
            if (velMag < 0.1f && LActorRoot_get_forward &&
                LActorRoot_get_PlayerMovement && get_speed) {
              Vector3 fwd =
                  Vector3(LActorRoot_get_forward(g_aimDraw.drawLactor));
              void *pm = LActorRoot_get_PlayerMovement(g_aimDraw.drawLactor);
              if (pm) {
                float spd = (float)(get_speed(pm)) / 1000.0f;
                vel = fwd * spd;
              }
            }

            Vector3 predictPos = enemyPos + vel * timeToHit;
            Vector3 prSc = Camera_WorldToViewportPoint(cam, predictPos);
            if (prSc.z > 0) {
              ImVec2 p3 = toImGui(prSc); // predicted screen pos

              // Aim line: my pos → PREDICTED pos (ESP.h style)
              dl->AddLine(p1, p3, IM_COL32(200, 200, 200, 100), 0.1f);

              // Current enemy position: small white dot
              dl->AddCircleFilled(p2, 3.0f, IM_COL32(255, 255, 255, 180));
              // Thin dashed segment: current → predicted (visualise lead)
              dl->AddLine(p2, p3, IM_COL32(255, 255, 100, 60), 0.5f);

              // Predicted aim point: crosshair circle at line endpoint
              dl->AddCircle(p3, 6.0f, IM_COL32(255, 60, 60, 230), 12, 1.5f);
              dl->AddCircleFilled(p3, 2.5f, IM_COL32(255, 60, 60, 255));
            }
          } else {
            // No bullettime: straight line to current enemy pos
            dl->AddLine(p1, p2, IM_COL32(200, 200, 200, 100), 0.1f);
            dl->AddCircleFilled(p2, 3.0f, IM_COL32(255, 255, 255, 255));
          }
        }
      }
    }
  }
  DrawBotroESP();
  Muabando();
  ImGui::Render();
  ImGui_ImplMetal_RenderDrawData(ImGui::GetDrawData(), cmd, enc);
  [enc popDebugGroup];
  [enc endEncoding];
  [cmd presentDrawable:view.currentDrawable];
  [cmd commit];
}
- (void)mtkView:(MTKView *)view drawableSizeWillChange:(CGSize)size {
}
#pragma mark - Auto Buy/Sell
void Muabando() {
  if (!myActorLinker || !myLactorRoot || !LActorRoot_LHeroWrapper || !doiitem ||
      !muaitem)
    return;
  static int muaFrame = 0;
  if (++muaFrame % 3 != 0)
    return;
  static size_t off_CommunicateAgentCtrl =
      FieldOffset("Project.Plugins_d.dll", "NucleusDrive.Logic", "LHeroWrapper",
                  "CommunicateAgentCtrl");
  static size_t off_SkillControl =
      FieldOffset("Project.Plugins_d.dll", "NucleusDrive.Logic", "LActorRoot",
                  "SkillControl");
  static size_t off_EquipComponent =
      FieldOffset("Project.Plugins_d.dll", "NucleusDrive.Logic", "LActorRoot",
                  "EquipComponent");
  static size_t off_EquipLinkerComp = FieldOffset(
      "Project_d.dll", "Kyrios.Actor", "ActorLinker", "EquipLinkerComp");
  static size_t off_BattleEquipSystem =
      FieldOffset("Project_d.dll", "Assets.Scripts.GameSystem", "CBattleSystem",
                  "<TheBattleEquipSystem>k__BackingField");
  static size_t off_ValueComponent_cached =
      FieldOffset("Project.Plugins_d.dll", "NucleusDrive.Logic", "LActorRoot",
                  "ValueComponent");
  int currentTimer = 0;
  void *hw = LActorRoot_LHeroWrapper(myLactorRoot);
  if (hw) {
    void *ca = *(void **)((uintptr_t)hw + off_CommunicateAgentCtrl);
    if (ca) {
      currentTimer = GetGameTime(ca);
      static int prev = -1;
      if (prev > 10 && currentTimer < 10) {
        // Reset toàn bộ biến trạng thái khi vào trận mới
        for (int i = 0; i < COMBO_COUNT; i++) {
          items[i].lastSold = 0;
          items[i].lastbuy = 0;
          items[i].cdRemain = 0;
          items[i].index = -1;
          items[i].cd = 0;
        }
        solan = 0;
        lastId = -1;
        muaFrame = 0;
        for (int i = 0; i < 6; i++)
          ItemID[i] = 0;
      }
      prev = currentTimer;
    }
  }
  void *sc = *(void **)((uintptr_t)myLactorRoot + off_SkillControl);
  void *ec = *(void **)((uint64_t)myLactorRoot + off_EquipComponent);
  void *el = *(void **)((uint64_t)myActorLinker + off_EquipLinkerComp);
  void *bes =
      *(void **)((uint64_t)CBattleSystem_instance + off_BattleEquipSystem);
  if (!ec || !el || !sc || !bes)
    return;
  void *ts = get_talentSystem(sc);
  if (!ts)
    return;
  int cd[8] = {
      GetTalentCDTime(ts, 91337),
      GetEquipActiveSkillCD(el, EquipID::CauBangSuong),
      GetTalentCDTime(ts, 911271),
      GetEquipActiveSkillCD(el, EquipID::ThuongKhungKiem),
      GetEquipActiveSkillCD(el, EquipID::ThuanNhamThach),
      GetTalentCDTime(ts, 91328),
      GetEquipActiveSkillCD(el, EquipID::CungTaMa),
      GetEquipActiveSkillCD(el, EquipID::XaNhatCung),
  };
  // Chỉ query CD đại địa/liệt hoả khi cần đổi item (doiitem), tránh gọi thừa 10
  // lần GetEquipActiveSkillCD
  int cdDD[5] = {0, 0, 0, 0, 0};
  int cdLH[5] = {0, 0, 0, 0, 0};
  if (doiitem) {
    cdDD[0] = GetEquipActiveSkillCD(el, EquipID::DaiDiaThanKhien);
    cdDD[1] = GetEquipActiveSkillCD(el, EquipID::DaiDiaMaNhan);
    cdDD[2] = GetEquipActiveSkillCD(el, EquipID::DaiDiaThanToc);
    cdDD[3] = GetEquipActiveSkillCD(el, EquipID::DaiDiaMoTroi);
    cdDD[4] = GetEquipActiveSkillCD(el, EquipID::DaiDiaHoiHuyet);
    cdLH[0] = GetEquipActiveSkillCD(el, EquipID::LietHoaThanKhien);
    cdLH[1] = GetEquipActiveSkillCD(el, EquipID::LietHoaMaNhan);
    cdLH[2] = GetEquipActiveSkillCD(el, EquipID::LietHoaThanToc);
    cdLH[3] = GetEquipActiveSkillCD(el, EquipID::LietHoaMoTroi);
    cdLH[4] = GetEquipActiveSkillCD(el, EquipID::LietHoaHoiHuyet);
  }
  int ddI[5] = {-1, -1, -1, -1, -1}, lhI[5] = {-1, -1, -1, -1, -1}, ctmI = -1,
      xncI = -1;
  auto eq = LEquipComponent_GetEquips(ec);
  if (eq) {
    static const int off[] = {0x18, 0x24, 0x30, 0x3C, 0x48, 0x54};
    for (int i = 0; i < 6; i++)
      ItemID[i] = *(uint16_t *)((uint64_t)eq + off[i]);
  }
  bool have[8] = {};
  for (int i = 0; i < 6; i++) {
    for (int j = 0; j < 8; j++) {
      if (ItemID[i] == items[j].id) {
        items[j].index = i;
        have[j] = true;
        items[j].cd = cd[j];
        items[j].cdRemain = cdToSeconds(cd[j]);
        if (j == 6)
          ctmI = i;
        if (j == 7)
          xncI = i;
        goto ns;
      }
    }
    {
      int ids[] = {EquipID::DaiDiaThanKhien, EquipID::DaiDiaMaNhan,
                   EquipID::DaiDiaThanToc, EquipID::DaiDiaMoTroi,
                   EquipID::DaiDiaHoiHuyet};
      for (int k = 0; k < 5; k++)
        if (ItemID[i] == ids[k]) {
          ddI[k] = i;
          goto ns;
        }
    }
    {
      int ids[] = {EquipID::LietHoaThanKhien, EquipID::LietHoaMaNhan,
                   EquipID::LietHoaThanToc, EquipID::LietHoaMoTroi,
                   EquipID::LietHoaHoiHuyet};
      for (int k = 0; k < 5; k++)
        if (ItemID[i] == ids[k]) {
          lhI[k] = i;
          goto ns;
        }
    }
  ns:;
  }
  for (int i = 0; i < 8; i++)
    if (!have[i])
      items[i].index = -1;
  // Chỉ build smEntries khi doiitem bật, tránh rebuild 15 entries mỗi 3 frames
  // khi không cần
  struct EquipSkillEntry {
    int key;
    EquipSkill skill;
  };
  static EquipSkillEntry smEntries[15];
  int smCount = 0;
  if (doiitem) {
    smEntries[smCount++] = {EquipID::CauBangSuong,
                            {EquipID::CauBangSuong, cd[1], items[1].index}};
    smEntries[smCount++] = {EquipID::ThuongKhungKiem,
                            {EquipID::ThuongKhungKiem, cd[3], items[3].index}};
    smEntries[smCount++] = {EquipID::ThuanNhamThach,
                            {EquipID::ThuanNhamThach, cd[4], items[4].index}};
    smEntries[smCount++] = {EquipID::CungTaMa,
                            {EquipID::CungTaMa, cd[6], ctmI}};
    smEntries[smCount++] = {EquipID::XaNhatCung,
                            {EquipID::XaNhatCung, cd[7], xncI}};
    {
      int ids[] = {EquipID::DaiDiaThanKhien, EquipID::DaiDiaMaNhan,
                   EquipID::DaiDiaThanToc, EquipID::DaiDiaMoTroi,
                   EquipID::DaiDiaHoiHuyet};
      for (int k = 0; k < 5; k++)
        smEntries[smCount++] = {ids[k], {ids[k], cdDD[k], ddI[k]}};
    }
    {
      int ids[] = {EquipID::LietHoaThanKhien, EquipID::LietHoaMaNhan,
                   EquipID::LietHoaThanToc, EquipID::LietHoaMoTroi,
                   EquipID::LietHoaHoiHuyet};
      for (int k = 0; k < 5; k++)
        smEntries[smCount++] = {ids[k], {ids[k], cdLH[k], lhI[k]}};
    }
  }
  int gold = 0;
  void *vc = *(void **)((uint64_t)myLactorRoot + off_ValueComponent_cached);
  if (vc)
    gold = GetGoldCoinInBattle(vc);
  bool empty = false;
  if (fullslot)
    for (int i = 0; i < 6; i++)
      if (ItemID[i] == 0) {
        empty = true;
        break;
      }
  if (muaitem && !empty) {
    static vector<ItemData> sel;
    sel.clear();
    for (int i = 0; i < COMBO_COUNT; ++i) {
      int idx = selectedIndices[i];
      if (idx >= 0 && idx < COMBO_COUNT && isEnabled[idx] &&
          idx < (int)items.size())
        sel.push_back(items[idx]);
    }
    ItemData *sell = nullptr;
    for (auto &it : sel) {
      if (it.index == -1 || it.cd == 0)
        continue;
      if (it.lastSold > 0 && currentTimer - it.lastSold < it.cdRemain)
        continue;
      if (checktime && it.cdRemain + 4 <= it.cdmax)
        continue;
      sell = &it;
      break;
    }
    if (sell) {
      ItemData *buy = nullptr;
      for (auto &it : sel) {
        if (solan >= 2 && it.id == EquipID::GiapHoiSinh)
          continue;
        if (it.index != -1)
          continue;
        if (currentTimer - it.lastSold < it.cdRemain)
          continue;
        if (currentTimer - it.lastbuy < 2)
          continue;
        if (gold + sell->sellPrice < it.cost)
          continue;
        buy = &it;
        break;
      }
      if (buy) {
        SendSellEquipFrameCommand(bes, sell->index);
        int nc = cdToSecondsCeil(cd[sell->stt - 1]);
        if (sell->stt == 1)
          solan++;
        sell->cdRemain = nc;
        sell->lastSold = currentTimer;
        sell->index = -1;
        SyncItemState(sell->id, nc, currentTimer, -1);
        int bid = buy->id;
        dispatch_after(
            dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.15 * NSEC_PER_SEC)),
            dispatch_get_main_queue(), ^{
              SendBuyEquipFrameCommand(bes, bid, false);
            });
        buy->lastbuy = currentTimer;
        buy->cdRemain = 0;
        for (auto &it : items)
          if (it.id == bid) {
            it.lastbuy = currentTimer;
            it.cdRemain = 0;
            break;
          }
        gold += sell->sellPrice - buy->cost;
      }
    }
  }
  if (doiitem) {
    static vector<EquipSkill> rdy;
    rdy.clear();
    for (int i = 0; i < smCount; i++) {
      if (smEntries[i].skill.index != -1 && smEntries[i].skill.cooldown == 0)
        rdy.push_back(smEntries[i].skill);
    }
    sort(rdy.begin(), rdy.end(), [](const EquipSkill &a, const EquipSkill &b) {
      return a.index < b.index;
    });
    if (!rdy.empty() && lastId != rdy[0].id) {
      SendPlayerChoseEquipSkillCommand(bes, rdy[0].index);
      lastId = rdy[0].id;
    }
  }
}

@end
