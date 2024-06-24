#import <UIKit/UIKit.h>

#define PLIST_PATH @"/var/mobile/Library/Preferences/com.apple.springboard.plist"
#define KEY1 @"_NepetaIconState"
#define KEY2 @"_GridiculousIconState"

int main(int argc, char **argv, char **envp) {
    @autoreleasepool {
        NSDictionary *dict = [NSDictionary dictionaryWithContentsOfFile:PLIST_PATH];
        NSMutableDictionary *mutableDict = [dict mutableCopy];

        if (!dict) return 0;
        
        [mutableDict removeObjectForKey:KEY1];
        [mutableDict removeObjectForKey:KEY2];
        [mutableDict writeToFile:PLIST_PATH atomically:YES];
    }
    return 0;
}
