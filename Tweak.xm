#import <UIKit/UIKit.h>

#define PREF_PATH @"/var/mobile/Library/Preferences/com.ichitaso.iconanus.plist"
#define KEY @"IconAnus"

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

NSDictionary *dict = [NSDictionary dictionaryWithContentsOfFile:PREF_PATH];
NSMutableDictionary *mutableDict = dict ? [dict mutableCopy] : [NSMutableDictionary dictionary];

%hook SBDefaultIconModelStore
- (id)loadCurrentIconState:(id*)error {
    id orig = %orig;

    if ([mutableDict objectForKey:KEY]) {
        return [mutableDict objectForKey:KEY];
    }

    [mutableDict setValue:orig forKey:KEY];
    [mutableDict writeToFile:PREF_PATH atomically:YES];

    return orig;
}
- (BOOL)saveCurrentIconState:(id)state error:(id*)error {
    [mutableDict setValue:state forKey:KEY];
    [mutableDict writeToFile:PREF_PATH atomically:YES];
    return %orig;
}
%end

%ctor {
    // Add gridiculous fix https://github.com/ryannair05/GridiculousFix
    class_addMethod(objc_getClass("SBIconListFlowExtendedLayout"), @selector(maximumIconCount), (IMP)&SBIconListFlowExtendedLayout_maximumIconCount, "Q@:");
    %init;
}
