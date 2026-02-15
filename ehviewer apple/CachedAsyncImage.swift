//
//  CachedAsyncImage.swift
//  ehviewer apple
//
//  带磁盘缓存的异步图片视图 — AsyncImage 不总是正确使用 URLCache
//  对标 Android Conaco 图片加载库的内存+磁盘双缓存
//

import SwiftUI
#if os(macOS)
import AppKit
#else
import UIKit
#endif

/// 共享 URLSession — 避免每次 load() 创建新 session (连接池/DNS 复用显著提速)
private enum ImageSessionProvider {
    static let shared: URLSession = {
        let config = URLSessionConfiguration.default
        config.httpCookieStorage = .shared
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 120
        config.httpMaximumConnectionsPerHost = 6
        // 使用全局 URLCache (与 App init 中配置的 320MB 磁盘缓存一致)
        config.urlCache = URLCache.shared
        config.requestCachePolicy = .returnCacheDataElseLoad
        return URLSession(configuration: config)
    }()
}

/// 内存图片缓存 — 避免重复解码已下载的图片
private final class ThumbnailMemoryCache: @unchecked Sendable {
    static let shared = ThumbnailMemoryCache()
    private let cache = NSCache<NSURL, PlatformImage>()
    private init() {
        cache.countLimit = 200
        cache.totalCostLimit = 50 * 1024 * 1024  // 50MB
    }
    func get(_ url: URL) -> PlatformImage? { cache.object(forKey: url as NSURL) }
    func set(_ image: PlatformImage, for url: URL) {
        let cost = image.size.width * image.size.height * 4
        cache.setObject(image, forKey: url as NSURL, cost: Int(cost))
    }
}

/// 缓存友好的异步图片加载器
/// AsyncImage 内部使用的 URLSession 可能不尊重 URLCache，
/// 本组件使用共享的 URLSession 确保缓存命中
struct CachedAsyncImage<Content: View, Placeholder: View>: View {
    let url: URL?
    let showProgress: Bool
    @ViewBuilder let content: (Image) -> Content
    @ViewBuilder let placeholder: () -> Placeholder

    @State private var image: PlatformImage?
    @State private var isLoading = false
    @State private var hasFailed = false
    @State private var progress: Double = 0
    @State private var receivedBytes: Int64 = 0  // 已接收字节数
    @State private var hasContentLength: Bool = false  // 服务器是否返回了 Content-Length

    init(
        url: URL?,
        showProgress: Bool = true,
        @ViewBuilder content: @escaping (Image) -> Content,
        @ViewBuilder placeholder: @escaping () -> Placeholder
    ) {
        self.url = url
        self.showProgress = showProgress
        self.content = content
        self.placeholder = placeholder
    }

    var body: some View {
        Group {
            if let image {
                #if os(macOS)
                content(Image(nsImage: image))
                #else
                content(Image(uiImage: image))
                #endif
            } else if hasFailed {
                placeholder()
            } else {
                ZStack {
                    placeholder()
                    if isLoading && showProgress {
                        if hasContentLength && progress > 0 && progress < 1 {
                            // 有 Content-Length：显示百分比进度
                            ProgressView(value: progress)
                                .progressViewStyle(CircularProgressStyle())
                                .frame(width: 40, height: 40)
                        } else if receivedBytes > 0 {
                            // 无 Content-Length：显示已下载大小
                            BytesProgressView(bytes: receivedBytes)
                                .frame(width: 48, height: 48)
                        } else {
                            // 刚开始：转圈
                            ProgressView()
                                .frame(width: 24, height: 24)
                        }
                    } else if isLoading {
                        ProgressView()
                            .frame(width: 24, height: 24)
                    }
                }
                .task(id: url) {
                    await load()
                }
            }
        }
    }

    private func load() async {
        guard let url, !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        // 1. 内存图片缓存 (最快, 避免重复解码)
        if let memCached = ThumbnailMemoryCache.shared.get(url) {
            await MainActor.run { self.image = memCached }
            return
        }

        // 2. URLCache 磁盘缓存
        let request = URLRequest(url: url, cachePolicy: .returnCacheDataElseLoad)
        if let cached = URLCache.shared.cachedResponse(for: request),
           let img = PlatformImage(data: cached.data) {
            ThumbnailMemoryCache.shared.set(img, for: url)
            await MainActor.run { self.image = img }
            return
        }

        do {
            let (bytes, response) = try await ImageSessionProvider.shared.bytes(for: request)
            let expectedLength = response.expectedContentLength
            var data = Data()
            if expectedLength > 0 {
                data.reserveCapacity(Int(expectedLength))
                await MainActor.run { self.hasContentLength = true }
            }
            
            var receivedLength: Int64 = 0
            for try await byte in bytes {
                data.append(byte)
                receivedLength += 1
                
                // 每 4KB 更新一次进度 (减少 MainActor 调度开销)
                if receivedLength % 4096 == 0 {
                    if expectedLength > 0 {
                        let newProgress = Double(receivedLength) / Double(expectedLength)
                        await MainActor.run { self.progress = newProgress }
                    } else {
                        await MainActor.run { self.receivedBytes = receivedLength }
                    }
                }
            }
            
            // 缓存响应
            let cachedResponse = CachedURLResponse(response: response, data: data)
            URLCache.shared.storeCachedResponse(cachedResponse, for: request)
            
            if let img = PlatformImage(data: data) {
                ThumbnailMemoryCache.shared.set(img, for: url)
                await MainActor.run { self.image = img }
            } else {
                await MainActor.run { self.hasFailed = true }
            }
        } catch {
            print("[CachedAsyncImage] Failed to load \(url.absoluteString): \(error)")
            await MainActor.run { self.hasFailed = true }
        }
    }
}

/// 圆形进度样式，显示百分比
struct CircularProgressStyle: ProgressViewStyle {
    func makeBody(configuration: Configuration) -> some View {
        let progress = configuration.fractionCompleted ?? 0
        
        ZStack {
            Circle()
                .fill(Color.black.opacity(0.5))
            
            Circle()
                .trim(from: 0, to: progress)
                .stroke(Color.white, lineWidth: 3)
                .rotationEffect(.degrees(-90))
                .padding(4)
            
            Text("\(Int(progress * 100))%")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.white)
        }
    }
}

/// 无 Content-Length 时显示已下载字节数
struct BytesProgressView: View {
    let bytes: Int64
    
    var body: some View {
        ZStack {
            Circle()
                .fill(Color.black.opacity(0.5))
            
            // 旋转动画的圆弧表示加载中
            Circle()
                .trim(from: 0, to: 0.3)
                .stroke(Color.white, lineWidth: 3)
                .rotationEffect(.degrees(-90))
                .padding(4)
                .rotationEffect(.degrees(Double.random(in: 0...360)))
            
            Text(formattedBytes)
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(.white)
        }
    }
    
    private var formattedBytes: String {
        if bytes < 1024 {
            return "\(bytes)B"
        } else if bytes < 1024 * 1024 {
            return String(format: "%.0fK", Double(bytes) / 1024)
        } else {
            return String(format: "%.1fM", Double(bytes) / (1024 * 1024))
        }
    }
}

#if os(macOS)
typealias PlatformImage = NSImage
#else
typealias PlatformImage = UIImage
#endif
