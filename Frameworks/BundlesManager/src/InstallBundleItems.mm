#import "InstallBundleItems.h"
#import "BundlesManager.h"
#import <OakAppKit/NSAlert Additions.h>
#import <OakFoundation/NSString Additions.h>
#import <bundles/bundles.h>
#import <text/ctype.h>
#import <regexp/format_string.h>
#import <io/io.h>
#import <ns/ns.h>

static std::map<std::string, bundles::item_ptr> installed_items ()
{
	std::map<std::string, bundles::item_ptr> res;
	for(auto const& item : bundles::query(bundles::kFieldAny, NULL_STR, scope::wildcard, bundles::kItemTypeAny, oak::uuid_t(), false, true))
	{
		for(auto const& path : item->paths())
			res.emplace(path, item);
	}
	return res;
}

void InstallBundleItems (NSArray* itemPaths)
{
	struct info_t
	{
		info_t (std::string const& path, std::string const& name, oak::uuid_t const& uuid, bool isBundle, bundles::item_ptr installed = bundles::item_ptr()) : path(path), name(name), uuid(uuid), is_bundle(isBundle), installed(installed) { }

		std::string path;
		std::string name;
		oak::uuid_t uuid;
		bool is_bundle;
		bundles::item_ptr installed;
	};

	std::map<std::string, bundles::item_ptr> const installedItems = installed_items();
	std::vector<info_t> installed, toInstall, delta, malformed;

	for(NSString* path in itemPaths)
	{
		bool isDelta;
		std::string bundleName;
		oak::uuid_t bundleUUID;
		bundles::item_ptr installedItem;

		bool isBundle                       = [[[path pathExtension] lowercaseString] isEqualToString:@"tmbundle"];
		std::string const loadPath          = isBundle ? path::join(to_s(path), "info.plist") : to_s(path);
		plist::dictionary_t const infoPlist = plist::load(loadPath);

		auto it = installedItems.find(loadPath);
		if(it != installedItems.end())
			installedItem = it->second;

		if(plist::get_key_path(infoPlist, "isDelta", isDelta) && isDelta)
		{
			delta.push_back(info_t(to_s(path), NULL_STR, oak::uuid_t(), isBundle, installedItem));
		}
		else if(plist::get_key_path(infoPlist, "name", bundleName) && plist::get_key_path(infoPlist, "uuid", bundleUUID))
		{
			if(installedItem)
					installed.push_back(info_t(to_s(path), bundleName, bundleUUID, isBundle, installedItem));
			else	toInstall.push_back(info_t(to_s(path), bundleName, bundleUUID, isBundle, installedItem));
		}
		else
		{
			malformed.push_back(info_t(to_s(path), NULL_STR, oak::uuid_t(), isBundle, installedItem));
		}
	}

	for(auto const& info : delta)
	{
		char const* type = info.is_bundle ? "bundle" : "bundle item";
		std::string const name = path::name(path::strip_extension(info.path));
		std::string const title = text::format("%s “%s”无法安装，因为是增量格式。", type, name.c_str());

		NSAlert* alert        = [[NSAlert alloc] init];
		alert.messageText     = [NSString stringWithCxxString:title];
		alert.informativeText = [NSString stringWithFormat:@"请联系插件%s的作者以获取正确的道出版本", type];
		[alert addButtonWithTitle:@"好"];
		[alert runModal];
	}

	for(auto const& info : malformed)
	{
		char const* type = info.is_bundle ? "bundle" : "bundle item";
		std::string const name = path::name(path::strip_extension(info.path));
		std::string const title = text::format("%s “%s”无法安装，因为格式不正确", type, name.c_str());

		NSAlert* alert        = [[NSAlert alloc] init];
		alert.messageText     = [NSString stringWithCxxString:title];
		alert.informativeText = [NSString stringWithFormat:@"%s属性列表文件中缺少强制键", type];
		[alert addButtonWithTitle:@"好"];
		[alert runModal];
	}

	for(auto const& info : installed)
	{
		char const* type = info.is_bundle ? "bundle" : "bundle item";
		std::string const name = info.name;
		std::string const title = text::format("%s “%s”已经安装", type, name.c_str());

		NSAlert* alert        = [[NSAlert alloc] init];
		alert.messageText     = [NSString stringWithCxxString:title];
		alert.informativeText = [NSString stringWithFormat:@"您可以编辑已安装的%s以检测它", type];
		[alert addButtons:@"好", @"编辑", nil];
		if([alert runModal] == NSAlertSecondButtonReturn) // "Edit"
			[NSApp sendAction:@selector(editBundleItemWithUUIDString:) to:nil from:[NSString stringWithCxxString:info.uuid]];
	}

	std::set<std::string> pathsToReload;
	for(auto const& info : toInstall)
	{
		if(info.is_bundle)
		{
			NSAlert* alert        = [[NSAlert alloc] init];
			alert.messageText     = [NSString stringWithFormat:@"您要安装“%@”插件吗?", [NSString stringWithCxxString:info.name]];
			alert.informativeText = @"安装插件会为文本编辑增加新功能";
			[alert addButtons:@"安装", @"取消", nil];
			if([alert runModal] == NSAlertFirstButtonReturn) // "Install"
			{
				std::string const installDir = path::join(path::home(), "Library/Application Support/TextMate/Pristine Copy/Bundles");
				if(path::make_dir(installDir))
				{
					std::string const installPath = path::unique(path::join(installDir, path::name(info.path)));
					if(path::copy(info.path, installPath))
					{
						pathsToReload.insert(installDir);
						os_log(OS_LOG_DEFAULT, "安装插件在: %{public}s", installPath.c_str());
						continue;
					}
				}
				os_log_error(OS_LOG_DEFAULT, "安装插件失败: %{public}s", info.path.c_str());
			}
		}
		else
		{
			bundles::item_ptr bundle;
			if([BundlesManager.sharedInstance findBundleForInstall:&bundle])
			{
				static struct { std::string extension; std::string directory; } DirectoryMap[] =
				{
					{ ".tmCommand",     "Commands"     },
					{ ".tmDragCommand", "DragCommands" },
					{ ".tmMacro",       "Macros"       },
					{ ".tmPreferences", "Preferences"  },
					{ ".tmSnippet",     "Snippets"     },
					{ ".tmLanguage",    "Syntaxes"     },
					{ ".tmProxy",       "Proxies"      },
					{ ".tmTheme",       "Themes"       },
				};

				if(bundle->local() || bundle->save())
				{
					std::string dest = path::parent(bundle->paths().front());
					for(auto const& iter : DirectoryMap)
					{
						if(path::extension(info.path) == iter.extension)
						{
							dest = path::join(dest, iter.directory);
							if(path::make_dir(dest))
							{
								dest = path::join(dest, path::name(info.path));
								pathsToReload.insert(dest);
								dest = path::unique(dest);
								if(path::copy(info.path, dest))
										break;
								else	os_log_error(OS_LOG_DEFAULT, "error: copy(‘%{public}s’, ‘%{public}s’)", info.path.c_str(), dest.c_str());
							}
							else
							{
								os_log_error(OS_LOG_DEFAULT, "error: makedir(‘%{public}s’)", dest.c_str());
							}
						}
					}
				}
			}
		}
	}

	for(auto path : pathsToReload)
		[BundlesManager.sharedInstance reloadPath:[NSString stringWithCxxString:path]];
}
