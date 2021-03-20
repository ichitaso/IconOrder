#import <UIKit/UIKit.h>

#define PREF_PATH @"/var/mobile/Library/Preferences/com.apple.springboard.plist"
#define KEY @"_NepetaIconState"

int main(int argc, char **argv, char **envp) {
    @autoreleasepool {
        NSDictionary *dict = [NSDictionary dictionaryWithContentsOfFile:PREF_PATH];
        NSMutableDictionary *mutableDict = dict ? [dict mutableCopy] : [NSMutableDictionary dictionary];

        [mutableDict removeObjectForKey:KEY];
        [mutableDict writeToFile:PREF_PATH atomically:YES];
    }
    return 0;
}
