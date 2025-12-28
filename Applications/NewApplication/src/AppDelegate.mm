#import "AppDelegate.h"
#import "WindowController.h"
#import <MenuBuilder/MenuBuilder.h>

@interface AppDelegate () <NSApplicationDelegate, NSWindowDelegate>
@property (nonatomic) NSWindow* window;
@end

@implementation AppDelegate
- (void)applicationWillFinishLaunching:(NSNotification*)aNotification
{
	MBMenu const items = {
		{ @"文本编辑",
			.submenu = {
				{ @"关于文本编辑", @selector(orderFrontStandardAboutPanel:)         },
				{ /* -------- */ },
				{ @"偏好设置…",         NULL,                                     @","   },
				{ /* -------- */ },
				{ @"服务", .systemMenu = MBMenuTypeServices                             },
				{ /* -------- */ },
				{ @"隐藏文本编辑",  @selector(hide:),                         @"h"   },
				{ @"隐藏其他",          @selector(hideOtherApplications:),        @"h", .modifierFlags = NSEventModifierFlagCommand|NSEventModifierFlagOption },
				{ @"显示全部",             @selector(unhideAllApplications:)                },
				{ /* -------- */ },
				{ @"退出文本编辑",  @selector(terminate:),                    @"q"   },
			}
		},
		{ @"File",
			.submenu = {
				{ @"文件",             @selector(newDocument:),           @"n"   },
				{ @"打开…",           @selector(openDocument:),          @"o"   },
				{ @"打开最近",
					.systemMenu = MBMenuTypeOpenRecent, .submenu = {
						{ @"清除历史", @selector(clearRecentDocuments:) },
					}
				},
				{ /* -------- */ },
				{ @"关闭",           @selector(performClose:),          @"w"   },
				{ @"关闭所有",       @selector(closeAll:),              @"w", .modifierFlags = NSEventModifierFlagCommand|NSEventModifierFlagOption, .target = NSApp, .alternate = YES },
				{ @"保存…",           @selector(saveDocument:),          @"s"   },
				{ @"另存为…",        @selector(saveDocumentAs:),        @"S"   },
				{ @"恢复到已保存", @selector(revertDocumentToSaved:), @"r"   },
				{ /* -------- */ },
				{ @"页面设置…",     @selector(runPageLayout:),         @"P"   },
				{ @"打印…",          @selector(print:),                 @"p"   },
			}
		},
		{ @"编辑",
			.submenu = {
				{ @"撤销",                  @selector(undo:),             @"z"   },
				{ @"重做",                  @selector(redo:),             @"Z"   },
				{ /* -------- */ },
				{ @"剪切",                   @selector(cut:),              @"x"   },
				{ @"复制",                  @selector(copy:),             @"c"   },
				{ @"粘贴",                 @selector(paste:),            @"v"   },
				{ @"粘贴并匹配样式", @selector(pasteAsPlainText:), @"V", .modifierFlags = NSEventModifierFlagCommand|NSEventModifierFlagOption },
				{ @"删除",                @selector(delete:)                   },
				{ @"全选",            @selector(selectAll:),        @"a"   },
				{ /* -------- */ },
				{ @"查找",
					.submenu = {
						{ @"查找…",                  @selector(performTextFinderAction:),      @"f",                                                                        .tag = NSTextFinderActionShowFindInterface    },
						{ @"查找和替换…",      @selector(performTextFinderAction:),      @"f", .modifierFlags = NSEventModifierFlagCommand|NSEventModifierFlagOption, .tag = NSTextFinderActionShowReplaceInterface },
						{ @"查找下一个",              @selector(performTextFinderAction:),      @"g",                                                                        .tag = NSTextFinderActionNextMatch            },
						{ @"查找上一个",          @selector(performTextFinderAction:),      @"G",                                                                        .tag = NSTextFinderActionPreviousMatch        },
						{ @"使用已选择进行查找", @selector(performTextFinderAction:),      @"e",                                                                        .tag = NSTextFinderActionSetSearchString      },
						{ @"跳转到已选择",      @selector(centerSelectionInVisibleArea:), @"j"   },
					}
				},
				{ @"拼写和语法",
					.submenu = {
						{ @"显示拼写和语法",      @selector(showGuessPanel:),                  @":" },
						{ @"立即检查文本",             @selector(checkSpelling:),                   @";" },
						{ /* -------- */ },
						{ @"打字时检查拼写",    @selector(toggleContinuousSpellChecking:)         },
						{ @"拼写时检查语法",    @selector(toggleGrammarChecking:)                 },
						{ @"自动更正拼写", @selector(toggleAutomaticSpellingCorrection:)     },
					}
				},
				{ @"替换",
					.submenu = {
						{ @"显示替换", @selector(orderFrontSubstitutionsPanel:)     },
						{ /* -------- */ },
						{ @"智能复制/粘贴",   @selector(toggleSmartInsertDelete:)          },
						{ @"智能引号",       @selector(toggleAutomaticQuoteSubstitution:) },
						{ @"智能破折号",       @selector(toggleAutomaticDashSubstitution:)  },
						{ @"智能链接",        @selector(toggleAutomaticLinkDetection:)     },
						{ @"数据检查器",     @selector(toggleAutomaticDataDetection:)     },
						{ @"文本替换",   @selector(toggleAutomaticTextReplacement:)   },
					}
				},
				{ @"转换",
					.submenu = {
						{ @"转为大写", @selector(uppercaseWord:)  },
						{ @"转为小写", @selector(lowercaseWord:)  },
						{ @"转为首字母大写",      @selector(capitalizeWord:) },
					}
				},
				{ @"语音",
					.submenu = {
						{ @"开始朗读", @selector(startSpeaking:) },
						{ @"停止朗读",  @selector(stopSpeaking:)  },
					}
				},
			}
		},
		{ @"格式",
			.submenu = {
				{ @"字体",
					.systemMenu = MBMenuTypeFont, .submenu = {
						{ @"显示字体",  @selector(orderFrontFontPanel:),  @"t",                              .target = NSFontManager.sharedFontManager },
						{ @"粗体",        @selector(addFontTrait:),         @"b", .tag = NSBoldFontMask ,      .target = NSFontManager.sharedFontManager },
						{ @"斜体",      @selector(addFontTrait:),         @"i", .tag = NSItalicFontMask ,    .target = NSFontManager.sharedFontManager },
						{ @"下划线",   @selector(underline:),            @"u"   },
						{ /* -------- */ },
						{ @"放大",      @selector(modifyFont:),           @"+", .tag = NSSizeUpFontAction,   .target = NSFontManager.sharedFontManager },
						{ @"缩小",     @selector(modifyFont:),           @"-", .tag = NSSizeDownFontAction, .target = NSFontManager.sharedFontManager },
						{ /* -------- */ },
						{ @"自距调整",
							.submenu = {
								{ @"默认", @selector(useStandardKerning:) },
								{ @"都不使用",    @selector(turnOffKerning:)     },
								{ @"紧排",     @selector(tightenKerning:)     },
								{ @"松排",      @selector(loosenKerning:)      },
							}
						},
						{ @"连字",
							.submenu = {
								{ @"使用默认", @selector(useStandardLigatures:) },
								{ @"都不使用",    @selector(turnOffLigatures:)     },
								{ @"全部使用",     @selector(useAllLigatures:)      },
							}
						},
						{ @"基线",
							.submenu = {
								{ @"使用默认", @selector(unscript:)      },
								{ @"上标", @selector(superscript:)   },
								{ @"下标",   @selector(subscript:)     },
								{ @"升高",       @selector(raiseBaseline:) },
								{ @"降低",       @selector(lowerBaseline:) },
							}
						},
						{ /* -------- */ },
						{ @"显示颜色", @selector(orderFrontColorPanel:), @"C"   },
						{ /* -------- */ },
						{ @"复制样式",  @selector(copyFont:),             @"c", .modifierFlags = NSEventModifierFlagCommand|NSEventModifierFlagOption },
						{ @"粘贴样式", @selector(pasteFont:),            @"v", .modifierFlags = NSEventModifierFlagCommand|NSEventModifierFlagOption },
					}
				},
				{ @"文本",
					.submenu = {
						{ @"左对齐",  @selector(alignLeft:),    @"{"   },
						{ @"居中",      @selector(alignCenter:),  @"|"   },
						{ @"两端对齐",     @selector(alignJustified:)       },
						{ @"右对齐", @selector(alignRight:),   @"}"   },
						{ /* -------- */ },
						{ @"书写方向",
							.submenu = {
								{ @"段落",                                                      .enabled = NO },
								{ @"默认",       @selector(makeBaseWritingDirectionNatural:),     .indent = 1 },
								{ @"从左到右", @selector(makeBaseWritingDirectionLeftToRight:), .indent = 1 },
								{ @"从右到左", @selector(makeBaseWritingDirectionRightToLeft:), .indent = 1 },
								{ /* -------- */ },
								{ @"所选内容",                                                      .enabled = NO },
								{ @"默认",       @selector(makeTextWritingDirectionNatural:),     .indent = 1 },
								{ @"从左到右", @selector(makeTextWritingDirectionLeftToRight:), .indent = 1 },
								{ @"从右到左", @selector(makeTextWritingDirectionRightToLeft:), .indent = 1 },
							}
						},
						{ /* -------- */ },
						{ @"显示标尺",  @selector(toggleRuler:)          },
						{ @"复制标尺",  @selector(copyRuler:),    @"c", .modifierFlags = NSEventModifierFlagCommand|NSEventModifierFlagControl },
						{ @"粘贴标尺", @selector(pasteRuler:),   @"v", .modifierFlags = NSEventModifierFlagCommand|NSEventModifierFlagControl },
					}
				},
			}
		},
		{ @"显示",
			.submenu = {
				{ @"显示工具栏",         @selector(toggleToolbarShown:),           @"t", .modifierFlags = NSEventModifierFlagCommand|NSEventModifierFlagOption },
				{ @"自定义工具栏…",   @selector(runToolbarCustomizationPalette:)     },
				{ /* -------- */ },
				{ @"显示侧边栏",         @selector(toggleSourceList:),             @"s", .modifierFlags = NSEventModifierFlagCommand|NSEventModifierFlagControl },
				{ @"进入全屏幕",    @selector(toggleFullScreen:),             @"f", .modifierFlags = NSEventModifierFlagCommand|NSEventModifierFlagControl },
				{ /* -------- */ },
				{ @"自定义触控栏…", @selector(toggleTouchBarCustomizationPalette:) },
			}
		},
		{ @"窗口",
			.systemMenu = MBMenuTypeWindows, .submenu = {
				{ @"最小化",           @selector(performMiniaturize:), @"m" },
				{ @"缩放",               @selector(performZoom:)              },
				{ /* -------- */ },
				{ @"前置全部窗口", @selector(arrangeInFront:)           },
			}
		},
		{ @"帮助",
			.systemMenu = MBMenuTypeHelp, .submenu = {
				{ @"文本编辑帮助", @selector(showHelp:), @"?" },
			}
		},
	};

	if(NSMenu* menu = MBCreateMenu(items))
		NSApp.mainMenu = menu;
}

- (void)applicationDidFinishLaunching:(NSNotification*)aNotification
{
	WindowController* windowController = [[WindowController alloc] init];
	[windowController showWindow:self];
}
@end
