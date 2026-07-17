#!/usr/bin/env python3
"""基于 ClipboardHistory 模板生成 FileConverter.xcodeproj"""
import os, uuid, re

os.chdir(os.path.dirname(os.path.abspath(__file__)))

def mkid():
    """生成 Xcode 风格的 32 字符 hex UUID（无连字符）"""
    return uuid.uuid4().hex

def scan_files(base="FileConverter"):
    groups = {}
    for root, dirs, files in os.walk(base):
        sf = sorted([f for f in files if f.endswith(".swift")])
        if sf:
            rel = os.path.relpath(root, base)
            groups[rel] = sf
    return groups

def gen():
    groups = scan_files()

    # —— 固定 UUID ——
    PROJ_UUID     = mkid()
    MAIN_GRP      = mkid()
    PRODS_GRP     = mkid()
    TARGET_UUID   = mkid()
    SRC_PHASE     = mkid()
    FRM_PHASE     = mkid()
    PROD_REF      = mkid()
    DBG_CFG       = mkid()
    REL_CFG       = mkid()
    CFG_LIST_PROJ = mkid()
    CFG_LIST_TGT  = mkid()

    # —— 文件 UUID ——
    file_refs = {}   # rel_path -> ref_uuid
    build_refs = {}  # rel_path -> build_uuid
    for rel, flist in groups.items():
        for f in flist:
            rp = os.path.join(rel, f) if rel != "." else f
            file_refs[rp] = mkid()
            build_refs[rp] = mkid()

    # —— 目录 group UUID ——
    grp_ids = {".": MAIN_GRP}
    for rel in groups:
        if rel == ".": continue
        parts = rel.split("/")
        for i in range(len(parts)):
            fp = "/".join(parts[:i+1])
            if fp not in grp_ids:
                grp_ids[fp] = mkid()

    # —— 构建输出 ——
    # 使用和模板完全一样的格式：长行模式
    out = []
    def W(s): out.append(s)

    W("// !$*UTF8*$!")
    W("{")
    W("\tarchiveVersion = 1;")
    W("\tclasses = {")
    W("\t};")
    W("\tobjectVersion = 56;")
    W("\tobjects = {")
    W("")

    # PBXBuildFile — 每条一行
    W("/* Begin PBXBuildFile section */")
    for rp in sorted(build_refs):
        n = os.path.basename(rp)
        W(f'\t\t{build_refs[rp]} /* {n} in Sources */ = {{isa = PBXBuildFile; fileRef = {file_refs[rp]} /* {n} */; }};')
    W("/* End PBXBuildFile section */")
    W("")

    # PBXFileReference — 每条一行
    W("/* Begin PBXFileReference section */")
    for rp in sorted(file_refs):
        n = os.path.basename(rp)
        W(f'\t\t{file_refs[rp]} /* {n} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = "{n}"; sourceTree = "<group>"; }};')
    W(f'\t\t{PROD_REF} /* FileConverter.app */ = {{isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = FileConverter.app; sourceTree = BUILT_PRODUCTS_DIR; }};')
    W("/* End PBXFileReference section */")
    W("")

    # PBXFrameworksBuildPhase
    W("/* Begin PBXFrameworksBuildPhase section */")
    W(f'\t\t{FRM_PHASE} /* Frameworks */ = {{isa = PBXFrameworksBuildPhase; buildActionMask = 2147483647; files = (); runOnlyForDeploymentPostprocessing = 0; }};')
    W("/* End PBXFrameworksBuildPhase section */")
    W("")

    # PBXGroup — 构建树，每个 group 一行
    W("/* Begin PBXGroup section */")

    tree = {}
    for rel, flist in groups.items():
        if rel == ".":
            node = tree
        else:
            parts = rel.split("/")
            node = tree
            for p in parts:
                node = node.setdefault(p, {})
        node["__F__"] = flist

    def build_group(node, path_parts):
        fp = "/".join(path_parts) if path_parts else "."
        gid = grp_ids[fp]
        name = path_parts[-1] if path_parts else "FileConverter"

        # 收集子元素
        items = []
        for k, v in sorted(node.items()):
            if k == "__F__":
                for f in sorted(v):
                    rp = os.path.join(*path_parts, f) if path_parts else f
                    if rp in file_refs:
                        items.append((file_refs[rp], f))
            else:
                cid = build_group(v, path_parts + [k])
                items.append((cid, k))

        children = ", ".join(f'{uid} /* {lbl} */' for uid, lbl in items)
        if path_parts:
            W(f'\t\t{gid} /* {name} */ = {{isa = PBXGroup; children = ({children}); path = "{name}"; sourceTree = "<group>"; }};')
        else:
            W(f'\t\t{gid} /* {name} */ = {{isa = PBXGroup; children = ({children}); path = "FileConverter"; sourceTree = SOURCE_ROOT; }};')
        return gid

    build_group(tree, [])
    W(f'\t\t{PRODS_GRP} /* Products */ = {{isa = PBXGroup; children = ({PROD_REF} /* FileConverter.app */); name = Products; sourceTree = "<group>"; }};')
    W("/* End PBXGroup section */")
    W("")

    # PBXNativeTarget
    W("/* Begin PBXNativeTarget section */")
    W(f'\t\t{TARGET_UUID} /* FileConverter */ = {{isa = PBXNativeTarget; buildConfigurationList = {CFG_LIST_TGT}; buildPhases = ({SRC_PHASE} /* Sources */, {FRM_PHASE} /* Frameworks */); buildRules = (); dependencies = (); name = FileConverter; productName = FileConverter; productReference = {PROD_REF}; productType = "com.apple.product-type.application"; }};')
    W("/* End PBXNativeTarget section */")
    W("")

    # PBXProject
    W("/* Begin PBXProject section */")
    W(f'\t\t{PROJ_UUID} /* Project object */ = {{isa = PBXProject; attributes = {{BuildIndependentTargetsInParallel = 1; LastSwiftUpdateCheck = 1640; LastUpgradeCheck = 1640; TargetAttributes = {{{TARGET_UUID} = {{CreatedOnToolsVersion = 16.0; }}; }}; }}; buildConfigurationList = {CFG_LIST_PROJ}; compatibilityVersion = "Xcode 14.0"; developmentRegion = "zh-Hans"; hasScannedForEncodings = 0; knownRegions = (en, "zh-Hans", Base); mainGroup = {MAIN_GRP}; productRefGroup = {PRODS_GRP}; projectDirPath = ""; projectRoot = ""; targets = ({TARGET_UUID} /* FileConverter */); }};')
    W("/* End PBXProject section */")
    W("")

    # PBXSourcesBuildPhase
    W("/* Begin PBXSourcesBuildPhase section */")
    src_files = ", ".join(f'{build_refs[rp]} /* {os.path.basename(rp)} in Sources */' for rp in sorted(build_refs))
    W(f'\t\t{SRC_PHASE} /* Sources */ = {{isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = ({src_files}); runOnlyForDeploymentPostprocessing = 0; }};')
    W("/* End PBXSourcesBuildPhase section */")
    W("")

    # XCBuildConfiguration
    common = 'ALWAYS_SEARCH_USER_PATHS = NO; ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS = YES; CLANG_ANALYZER_NONNULL = YES; CLANG_CXX_LANGUAGE_STANDARD = "gnu++20"; CLANG_ENABLE_MODULES = YES; CLANG_ENABLE_OBJC_ARC = YES; ENABLE_STRICT_OBJC_MSGSEND = YES; ENABLE_USER_SCRIPT_SANDBOXING = NO; INFOPLIST_FILE = "Resources/Info.plist"; LD_RUNPATH_SEARCH_PATHS = ("$(inherited)", "@executable_path/../Frameworks"); MACOSX_DEPLOYMENT_TARGET = 15.0; PRODUCT_BUNDLE_IDENTIFIER = com.fileconverter.app; PRODUCT_NAME = "$(TARGET_NAME)"; SDKROOT = macosx; SWIFT_EMIT_LOC_STRINGS = YES; SWIFT_VERSION = 5.0;'

    W("/* Begin XCBuildConfiguration section */")
    W(f'\t\t{DBG_CFG} /* Debug */ = {{isa = XCBuildConfiguration; buildSettings = {{{common} COPY_PHASE_STRIP = NO; DEBUG_INFORMATION_FORMAT = dwarf; ENABLE_TESTABILITY = YES; GCC_DYNAMIC_NO_PIC = NO; GCC_OPTIMIZATION_LEVEL = 0; GCC_PREPROCESSOR_DEFINITIONS = ("DEBUG=1",); MTL_ENABLE_DEBUG_INFO = INCLUDE_SOURCE; ONLY_ACTIVE_ARCH = YES; SWIFT_ACTIVE_COMPILATION_CONDITIONS = "DEBUG $(inherited)"; SWIFT_OPTIMIZATION_LEVEL = "-Onone"; }}; name = Debug; }};')
    W(f'\t\t{REL_CFG} /* Release */ = {{isa = XCBuildConfiguration; buildSettings = {{{common} COPY_PHASE_STRIP = NO; DEBUG_INFORMATION_FORMAT = "dwarf-with-dsym"; ENABLE_NS_ASSERTIONS = NO; MTL_ENABLE_DEBUG_INFO = NO; SWIFT_COMPILATION_MODE = wholemodule; }}; name = Release; }};')
    W("/* End XCBuildConfiguration section */")
    W("")

    # XCConfigurationList
    W("/* Begin XCConfigurationList section */")
    W(f'\t\t{CFG_LIST_PROJ} /* Build configuration list for PBXProject */ = {{isa = XCConfigurationList; buildConfigurations = ({DBG_CFG} /* Debug */, {REL_CFG} /* Release */); defaultConfigurationIsVisible = 0; defaultConfigurationName = Release; }};')
    W(f'\t\t{CFG_LIST_TGT} /* Build configuration list for PBXNativeTarget */ = {{isa = XCConfigurationList; buildConfigurations = ({DBG_CFG} /* Debug */, {REL_CFG} /* Release */); defaultConfigurationIsVisible = 0; defaultConfigurationName = Release; }};')
    W("/* End XCConfigurationList section */")
    W("")

    W("\t};")
    W(f'\trootObject = {PROJ_UUID} /* Project object */;')
    W("}")

    # 写入
    os.makedirs("FileConverter.xcodeproj", exist_ok=True)
    path = "FileConverter.xcodeproj/project.pbxproj"
    with open(path, "w") as f:
        f.write("\n".join(out) + "\n")

    # 同时创建 project.xcworkspace（Xcode 16 必须）
    ws_dir = "FileConverter.xcodeproj/project.xcworkspace"
    os.makedirs(ws_dir, exist_ok=True)

    # 最小 xcworkspace 内容
    with open(f"{ws_dir}/contents.xcworkspacedata", "w") as f:
        f.write('<?xml version="1.0" encoding="UTF-8"?>\n<Workspace version="1.0">\n</Workspace>\n')

    print(f"✅ 生成完成 ({len(file_refs)} 个文件, {len(groups)} 个组)")

if __name__ == "__main__":
    gen()
