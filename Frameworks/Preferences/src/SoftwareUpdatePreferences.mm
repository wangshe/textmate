#import "SoftwareUpdatePreferences.h"
#import "Keys.h"
#import <OakAppKit/NSImage Additions.h>
#import <OakAppKit/OakUIConstructionFunctions.h>
#import <OakFoundation/OakStringListTransformer.h>
#import <SoftwareUpdate/SoftwareUpdate.h>
#import <MenuBuilder/MenuBuilder.h>

@interface SoftwareUpdatePreferences ()
{
	id _relativeDateUserDefaultsObserver;
	NSTimer* _relativeDateUpdateTimer;
}
@property (nonatomic) NSString* relativeStringForLastCheck;
@end

@implementation SoftwareUpdatePreferences
+ (NSSet*)keyPathsForValuesAffectingLastCheckDescription { return [NSSet setWithObjects:@"softwareUpdateController.checking", @"softwareUpdateController.errorString", @"relativeStringForLastCheck", nil]; }

- (id)init
{
	if(self = [super initWithNibName:nil label:@"软件更新" image:[NSImage imageNamed:@"Software Update" inSameBundleAsClass:[self class]]])
	{
		[OakStringListTransformer createTransformerWithName:@"OakSoftwareUpdateChannelTransformer" andObjectsArray:@[ kSoftwareUpdateChannelRelease, kSoftwareUpdateChannelPrerelease ]];
	}
	return self;
}

- (SoftwareUpdate*)softwareUpdateController
{
	return SoftwareUpdate.sharedInstance;
}

- (NSString*)lastCheckDescription
{
	return self.softwareUpdateController.isChecking ? @"正在检查…" : (self.softwareUpdateController.errorString ?: _relativeStringForLastCheck ?: @"从未");
}

- (NSString*)relativeStringForDate:(NSDate*)date
{
	if(!date)
		return nil;

#if defined(MAC_OS_X_VERSION_10_15) && (MAC_OS_X_VERSION_10_15 <= MAC_OS_X_VERSION_MAX_ALLOWED)
	if(@available(macos 10.15, *))
	{
		return -[date timeIntervalSinceNow] < 5 ? @"刚刚" : [[[NSRelativeDateTimeFormatter alloc] init] localizedStringForDate:date relativeToDate:NSDate.now];
	}
	else
#endif
	{
		NSTimeInterval const minute =  60;
		NSTimeInterval const hour   =  60*minute;
		NSTimeInterval const day    =  24*hour;
		NSTimeInterval const week   =   7*day;
		NSTimeInterval const month  =  31*day;
		NSTimeInterval const year   = 365*day;

		NSString* res;

		NSTimeInterval t = -[date timeIntervalSinceNow];
		if(t < 1)
			res = @"刚刚";
		else if(t < minute)
			res = @"不到一分钟之前";
		else if(t < 2 * minute)
			res = @"一分钟之前";
		else if(t < hour)
			res = [NSString stringWithFormat:@"%.0f分钟之前", t / minute];
		else if(t < 2 * hour)
			res = @"一小时之前";
		else if(t < day)
			res = [NSString stringWithFormat:@"%.0f小时之前", t / hour];
		else if(t < 2*day)
			res = @"昨天";
		else if(t < week)
			res = [NSString stringWithFormat:@"%.0f天之前", t / day];
		else if(t < 2*week)
			res = @"上周";
		else if(t < month)
			res = [NSString stringWithFormat:@"%.0f周之前", t / week];
		else if(t < 2*month)
			res = @"上个月";
		else if(t < year)
			res = [NSString stringWithFormat:@"%.0f个月之前", t / month];
		else if(t < 2*year)
			res = @"去年";
		else
			res = [NSString stringWithFormat:@"%.0f年之前", t / year];

		return res;
	}
}

- (void)viewWillAppear
{
	_relativeDateUserDefaultsObserver = [NSNotificationCenter.defaultCenter addObserverForName:NSUserDefaultsDidChangeNotification object:NSUserDefaults.standardUserDefaults queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification* notification){
		self.relativeStringForLastCheck = [self relativeStringForDate:[NSUserDefaults.standardUserDefaults objectForKey:kUserDefaultsLastSoftwareUpdateCheckKey]];
	}];

	_relativeDateUpdateTimer = [NSTimer scheduledTimerWithTimeInterval:60 repeats:YES block:^(NSTimer* timer){
		self.relativeStringForLastCheck = [self relativeStringForDate:[NSUserDefaults.standardUserDefaults objectForKey:kUserDefaultsLastSoftwareUpdateCheckKey]];
	}];

	self.relativeStringForLastCheck = [self relativeStringForDate:[NSUserDefaults.standardUserDefaults objectForKey:kUserDefaultsLastSoftwareUpdateCheckKey]];
}

- (void)viewDidDisappear
{
	[_relativeDateUpdateTimer invalidate];
	[NSNotificationCenter.defaultCenter removeObserver:_relativeDateUserDefaultsObserver];
}

