#import "TMPlugInController.h"
#import <OakAppKit/NSAlert Additions.h>
#import <OakSystem/application.h>
#import <crash/info.h>
#import <io/path.h>
#import <ns/ns.h>
#import <oak/debug.h>

static NSInteger const kPlugInAPIVersion = 2;
static NSString* const kUserDefaultsDisabledPlugInsKey = @"disabledPlugIns";

@interface TMPlugInController ()
@property (nonatomic) NSMutableDictionary* loadedPlugIns;
@end

static id CreateInstanceOfPlugInClass (Class cl, TMPlugInController* controller)
{
	if(id instance = [cl alloc])
	{
		if([instance respondsToSelector:@selector(initWithPlugInController:)])
				return [instance initWithPlugInController:controller];
		else	return [instance init];
	}
	return nil;
}

@implementation TMPlugInController
+ (instancetype)sharedInstance
{
	static TMPlugInController* sharedInstance = [self new];
	return sharedInstance;
}

+ (void)initialize
{
	[NSUserDefaults.standardUserDefaults registerDefaults:@{
		kUserDefaultsDisabledPlugInsKey: @[ @"io.emmet.EmmetTextmate" ]
	}];
}

- (id)init
{
	if(self = [super init])
	{
		self.loadedPlugIns = [NSMutableDictionary dictionary];
	}
	return self;
}

- (CGFloat)version
{
	return 2.0;
}

- (void)loadPlugInAtPath:(NSString*)aPath
{
	if(NSBundle* bundle = [NSBundle bundleWithPath:aPath])
	{
		NSString* identifier = [bundle objectForInfoDictionaryKey:@"CFBundleIdentifier"];
		NSString* name = [bundle objectForInfoDictionaryKey:@"CFBundleName"];

		NSArray* blacklist = [NSUserDefaults.standardUserDefaults stringArrayForKey:kUserDefaultsDisabledPlugInsKey];
		if([blacklist containsObject:identifier])
			return;

		if(![self.loadedPlugIns objectForKey:identifier])
		{
			if([[bundle objectForInfoDictionaryKey:@"TMPlugInAPIVersion"] intValue] == kPlugInAPIVersion)
			{
				std::string const crashedDuringPlugInLoad = path::join(path::temp(), "load_" + to_s(identifier));
				if(path::exists(crashedDuringPlugInLoad))
				{
					NSAlert* alert = [NSAlert tmAlertWithMessageText:[NSString stringWithFormat:@"移动“%@”插件到废纸篓?", name ?: identifier] informativeText:@"之前尝试加载插件导致异常退出。你想把它移到废纸篓吗？" buttons:@"移动到废纸篓", @"取消", @"跳过加载", nil];
					NSInteger choice = [alert runModal];
					if(choice == NSAlertFirstButtonReturn) // "Move to Trash"
						[NSFileManager.defaultManager trashItemAtURL:[NSURL fileURLWithPath:aPath] resultingItemURL:nil error:nil];

					if(choice != NSAlertThirdButtonReturn) // "Skip Loading"
						unlink(crashedDuringPlugInLoad.c_str());

					if(choice != NSAlertSecondButtonReturn) // "Cancel"
						return;
				}

				close(open(crashedDuringPlugInLoad.c_str(), O_CREAT|O_TRUNC|O_WRONLY|O_CLOEXEC));

				NSError* loadError;
				if([bundle loadAndReturnError:&loadError])
				{
					crash_reporter_info_t info("bad plug-in: %s", [identifier UTF8String]);
					if(id instance = CreateInstanceOfPlugInClass([bundle principalClass], self))
					{
						self.loadedPlugIns[identifier] = instance;
					}
					else
					{
						NSLog(@"无法实例化插件类: %@, path %@", [bundle principalClass], aPath);
					}
				}
				else
				{
					NSLog(@"加载失败 ‘%@’ (%@): %@", name ?: identifier, [aPath stringByAbbreviatingWithTildeInPath], [loadError localizedDescription]);
				}

				unlink(crashedDuringPlugInLoad.c_str());
			}
			else
			{
				NSLog(@"跳过不兼容的插件: %@, path %@", name ?: identifier, aPath);
			}
		}
		else
		{
			NSLog(@"跳过路径中的插件: %@ (already loaded %@)", identifier, [self.loadedPlugIns[identifier] bundlePath]);
		}
	}
	else
	{
		NSLog(@"无法为路径创建 NSBundle: %@", aPath);
	}
}

- (void)loadAllPlugIns:(id)sender
{
	NSMutableArray* paths = [NSMutableArray array];
	for(NSString* path in NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSAllDomainsMask, YES))
		[paths addObject:[NSString pathWithComponents:@[ path, @"TextMate", @"PlugIns" ]]];
	[paths addObject:[[NSBundle mainBundle] builtInPlugInsPath]];

	for(NSString* path in paths)
	{
		for(NSString* plugInName in [NSFileManager.defaultManager contentsOfDirectoryAtPath:path error:nil])
		{
			if([[[plugInName pathExtension] lowercaseString] isEqualToString:@"tmplugin"])
				[self loadPlugInAtPath:[path stringByAppendingPathComponent:plugInName]];
		}
	}
}

