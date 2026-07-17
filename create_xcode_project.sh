#!/bin/bash
# 生成 FileConverter.xcodeproj
# 用法：./create_xcode_project.sh

set -e
cd "$(dirname "$0")"

PROJ_DIR="FileConverter.xcodeproj"
mkdir -p "$PROJ_DIR"

# 获取当前绝对路径
PROJECT_DIR="$(pwd)"

# 生成 UUID
uuid() {
    uuidgen | tr '[:upper:]' '[:lower:]' | tr -d '-' | cut -c1-24
}

# 生成所有需要的 UUID
PBX_PROJ=$(uuid)
PBX_GROUP_MAIN=$(uuid)
PBX_GROUP_MODELS=$(uuid)
PBX_GROUP_SERVICES=$(uuid)
PBX_GROUP_PROTOCOLS=$(uuid)
PBX_GROUP_CONVERTERS=$(uuid)
PBX_GROUP_PROCESSRUNNERS=$(uuid)
PBX_GROUP_VIEWMODELS=$(uuid)
PBX_GROUP_VIEWS=$(uuid)
PBX_GROUP_SIDEBAR=$(uuid)
PBX_GROUP_MAINCONTENT=$(uuid)
PBX_GROUP_SETTINGS=$(uuid)
PBX_GROUP_COMPONENTS=$(uuid)
PBX_GROUP_BOTTOMBAR=$(uuid)
PBX_GROUP_UTILITIES=$(uuid)
PBX_GROUP_EXTENSIONS=$(uuid)
PBX_GROUP_RESOURCES=$(uuid)
PBX_GROUP_PRODUCTS=$(uuid)
PBX_NATIVE_TARGET=$(uuid)
PBX_SOURCES_PHASE=$(uuid)
PBX_FRAMEWORKS_PHASE=$(uuid)
PBX_RESOURCES_PHASE=$(uuid)
PBX_BUILD_CONFIG_DEBUG=$(uuid)
PBX_BUILD_CONFIG_RELEASE=$(uuid)
PBX_CONFIG_LIST_PROJ=$(uuid)
PBX_CONFIG_LIST_TARGET=$(uuid)
PBX_PRODUCT=$(uuid)
PBX_INFO_PLIST=$(uuid)

# 收集所有源文件
collect_sources() {
    local dir="$1"
    find "FileConverter/$dir" -name "*.swift" 2>/dev/null | while read f; do
        local file_uuid=$(uuid)
        local file_ref=$(uuid)
        local build_ref=$(uuid)
        echo "FILE|$f|$file_uuid|$file_ref|$build_ref"
    done
}

SOURCES=""
FILE_REFS=""
BUILD_FILES=""
FILE_GROUP_ENTRIES=""

add_source() {
    local f="$1"
    local file_uuid=$(uuid)
    local file_ref=$(uuid)
    local build_ref=$(uuid)
    local name=$(basename "$f")

    SOURCES="${SOURCES}
/* ${name} = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = \"${name}\"; sourceTree = \"<group>\"; }; */ ${file_ref}"
    BUILD_FILES="${BUILD_FILES}
/* ${name} in Sources = {isa = PBXBuildFile; fileRef = ${file_ref}; }; */ ${build_ref}"
    echo "${build_ref}"
}

# Collect all files
echo "正在扫描源文件..."

build_refs=""
for f in $(find FileConverter -name "*.swift" | sort); do
    ref=$(add_source "$f")
    build_refs="$build_refs $ref"
done

echo "找到 $(echo $build_refs | wc -w) 个 Swift 源文件"

