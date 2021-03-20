#import <UIKit/UIKit.h>

#define PREF_PATH @"/var/mobile/Library/Preferences/com.ichitaso.iconanus.plist"
#define KEY @"IconAnus"

NSDictionary *dict = [NSDictionary dictionaryWithContentsOfFile:PREF_PATH];
NSMutableDictionary *mutableDict = dict ? [dict mutableCopy] : [NSMutableDictionary dictionary];

%hook SBDefaultIconModelStore
- (id)loadCurrentIconState:(id*)error {
    id orig = %orig;

    if ([mutableDict objectForKey:KEY]) {
        return [mutableDict objectForKey:KEY];
    } else {
        [mutableDict setValue:orig forKey:KEY];
        [mutableDict writeToFile:PREF_PATH atomically:YES];

        return orig;
    }
}
- (BOOL)saveCurrentIconState:(id)state error:(id*)error {
    [mutableDict setValue:state forKey:KEY];
    [mutableDict writeToFile:PREF_PATH atomically:YES];
    return %orig;
}
%end