- (void)installPlugInAtPath:(NSString*)src
{
	NSFileManager* fm = NSFileManager.defaultManager;

	NSArray* libraryPaths = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSAllDomainsMask, YES);
	NSString* dst = [NSString pathWithComponents:@[ libraryPaths[0], @"TextMate", @"PlugIns", [src lastPathComponent] ]];
	if([src isEqualToString:dst])
		return;

	NSBundle* plugInBundle = [NSBundle bundleWithPath:src];
	NSString* plugInName   = [plugInBundle objectForInfoDictionaryKey:@"CFBundleName"] ?: [[src lastPathComponent] stringByDeletingPathExtension];

	if([[plugInBundle objectForInfoDictionaryKey:@"TMPlugInAPIVersion"] intValue] != kPlugInAPIVersion)
	{
		NSAlert* alert        = [[NSAlert alloc] init];
		alert.messageText     = @"Cannot Install Plug-in";
		alert.informativeText = [NSString stringWithFormat:@"插件%@插件与此版本的文本编辑不兼容。", plugInName];
		[alert addButtonWithTitle:@"Continue"];
		[alert runModal];
		return;
	}

	NSArray* blacklist = [NSUserDefaults.standardUserDefaults stringArrayForKey:kUserDefaultsDisabledPlugInsKey];
	if([blacklist containsObject:[plugInBundle objectForInfoDictionaryKey:@"CFBundleIdentifier"]])
	{
		NSAlert* alert        = [[NSAlert alloc] init];
		alert.messageText     = @"无法安装插件";
		alert.informativeText = [NSString stringWithFormat:@"插件%@由于稳定性问题，不应与此版本的文本编辑一起使用。", plugInName];
		[alert addButtonWithTitle:@"Continue"];
		[alert runModal];
		return;
	}

	if([fm fileExistsAtPath:dst])
	{
		NSString* newVersion = [plugInBundle objectForInfoDictionaryKey:@"CFBundleShortVersionString"] ?: [plugInBundle objectForInfoDictionaryKey:@"CFBundleVersion"];
		NSString* oldVersion = [[NSBundle bundleWithPath:dst] objectForInfoDictionaryKey:@"CFBundleShortVersionString"] ?: [[NSBundle bundleWithPath:dst] objectForInfoDictionaryKey:@"CFBundleVersion"];

		NSAlert* alert        = [[NSAlert alloc] init];
		alert.messageText     = @"插件已经安装";
		alert.informativeText = [NSString stringWithFormat:@"版本%@的“%@”已经安装，\n您需要用版本%@替换吗?\n\n升级插件需要重新启动应用", oldVersion ?: @"???", plugInName, newVersion ?: @"???"];
		[alert addButtons:@"替换", @"取消", nil];

		NSModalResponse choice = [alert runModal];
		if(choice == NSAlertFirstButtonReturn) // "Replace"
		{
			if(![fm removeItemAtPath:dst error:NULL])
			{
				NSAlert* alert = [[NSAlert alloc] init];
				alert.messageText = @"安装失败";
				alert.informativeText = [NSString stringWithFormat:@"无法移除旧插件(“%@”)", [dst stringByAbbreviatingWithTildeInPath]];
				[alert addButtonWithTitle:@"继续"];
				[alert runModal];
				dst = nil;
			}
		}
		else if(choice == NSAlertSecondButtonReturn) // "Cancel"
		{
			dst = nil;
		}
	}

	if(!dst)
		return;

	NSString* dstDir = [dst stringByDeletingLastPathComponent];
	if([fm createDirectoryAtPath:dstDir withIntermediateDirectories:YES attributes:nil error:NULL])
	{
		if([fm copyItemAtPath:src toPath:dst error:NULL])
		{
			NSAlert* alert        = [[NSAlert alloc] init];
			alert.messageText     = @"插件已安装";
			alert.informativeText = [NSString stringWithFormat:@"注册“%@”您需要重新启动应用。", plugInName];
			[alert addButtons:@"重新启动", @"取消", nil];
			if([alert runModal] == NSAlertFirstButtonReturn) // "Relaunch"
				oak::application_t::relaunch();
		}
		else
		{
			NSAlert* alert        = [[NSAlert alloc] init];
			alert.messageText     = @"安装失败";
			alert.informativeText = @"插件未安装";
			[alert addButtonWithTitle:@"继续"];
			[alert runModal];
		}
	}
	else
	{
		NSAlert* alert        = [[NSAlert alloc] init];
		alert.messageText     = @"安装失败";
		alert.informativeText = [NSString stringWithFormat:@"无法创建插件文件夹(“%@”)", [dstDir stringByAbbreviatingWithTildeInPath]];
		[alert addButtonWithTitle:@"继续"];
		[alert runModal];
	}
}
@end