# Write project.pbxproj
cat > "$PROJ_DIR/project.pbxproj" << 'PBXEOF'
// !$*UTF8*$!
{
	archiveVersion = 1;
	classes = {
	};
	objectVersion = 56;
	objects = {
PBXEOF

# 用实际内容填充
cat >> "$PROJ_DIR/project.pbxproj" << EOF

/* Begin PBXBuildFile section */
$(echo "$BUILD_FILES" | sed 's/^\/\*/*/')
/* End PBXBuildFile section */

/* Begin PBXFileReference section */
$(for f in $(find FileConverter -name "*.swift" | sort); do
    ref=$(uuid)
    name=$(basename "$f")
    echo "        ${ref} /* ${name} = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = \"${name}\"; sourceTree = \"<group>\"; }; */,"
done)
        ${PBX_PRODUCT} /* FileConverter.app = {isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = FileConverter.app; sourceTree = BUILT_PRODUCTS_DIR; }; */
/* End PBXFileReference section */

/* Begin PBXFrameworksBuildPhase section */
        ${PBX_FRAMEWORKS_PHASE} /* Frameworks = {
            isa = PBXFrameworksBuildPhase;
            buildActionMask = 2147483647;
            files = ();
            runOnlyForDeploymentPostprocessing = 0;
        }; */
/* End PBXFrameworksBuildPhase section */

/* Begin PBXGroup section */
        ${PBX_GROUP_MAIN} /* = {
            isa = PBXGroup;
            children = (
                $(for f in $(find FileConverter -maxdepth 1 -name "*.swift" | sort); do
                    ref=$(uuid)
                    name=$(basename "$f")
                    echo "                ${ref} /* ${name} */,"
                done)
                ${PBX_GROUP_MODELS} /* Models */,
                ${PBX_GROUP_SERVICES} /* Services */,
                ${PBX_GROUP_VIEWMODELS} /* ViewModels */,
                ${PBX_GROUP_VIEWS} /* Views */,
                ${PBX_GROUP_UTILITIES} /* Utilities */,
                ${PBX_GROUP_RESOURCES} /* Resources */,
            );
            sourceTree = "<group>";
        }; */
        ${PBX_GROUP_MODELS} /* Models = {
            isa = PBXGroup;
            children = (
                $(for f in $(find FileConverter/Models -name "*.swift" | sort); do
                    ref=$(uuid)
                    name=$(basename "$f")
                    echo "                ${ref} /* ${name} */,"
                done)
            );
            path = Models;
            sourceTree = "<group>";
        }; */
        ${PBX_GROUP_SERVICES} /* Services = {
            isa = PBXGroup;
            children = (
                $(for f in $(find FileConverter/Services -maxdepth 1 -name "*.swift" | sort); do
                    ref=$(uuid)
                    name=$(basename "$f")
                    echo "                ${ref} /* ${name} */,"
                done)
                ${PBX_GROUP_PROTOCOLS} /* Protocols */,
                ${PBX_GROUP_CONVERTERS} /* Converters */,
                ${PBX_GROUP_PROCESSRUNNERS} /* ProcessRunners */,
            );
            path = Services;
            sourceTree = "<group>";
        }; */
        ${PBX_GROUP_PROTOCOLS} /* Protocols = {
            isa = PBXGroup;
            children = (
                $(for f in $(find FileConverter/Services/Protocols -name "*.swift" | sort); do
                    ref=$(uuid)
                    name=$(basename "$f")
                    echo "                ${ref} /* ${name} */,"
                done)
            );
            path = Protocols;
            sourceTree = "<group>";
        }; */
        ${PBX_GROUP_CONVERTERS} /* Converters = {
            isa = PBXGroup;
            children = (
                $(for f in $(find FileConverter/Services/Converters -name "*.swift" | sort); do
                    ref=$(uuid)
                    name=$(basename "$f")
                    echo "                ${ref} /* ${name} */,"
                done)
            );
            path = Converters;
            sourceTree = "<group>";
        }; */
        ${PBX_GROUP_PROCESSRUNNERS} /* ProcessRunners = {
            isa = PBXGroup;
            children = (
                $(for f in $(find FileConverter/Services/ProcessRunners -name "*.swift" | sort); do
                    ref=$(uuid)
                    name=$(basename "$f")
                    echo "                ${ref} /* ${name} */,"
                done)
            );
            path = ProcessRunners;
            sourceTree = "<group>";
        }; */
        ${PBX_GROUP_VIEWMODELS} /* ViewModels = {
            isa = PBXGroup;
            children = (
                $(for f in $(find FileConverter/ViewModels -name "*.swift" | sort); do
                    ref=$(uuid)
                    name=$(basename "$f")
                    echo "                ${ref} /* ${name} */,"
                done)
            );
            path = ViewModels;
            sourceTree = "<group>";
        }; */
        ${PBX_GROUP_VIEWS} /* Views = {
            isa = PBXGroup;
            children = (
                ${PBX_GROUP_SIDEBAR} /* Sidebar */,
                ${PBX_GROUP_MAINCONTENT} /* MainContent */,
                ${PBX_GROUP_SETTINGS} /* Settings */,
                ${PBX_GROUP_COMPONENTS} /* Components */,
                ${PBX_GROUP_BOTTOMBAR} /* BottomBar */,
            );
            path = Views;
            sourceTree = "<group>";
        }; */
        ${PBX_GROUP_SIDEBAR} /* Sidebar = {
            isa = PBXGroup;
            children = (
                $(for f in $(find FileConverter/Views/Sidebar -name "*.swift" | sort); do
                    ref=$(uuid)
                    name=$(basename "$f")
                    echo "                ${ref} /* ${name} */,"
                done)
            );
            path = Sidebar;
            sourceTree = "<group>";
        }; */
        ${PBX_GROUP_MAINCONTENT} /* MainContent = {
            isa = PBXGroup;
            children = (
                $(for f in $(find FileConverter/Views/MainContent -name "*.swift" | sort); do
                    ref=$(uuid)
                    name=$(basename "$f")
                    echo "                ${ref} /* ${name} */,"
                done)
            );
            path = MainContent;
            sourceTree = "<group>";
        }; */
        ${PBX_GROUP_SETTINGS} /* Settings = {
            isa = PBXGroup;
            children = (
                $(for f in $(find FileConverter/Views/Settings -name "*.swift" | sort); do
                    ref=$(uuid)
                    name=$(basename "$f")
                    echo "                ${ref} /* ${name} */,"
                done)
            );
            path = Settings;
            sourceTree = "<group>";
        }; */
        ${PBX_GROUP_COMPONENTS} /* Components = {
            isa = PBXGroup;
            children = (
                $(for f in $(find FileConverter/Views/Components -name "*.swift" | sort); do
                    ref=$(uuid)
                    name=$(basename "$f")
                    echo "                ${ref} /* ${name} */,"
                done)
            );
            path = Components;
            sourceTree = "<group>";
        }; */
        ${PBX_GROUP_BOTTOMBAR} /* BottomBar = {
            isa = PBXGroup;
            children = (
                $(for f in $(find FileConverter/Views/BottomBar -name "*.swift" | sort); do
                    ref=$(uuid)
                    name=$(basename "$f")
                    echo "                ${ref} /* ${name} */,"
                done)
            );
            path = BottomBar;
            sourceTree = "<group>";
        }; */
        ${PBX_GROUP_UTILITIES} /* Utilities = {
            isa = PBXGroup;
            children = (
                $(for f in $(find FileConverter/Utilities -maxdepth 1 -name "*.swift" | sort); do
                    ref=$(uuid)
                    name=$(basename "$f")
                    echo "                ${ref} /* ${name} */,"
                done)
                ${PBX_GROUP_EXTENSIONS} /* Extensions */,
            );
            path = Utilities;
            sourceTree = "<group>";
        }; */
        ${PBX_GROUP_EXTENSIONS} /* Extensions = {
            isa = PBXGroup;
            children = (
                $(for f in $(find FileConverter/Utilities/Extensions -name "*.swift" 2>/dev/null | sort); do
                    ref=$(uuid)
                    name=$(basename "$f")
                    echo "                ${ref} /* ${name} */,"
                done)
            );
            path = Extensions;
            sourceTree = "<group>";
        }; */
        ${PBX_GROUP_RESOURCES} /* Resources = {
            isa = PBXGroup;
            children = (
            );
            path = Resources;
            sourceTree = "<group>";
        }; */
        ${PBX_GROUP_PRODUCTS} /* Products = {
            isa = PBXGroup;
            children = (
                ${PBX_PRODUCT} /* FileConverter.app */,
            );
            name = Products;
            sourceTree = "<group>";
        }; */
        ${PBX_PROJ} /* Project object = {
            isa = PBXGroup;
            children = (
                ${PBX_GROUP_MAIN} /* FileConverter */,
                ${PBX_GROUP_PRODUCTS} /* Products */,
            );
            sourceTree = "<group>";
        }; */
