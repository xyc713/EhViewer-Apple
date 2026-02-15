//
//  GalleryCache.swift
//  ehviewer apple
//
//  内存缓存层 — 对标 Android LruCache<Long, GalleryDetail> + 画廊列表缓存
//  避免切换 Tab / 返回时重复网络请求
//

import Foundation
import EhModels

/// 全局画廊缓存 (线程安全)
final class GalleryCache: @unchecked Sendable {
    static let shared = GalleryCache()

    // MARK: - Gallery Detail Cache (对标 Android LruCache<Long, GalleryDetail>, 容量 25)

    private let detailCache = NSCache<NSNumber, GalleryDetailWrapper>()

    // MARK: - Gallery List Cache (按 URL/mode 缓存列表页结果)

    private let listCache = NSCache<NSString, GalleryListResultWrapper>()

    // MARK: - Image URL Cache (缓存已解析的图片 URL, 避免重复请求页面 HTML)

    private let imageURLCache = NSCache<NSString, NSString>()

    private init() {
        // 对标 Android: LruCache<>(25) for detail
        detailCache.countLimit = 25
        // 列表缓存: 最多保留 20 个不同查询的结果
        listCache.countLimit = 20
        // 图片 URL 缓存: 最多 500 条
        imageURLCache.countLimit = 500
    }

    // MARK: - Detail

    func getDetail(gid: Int64) -> GalleryDetail? {
        detailCache.object(forKey: NSNumber(value: gid))?.value
    }

    func putDetail(_ detail: GalleryDetail) {
        detailCache.setObject(GalleryDetailWrapper(detail), forKey: NSNumber(value: detail.info.gid))
    }

    func removeDetail(gid: Int64) {
        detailCache.removeObject(forKey: NSNumber(value: gid))
    }

    // MARK: - Gallery List

    /// 缓存 key = URL string (去掉 page 参数) + page
    func getListResult(forKey key: String) -> CachedGalleryListResult? {
        guard let wrapper = listCache.object(forKey: key as NSString) else { return nil }
        // 缓存有效期: 5 分钟
        if Date().timeIntervalSince(wrapper.timestamp) > 300 {
            listCache.removeObject(forKey: key as NSString)
            return nil
        }
        return wrapper.value
    }

    func putListResult(_ result: CachedGalleryListResult, forKey key: String) {
        listCache.setObject(GalleryListResultWrapper(result), forKey: key as NSString)
    }

    func removeListResult(forKey key: String) {
        listCache.removeObject(forKey: key as NSString)
    }

    // MARK: - Image URL

    /// key = "gid:pageIndex"
    func getImageURL(gid: Int64, page: Int) -> String? {
        let key = "\(gid):\(page)" as NSString
        return imageURLCache.object(forKey: key) as? String
    }

    func putImageURL(_ url: String, gid: Int64, page: Int) {
        let key = "\(gid):\(page)" as NSString
        imageURLCache.setObject(url as NSString, forKey: key)
    }

    func removeImageURL(gid: Int64, page: Int) {
        let key = "\(gid):\(page)" as NSString
        imageURLCache.removeObject(forKey: key)
    }

    // MARK: - Clear

    func clearAll() {
        detailCache.removeAllObjects()
        listCache.removeAllObjects()
        imageURLCache.removeAllObjects()
    }

    func clearListCache() {
        listCache.removeAllObjects()
    }
}

// MARK: - Wrapper Types (NSCache 需要 class 类型)

private final class GalleryDetailWrapper: NSObject {
    let value: GalleryDetail
    init(_ value: GalleryDetail) { self.value = value }
}

struct CachedGalleryListResult {
    let galleries: [GalleryInfo]
    let hasMore: Bool
    let nextPage: Int?
    let totalPages: Int? // 对齐 Android: GalleryListResult.pages
}

private final class GalleryListResultWrapper: NSObject {
    let value: CachedGalleryListResult
    let timestamp: Date
    init(_ value: CachedGalleryListResult) {
        self.value = value
        self.timestamp = Date()
    }
}
