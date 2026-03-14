// RepoAnalyzer.swift — Repo type detection for landmark assignment
// Determines what type of project a repo is by analyzing directory
// structure and file extensions (shallow scan, no git log needed).
// Detection heuristics checked in priority order (first match wins).
//
// This is P3-T1-08: Landmark Generation from Repo Analysis.

import Foundation

// MARK: - Repo Analysis

extension LandmarkSystem {

    /// Analyzes a repo path to determine its type.
    /// Shallow scan — checks directory structure and file extensions.
    /// Detection heuristics checked in priority order (first match wins).
    ///
    /// - Parameter repoPath: Path to the git repository root.
    /// - Returns: The detected repo type.
    static func analyzeRepo(at repoPath: String) -> RepoType {
        let fm = FileManager.default

        // Helper: check if file/dir exists at path
        func exists(_ relative: String) -> Bool {
            fm.fileExists(atPath: (repoPath as NSString)
                .appendingPathComponent(relative))
        }

        // Helper: check if any file with extension exists (shallow)
        func hasExtension(_ ext: String) -> Bool {
            guard let contents = try? fm.contentsOfDirectory(atPath: repoPath)
            else { return false }
            return contents.contains { $0.hasSuffix(ext) }
        }

        // Helper: check directory contents recursively (1 level deep)
        func hasFileInSubdirs(_ ext: String) -> Bool {
            guard let contents = try? fm.contentsOfDirectory(atPath: repoPath)
            else { return false }
            for item in contents {
                let fullPath = (repoPath as NSString)
                    .appendingPathComponent(item)
                var isDir: ObjCBool = false
                if fm.fileExists(atPath: fullPath, isDirectory: &isDir),
                   isDir.boolValue {
                    if let subContents = try? fm.contentsOfDirectory(
                        atPath: fullPath
                    ) {
                        if subContents.contains(where: {
                            $0.hasSuffix(ext)
                        }) {
                            return true
                        }
                    }
                }
            }
            return false
        }

        // 1. Web app: has package.json AND .tsx/.jsx/.vue/.svelte
        if exists("package.json") {
            let webExts = [".tsx", ".jsx", ".vue", ".svelte"]
            for ext in webExts {
                if hasExtension(ext) || hasFileInSubdirs(ext) {
                    return .webApp
                }
            }
        }

        // 2. Infra/DevOps
        if hasExtension(".tf") || exists("Dockerfile")
            || exists(".github/workflows") {
            return .infraDevOps
        }

        // 3. Data/ML
        if hasExtension(".ipynb") || hasFileInSubdirs(".ipynb")
            || exists("models") {
            return .dataML
        }

        // 4. API/backend
        if exists("routes") || exists("controllers") || exists("app") {
            if exists("package.json") || hasExtension(".py")
                || hasExtension(".rb") || hasExtension(".php")
                || hasExtension(".go") {
                return .apiBackend
            }
        }

        // 5. CLI tool
        if exists("bin") || exists("main.go") || exists("src/main.rs")
            || exists("src/main.ts") {
            return .cliTool
        }

        // 6. Library
        if exists("lib") {
            if exists(".npmrc") || exists("setup.py")
                || exists("Cargo.toml") || exists("Package.swift") {
                return .library
            }
        }

        // 7. Game/creative
        let gameIndicators = [".unity", ".godot", "SpriteKit", "SDL"]
        for indicator in gameIndicators {
            if exists(indicator) || hasExtension(indicator) {
                return .gameCreative
            }
        }

        // 8. Docs — majority of files are documentation
        if let contents = try? fm.contentsOfDirectory(atPath: repoPath) {
            let docExts = [".md", ".txt", ".rst", ".tex", ".adoc"]
            let docCount = contents.filter { file in
                docExts.contains { file.hasSuffix($0) }
            }.count
            if docCount > contents.count / 2 && contents.count > 2 {
                return .docsContent
            }
        }

        // 9. Generic fallback
        return .generic
    }
}
