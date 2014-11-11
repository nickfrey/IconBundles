static NSMutableArray *IBActiveThemes;
static NSString *WBPreferencesPath = @"/User/Library/Preferences/com.saurik.WinterBoard.plist";

@interface IBTheme : NSObject

@property (nonatomic, strong, readonly) NSString *path;
@property (nonatomic, assign) BOOL iconsArePrecomposed;

- (instancetype)initWithPath:(NSString *)path;

@end

@implementation IBTheme

- (instancetype)initWithPath:(NSString *)path {
    if (self = [super init]) {
        _path = path;
    }
    return self;
}

@end

%ctor {
    NSDictionary *settings = [NSDictionary dictionaryWithContentsOfFile:WBPreferencesPath];
    NSArray *themes = settings[@"Themes"];
    
    if (![themes count])
        return;
    
    IBActiveThemes = [[NSMutableArray alloc] initWithCapacity:8];
    
    for (NSDictionary *theme in themes) {
        NSNumber *active = theme[@"Active"];
        NSString *name = theme[@"Name"];
        
        if (![active boolValue] || !name)
            continue;
        
        NSArray *pathChecks = @[
            [NSString stringWithFormat:@"/Library/Themes/%@.theme", name],
            [NSString stringWithFormat:@"/Library/Themes/%@", name],
            [NSString stringWithFormat:@"/User/Library/SummerBoard/Themes/%@", name],
            [NSString stringWithFormat:@"/User/Library/SummerBoard/Themes/%@.theme", name]
        ];
        
        for (NSString *path in pathChecks) {
            NSString *iconBundlesPath = [path stringByAppendingPathComponent:@"IconBundles"];
            if ([[NSFileManager defaultManager] fileExistsAtPath:iconBundlesPath]) {
                IBTheme *theme = [[IBTheme alloc] initWithPath:iconBundlesPath];
                
                NSString *plistPath = [path stringByAppendingPathComponent:@"Info.plist"];
                NSDictionary *themeOptions = [NSDictionary dictionaryWithContentsOfFile:plistPath];
                theme.iconsArePrecomposed = ![themeOptions[@"IB-MaskIcons"] boolValue];
                
                [IBActiveThemes addObject:theme];
            }
        }
    }
}

@interface UIImage (UIApplicationIconPrivate)
- (id)_applicationIconImageForFormat:(int)arg1 precomposed:(BOOL)arg2 scale:(float)arg3;
@end

static UIImage* IBGetThemedIcon(NSString *displayIdentifier, int format = 0, float scale = 0) {
    if ([IBActiveThemes count] == 0)
        return nil;
    
    NSMutableArray *potentialFilenames = [[NSMutableArray alloc] init];
    CGFloat displayScale = (scale > 0 ? scale : [UIScreen mainScreen].scale);
    
    while (displayScale >= 1.0) {
        NSMutableString *filename = [NSMutableString stringWithString:displayIdentifier];
        
        if ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad)
            [filename appendString:@"~ipad"];
        
        if (displayScale == 2.0)
            [filename appendString:@"@2x"];
        else if (displayScale == 3.0)
            [filename appendString:@"@3x"];
        
        [filename appendString:@".png"];
        [potentialFilenames addObject:filename];
        displayScale--;
    }
    
    for (IBTheme *theme in IBActiveThemes) {
        for (NSString *filename in potentialFilenames) {
            NSString *path = [theme.path stringByAppendingPathComponent:filename];
            if ([[NSFileManager defaultManager] fileExistsAtPath:path]) {
                UIImage *themedImage = [UIImage imageWithContentsOfFile:path];
                
                if (theme.iconsArePrecomposed) {
                    // format == 2 means homescreen icon
                    if (format != 2) {
                        // if not formatting for a homescreen icon, resize the image
                        // to the correct size (namely for Notification Center)
                        UIImage *tempImage = [themedImage _applicationIconImageForFormat:format precomposed:NO scale:scale];
                        UIGraphicsBeginImageContextWithOptions(tempImage.size, NO, 0.0);
                        [themedImage drawInRect:CGRectMake(0, 0, tempImage.size.width, tempImage.size.height)];
                        themedImage = UIGraphicsGetImageFromCurrentImageContext();
                        UIGraphicsEndImageContext();
                    }
                } else {
                    themedImage = [themedImage _applicationIconImageForFormat:format precomposed:NO scale:scale];
                }
                
                return themedImage;
            }
        }
    }
    
    return nil;
}

%hook SBIconImageCrossfadeView

- (void)setMasksCorners:(BOOL)masks {
    // Prevent icons from being rounded on launch
    %orig(NO);
}

%end

%hook UIImage

+ (id)_applicationIconImageForBundleIdentifier:(id)bundleIdentifier roleIdentifier:(id)roleIdentifier format:(int)format scale:(float)scale {
    return IBGetThemedIcon(bundleIdentifier, format, scale) ?: %orig;
}

+ (id)_applicationIconImageForBundleIdentifier:(id)bundleIdentifier format:(int)format scale:(float)scale {
    return IBGetThemedIcon(bundleIdentifier, format, scale) ?: %orig;
}

%end
