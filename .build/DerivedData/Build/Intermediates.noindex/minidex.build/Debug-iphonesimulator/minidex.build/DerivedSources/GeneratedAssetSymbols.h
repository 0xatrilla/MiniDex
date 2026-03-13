#import <Foundation/Foundation.h>

#if __has_attribute(swift_private)
#define AC_SWIFT_PRIVATE __attribute__((swift_private))
#else
#define AC_SWIFT_PRIVATE
#endif

/// The resource bundle ID.
static NSString * const ACBundleID AC_SWIFT_PRIVATE = @"com.minidex.ios";

/// The "command" asset catalog color resource.
static NSString * const ACColorNameCommand AC_SWIFT_PRIVATE = @"command";

/// The "plan" asset catalog color resource.
static NSString * const ACColorNamePlan AC_SWIFT_PRIVATE = @"plan";

/// The "AppLogo" asset catalog image resource.
static NSString * const ACImageNameAppLogo AC_SWIFT_PRIVATE = @"AppLogo";

/// The "GitHub_Invertocat_Black" asset catalog image resource.
static NSString * const ACImageNameGitHubInvertocatBlack AC_SWIFT_PRIVATE = @"GitHub_Invertocat_Black";

/// The "arrow-circle-down" asset catalog image resource.
static NSString * const ACImageNameArrowCircleDown AC_SWIFT_PRIVATE = @"arrow-circle-down";

/// The "arrow-circle-up" asset catalog image resource.
static NSString * const ACImageNameArrowCircleUp AC_SWIFT_PRIVATE = @"arrow-circle-up";

/// The "brain" asset catalog image resource.
static NSString * const ACImageNameBrain AC_SWIFT_PRIVATE = @"brain";

/// The "cloud-upload" asset catalog image resource.
static NSString * const ACImageNameCloudUpload AC_SWIFT_PRIVATE = @"cloud-upload";

/// The "codex-signin" asset catalog image resource.
static NSString * const ACImageNameCodexSignin AC_SWIFT_PRIVATE = @"codex-signin";

/// The "copy" asset catalog image resource.
static NSString * const ACImageNameCopy AC_SWIFT_PRIVATE = @"copy";

/// The "git-branch" asset catalog image resource.
static NSString * const ACImageNameGitBranch AC_SWIFT_PRIVATE = @"git-branch";

/// The "git-commit" asset catalog image resource.
static NSString * const ACImageNameGitCommit AC_SWIFT_PRIVATE = @"git-commit";

/// The "pen-square" asset catalog image resource.
static NSString * const ACImageNamePenSquare AC_SWIFT_PRIVATE = @"pen-square";

/// The "terminal" asset catalog image resource.
static NSString * const ACImageNameTerminal AC_SWIFT_PRIVATE = @"terminal";

#undef AC_SWIFT_PRIVATE