/* End PBXGroup section */

/* Begin PBXNativeTarget section */
        ${PBX_NATIVE_TARGET} /* FileConverter = {
            isa = PBXNativeTarget;
            buildConfigurationList = ${PBX_CONFIG_LIST_TARGET} /* Build configuration list for FileConverter */;
            buildPhases = (
                ${PBX_SOURCES_PHASE} /* Sources */,
                ${PBX_FRAMEWORKS_PHASE} /* Frameworks */,
            );
            buildRules = ();
            dependencies = ();
            name = FileConverter;
            productName = FileConverter;
            productReference = ${PBX_PRODUCT} /* FileConverter.app */;
            productType = "com.apple.product-type.application";
        }; */
/* End PBXNativeTarget section */

/* Begin PBXProject section */
        ${PBX_PROJ} /* Project object = {
            isa = PBXProject;
            attributes = {
                BuildIndependentTargetsInParallel = 1;
                LastSwiftUpdateCheck = 1640;
                LastUpgradeCheck = 1640;
                ORGANIZATIONNAME = "";
                TargetAttributes = {
                    ${PBX_NATIVE_TARGET} = {
                        CreatedOnToolsVersion = 16.0;
                    };
                };
            };
            buildConfigurationList = ${PBX_CONFIG_LIST_PROJ} /* Build configuration list for project */;
            compatibilityVersion = "Xcode 14.0";
            developmentRegion = "zh-Hans";
            hasScannedForEncodings = 0;
            knownRegions = (
                en,
                "zh-Hans",
                Base,
            );
            mainGroup = ${PBX_PROJ};
            productRefGroup = ${PBX_GROUP_PRODUCTS} /* Products */;
            projectDirPath = "";
            projectRoot = "";
            targets = (
                ${PBX_NATIVE_TARGET} /* FileConverter */,
            );
        }; */
