#import "AppController.h"
#import "OakMainMenu.h"
#import "Favorites.h"
#import "AboutWindowController.h"
#import "TMPlugInController.h"
#import "RMateServer.h"
#import <BundleEditor/BundleEditor.h>
#import <BundlesManager/BundlesManager.h>
#import <CrashReporter/CrashReporter.h>
#import <DocumentWindow/DocumentWindowController.h>
#import <Find/Find.h>
#import <CommitWindow/CommitWindow.h>
#import <OakAppKit/NSAlert Additions.h>
#import <OakAppKit/NSMenuItem Additions.h>
#import <OakAppKit/OakAppKit.h>
#import <OakAppKit/OakPasteboard.h>
#import <OakFilterList/BundleItemChooser.h>
#import <OakFoundation/OakFoundation.h>
#import <OakFoundation/NSString Additions.h>
#import <OakTextView/OakDocumentView.h>
#import <MenuBuilder/MenuBuilder.h>
#import <MenuBuilder/MBMenuDelegate.h>
#import <Preferences/Keys.h>
#import <Preferences/Preferences.h>
#import <SoftwareUpdate/SoftwareUpdate.h>
#import <document/OakDocument.h>
#import <document/OakDocumentController.h>
#import <bundles/query.h>
#import <io/path.h>
#import <regexp/glob.h>
#import <network/tbz.h>
#import <ns/ns.h>
#import <settings/settings.h>
#import <oak/debug.h>
#import <oak/oak.h>
#import <scm/scm.h>
#import <text/types.h>

void OakOpenDocuments (NSArray* paths, BOOL treatFilePackageAsFolder)
{
	NSArray* const bundleExtensions = @[ @"tmbundle", @"tmcommand", @"tmdragcommand", @"tmlanguage", @"tmmacro", @"tmpreferences", @"tmsnippet", @"tmtheme" ];

	NSMutableArray<OakDocument*>* documents = [NSMutableArray array];
	NSMutableArray* itemsToInstall = [NSMutableArray array];
	NSMutableArray* plugInsToInstall = [NSMutableArray array];
	BOOL enableInstallHandler = treatFilePackageAsFolder == NO && ([NSEvent modifierFlags] & NSEventModifierFlagOption) == 0;
	for(NSString* path in paths)
	{
		BOOL isDirectory = NO;
		NSString* pathExt = [[path pathExtension] lowercaseString];
		if(enableInstallHandler && [bundleExtensions containsObject:pathExt])
		{
			[itemsToInstall addObject:path];
		}
		else if(enableInstallHandler && [pathExt isEqualToString:@"tmplugin"])
		{
			[plugInsToInstall addObject:path];
		}
		else if([NSFileManager.defaultManager fileExistsAtPath:path isDirectory:&isDirectory] && isDirectory)
		{
			[OakDocumentController.sharedInstance showFileBrowserAtPath:path];
		}
		else
		{
			[documents addObject:[OakDocumentController.sharedInstance documentWithPath:path]];
		}
	}

	if([itemsToInstall count])
		[BundlesManager.sharedInstance installBundleItemsAtPaths:itemsToInstall];

	for(NSString* path in plugInsToInstall)
		[TMPlugInController.sharedInstance installPlugInAtPath:path];

	[OakDocumentController.sharedInstance showDocuments:documents];
}

BOOL HasDocumentWindow (NSArray* windows)
{
	for(NSWindow* window in windows)
	{
		if([window.delegate isKindOfClass:[DocumentWindowController class]])
			return YES;
	}
	return NO;
}

@interface AppController () <OakUserDefaultsObserver>
@property (nonatomic) BOOL didFinishLaunching;
@property (nonatomic) BOOL keyWindowHasBackAndForwardActions;
@end

