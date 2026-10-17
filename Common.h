#include <roothide.h>
#import <os/log.h>

#define PREF_PATH jbroot(@"/var/mobile/Library/Preferences/com.ichitaso.iconorder.plist")
#define Notify_Preferences "com.ichitaso.iconorder.prefschanged"
#define KEY @"IconOrder"
#define BACKUPS_KEY @"Backups"

#define IS_PAD ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad)

#define TWEAK_TITLE @"IconOrder"
#define TWEAK_DESCRIPTION @"Preserve custom icon layouts \nby Springboard Crash or reboots etc"

#define CREDITS @"© 2015-2026 Cannathea by ichitaso"

#define SettingsColor(alphaValue) [UIColor colorWithRed:30.0f/255.0f green:144.0f/255.0f blue:255.0f/255.0f alpha:alphaValue]
#define PSTableColor(alphaValue) [UIColor colorWithRed:0.00 green:0.00 blue:0.00 alpha:alphaValue]
#define PSDarkColor(alphaValue) [UIColor colorWithRed:1.00 green:1.00 blue:1.00 alpha:alphaValue]

#define LOGO_IMAGE @"CannatheaLogo"

#ifdef DEBUG
#undef NSLog
    #define NSLog(fmt, ...) CustomOSLogBridge(fmt, ##__VA_ARGS__)
static inline void CustomOSLogBridge(NSString *format, ...) {
    if (!format) return;
    NSString *extendedFormat = [[NSString stringWithFormat:@"[%@] ", TWEAK_TITLE] stringByAppendingString:format];
    NSString *safeFormat = [extendedFormat stringByReplacingOccurrencesOfString:@"%{public}" withString:@"%"];
    safeFormat = [safeFormat stringByReplacingOccurrencesOfString:@"%{private}" withString:@"%"];
    va_list args;
    va_start(args, format);
    NSString *formattedMessage = [[NSString alloc] initWithFormat:safeFormat arguments:args];
    va_end(args);
    if (formattedMessage) {
        os_log(OS_LOG_DEFAULT, "%{public}s", [formattedMessage UTF8String]);
    }
}
#else
    #define NSLog(fmt, ...)
#endif
