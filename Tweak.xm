#import <UIKit/UIKit.h>
#import "Common.h"

static BOOL enabled;

@interface SBIconListGridLayoutConfiguration : NSObject
@property(nonatomic) NSUInteger numberOfPortraitRows;
@property(nonatomic) NSUInteger numberOfPortraitColumns;
@end

@interface SBIconListFlowExtendedLayout : NSObject
@property (nonatomic,copy,readonly) SBIconListGridLayoutConfiguration * layoutConfiguration;
@end

static NSUInteger SBIconListFlowExtendedLayout_maximumIconCount(__unsafe_unretained SBIconListFlowExtendedLayout* const self, SEL _cmd) {
    return self.layoutConfiguration.numberOfPortraitRows * self.layoutConfiguration.numberOfPortraitColumns;
}

// To avoid the risk of changes made via backups or Settings apps being overwritten,
// the data is loaded only when "enabled" is set.
static NSMutableDictionary *LoadPrefs(void) {
    NSDictionary *prefs = [NSDictionary dictionaryWithContentsOfFile:PREF_PATH];
    return prefs ? [prefs mutableCopy] : [NSMutableDictionary dictionary];
}

%hook SBDefaultIconModelStore
- (id)loadCurrentIconState:(id*)error {
    if (!enabled) return %orig;
    
    id orig = %orig;

    NSMutableDictionary *prefs = LoadPrefs();
    id saved = [prefs objectForKey:KEY];
    if (saved) {
        return saved;
    }

    if (orig) {
        [prefs setObject:orig forKey:KEY];
        [prefs writeToFile:PREF_PATH atomically:YES];
    }

    return orig;
}
- (BOOL)saveCurrentIconState:(id)state error:(id*)error {
    if (!enabled) return %orig;
    // Default save path /private/var/mobile/Library/SpringBoard/IconState.plist
    if (state) {
        NSMutableDictionary *prefs = LoadPrefs();
        [prefs setObject:state forKey:KEY];
        [prefs writeToFile:PREF_PATH atomically:YES];
    }
    return %orig;
}
%end

static void settingsChanged(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
    NSDictionary *prefs = [NSDictionary dictionaryWithContentsOfFile:PREF_PATH];
    enabled = (BOOL)[prefs[@"enabled"] ? : @YES boolValue];
}

%ctor {
    // Add gridiculous fix https://github.com/ryannair05/GridiculousFix
    class_addMethod(objc_getClass("SBIconListFlowExtendedLayout"), @selector(maximumIconCount), (IMP)&SBIconListFlowExtendedLayout_maximumIconCount, "Q@:");
    %init;
    // Settings Notifications
    CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(),
                                    NULL,
                                    settingsChanged,
                                    CFSTR(Notify_Preferences),
                                    NULL,
                                    CFNotificationSuspensionBehaviorCoalesce);

    settingsChanged(NULL, NULL, NULL, NULL, NULL);
}