@implementation AppController
- (NSMenu*)mainMenu
{
	MBMenu const items = {
		{ @"文本编辑",
			.submenu = {
				{ @"关于文本编辑",        @selector(orderFrontAboutPanel:)               },
				{ /* -------- */ },
				{ @"偏好设置…",          @selector(showPreferences:),            @","   },
				{ @"检查更新",      @selector(performSoftwareUpdateCheck:)         },
				{ @"检查测试版本",  @selector(performSoftwareUpdateCheck:),       .modifierFlags = NSEventModifierFlagCommand|NSEventModifierFlagOption, .alternate = YES },
				{ /* -------- */ },
				{ @"服务",              .systemMenu = MBMenuTypeServices               },
				{ /* -------- */ },
				{ @"隐藏文本编辑",         @selector(hide:),                       @"h"   },
				{ @"隐藏其他",           @selector(hideOtherApplications:),      @"h", .modifierFlags = NSEventModifierFlagCommand|NSEventModifierFlagOption },
				{ @"显示全部",              @selector(unhideAllApplications:),             },
				{ /* -------- */ },
				{ @"退出文本编辑",         @selector(terminate:),                  @"q"   },
			}
		},
		{ @"文件",
			.submenu = {
				{ @"新建窗口",                     @selector(newDocument:),              @"n"   },
				{ @"新文件浏览",        @selector(newFileBrowser:),           @"n", .modifierFlags = NSEventModifierFlagCommand|NSEventModifierFlagOption|NSEventModifierFlagControl, .alternate = YES },
				{ @"新建标签页",                 @selector(newDocumentInTab:),         @"n", .modifierFlags = NSEventModifierFlagCommand|NSEventModifierFlagOption },
				{ /* -------- */ },
				{ @"打开…",                   @selector(openDocument:),             @"o"   },
				{ @"快速打开…",           @selector(goToFile:),                 @"t"   },
				{ @"打开最近",
					.systemMenu = MBMenuTypeOpenRecent, .submenu = {
						{ @"清除历史", @selector(clearRecentDocuments:) },
					}
				},
				{ @"打开最近项目…",    @selector(openFavorites:),            @"O"   },
				{ /* -------- */ },
				{ @"关闭",                   @selector(performClose:),             @"w"   },
				{ @"关闭窗口",            @selector(performCloseWindow:),       @"W"   },
				{ @"关闭所有标签页",          @selector(performCloseAllTabs:),      @"w", .modifierFlags = NSEventModifierFlagCommand|NSEventModifierFlagOption|NSEventModifierFlagControl },
				{ @"关闭其他标签页s",        @selector(performCloseOtherTabsXYZ:), @"w", .modifierFlags = NSEventModifierFlagCommand|NSEventModifierFlagControl },
				{ @"关闭右边标签页", @selector(performCloseTabsToTheRight:)       },
				{ @"关闭左边标签页",  @selector(performCloseTabsToTheLeft:),      .modifierFlags = NSEventModifierFlagCommand|NSEventModifierFlagOption, .alternate = YES },
				{ /* -------- */ },
				{ @"保存",                    @selector(saveDocument:),             @"s"   },
				{ @"另存为…",                @selector(saveDocumentAs:),           @"S"   },
				{ @"全部保存",                @selector(saveAllDocuments:),         @"s", .modifierFlags = NSEventModifierFlagCommand|NSEventModifierFlagOption },
				{ @"恢复",                  @selector(revertDocumentToSaved:)            },
				{ /* -------- */ },
				{ @"页面设置…",             @selector(runPageLayout:),                  .target = NSApp.delegate },
				{ @"打印…",                  @selector(printDocument:),            @"p"   },
			}
		},
		{ @"编辑",
			.submenu = {
				{ @"撤销",   @selector(undo:),   @"z" },
				{ @"重做",   @selector(redo:),   @"Z" },
				{ /* -------- */ },
				{ @"剪切",    @selector(cut:),    @"x" },
				{ @"复制",   @selector(copy:),   @"c" },
				{ @"粘贴",
					.submenu = {
						{ @"粘贴",                   @selector(paste:),                @"v"   },
						{ @"粘贴而不缩进", @selector(pasteWithoutReindent:), @"v", .modifierFlags = NSEventModifierFlagCommand|NSEventModifierFlagControl, .alternate = YES },
						{ @"粘贴下一个",              @selector(pasteNext:),            @"v", .modifierFlags = NSEventModifierFlagCommand|NSEventModifierFlagOption },
						{ @"粘贴上一个",          @selector(pastePrevious:),        @"V"   },
						{ /* -------- */ },
						{ @"显示历史",            @selector(showClipboardHistory:), @"v", .modifierFlags = NSEventModifierFlagCommand|NSEventModifierFlagOption|NSEventModifierFlagControl },
					}
				},
				{ @"删除", @selector(delete:), .key = NSBackspaceCharacter },
				{ /* -------- */ },
				{ @"宏指令",
					.submenu = {
						{ @"录入指令", @selector(toggleMacroRecording:), @"m", .modifierFlags = NSEventModifierFlagCommand|NSEventModifierFlagOption },
						{ @"回放指令",    @selector(playScratchMacro:),     @"M"   },
						{ @"保存指令…",     @selector(saveScratchMacro:),     @"m", .modifierFlags = NSEventModifierFlagCommand|NSEventModifierFlagControl },
					}
				},
				{ /* -------- */ },
				{ @"选择",
					.submenu = {
						{ @"文字",                    @selector(selectWord:)                  },
						{ @"整行",                    @selector(selectHardLine:)              },
						{ @"段落",               @selector(selectParagraph:)             },
						{ @"当前范围",           @selector(selectCurrentScope:)          },
						{ @"字符串",  @selector(selectBlock:),           @"B" },
						{ @"全部",                     @selector(selectAll:),             @"a" },
						{ /* -------- */ },
						{ @"切换选择列", @selector(toggleColumnSelection:), .modifierFlags = NSEventModifierFlagOption },
					}
				},
				{ @"查找",
					.submenu = {
						{ @"查找和替换…",           @selector(orderFrontFindPanel:),          @"f", .tag = FFSearchTargetDocument },
						{ @"项目中查找…",            @selector(orderFrontFindPanel:),          @"F", .tag = FFSearchTargetProject  },
						{ @"文件夹中查找…",             @selector(orderFrontFindPanel:),                .tag = FFSearchTargetOther    },
						{ /* -------- */ },
						{ @"显示查找记录",           @selector(showFindHistory:),              @"f", .modifierFlags = NSEventModifierFlagCommand|NSEventModifierFlagOption|NSEventModifierFlagControl },
						{ /* -------- */ },
						{ @"查找下一个",                   @selector(findNext:),                     @"g"   },
						{ @"查找上一个",               @selector(findPrevious:),                 @"G"   },
						{ @"查找全部",                    @selector(findAllInSelection:),           @"f", .modifierFlags = NSEventModifierFlagCommand|NSEventModifierFlagOption },
						{ /* -------- */ },
						{ @"查找选项",
							.submenu = {
								{ @"忽略大小写",        @selector(toggleFindOption:), @"c", .modifierFlags = NSEventModifierFlagCommand|NSEventModifierFlagOption, .tag =   2 },
								{ @"正则表达式", @selector(toggleFindOption:), @"r", .modifierFlags = NSEventModifierFlagCommand|NSEventModifierFlagOption, .tag =   8 },
								{ @"忽略空格",  @selector(toggleFindOption:),                                                                              .tag =   4 },
								{ @"循环",        @selector(toggleFindOption:), @"a", .modifierFlags = NSEventModifierFlagCommand|NSEventModifierFlagOption, .tag = 128 },
							}
						},
						{ /* -------- */ },
						{ @"替换",                     @selector(replace:),                      @"g", .modifierFlags = NSEventModifierFlagCommand|NSEventModifierFlagOption },
						{ @"替换&查找",              @selector(replaceAndFind:)                       },
						{ @"替换全部",                 @selector(replaceAll:),                   @"g", .modifierFlags = NSEventModifierFlagCommand|NSEventModifierFlagControl },
						{ @"替换所有选择的",    @selector(replaceAllInSelection:),        @"G", .modifierFlags = NSEventModifierFlagCommand|NSEventModifierFlagControl },
						{ /* -------- */ },
						{ @"使用选择进行查找",      @selector(copySelectionToFindPboard:),    @"e"   },
						{ @"使用选择进行替换",   @selector(copySelectionToReplacePboard:), @"E"   },
					}
				},
				{ @"拼写",
					.submenuRef = &spellingMenu, .submenu = {
						{ @"拼写…",                   @selector(showGuessPanel:),                @":"   },
						{ @"立即检查文档",          @selector(checkSpelling:),                 @";"   },
						{ /* -------- */ },
						{ @"打字时检查拼写", @selector(toggleContinuousSpellChecking:), @";", .modifierFlags = NSEventModifierFlagCommand|NSEventModifierFlagOption },
						{ /* -------- */ },
					}
				},
			}
		},
		{ @"显示",
			.submenu = {
				{ @"字体",
					.systemMenu = MBMenuTypeFont, .submenu = {
						{ @"显示字体",   @selector(orderFrontFontPanel:),      .target = NSFontManager.sharedFontManager },
						{ /* -------- */ },
						{ @"放大",       @selector(makeTextLarger:),       @"+" },
						{ @"缩小",      @selector(makeTextSmaller:),      @"-" },
						{ @"默认大小", @selector(makeTextStandardSize:), @"0" },
					}
				},
				{ @"显示文件浏览",      @selector(toggleFileBrowser:),    @"d", .modifierFlags = NSEventModifierFlagCommand|NSEventModifierFlagOption|NSEventModifierFlagControl },
				{ @"显示HTML输出",       @selector(toggleHTMLOutput:),     @"h", .modifierFlags = NSEventModifierFlagCommand|NSEventModifierFlagOption|NSEventModifierFlagControl },
				{ @"显示行号",      @selector(toggleLineNumbers:),    @"l", .modifierFlags = NSEventModifierFlagCommand|NSEventModifierFlagOption },
				{ /* -------- */ },
				{ @"显示隐藏文件",        @selector(toggleShowInvisibles:), @"i", .modifierFlags = NSEventModifierFlagCommand|NSEventModifierFlagOption },
				{ /* -------- */ },
				{ @"允许自动换行",       @selector(toggleSoftWrap:),       @"w", .modifierFlags = NSEventModifierFlagCommand|NSEventModifierFlagOption },
				{ @"显示换行位置",       @selector(toggleShowWrapColumn:)         },
				{ @"显示缩进线",     @selector(toggleShowIndentGuides:)       },
				{ @"换行位置",
					.submenuRef = &wrapColumnMenu, .submenu = {
						{ @"使用窗口边框", @selector(takeWrapColumnFrom:)   },
						{ /* -------- */ },
						{ @"40",               @selector(takeWrapColumnFrom:), .tag = 40 },
						{ @"80",               @selector(takeWrapColumnFrom:), .tag = 80 },
						{ /* -------- */ },
						{ @"其他…",           @selector(takeWrapColumnFrom:), .tag = -1 },
					}
				},
				{ /* -------- */ },
				{ @"缩进位数",
					.submenu = {
						{ @"2",      @selector(takeTabSizeFrom:),        .tag = 2 },
						{ @"3",      @selector(takeTabSizeFrom:),        .tag = 3 },
						{ @"4",      @selector(takeTabSizeFrom:),        .tag = 4 },
						{ @"5",      @selector(takeTabSizeFrom:),        .tag = 5 },
						{ @"6",      @selector(takeTabSizeFrom:),        .tag = 6 },
						{ @"7",      @selector(takeTabSizeFrom:),        .tag = 7 },
						{ @"8",      @selector(takeTabSizeFrom:),        .tag = 8 },
						{ /* -------- */ },
						{ @"其他…", @selector(showTabSizeSelectorPanel:) },
					}
				},
				{ @"主题",                  .submenuRef = &themesMenu                },
				{ /* -------- */ },
				{ @"折叠当前模块",     @selector(toggleCurrentFolding:), .modifierFlags = 0, .key = NSF1FunctionKey },
				{ @"切换折叠级别",
					.submenu = {
						{ @"所有级别", @selector(takeLevelToFoldFrom:), @"0", .modifierFlags = NSEventModifierFlagCommand|NSEventModifierFlagOption },
						{ @"1",          @selector(takeLevelToFoldFrom:), @"1", .modifierFlags = NSEventModifierFlagCommand|NSEventModifierFlagOption, .tag = 1 },
						{ @"2",          @selector(takeLevelToFoldFrom:), @"2", .modifierFlags = NSEventModifierFlagCommand|NSEventModifierFlagOption, .tag = 2 },
						{ @"3",          @selector(takeLevelToFoldFrom:), @"3", .modifierFlags = NSEventModifierFlagCommand|NSEventModifierFlagOption, .tag = 3 },
						{ @"4",          @selector(takeLevelToFoldFrom:), @"4", .modifierFlags = NSEventModifierFlagCommand|NSEventModifierFlagOption, .tag = 4 },
						{ @"5",          @selector(takeLevelToFoldFrom:), @"5", .modifierFlags = NSEventModifierFlagCommand|NSEventModifierFlagOption, .tag = 5 },
						{ @"6",          @selector(takeLevelToFoldFrom:), @"6", .modifierFlags = NSEventModifierFlagCommand|NSEventModifierFlagOption, .tag = 6 },
						{ @"7",          @selector(takeLevelToFoldFrom:), @"7", .modifierFlags = NSEventModifierFlagCommand|NSEventModifierFlagOption, .tag = 7 },
						{ @"8",          @selector(takeLevelToFoldFrom:), @"8", .modifierFlags = NSEventModifierFlagCommand|NSEventModifierFlagOption, .tag = 8 },
						{ @"9",          @selector(takeLevelToFoldFrom:), @"9", .modifierFlags = NSEventModifierFlagCommand|NSEventModifierFlagOption, .tag = 9 },
					}
				},
				{ /* -------- */ },
				{ @"切换滚动越过末尾", @selector(toggleScrollPastEnd:)          },
				{ /* -------- */ },
				{ @"查看源代码",            @selector(viewSource:),           @"u", .modifierFlags = NSEventModifierFlagCommand|NSEventModifierFlagOption },
				{ @"进入全屏幕",      @selector(toggleFullScreen:),     @"f", .modifierFlags = NSEventModifierFlagCommand|NSEventModifierFlagControl },
				{ /* -------- */ },
				{ @"自定义触控条…",   @selector(toggleTouchBarCustomizationPalette:) },
			}
		},
		{ @"导航",
			.submenu = {
				{ @"跳转到行…",              @selector(orderFrontGoToLinePanel:),      @"l" },
				{ @"跳转到字符…",            @selector(showSymbolChooser:),            @"T" },
				{ @"跳转到选择",          @selector(centerSelectionInVisibleArea:), @"j" },
				{ /* -------- */ },
				{ @"设置书签",               @selector(toggleCurrentBookmark:),                                                   .key = NSF2FunctionKey },
				{ @"跳转到下一个书签",      @selector(goToNextBookmark:),             .modifierFlags = 0,                        .key = NSF2FunctionKey },
				{ @"跳转到上一个书签",  @selector(goToPreviousBookmark:),         .modifierFlags = NSEventModifierFlagShift, .key = NSF2FunctionKey },
				{ @"跳转到书签",           .delegate = [MBMenuDelegate delegateUsingSelector:@selector(updateBookmarksMenu:)] },
				{ /* -------- */ },
				{ @"跳转到下一个标记",          @selector(jumpToNextMark:),               .modifierFlags = 0,                        .key = NSF3FunctionKey },
				{ @"跳转到上一个标记",      @selector(jumpToPreviousMark:),           .modifierFlags = NSEventModifierFlagShift, .key = NSF3FunctionKey },
				{ /* -------- */ },
				{ @"滚动",
					.submenu = {
						{ @"向上",      @selector(scrollLineUp:),      .modifierFlags = NSEventModifierFlagCommand|NSEventModifierFlagOption|NSEventModifierFlagControl, .key = NSUpArrowFunctionKey    },
						{ @"向下",    @selector(scrollLineDown:),    .modifierFlags = NSEventModifierFlagCommand|NSEventModifierFlagOption|NSEventModifierFlagControl, .key = NSDownArrowFunctionKey  },
						{ @"向左",  @selector(scrollColumnLeft:),  .modifierFlags = NSEventModifierFlagCommand|NSEventModifierFlagOption|NSEventModifierFlagControl, .key = NSLeftArrowFunctionKey  },
						{ @"向右", @selector(scrollColumnRight:), .modifierFlags = NSEventModifierFlagCommand|NSEventModifierFlagOption|NSEventModifierFlagControl, .key = NSRightArrowFunctionKey },
					}
				},
				{ /* -------- */ },
				{ @"转到相关的文件",         @selector(goToRelatedFile:),              .modifierFlags = NSEventModifierFlagCommand|NSEventModifierFlagOption, .key = NSUpArrowFunctionKey },
				{ /* -------- */ },
				{ @"将焦点移至文件浏览", @selector(moveFocus:),                    .modifierFlags = NSEventModifierFlagCommand|NSEventModifierFlagOption, .key = NSTabCharacter },
			}
		},
		{ @"文本",
			.submenu = {
				{ @"移动",                            @selector(transpose:)                        },
				{ /* -------- */ },
				{ @"移动方向",
					.submenu = {
						{ @"向上",    @selector(moveSelectionUp:),    .modifierFlags = NSEventModifierFlagCommand|NSEventModifierFlagControl, .key = NSUpArrowFunctionKey    },
						{ @"向下",  @selector(moveSelectionDown:),  .modifierFlags = NSEventModifierFlagCommand|NSEventModifierFlagControl, .key = NSDownArrowFunctionKey  },
						{ @"向左",  @selector(moveSelectionLeft:),  .modifierFlags = NSEventModifierFlagCommand|NSEventModifierFlagControl, .key = NSLeftArrowFunctionKey  },
						{ @"向右", @selector(moveSelectionRight:), .modifierFlags = NSEventModifierFlagCommand|NSEventModifierFlagControl, .key = NSRightArrowFunctionKey },
					}
				},
				{ /* -------- */ },
				{ @"单词切换为大写",           @selector(uppercaseWord:)                    },
				{ @"单词切换为小写",           @selector(lowercaseWord:)                    },
				{ @"单词首字母大写",           @selector(capitalizeWord:)                   },
				{ /* -------- */ },
				{ @"左移",                           @selector(shiftLeft:),                  @"[" },
				{ @"右移",                          @selector(shiftRight:),                 @"]" },
				{ @"缩进线/选择",              @selector(indent:)                           },
				{ /* -------- */ },
				{ @"重新设置文本格式",                        @selector(reformatText:)                     },
				{ @"重新格式化文本并对齐",            @selector(reformatTextAndJustify:)           },
				{ @"展开段落",                     @selector(unwrapText:)                       },
				{ /* -------- */ },
				{ @"通过命令过滤…",              @selector(orderFrontRunCommandWindow:), @"|" },
			}
		},
		{ @"文件浏览",
			.submenu = {
				{ @"新建文件",         @selector(newDocumentInDirectory:), @"n", .modifierFlags = NSEventModifierFlagCommand|NSEventModifierFlagControl },
				{ @"新建文件夹",       @selector(newFolder:),              @"N"   },
				{ /* -------- */ },
				{ @"后退",             @selector(goBack:)                         },
				{ @"前进",          @selector(goForward:)                      },
				{ @"上层文件夹", @selector(goToParentFolder:),       .key = NSUpArrowFunctionKey },
				{ /* -------- */ },
				{ @"选择文档",  @selector(revealFileInProject:),    @"r", .modifierFlags = NSEventModifierFlagCommand|NSEventModifierFlagControl },
				{ @"不选择",      @selector(deselectAll:),            @"A"   },
				{ /* -------- */ },
				{ @"项目文件夹",   @selector(goToProjectFolder:),      @"P"   },
				{ @"SCM状态",       @selector(goToSCMDataSource:),      @"Y"   },
				{ @"计算机",         @selector(goToComputer:),           @"C"   },
				{ @"个人文件夹",             @selector(goToHome:),               @"H"   },
				{ @"桌面",          @selector(goToDesktop:),            @"D"   },
				{ @"收藏夹",        @selector(goToFavorites:)                  },
				{ /* -------- */ },
				{ @"前往文件夹…",    @selector(orderFrontGoToFolder:)           },
				{ @"重新加载",           @selector(reload:)                         },
			}
		},
		{ @"插件",
			.submenuRef = &bundlesMenu, .submenu = {
				{ @"选择插件项目…", @selector(showBundleItemChooser:), @"t", .modifierFlags = NSEventModifierFlagCommand|NSEventModifierFlagControl },
				{ @"编辑插件…",       @selector(showBundleEditor:),      @"b", .modifierFlags = NSEventModifierFlagCommand|NSEventModifierFlagOption|NSEventModifierFlagControl },
				{ /* -------- */ },
			}
		},
		{ @"窗口",
			.systemMenu = MBMenuTypeWindows, .submenu = {
				{ @"最小化",               @selector(miniaturize:),           @"m" },
				{ @"缩放",                   @selector(performZoom:)                 },
				{ /* -------- */ },
				{ @"显示上一个标签页",      @selector(selectPreviousTab:),     .modifierFlags = NSEventModifierFlagControl|NSEventModifierFlagShift,  .key = NSTabCharacter,                        },
				{ @"显示下一个标签页",          @selector(selectNextTab:),         .modifierFlags = NSEventModifierFlagControl,                           .key = NSTabCharacter,                        },
				{ @"显示上一个标签页",      @selector(selectPreviousTab:),     .modifierFlags = NSEventModifierFlagOption|NSEventModifierFlagCommand, .key = NSLeftArrowFunctionKey,  .hidden = YES },
				{ @"显示下一个标签页",          @selector(selectNextTab:),         .modifierFlags = NSEventModifierFlagOption|NSEventModifierFlagCommand, .key = NSRightArrowFunctionKey, .hidden = YES },
				{ @"显示上一个标签页",      @selector(selectPreviousTab:),     @"{", .hidden = YES },
				{ @"显示下一个标签页",          @selector(selectNextTab:),         @"}", .hidden = YES },
				{ @"显示标签页",               .delegate = [MBMenuDelegate delegateUsingSelector:@selector(updateShowTabMenu:)] },
				{ /* -------- */ },
				{ @"把标签页移动到新窗口", @selector(moveDocumentToNewWindow:)     },
				{ @"合并所有窗口",      @selector(mergeAllWindows:)             },
				{ /* -------- */ },
				{ @"前置全部窗口",     @selector(arrangeInFront:)              },
			}
		},
		{ @"帮助",
			.systemMenu = MBMenuTypeHelp, .submenu = {
				{ @"文本编辑帮助", @selector(showHelp:), @"?" },
			}
		},
	};

	NSMenu* menu = MBCreateMenu(items, [[OakMainMenu alloc] initWithTitle:@"AMainMenu"]);
	bundlesMenu.delegate    = self;
	themesMenu.delegate     = self;
	spellingMenu.delegate   = self;
	wrapColumnMenu.delegate = self;
	return menu;
}

