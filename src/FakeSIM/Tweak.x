#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <notify.h>
#import <objc/runtime.h>

// Приватные интерфейсы статус-бара iOS 16.
@interface _UIStatusBarDataEntry : NSObject <NSCopying>
@end

@interface _UIStatusBarDataIntegerEntry : _UIStatusBarDataEntry
@property (nonatomic, assign) NSInteger rawValue;
@property (nonatomic, assign) NSInteger displayValue;
@property (nonatomic, assign) BOOL displayRawValue;
@end

@interface _UIStatusBarDataNetworkEntry : _UIStatusBarDataIntegerEntry
@property (nonatomic, assign) NSInteger status;
@property (nonatomic, assign) BOOL lowDataModeActive;
@end

@interface _UIStatusBarDataCellularEntry : _UIStatusBarDataNetworkEntry
@property (nonatomic, assign) NSInteger type;
@property (nonatomic, copy) NSString *string;
@property (nonatomic, copy) NSString *crossfadeString;
@property (nonatomic, copy) NSString *badgeString;
@property (nonatomic, assign) BOOL wifiCallingEnabled;
@property (nonatomic, assign) BOOL callForwardingEnabled;
@property (nonatomic, assign) BOOL showsSOSWhenDisabled;
@property (nonatomic, assign) BOOL sosAvailable;
@end

@interface UIStatusBar_Modern : NSObject
- (void)forceUpdateData:(BOOL)force;
@end

@interface FBSystemService : NSObject
+ (instancetype)sharedInstance;
- (void)exitAndRelaunch:(BOOL)relaunch;
@end

static NSString *const kDomain = @"com.makr.fakesim";

static NSUserDefaults *prefs(void) {
	static NSUserDefaults *d;
	static dispatch_once_t once;
	dispatch_once(&once, ^{ d = [[NSUserDefaults alloc] initWithSuiteName:kDomain]; });
	return d;
}

static BOOL boolPref(NSString *key, BOOL def) {
	id v = [prefs() objectForKey:key];
	return v ? [v boolValue] : def;
}

static NSString *stringPref(NSString *key, NSString *def) {
	id v = [prefs() objectForKey:key];
	return [v isKindOfClass:NSString.class] ? v : def;
}

static BOOL fsEnabled(void) { return boolPref(@"enabled", YES); }

// Текст типа сети; nil — не показывать.
static NSString *networkString(void) {
	NSString *n = stringPref(@"network", @"LTE");
	return [n isEqualToString:@"none"] ? nil : n;
}

static NSString *carrierString(void) {
	NSString *custom = [stringPref(@"customCarrier", @"") stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
	return custom.length ? custom : stringPref(@"carrier", @"МТС");
}

// ---- Реалистичный режим: палочки плавно «гуляют» вокруг выбранного уровня ----

static NSInteger gWalkBars = -1;      // текущее значение блуждания, -1 — ещё не задано
static NSUInteger gTimerGeneration;
static NSHashTable *gStatusBars;

static NSInteger baseBars(void) { return stringPref(@"bars", @"4").integerValue; }

static NSInteger currentBars(void) {
	if (boolPref(@"noSIM", NO)) return 0;
	NSInteger base = baseBars();
	if (!boolPref(@"realistic", NO) || base == 0) return base;
	if (gWalkBars < 0) gWalkBars = base;
	return gWalkBars;
}

static void refreshStatusBars(void) {
	for (id bar in gStatusBars.allObjects) [bar forceUpdateData:YES];
}

static void scheduleTick(void);

static void tick(NSUInteger generation) {
	if (generation != gTimerGeneration) return;
	NSInteger base = baseBars();
	if (fsEnabled() && boolPref(@"realistic", NO) && base > 0 && !boolPref(@"noSIM", NO)) {
		NSInteger cur = gWalkBars < 0 ? base : gWalkBars;
		NSInteger next = cur;
		uint32_t r = arc4random_uniform(100);
		// Тянемся к выбранному уровню, но иногда проседаем или подскакиваем.
		NSInteger pull = base > cur ? 1 : (base < cur ? -1 : 0);
		if (r < 35) next = cur + pull;
		else if (r < 55) next = cur - 1;
		else if (r < 70) next = cur + 1;
		next = MAX(MAX(1, base - 2), MIN(MIN(4, base + 1), next));
		if (next != cur || gWalkBars < 0) {
			gWalkBars = next;
			refreshStatusBars();
		}
	}
	scheduleTick();
}

static void scheduleTick(void) {
	NSUInteger gen = gTimerGeneration;
	double delay = 3.0 + arc4random_uniform(10000) / 1000.0; // 3–13 c
	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{ tick(gen); });
}

static void reloadPrefs(void) {
	gTimerGeneration++;
	gWalkBars = -1;
	scheduleTick();
	refreshStatusBars();
}

static _UIStatusBarDataCellularEntry *fakeEntry(_UIStatusBarDataCellularEntry *orig) {
	Class cls = objc_getClass("_UIStatusBarDataCellularEntry");
	_UIStatusBarDataCellularEntry *e = orig ? [orig copy] : [[cls alloc] init];

	BOOL noSIM = boolPref(@"noSIM", NO);
	NSInteger bars = currentBars();
	NSString *net = noSIM ? nil : networkString();

	e.status = noSIM ? 1 : 5;
	e.rawValue = bars;
	e.displayValue = bars;
	e.displayRawValue = NO;
	e.type = net ? 6 : 0;
	e.string = noSIM ? @"Нет SIM" : (boolPref(@"hideCarrier", NO) ? nil : carrierString());
	e.crossfadeString = nil;
	e.badgeString = nil;
	e.wifiCallingEnabled = !noSIM && boolPref(@"wifiCalling", NO);
	e.callForwardingEnabled = !noSIM && boolPref(@"callForwarding", NO);
	e.showsSOSWhenDisabled = noSIM;
	e.sosAvailable = noSIM;
	return e;
}

%hook _UIStatusBarData

- (id)cellularEntry {
	id orig = %orig;
	return fsEnabled() ? fakeEntry(orig) : orig;
}

%end

%hook UIStatusBar_Modern

- (void)_updateWithData:(id)data force:(BOOL)force {
	if (!gStatusBars) gStatusBars = [NSHashTable weakObjectsHashTable];
	[gStatusBars addObject:self];
	%orig;
}

%end

%hook _UIStatusBarCellularItem

// Подменяем текст типа сети (LTE, 5G ...) своим.
- (id)_stringForCellularType:(NSInteger)type {
	if (fsEnabled() && type != 0) {
		NSString *s = networkString();
		if (s) return s;
	}
	return %orig;
}

%end

%ctor {
	// Настройки изменились → применяем сразу, без респринга.
	int reloadToken;
	notify_register_dispatch("com.makr.fakesim/reload", &reloadToken, dispatch_get_main_queue(), ^(int t) {
		reloadPrefs();
	});
	scheduleTick();

	// «Применить» в настройках → перезапуск SpringBoard.
	int token;
	notify_register_dispatch("com.makr.fakesim/respring", &token, dispatch_get_main_queue(), ^(int t) {
		[[objc_getClass("FBSystemService") sharedInstance] exitAndRelaunch:YES];
	});
}