/* End PBXProject section */

/* Begin PBXSourcesBuildPhase section */
        ${PBX_SOURCES_PHASE} /* Sources = {
            isa = PBXSourcesBuildPhase;
            buildActionMask = 2147483647;
            files = (
$(for f in $(find FileConverter -name "*.swift" | sort); do
    ref=$(uuid)
    name=$(basename "$f")
    echo "                ${ref} /* ${name} in Sources */,"
done)
            );
            runOnlyForDeploymentPostprocessing = 0;
        }; */
/* End PBXSourcesBuildPhase section */

/* Begin XCBuildConfiguration section */
        ${PBX_BUILD_CONFIG_DEBUG} /* Debug = {
            isa = XCBuildConfiguration;
            buildSettings = {
                ALWAYS_SEARCH_USER_PATHS = NO;
                ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS = YES;
                CLANG_ANALYZER_NONNULL = YES;
                CLANG_CXX_LANGUAGE_STANDARD = "gnu++20";
                CLANG_ENABLE_MODULES = YES;
                CLANG_ENABLE_OBJC_ARC = YES;
                COPY_PHASE_STRIP = NO;
                DEBUG_INFORMATION_FORMAT = dwarf;
                ENABLE_STRICT_OBJC_MSGSEND = YES;
                ENABLE_TESTABILITY = YES;
                ENABLE_USER_SCRIPT_SANDBOXING = YES;
                GCC_DYNAMIC_NO_PIC = NO;
                GCC_OPTIMIZATION_LEVEL = 0;
                GCC_PREPROCESSOR_DEFINITIONS = (
                    "DEBUG=1",
                );
                INFOPLIST_FILE = "Resources/Info.plist";
                IPHONEOS_DEPLOYMENT_TARGET = 18.0;
                LD_RUNPATH_SEARCH_PATHS = (
                    "\$(inherited)",
                    "@executable_path/../Frameworks",
                );
                MACOSX_DEPLOYMENT_TARGET = 15.0;
                MTL_ENABLE_DEBUG_INFO = INCLUDE_SOURCE;
                ONLY_ACTIVE_ARCH = YES;
                PRODUCT_BUNDLE_IDENTIFIER = com.fileconverter.app;
                PRODUCT_NAME = FileConverter;
                SDKROOT = macosx;
                SWIFT_ACTIVE_COMPILATION_CONDITIONS = "DEBUG \$(inherited)";
                SWIFT_EMIT_LOC_STRINGS = YES;
                SWIFT_OPTIMIZATION_LEVEL = "-Onone";
                SWIFT_VERSION = 5.0;
            };
            name = Debug;
        }; */
        ${PBX_BUILD_CONFIG_RELEASE} /* Release = {
            isa = XCBuildConfiguration;
            buildSettings = {
                ALWAYS_SEARCH_USER_PATHS = NO;
                ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS = YES;
                CLANG_ANALYZER_NONNULL = YES;
                CLANG_CXX_LANGUAGE_STANDARD = "gnu++20";
                CLANG_ENABLE_MODULES = YES;
                CLANG_ENABLE_OBJC_ARC = YES;
                COPY_PHASE_STRIP = NO;
                DEBUG_INFORMATION_FORMAT = "dwarf-with-dsym";
                ENABLE_NS_ASSERTIONS = NO;
                ENABLE_STRICT_OBJC_MSGSEND = YES;
                ENABLE_USER_SCRIPT_SANDBOXING = YES;
                INFOPLIST_FILE = "Resources/Info.plist";
                LD_RUNPATH_SEARCH_PATHS = (
                    "\$(inherited)",
                    "@executable_path/../Frameworks",
                );
                MACOSX_DEPLOYMENT_TARGET = 15.0;
                MTL_ENABLE_DEBUG_INFO = NO;
                PRODUCT_BUNDLE_IDENTIFIER = com.fileconverter.app;
                PRODUCT_NAME = FileConverter;
                SDKROOT = macosx;
                SWIFT_COMPILATION_MODE = wholemodule;
                SWIFT_EMIT_LOC_STRINGS = YES;
                SWIFT_VERSION = 5.0;
            };
            name = Release;
        }; */