- (NSMenu*)applicationDockMenu:(NSApplication*)anApplication
{
	MBMenu const items = {
		{ @"新建文件", @selector(newDocumentAndActivate:),  .target = self },
		{ @"打开…",    @selector(openDocumentAndActivate:), .target = self },
	};
	return MBCreateMenu(items);
}

- (void)setKeyWindowHasBackAndForwardActions:(BOOL)flag
{
	if(_keyWindowHasBackAndForwardActions == flag)
		return;
	_keyWindowHasBackAndForwardActions = flag;

	NSMenu* textMenu        = [NSApp.mainMenu itemWithTitle:@"文本"].submenu;
	NSMenu* fileBrowserMenu = [NSApp.mainMenu itemWithTitle:@"文件浏览"].submenu;

	auto itemWithAction = ^NSMenuItem*(NSMenu* menu, SEL action){
		NSInteger index = [menu indexOfItemWithTarget:nil andAction:action];
		return index == -1 ? nil : menu.itemArray[index];
	};

	NSMenuItem* backMenuItem       = itemWithAction(fileBrowserMenu, @selector(goBack:));
	NSMenuItem* forwardMenuItem    = itemWithAction(fileBrowserMenu, @selector(goForward:));
	NSMenuItem* shiftLeftMenuItem  = itemWithAction(textMenu,        @selector(shiftLeft:));
	NSMenuItem* shiftRightMenuItem = itemWithAction(textMenu,        @selector(shiftRight:));

	if(!backMenuItem || !forwardMenuItem || !shiftLeftMenuItem || !shiftRightMenuItem)
		return;

	for(NSMenuItem* menuItem in @[ backMenuItem, forwardMenuItem, shiftLeftMenuItem, shiftRightMenuItem ])
		menuItem.keyEquivalent = @"";

	(flag ? backMenuItem : shiftLeftMenuItem).keyEquivalent                 = @"[";
	(flag ? backMenuItem : shiftLeftMenuItem).keyEquivalentModifierMask     = NSEventModifierFlagCommand;
	(flag ? forwardMenuItem : shiftRightMenuItem).keyEquivalent             = @"]";
	(flag ? forwardMenuItem : shiftRightMenuItem).keyEquivalentModifierMask = NSEventModifierFlagCommand;
}

