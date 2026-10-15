#import "FSPRootListController.h"
#import <Preferences/PSSpecifier.h>
#import <notify.h>

@implementation FSPRootListController

- (NSArray *)specifiers {
	if (!_specifiers) {
		_specifiers = [self loadSpecifiersFromPlistName:@"Root" target:self];
	}
	return _specifiers;
}

// Кнопка «Применить»: просим SpringBoard перезапуститься (твик слушает это уведомление).
- (void)apply {
	notify_post("com.makr.fakesim/respring");
}

@end