/* End XCBuildConfiguration section */

/* Begin XCConfigurationList section */
        ${PBX_CONFIG_LIST_PROJ} /* Build configuration list for project = {
            isa = XCConfigurationList;
            buildConfigurations = (
                ${PBX_BUILD_CONFIG_DEBUG} /* Debug */,
                ${PBX_BUILD_CONFIG_RELEASE} /* Release */,
            );
            defaultConfigurationIsVisible = 0;
            defaultConfigurationName = Release;
        }; */
        ${PBX_CONFIG_LIST_TARGET} /* Build configuration list for FileConverter = {
            isa = XCConfigurationList;
            buildConfigurations = (
                ${PBX_BUILD_CONFIG_DEBUG} /* Debug */,
                ${PBX_BUILD_CONFIG_RELEASE} /* Release */,
            );
            defaultConfigurationIsVisible = 0;
            defaultConfigurationName = Release;
        }; */
/* End XCConfigurationList section */

        rootObject = ${PBX_PROJ} /* Project object */;
    };
}
EOF

echo ""
echo "✅ Xcode 项目已生成：$PROJ_DIR"
echo ""
echo "现在可以在 Xcode 中打开项目："
echo "  open FileConverter.xcodeproj"
echo ""
echo "或者在终端运行："
echo "  xed ."
echo ""

# 尝试打开项目
if [[ "$1" == "--open" ]]; then
    open "$PROJ_DIR"
fi