- (void)applicationDidUpdate:(NSNotification*)aNotification
{
	BOOL foundBackAndForwardActions = NO;
	for(NSResponder* responder = NSApp.keyWindow.firstResponder; responder && !foundBackAndForwardActions; responder = responder.nextResponder)
	{
		if([responder respondsToSelector:@selector(shiftLeft:)])
			break;
		else if([responder respondsToSelector:@selector(goBack:)])
			foundBackAndForwardActions = YES;
	}
	self.keyWindowHasBackAndForwardActions = foundBackAndForwardActions;
}

- (void)userDefaultsDidChange:(id)sender
{
	BOOL disableRmate        = [NSUserDefaults.standardUserDefaults boolForKey:kUserDefaultsDisableRMateServerKey];
	NSString* rmateInterface = [NSUserDefaults.standardUserDefaults stringForKey:kUserDefaultsRMateServerListenKey];
	int rmatePort            = [NSUserDefaults.standardUserDefaults integerForKey:kUserDefaultsRMateServerPortKey];
	setup_rmate_server(!disableRmate, rmatePort, [rmateInterface isEqualToString:kRMateServerListenRemote]);
}

- (void)applicationWillFinishLaunching:(NSNotification*)aNotification
{
	if(NSMenu* menu = [self mainMenu])
		NSApp.mainMenu = menu;

	NSOperatingSystemVersion osVersion = NSProcessInfo.processInfo.operatingSystemVersion;
	NSString* parms = [NSString stringWithFormat:@"v=%@&os=%ld.%ld.%ld", [[[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"] stringByAddingPercentEncodingWithAllowedCharacters:NSCharacterSet.URLQueryAllowedCharacterSet], osVersion.majorVersion, osVersion.minorVersion, osVersion.patchVersion];

	SoftwareUpdate.sharedInstance.channels = @{
		kSoftwareUpdateChannelRelease:    [NSURL URLWithString:[NSString stringWithFormat:@"" REST_API "/releases/release?%@", parms]],
		kSoftwareUpdateChannelPrerelease: [NSURL URLWithString:[NSString stringWithFormat:@"" REST_API "/releases/beta?%@", parms]],
		kSoftwareUpdateChannelCanary:     [NSURL URLWithString:[NSString stringWithFormat:@"" REST_API "/releases/nightly?%@", parms]],
	};

	settings_t::set_default_settings_path([[[NSBundle mainBundle] pathForResource:@"Default" ofType:@"tmProperties"] fileSystemRepresentation]);
	settings_t::set_global_settings_path(path::join(path::home(), "Library/Application Support/TextMate/Global.tmProperties"));

	[NSUserDefaults.standardUserDefaults registerDefaults:@{
		@"NSRecentDocumentsLimit": @25,
		@"WebKitDeveloperExtras":  @YES,
	}];
	RegisterDefaults();

	[TMPlugInController.sharedInstance loadAllPlugIns:nil];

	std::string dest = path::join(path::home(), "Library/Application Support/TextMate/Managed");
	if(!path::exists(dest))
	{
		if(NSString* archive = [[NSBundle mainBundle] pathForResource:@"DefaultBundles" ofType:@"tbz"])
		{
			path::make_dir(dest);

			network::tbz_t tbz(dest);
			if(tbz)
			{
				int fd = open([archive fileSystemRepresentation], O_RDONLY|O_CLOEXEC);
				if(fd != -1)
				{
					char buf[4096];
					ssize_t len;
					while((len = read(fd, buf, sizeof(buf))) > 0)
					{
						if(write(tbz.input_fd(), buf, len) != len)
						{
							os_log_error(OS_LOG_DEFAULT, "无法将字节写入tar");
							break;
						}
					}
					close(fd);
				}

				std::string output, error;
				if(!tbz.wait_for_tbz(&output, &error))
					os_log_error(OS_LOG_DEFAULT, "tar: %{public}s%{public}s", output.c_str(), error.c_str());
			}
			else
			{
				os_log_error(OS_LOG_DEFAULT, "无法启动tar");
			}
		}
		else
		{
			os_log_error(OS_LOG_DEFAULT, "No ‘DefaultBundles.tbz’ in TextMate.app");
		}
	}
	[BundlesManager.sharedInstance loadBundlesIndex];

	if(BOOL restoreSession = ![NSUserDefaults.standardUserDefaults boolForKey:kUserDefaultsDisableSessionRestoreKey])
	{
		std::string const prematureTerminationDuringRestore = path::join(path::temp(), "textmate_session_restore");

		NSString* promptUser = nil;
		if(path::exists(prematureTerminationDuringRestore))
			promptUser = @"先前尝试恢复会话导致异常退出。您想跳过会话恢复吗？";
		else if([NSEvent modifierFlags] & NSEventModifierFlagShift)
			promptUser = @"按住 shift (⇧) 表示您希望禁用恢复上次会话中打开的文档。";

		if(promptUser)
		{
			NSAlert* alert        = [[NSAlert alloc] init];
			alert.messageText     = @"禁用会话恢复？";
			alert.informativeText = promptUser;
			[alert addButtons:@"还原文件", @"停用", nil];
			if([alert runModal] == NSAlertSecondButtonReturn) // "Disable"
				restoreSession = NO;
		}

		if(restoreSession)
		{
			close(open(prematureTerminationDuringRestore.c_str(), O_CREAT|O_TRUNC|O_WRONLY|O_CLOEXEC));
			[DocumentWindowController restoreSession];
		}
		unlink(prematureTerminationDuringRestore.c_str());
	}
}

- (BOOL)applicationShouldOpenUntitledFile:(NSApplication*)anApplication
{
	return self.didFinishLaunching;
}

- (void)applicationDidFinishLaunching:(NSNotification*)aNotification
{
	NSWindow.allowsAutomaticWindowTabbing = NO;

	if([NSApp respondsToSelector:@selector(setAutomaticCustomizeTouchBarMenuItemEnabled)]) // MAC_OS_X_VERSION_10_12_1
		NSApp.automaticCustomizeTouchBarMenuItemEnabled = YES;

	if(!HasDocumentWindow([NSApp orderedWindows]))
	{
		BOOL disableUntitledAtStartupPrefs = [NSUserDefaults.standardUserDefaults boolForKey:kUserDefaultsDisableNewDocumentAtStartupKey];
		BOOL showFavoritesInsteadPrefs     = [NSUserDefaults.standardUserDefaults boolForKey:kUserDefaultsShowFavoritesInsteadOfUntitledKey];

		if(showFavoritesInsteadPrefs)
			[self openFavorites:self];
		else if(!disableUntitledAtStartupPrefs)
			[self newDocument:self];
	}

	[self userDefaultsDidChange:nil]; // setup mate/rmate server
	OakObserveUserDefaults(self);

	NSMenu* selectMenu = [[[[[NSApp mainMenu] itemWithTitle:@"编辑"] submenu] itemWithTitle:@"选择"] submenu];
	[[selectMenu itemWithTitle:@"切换列选择"] setActivationString:@"⌥" withFont:nil];

	[AboutWindowController showChangesIfUpdated];

	[CrashReporter.sharedInstance applicationDidFinishLaunching:aNotification];
	[CrashReporter.sharedInstance postNewCrashReportsToURLString:[NSString stringWithFormat:@"%s/crashes", REST_API]];

	[OakCommitWindowServer sharedInstance]; // Setup server

	self.didFinishLaunching = YES;
}

- (void)applicationWillResignActive:(NSNotification*)aNotification
{
	scm::disable();
}

- (void)applicationWillBecomeActive:(NSNotification*)aNotification
{
	scm::enable();
}

- (void)applicationDidResignActive:(NSNotification*)aNotification
{
	// If the window to activate, when switching back to TextMate, has “Move to
	// Active Space” set, then the system will move this window to the current
	// space. This is not what we want for auxillary windows like the Find dialog
	// or HTML output, as these windows are tied to a document window.
	//
	// Starting with macOS 10.11 we have to change collection behavior after the
	// current event loop cycle, both when receiving the did become and did resign
	// active notification.

	dispatch_async(dispatch_get_main_queue(), ^{
		NSMutableArray* changedWindows = [NSMutableArray array];
		for(NSWindow* window in NSApp.windows)
		{
			if((window.collectionBehavior & (NSWindowCollectionBehaviorMoveToActiveSpace|NSWindowCollectionBehaviorFullScreenAuxiliary)) == (NSWindowCollectionBehaviorMoveToActiveSpace|NSWindowCollectionBehaviorFullScreenAuxiliary))
			{
				window.collectionBehavior &= ~NSWindowCollectionBehaviorMoveToActiveSpace;
				[changedWindows addObject:window];
			}
		}

		if(changedWindows.count)
		{
			__weak __block id token = [NSNotificationCenter.defaultCenter addObserverForName:NSApplicationDidBecomeActiveNotification object:NSApp queue:nil usingBlock:^(NSNotification*){
				[NSNotificationCenter.defaultCenter removeObserver:token];
				dispatch_async(dispatch_get_main_queue(), ^{
					for(NSWindow* window in changedWindows)
						window.collectionBehavior |= NSWindowCollectionBehaviorMoveToActiveSpace;
				});
			}];
		}
	});
}

// =========================
// = Past Startup Delegate =
// =========================

- (IBAction)newDocumentAndActivate:(id)sender
{
	[NSApp activateIgnoringOtherApps:YES];
	[self newDocument:sender];
}

- (IBAction)openDocumentAndActivate:(id)sender
{
	[NSApp activateIgnoringOtherApps:YES];
	[self openDocument:sender];
}

- (IBAction)orderFrontAboutPanel:(id)sender
{
	[AboutWindowController.sharedInstance showAboutWindow:self];
}

- (IBAction)orderFrontFindPanel:(id)sender
{
	Find* find = Find.sharedInstance;
	NSInteger mode = [sender respondsToSelector:@selector(tag)] ? [sender tag] : FFSearchTargetDocument;
	switch(mode)
	{
		case FFSearchTargetDocument:  find.searchTarget = FFSearchTargetDocument;  break;
		case FFSearchTargetSelection: find.searchTarget = FFSearchTargetSelection; break;
		case FFSearchTargetProject:   find.searchTarget = FFSearchTargetProject;   break;
		case FFSearchTargetOther:     return [find showFolderSelectionPanel:self]; break;
	}
	[find showWindow:self];
}

- (IBAction)orderFrontGoToLinePanel:(id)sender;
{
	if(id textView = [NSApp targetForAction:@selector(selectionString)])
		[goToLineTextField setStringValue:[textView selectionString]];
	[goToLinePanel makeKeyAndOrderFront:self];
}

- (IBAction)performGoToLine:(id)sender
{
	[goToLinePanel orderOut:self];
	[NSApp sendAction:@selector(selectAndCenter:) to:nil from:[goToLineTextField stringValue]];
}

- (IBAction)performSoftwareUpdateCheck:(id)sender
{
	[SoftwareUpdate.sharedInstance checkForUpdate:self];
}

- (IBAction)showPreferences:(id)sender
{
	[Preferences.sharedInstance showWindow:self];
}

- (IBAction)showBundleEditor:(id)sender
{
	[BundleEditor.sharedInstance showWindow:self];
}

- (IBAction)openFavorites:(id)sender
{
	FavoriteChooser* chooser = FavoriteChooser.sharedInstance;
	chooser.action = @selector(didSelectFavorite:);
	[chooser showWindow:self];
}

- (void)didSelectFavorite:(id)sender
{
	NSMutableArray* paths = [NSMutableArray array];
	for(id item in [sender selectedItems])
		[paths addObject:[item valueForKey:@"path"]];
	OakOpenDocuments(paths, YES);
}

// =======================
// = Bundle Item Chooser =
// =======================

- (IBAction)showBundleItemChooser:(id)sender
{
	BundleItemChooser* chooser = BundleItemChooser.sharedInstance;
	chooser.action     = @selector(bundleItemChooserDidSelectItems:);
	chooser.editAction = @selector(editBundleItem:);

	OakTextView* textView = [NSApp targetForAction:@selector(scopeContext)];
	chooser.scope        = textView ? [textView scopeContext] : scope::wildcard;
	chooser.hasSelection = [textView hasSelection];

	if(DocumentWindowController* controller = [NSApp targetForAction:@selector(selectedDocument)])
	{
		OakDocument* doc = controller.selectedDocument;
		chooser.path      = doc.path;
		chooser.directory = [doc.path stringByDeletingLastPathComponent] ?: doc.directory;
	}
	else
	{
		chooser.path      = nil;
		chooser.directory = nil;
	}

	[chooser showWindowRelativeToFrame:textView.window ? [textView.window convertRectToScreen:[textView convertRect:[textView visibleRect] toView:nil]] : [[NSScreen mainScreen] visibleFrame]];
}

- (void)bundleItemChooserDidSelectItems:(id)sender
{
	for(id item in [sender selectedItems])
		[NSApp sendAction:@selector(performBundleItemWithUUIDStringFrom:) to:nil from:@{ @"representedObject": [item valueForKey:@"uuid"] }];
}

// ===========================
// = Find options menu items =
// ===========================

- (IBAction)toggleFindOption:(id)sender
{
	[Find.sharedInstance takeFindOptionToToggleFrom:sender];
}

- (BOOL)validateMenuItem:(NSMenuItem*)item
{
	BOOL enabled = YES;
	if([item action] == @selector(toggleFindOption:))
	{
		BOOL active = NO;
		if(OakPasteboardEntry* entry = [OakPasteboard.findPasteboard current])
		{
			switch([item tag])
			{
				case find::ignore_case:        active = [NSUserDefaults.standardUserDefaults boolForKey:kUserDefaultsFindIgnoreCase]; break;
				case find::regular_expression: active = [entry regularExpression]; break;
				case find::full_words:         active = [entry fullWordMatch];     enabled = ![entry regularExpression]; break;
				case find::ignore_whitespace:  active = [entry ignoreWhitespace];  enabled = ![entry regularExpression]; break;
				case find::wrap_around:        active = [NSUserDefaults.standardUserDefaults boolForKey:kUserDefaultsFindWrapAround]; break;
			}
			[item setState:(active ? NSControlStateValueOn : NSControlStateValueOff)];
		}
		else
		{
			enabled = NO;
		}
	}
	else if([item action] == @selector(orderFrontGoToLinePanel:))
	{
		enabled = [NSApp targetForAction:@selector(setSelectionString:)] != nil;
	}
	else if([item action] == @selector(performBundleItemWithUUIDStringFrom:))
	{
		id menuItemValidator = [NSApp.keyWindow.delegate respondsToSelector:@selector(performBundleItem:)] ? NSApp.keyWindow.delegate : [NSApp targetForAction:@selector(performBundleItem:)];
		if(menuItemValidator != self && [menuItemValidator respondsToSelector:@selector(validateMenuItem:)])
			enabled = [menuItemValidator validateMenuItem:item];
	}
	else
	{
		enabled = [self validateThemeMenuItem:item];
	}
	return enabled;
}

- (void)editBundleItem:(id)sender
{
	ASSERT([sender respondsToSelector:@selector(selectedItems)]);
	ASSERT([[sender selectedItems] count] == 1);

	if(NSString* uuid = [[[sender selectedItems] lastObject] valueForKey:@"uuid"])
	{
		[BundleEditor.sharedInstance revealBundleItem:bundles::lookup(to_s(uuid))];
	}
	else if(NSString* path = [[[sender selectedItems] lastObject] valueForKey:@"file"])
	{
		OakDocument* doc = [OakDocumentController.sharedInstance documentWithPath:path];
		NSString* line = [[[sender selectedItems] lastObject] valueForKey:@"line"];
		[OakDocumentController.sharedInstance showDocument:doc andSelect:(line ? text::pos_t(to_s(line)) : text::pos_t::undefined) inProject:nil bringToFront:YES];
	}
}

- (void)editBundleItemWithUUIDString:(NSString*)uuidString
{
	[BundleEditor.sharedInstance revealBundleItem:bundles::lookup(to_s(uuidString))];
}

// ============
// = Printing =
// ============

- (IBAction)runPageLayout:(id)sender
{
	[[NSPageLayout pageLayout] runModal];
}
@end
