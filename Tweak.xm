#import <UIKit/UIKit.h>

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
  
  // If no themes are available, do nothing as there are no icons to use
  if (![themes count]) {
    return;
  }
  
  // Search through all of the known themes that WinterBoard has registered, this includes any
  // legacy SummerBoard themes that shouldn't even exist anymore.
  IBActiveThemes = [[NSMutableArray alloc] initWithCapacity:8];
  
  for (NSDictionary *theme in themes) {
    NSNumber *active = theme[@"Active"];
    NSString *name = theme[@"Name"];
    
    // If the theme isn't active, or doesn't contain a name for whatever reason - continue on
    // as there's no point working with something that may be inactive or broken.
    if (![active boolValue] || !name) {
      continue;
    }
    
    // Paths to look for the theme
    NSArray *pathChecks = @[
      [NSString stringWithFormat:@"/Library/Themes/%@.theme", name],
      [NSString stringWithFormat:@"/Library/Themes/%@", name],
      [NSString stringWithFormat:@"/User/Library/SummerBoard/Themes/%@", name],
      [NSString stringWithFormat:@"/User/Library/SummerBoard/Themes/%@.theme", name]
    ];
    
    for (NSString *path in pathChecks) {
      NSString *iconBundlesPath = [path stringByAppendingPathComponent:@"IconBundles"];
      
      // If the theme doesn't exist in the current path, skip it!
      if (![[NSFileManager defaultManager] fileExistsAtPath:iconBundlesPath]) {
        continue;
      }
      
      // Create a new IconBundles Theme instance using the current path
      IBTheme *theme = [[IBTheme alloc] initWithPath:iconBundlesPath];
      
      NSString *plistPath = [path stringByAppendingPathComponent:@"Info.plist"];
      NSDictionary *themeOptions = [NSDictionary dictionaryWithContentsOfFile:plistPath];
      theme.iconsArePrecomposed = ![themeOptions[@"IB-MaskIcons"] boolValue];
      
      [IBActiveThemes addObject:theme];
    }
  }
}

@interface UIImage (UIApplicationIconPrivate)
- (id)_applicationIconImageForFormat:(int)arg1 precomposed:(BOOL)arg2 scale:(float)arg3;
@end

static NSMutableString* IBGetFileForIdentifier(NSMutableString *filename, CGFloat scale) {
  if (scale == 3.0) {
    [filename appendString:@"@3x"];
  } else if (scale == 2.0) {
    [filename appendString:@"@2x"];
  }
  
  [filename appendString:@".png"];
  return filename;
}

static UIImage* IBGetThemedIcon(NSString *displayIdentifier, int format = 0, float scale = 0) {
  // If there are no active themes, or if a tweak such as 'Appendix' is installed, return a nil
  // value to ensure other parts of the code knows an invalid use-case has being reached.
  if ([IBActiveThemes count] == 0 || displayIdentifier.length == 0) {
    return nil;
  }
  
  NSMutableArray *potentialFilenames = [[NSMutableArray alloc] init];
  CGFloat displayScale = (scale > 0 ? scale : [UIScreen mainScreen].scale);
  
  NSMutableString *filename = [NSMutableString stringWithString:displayIdentifier];
  
  if ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad) {
    [filename appendString:@"~ipad"];
    [potentialFilenames addObject:IBGetFileForIdentifier(filename, displayScale)];
  } else {
    while (displayScale >= 1.0) {
      filename = [NSMutableString stringWithString:displayIdentifier];
      [potentialFilenames addObject:IBGetFileForIdentifier(filename, displayScale)];
      displayScale--;
    }
  }
  
  for (IBTheme *theme in IBActiveThemes) {
    for (NSString *filename in potentialFilenames) {
      NSString *path = [theme.path stringByAppendingPathComponent:filename];
      
      if (![[NSFileManager defaultManager] fileExistsAtPath:path]) {
        continue;
      }
      
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

@interface SBIcon : NSObject
- (NSString *)applicationBundleID;
@end

@interface SBClockApplicationIconImageView : UIView
- (SBIcon *)icon;
@end

%hook SBClockApplicationIconImageView

- (id)contentsImage {
  // Quick hack for iOS 7 "live" clock icon
  if ([self respondsToSelector:@selector(icon)]) {
    SBIcon *sbIcon = [self icon];
    
    if (UIImage *icon = IBGetThemedIcon([sbIcon applicationBundleID])) {
      return icon;
    }
  }
  
  return %orig;
}

%end