- (void)loadView
{
	NSButton* watchForUpdatesCheckBox      = OakCreateCheckBox(@"查看:");
	NSPopUpButton* updateChannelPopUp      = OakCreatePopUpButton();
	NSButton* askBeforeDownloadingCheckBox = OakCreateCheckBox(@"下载更新之前先询问");

	NSStackView* watchForStackView = [NSStackView stackViewWithViews:@[ watchForUpdatesCheckBox, updateChannelPopUp ]];
	watchForStackView.alignment = NSLayoutAttributeFirstBaseline;

	NSTextField* lastCheckTextField        = OakCreateLabel(@"一段时间之前");
	NSButton* checkNowButton               = [NSButton buttonWithTitle:@"现在检查" target:self.softwareUpdateController action:@selector(checkForUpdate:)];

	NSButton* submitCrashReportsCheckBox   = OakCreateCheckBox(@"提交到开发者");

	NSTextField* contactTextField          = [NSTextField textFieldWithString:@"匿名"];

	NSFont* smallFont = [NSFont messageFontOfSize:[NSFont systemFontSizeForControlSize:NSControlSizeSmall]];
	contactTextField.font        = smallFont;
	contactTextField.controlSize = NSControlSizeSmall;

	NSStackView* contactStackView = [NSStackView stackViewWithViews:@[
		OakCreateLabel(@"联系:", smallFont), contactTextField
	]];
	contactStackView.alignment  = NSLayoutAttributeFirstBaseline;
	contactStackView.edgeInsets = { .left = 18 };
	[contactStackView setHuggingPriority:NSLayoutPriorityDefaultHigh-1 forOrientation:NSLayoutConstraintOrientationVertical];

	MBMenu const updateChannelMenuItems = {
		{ @"常规版本", .tag = 0 },
		{ @"预览版本",     .tag = 1 },
	};
	MBCreateMenu(updateChannelMenuItems, updateChannelPopUp.menu);

	NSGridView* gridView = [NSGridView gridViewWithViews:@[
		@[ OakCreateLabel(@"软件更新:"),        watchForStackView                 ],
		@[ NSGridCell.emptyContentView,                askBeforeDownloadingCheckBox      ],
		@[ ],
		@[ OakCreateLabel(@"上次检查:"),             lastCheckTextField                ],
		@[ NSGridCell.emptyContentView,                checkNowButton                    ],
		@[ ],
		@[ OakCreateLabel(@"崩溃报告:"),          submitCrashReportsCheckBox        ],
		@[ NSGridCell.emptyContentView,                contactStackView                  ],
	]];

	[contactTextField.trailingAnchor constraintEqualToAnchor:updateChannelPopUp.trailingAnchor].active = YES;

	self.view = OakSetupGridViewWithSeparators(gridView, { 2, 5 });

	[watchForUpdatesCheckBox      bind:NSValueBinding       toObject:NSUserDefaultsController.sharedUserDefaultsController withKeyPath:[NSString stringWithFormat:@"values.%@", kUserDefaultsDisableSoftwareUpdateKey]   options:@{ NSValueTransformerNameBindingOption: NSNegateBooleanTransformerName }];
	[updateChannelPopUp           bind:NSSelectedTagBinding toObject:NSUserDefaultsController.sharedUserDefaultsController withKeyPath:[NSString stringWithFormat:@"values.%@", kUserDefaultsSoftwareUpdateChannelKey]   options:@{ NSValueTransformerNameBindingOption: @"OakSoftwareUpdateChannelTransformer" }];
	[askBeforeDownloadingCheckBox bind:NSValueBinding       toObject:NSUserDefaultsController.sharedUserDefaultsController withKeyPath:[NSString stringWithFormat:@"values.%@", kUserDefaultsAskBeforeUpdatingKey]       options:nil];
	[lastCheckTextField           bind:NSValueBinding       toObject:self                                                  withKeyPath:@"lastCheckDescription"                                                           options:nil];
	[submitCrashReportsCheckBox   bind:NSValueBinding       toObject:NSUserDefaultsController.sharedUserDefaultsController withKeyPath:[NSString stringWithFormat:@"values.%@", kUserDefaultsDisableCrashReportingKey]   options:@{ NSValueTransformerNameBindingOption: NSNegateBooleanTransformerName }];
	[contactTextField             bind:NSValueBinding       toObject:NSUserDefaultsController.sharedUserDefaultsController withKeyPath:[NSString stringWithFormat:@"values.%@", kUserDefaultsCrashReportsContactInfoKey] options:nil];

	[updateChannelPopUp           bind:NSEnabledBinding     toObject:NSUserDefaultsController.sharedUserDefaultsController withKeyPath:[NSString stringWithFormat:@"values.%@", kUserDefaultsDisableSoftwareUpdateKey]   options:@{ NSValueTransformerNameBindingOption: NSNegateBooleanTransformerName }];
	[askBeforeDownloadingCheckBox bind:NSEnabledBinding     toObject:NSUserDefaultsController.sharedUserDefaultsController withKeyPath:[NSString stringWithFormat:@"values.%@", kUserDefaultsDisableSoftwareUpdateKey]   options:@{ NSValueTransformerNameBindingOption: NSNegateBooleanTransformerName }];
	[checkNowButton               bind:NSEnabledBinding     toObject:self.softwareUpdateController                         withKeyPath:@"checking"                                                                       options:@{ NSValueTransformerNameBindingOption: NSNegateBooleanTransformerName }];
	[contactTextField             bind:NSEnabledBinding     toObject:NSUserDefaultsController.sharedUserDefaultsController withKeyPath:[NSString stringWithFormat:@"values.%@", kUserDefaultsDisableCrashReportingKey]   options:@{ NSValueTransformerNameBindingOption: NSNegateBooleanTransformerName }];
}
@end
